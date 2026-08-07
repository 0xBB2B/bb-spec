import { describe, expect, test } from "bun:test"
import { mkdtempSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { bunGuard, gitGuard, versionFileHit } from "./guards"

const HOME = "/home/u"
const onMain = async () => "main"
const onFeat = async () => "feat/x"

describe("gitGuard", () => {
  test("main 分支 commit → deny", async () => {
    expect((await gitGuard('git commit -m "x"', HOME, onMain)).deny).toEqual({ kind: "branch", branch: "main" })
  })
  test("功能分支 commit → 放行", async () => {
    expect((await gitGuard('git commit -m "x"', HOME, onFeat)).deny).toBeUndefined()
  })
  test("复合命令逐段识别", async () => {
    expect((await gitGuard("cd /tmp && git commit -m x", HOME, onMain)).deny).toEqual({ kind: "branch", branch: "main" })
  })
  test("剥 env / sudo 前缀", async () => {
    expect((await gitGuard("FOO=1 sudo git commit -m x", HOME, onMain)).deny).toEqual({ kind: "branch", branch: "main" })
  })
  test("worktree add 路径不在 ~/.bb-spec/worktrees/ → deny", async () => {
    expect((await gitGuard("git worktree add ../side -b b main", HOME, onFeat)).deny).toEqual({
      kind: "worktree-path",
      path: "../side",
    })
  })
  test("worktree add 合规路径（~ 展开）→ 放行", async () => {
    expect((await gitGuard("git worktree add ~/.bb-spec/worktrees/r-b -b b main", HOME, onFeat)).deny).toBeUndefined()
  })
  test("worktree add 合规路径（$HOME 字面 token 展开）→ 放行", async () => {
    expect((await gitGuard("git worktree add $HOME/.bb-spec/worktrees/x -b b main", HOME, onFeat)).deny).toBeUndefined()
  })
  test("worktree add 取值 flag 在前 → 正确取路径", async () => {
    expect((await gitGuard("git worktree add -b b ~/.bb-spec/worktrees/r-b main", HOME, onFeat)).deny).toBeUndefined()
  })
  test("worktree list 放行", async () => {
    expect((await gitGuard("git worktree list", HOME, onFeat)).deny).toBeUndefined()
  })
  test("push 是流程动作", async () => {
    expect((await gitGuard("git push origin x", HOME, onFeat)).flow).toBe(true)
  })
  test("status 非流程动作", async () => {
    expect((await gitGuard("git status", HOME, onFeat)).flow).toBe(false)
  })
  test("gh pr 是流程动作", async () => {
    expect((await gitGuard("gh pr create", HOME, onFeat)).flow).toBe(true)
  })
  test("git -C 用指定目录查分支", async () => {
    const guard = await gitGuard("git -C /x/y commit -m z", HOME, async (d) => (d === "/x/y" ? "master" : "feat"))
    expect(guard.deny).toEqual({ kind: "branch", branch: "master" })
  })

  function recordingBranch(map: Record<string, string>) {
    const calls: string[] = []
    const fn = async (dir: string) => {
      calls.push(dir)
      return map[dir] ?? "unknown"
    }
    return { fn, calls }
  }

  test("cd 到功能分支目录后 commit → 放行（判定用推导目录而非会话目录）", async () => {
    const { fn } = recordingBranch({ ".": "main", "/feat": "feat-x" })
    const guard = await gitGuard("cd /feat && git commit -m m", HOME, fn)
    expect(guard.deny).toBeUndefined()
  })

  test("会话目录在功能分支，cd 到 main 分支目录后 commit → deny", async () => {
    const { fn } = recordingBranch({ ".": "feat-x", "/main-repo": "main" })
    const guard = await gitGuard("cd /main-repo && git commit -m m", HOME, fn)
    expect(guard.deny).toEqual({ kind: "branch", branch: "main" })
  })

  test("-C 路径含未展开变量 → 回退会话目录且 fallback=true", async () => {
    const { fn } = recordingBranch({ ".": "main" })
    const guard = await gitGuard('git -C "$WT" commit -m m', HOME, fn)
    expect(guard.fallback).toBe(true)
    expect(guard.deny).toEqual({ kind: "branch", branch: "main" })
  })

  test("-C 字面量路径指向功能分支 → 放行", async () => {
    const { fn } = recordingBranch({ "/repo-feat": "feat-x" })
    const guard = await gitGuard("git -C /repo-feat commit -m m", HOME, fn)
    expect(guard.deny).toBeUndefined()
  })

  test("-C 带双引号路径 → 剥离引号后按实际路径判定", async () => {
    const { fn, calls } = recordingBranch({ "/repo-feat": "feat-x" })
    const guard = await gitGuard('git -C "/repo-feat" commit -m m', HOME, fn)
    expect(calls).toEqual(["/repo-feat"])
    expect(guard.deny).toBeUndefined()
  })

  test("cd 后 -C 相对路径 → 基于推导目录拼接", async () => {
    const { fn, calls } = recordingBranch({ "/base/sub": "feat-x" })
    const guard = await gitGuard("cd /base && git -C sub commit -m m", HOME, fn)
    expect(calls).toEqual(["/base/sub"])
    expect(guard.deny).toBeUndefined()
  })

  test("cd 到功能分支目录后 push → 状态注入目录为该目录而非会话目录", async () => {
    const { fn } = recordingBranch({})
    const guard = await gitGuard("cd /feat && git push", HOME, fn)
    expect(guard.statusDir).toBe("/feat")
  })

  test("~ 展开：cd ~/proj 后 commit 定位到展开后目录", async () => {
    const { fn, calls } = recordingBranch({ "/home/u/proj": "feat-x" })
    const guard = await gitGuard("cd ~/proj && git commit -m m", HOME, fn)
    expect(calls).toEqual(["/home/u/proj"])
    expect(guard.deny).toBeUndefined()
  })

  test("-C 不污染后续段：commit 用 -C 目录，push 状态用会话目录", async () => {
    const { fn } = recordingBranch({ "/wt": "feat-x" })
    const guard = await gitGuard("git -C /wt commit -m m && git push", HOME, fn)
    expect(guard.statusDir).toBe(".")
  })

  test("cd $HOME/<相对路径> → 展开后按实际目录判定，不回退", async () => {
    const { fn, calls } = recordingBranch({ "/home/u/proj": "feat-x" })
    const guard = await gitGuard("cd $HOME/proj && git commit -m m", HOME, fn)
    expect(guard.fallback).toBe(false)
    expect(calls).toEqual(["/home/u/proj"])
    expect(guard.deny).toBeUndefined()
  })

  test("git -C $HOME/<路径> commit → 展开后按实际目录判定，不回退", async () => {
    const { fn, calls } = recordingBranch({ "/home/u/proj2": "feat-x" })
    const guard = await gitGuard("git -C $HOME/proj2 commit -m m", HOME, fn)
    expect(guard.fallback).toBe(false)
    expect(calls).toEqual(["/home/u/proj2"])
    expect(guard.deny).toBeUndefined()
  })

  test("cd $HOME（单独 token）→ 展开为 home 且不回退", async () => {
    const { fn, calls } = recordingBranch({ "/home/u": "feat-x" })
    const guard = await gitGuard("cd $HOME && git commit -m m", HOME, fn)
    expect(guard.fallback).toBe(false)
    expect(calls).toEqual(["/home/u"])
    expect(guard.deny).toBeUndefined()
  })

  test("$HOMEBREW_PREFIX 类变量不得被当作 $HOME 前缀子串展开 → 回退会话目录", async () => {
    const { fn } = recordingBranch({ ".": "main" })
    const guard = await gitGuard("cd $HOMEBREW_PREFIX/repo && git commit -m m", HOME, fn)
    expect(guard.fallback).toBe(true)
    expect(guard.deny).toEqual({ kind: "branch", branch: "main" })
  })

  test("deny 由早前回退段产生，其后合法段不冲掉 fallback 说明", async () => {
    const { fn } = recordingBranch({ ".": "main", "/legit": "feat-x" })
    const guard = await gitGuard("cd $V && git commit -m m && git -C /legit push", HOME, fn)
    expect(guard.deny).toEqual({ kind: "branch", branch: "main" })
    expect(guard.fallback).toBe(true)
  })

  test("cd 无法解析的变量 → 回退会话目录，fallback=true 且按会话目录分支判定", async () => {
    const { fn } = recordingBranch({ ".": "main" })
    const guard = await gitGuard("cd $WT && git commit -m m", HOME, fn)
    expect(guard.fallback).toBe(true)
    expect(guard.deny).toEqual({ kind: "branch", branch: "main" })
  })

  test("git -C <path> worktree add <非法路径> → deny（-C 与 worktree 组合正确解析）", async () => {
    const { fn } = recordingBranch({})
    const guard = await gitGuard("git -C /some/repo worktree add /outside -b b main", HOME, fn)
    expect(guard.deny).toEqual({ kind: "worktree-path", path: "/outside" })
  })

  test("cd 无法解析的变量后又 cd 到合法目录 → fallback 不外溢", async () => {
    const { fn } = recordingBranch({ "/feat": "feat-x" })
    const guard = await gitGuard("cd $V && cd /feat && git push", HOME, fn)
    expect(guard.fallback).toBe(false)
    expect(guard.statusDir).toBe("/feat")
  })

  test("cd 无参数 → 等价于 cd $HOME", async () => {
    const { fn, calls } = recordingBranch({ "/home/u": "feat-x" })
    const guard = await gitGuard("cd && git commit -m m", HOME, fn)
    expect(calls).toEqual(["/home/u"])
    expect(guard.deny).toBeUndefined()
  })
})

describe("bunGuard", () => {
  const dir = mkdtempSync(join(tmpdir(), "bun-guard-"))
  test("npm install → deny 并给 bun 替代", () => {
    expect(bunGuard("npm install lodash", dir)).toContain("bun")
  })
  test("npm run 脚本执行 → 放行", () => {
    expect(bunGuard("npm run test", dir)).toBeNull()
  })
  test("裸 yarn 默认 install → deny", () => {
    expect(bunGuard("yarn", dir)).toContain("bun")
  })
  test("pnpm add → deny", () => {
    expect(bunGuard("pnpm add x", dir)).toContain("bun")
  })
  test("bun 自身放行", () => {
    expect(bunGuard("bun add x", dir)).toBeNull()
  })
  test("既有项目跟随 lockfile：有 package-lock.json 放行 npm", async () => {
    const locked = mkdtempSync(join(tmpdir(), "bun-guard-locked-"))
    await Bun.write(join(locked, "package-lock.json"), "{}")
    expect(bunGuard("npm install", locked)).toBeNull()
  })
})

describe("versionFileHit", () => {
  test.each([
    ["/a/b/package.json", true],
    ["/a/go.mod", true],
    ["/a/Dockerfile.dev", true],
    ["/r/.github/workflows/ci.yml", true],
    ["/x/main.tf", true],
    ["/x/requirements-dev.txt", true],
    ["/x/main.go", false],
    ["/x/README.md", false],
  ])("%s → %p", (path, want) => {
    expect(versionFileHit(path as string)).toBe(want as boolean)
  })
})
