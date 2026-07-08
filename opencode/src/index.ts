import type { Plugin } from "@opencode-ai/plugin"
import { readFileSync, readdirSync } from "node:fs"
import { basename, dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { bunGuard, gitGuard, versionFileHit } from "./guards"

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..")
const SKILL_DOMAINS = ["core", "backend", "frontend", "product", "workflow"]

// 原 Claude Code 版中 prompt 明示「禁止修改文件」的 agent，用权限硬化
const EDIT_ALLOWED_AGENTS = new Set(["impl-engineer", "test-engineer"])

const COMMANDS: Record<string, { description: string; skill: string; hint?: string }> = {
  prd: { description: "PRD 头脑风暴与文档化：质疑→发散→收敛→产出自包含 PRD", skill: "prd", hint: "<想法或需求描述>" },
  spec: { description: "需求拆解与文档化：澄清→拆解→落盘一文一规则的小规则 spec", skill: "spec" },
  plan: { description: "读 spec + 项目代码结构，产出函数级实施计划", skill: "plan" },
  exec: { description: "三 Agent 隔离执行 plan：Test→Impl→Review 串行，断点续接", skill: "exec", hint: "<YYYY-MM-DD.主题>[/<plan名>]" },
  revise: { description: "产出修订：诊断→定向修正→回归验证", skill: "revise", hint: "<问题或优化诉求描述>" },
  review: { description: "多代理对抗 review：并发 finder + 对抗验证", skill: "review", hint: "[base-branch] [本次 review 重点...]" },
  "git-push": { description: "推送本地代码到远程并开 PR 全流程", skill: "git-push" },
  "git-clone": { description: "clone 远程仓库到本地并落 .bb-spec.yaml", skill: "git-clone", hint: "<repo-url>..." },
  "doc-update": { description: "全仓 spec/文档/代码一致性维护", skill: "doc-update", hint: "[可选：限定范围]" },
  "test-api": { description: "后端 API e2e 测试：md 用例渲染 Bun TS runner", skill: "test-api", hint: "[scope]" },
  "test-webview": { description: "网页交互用例执行：真实浏览器驱动", skill: "test-webview", hint: "[category]" },
}

const GIT_DISCIPLINE = `[git-workflow 纪律] 本次涉及 git 流程操作。执行前请遵循 bb-spec 的 git-workflow skill（若尚未加载，先用 skill 工具加载再操作）。核心约束：
- 开新任务先与用户确认开分支方式（默认 worktree），禁止在 main 直接开发 / 提交。
- 阶段性 commit 后不立即 push；仅当功能本地完成 + 测试通过 + 用户确认后才推送。
- 开 PR 用六段式描述；PR 合并后清理本地分支 + 远程引用。`

const SELF_CHECK = `任务结束前必须完成下列自检，逐条核对后才能停下。如本回合未涉及编码改动，仅口头核对即可：

1. **临时文件清理**：列出本次任务产生的任何临时文件（测试输出、日志、缓存、临时打包文件等），并确认已清理；未清理的请立即清理。
2. **改动范围**：检查本次 diff 是否仅限本次需求所必须，是否混入了"顺手优化"/无关重构/相邻代码风格调整。若有，回滚无关改动。
3. **孤立残留**：本次改动导致的不再使用的 import / 变量 / 函数是否已清掉。
4. **历史包袱**：是否在文档或代码里写了"保留原 X 以兼容"/"加注释标记已废弃"/"新旧并列"等过渡式表述。若有，按 No Legacy Baggage 原则直接清掉。

逐条核对完成后，再按下面的简报格式收尾，然后停下：

## 简报
- 已完成：<用一句话说明做了些什么>
- 待解决：<有什么还未解决的问题>
- 下一步：<下一步建议做什么>`

interface AgentDef {
  description: string
  mode: "subagent"
  prompt: string
  permission?: Record<string, string>
}

function loadAgents(): Record<string, AgentDef> {
  const agents: Record<string, AgentDef> = {}
  const dir = join(ROOT, "agents")
  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".md")) continue
    const name = basename(file, ".md")
    const raw = readFileSync(join(dir, file), "utf8")
    const match = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/)
    if (!match) continue
    const description = match[1].match(/^description:\s*(.+)$/m)?.[1]?.trim() ?? name
    const def: AgentDef = { description, mode: "subagent", prompt: match[2].trim() }
    if (!EDIT_ALLOWED_AGENTS.has(name)) def.permission = { edit: "deny" }
    agents[`bb-spec-${name}`] = def
  }
  return agents
}

