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
