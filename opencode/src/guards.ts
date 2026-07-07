import { existsSync } from "node:fs"
import { dirname, join } from "node:path"

const FLOW_GIT_VERBS = new Set([
  "commit",
  "push",
  "switch",
  "checkout",
  "branch",
  "worktree",
  "merge",
  "rebase",
  "cherry-pick",
])

export interface GitGuardResult {
  flow: boolean
  gitCPath: string
  deny?: { kind: "branch"; branch: string } | { kind: "worktree-path"; path: string }
}

function splitSegments(command: string): string[] {
  return command
    .split(/\s*(?:&&|\|\||;|\n)\s*/)
    .map((s) => s.trim())
    .filter(Boolean)
}

function stripPrefixes(tokens: string[]): string[] {
  let i = 0
  while (i < tokens.length && (/^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i]) || tokens[i] === "sudo" || tokens[i] === "nohup")) {
    i++
  }
  return tokens.slice(i)
}

function expandHome(p: string, home: string): string {
  let out = p
  if (out === "~") out = home
  else if (out.startsWith("~/")) out = `${home}/${out.slice(2)}`
  return out.replaceAll("$HOME", home)
}

export async function gitGuard(
  command: string,
  home: string,
  getBranch: (dir: string) => Promise<string>,
): Promise<GitGuardResult> {
  const result: GitGuardResult = { flow: false, gitCPath: "" }

  for (const seg of splitSegments(command)) {
    const tokens = stripPrefixes(seg.split(/\s+/))
    const first = tokens[0]
    if (first === "gh") {
      if (tokens[1] === "pr") result.flow = true
      continue
    }
    if (first !== "git") continue

    let rest = tokens.slice(1)
    let segC = ""
    if (rest[0] === "-C" && rest[1]) {
      segC = rest[1]
      rest = rest.slice(2)
    }
    const verb = rest[0]
    if (!verb || !FLOW_GIT_VERBS.has(verb)) continue

    result.flow = true
    if (segC) result.gitCPath = segC

    if (verb === "commit") {
      const branch = await getBranch(segC || ".")
      if (branch === "main" || branch === "master") {
        result.deny = { kind: "branch", branch }
      }
    }

    if (verb === "worktree" && rest[1] === "add") {
      // 从 add 后的 token 流里找到第一个「非 flag 且非 flag 取值」的 token = 目标路径
      const args = rest.slice(2)
      let wtPath = ""
      for (let i = 0; i < args.length; i++) {
        const t = args[i]
        if (t === "-b" || t === "-B" || t === "--reason") {
          i++
          continue
        }
        if (t.startsWith("-")) continue
        wtPath = t
        break
      }
      if (wtPath) {
        const expanded = expandHome(wtPath, home)
        if (!expanded.startsWith(`${home}/.bb-spec/worktrees/`)) {
          result.deny = { kind: "worktree-path", path: expanded }
        }
      }
    }
  }
  return result
}

const PM_BLOCK: Record<string, { subs: Set<string>; suggest: string; lockfile: string; defaultInstall: boolean }> = {
  npm: {
    subs: new Set(["install", "i", "add", "ci", "isntall", "uninstall", "un", "rm", "remove", "update", "up", "upgrade"]),
    suggest: "bun add / bun install / bun remove / bun update",
    lockfile: "package-lock.json",
    defaultInstall: false,
  },
  yarn: {
    subs: new Set(["install", "add", "remove", "upgrade", "upgrade-interactive"]),
    suggest: "bun install / bun add / bun remove / bun update",
    lockfile: "yarn.lock",
    defaultInstall: true,
  },
  pnpm: {
    subs: new Set(["install", "i", "add", "remove", "rm", "un", "uninstall", "update", "up", "upgrade"]),
    suggest: "bun install / bun add / bun remove / bun update",
    lockfile: "pnpm-lock.yaml",
    defaultInstall: true,
  },
}

export function bunGuard(command: string, cwd: string): string | null {
  for (const seg of splitSegments(command)) {
    const tokens = stripPrefixes(seg.split(/\s+/))
    const first = tokens[0]
    const rule = first ? PM_BLOCK[first] : undefined
    if (!rule) continue

    const sub = tokens[1]
    const blocked = sub ? rule.subs.has(sub) : rule.defaultInstall
    if (!blocked) continue

    // 既有项目跟随现存 lockfile：向上找到匹配 lockfile 即放行；越过 .git 或到根目录为止
    let dir = cwd
    let found = false
    for (;;) {
      if (existsSync(join(dir, rule.lockfile))) {
        found = true
        break
      }
      if (existsSync(join(dir, ".git"))) break
      const parent = dirname(dir)
      if (parent === dir) break
      dir = parent
    }
    if (found) continue

    return `前端约束（vue-constraints）：禁止使用 ${first} 做包管理动作，请改用 bun 等价命令：${rule.suggest}。如确实需要保留原命令，请在本回合明确说明理由再继续。`
  }
  return null
}

const VERSION_FILE_NAMES = new Set([
  "package.json",
  "go.mod",
  "requirements.txt",
  "Pipfile",
  "pyproject.toml",
  "Cargo.toml",
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  ".nvmrc",
  ".tool-versions",
  "Chart.yaml",
  ".python-version",
  "Gemfile",
  "docker-compose.yml",
  "docker-compose.yaml",
  "compose.yml",
  "compose.yaml",
])

export function versionFileHit(filePath: string): boolean {
  const base = filePath.split("/").pop() ?? ""
  if (VERSION_FILE_NAMES.has(base)) return true
  if (base === "Dockerfile" || base.startsWith("Dockerfile.") || base.endsWith(".dockerfile")) return true
  if (/^requirements[-_].+\.txt$/.test(base)) return true
  if (/\.github\/workflows\/[^/]+\.ya?ml$/.test(filePath)) return true
  if (/\.gitlab-ci\.ya?ml$/.test(filePath)) return true
  if (base.endsWith(".tf") || base.endsWith(".tf.json")) return true
  return false
}