export const BbSpec: Plugin = async ({ client, $, directory }) => {
  const agents = loadAgents()
  const stopChecked = new Set<string>()

  const getBranch = async (dir: string): Promise<string> => {
    try {
      const out = await $`git -C ${dir === "." ? directory : dir} branch --show-current`.quiet().nothrow().text()
      return out.trim()
    } catch {
      return ""
    }
  }

  return {
    config: async (config) => {
      const cfg = config as Record<string, any>
      cfg.skills ??= {}
      cfg.skills.paths ??= []
      for (const domain of SKILL_DOMAINS) cfg.skills.paths.push(join(ROOT, "skills", domain))

      cfg.agent ??= {}
      for (const [name, def] of Object.entries(agents)) cfg.agent[name] ??= def

      cfg.command ??= {}
      for (const [name, cmd] of Object.entries(COMMANDS)) {
        cfg.command[name] ??= {
          description: cmd.hint ? `${cmd.description}（参数：${cmd.hint}）` : cmd.description,
          template: `先调用 skill 工具加载 bb-spec 的「${cmd.skill}」skill（name: "${cmd.skill}"），然后严格按其流程执行，不得凭记忆简化步骤。\n\n用户输入：$ARGUMENTS`,
        }
      }
    },

    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const command: string = output.args?.command ?? ""
      if (!command) return

      const bunDeny = bunGuard(command, directory)
      if (bunDeny) throw new Error(bunDeny)

      const guard = await gitGuard(command, process.env.HOME ?? "", getBranch)
      if (guard.deny?.kind === "branch") {
        throw new Error(
          `Git 工作流纪律：当前分支为 ${guard.deny.branch}，禁止直接 commit 到主干。请先 \`git switch -c <feature-branch>\` 切到新分支再提交。`,
        )
      }
      if (guard.deny?.kind === "worktree-path") {
        throw new Error(
          `Git 工作流纪律：worktree 必须落在 ~/.bb-spec/worktrees/ 下（单 repo: <repo>-<branch>；多 repo 工作区: <project>-<branch>/<repo>），禁止嵌套当前 repo 或放 sibling 目录。本次目标路径：${guard.deny.path}`,
        )
      }
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool === "bash") {
        const command: string = input.args?.command ?? ""
        if (!command) return
        const guard = await gitGuard(command, process.env.HOME ?? "", async () => "")
        if (!guard.flow) return
        const dir = guard.gitCPath || directory
        const branch = (await getBranch(dir)) || "(detached / 非 git 仓库)"
        let dirty = ""
        try {
          const status = await $`git -C ${dir} status --short`.quiet().nothrow().text()
          dirty = status.split("\n").filter(Boolean).slice(0, 5).join("\n")
        } catch {}
        output.output += `\n\n${GIT_DISCIPLINE}\n\n实时 git 状态：\n- 当前分支：${branch}\n- 工作区：\n${dirty || "(clean)"}`
        return
      }

      const filePath: string = input.args?.filePath ?? ""
      if (!filePath || !versionFileHit(filePath)) return
      output.output += `\n\n依赖版本号自检（version-policy）：刚改动了 \`${filePath}\`。若本次改动写入或更新了任何外部资产的版本号（npm/Go/PyPI/Cargo/Maven/Actions/容器镜像/IaC provider/Helm/CLI 等），请确认每个版本号都通过**官方渠道**查询过最新稳定版（npm view / go list -m -versions / pip index versions / cargo search / docker manifest 等），未凭训练记忆填写。若仅改动非版本字段（脚本、依赖名、配置 key 等），请忽略本提示。`
    },

    "chat.message": async (input, output) => {
      const text = output.parts
        .filter((part: any) => part.type === "text")
        .map((part: any) => part.text)
        .join("\n")
      if (text !== SELF_CHECK) stopChecked.delete(input.sessionID)
    },

    event: async ({ event }) => {
      try {
        const e = event as { type: string; properties?: any }
        if (e.type === "session.deleted") {
          stopChecked.delete(e.properties?.info?.id ?? "")
          return
        }
        if (e.type === "command.executed") {
          stopChecked.delete(e.properties?.sessionID ?? "")
          return
        }
        if (e.type !== "session.idle") return
        const sessionID: string = e.properties?.sessionID ?? ""
        if (!sessionID) return
        if (stopChecked.has(sessionID)) return
        const session = await client.session.get({ path: { id: sessionID } })
        const info = (session as any)?.data ?? session
        if (info?.parentID) return
        stopChecked.add(sessionID)
        await client.session.prompt({
          path: { id: sessionID },
          body: { parts: [{ type: "text", text: SELF_CHECK }] },
        })
      } catch {}
    },
  }
}
