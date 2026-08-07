import { describe, expect, test } from "bun:test"
import { BbSpec } from "./index"

describe("config 钩子：agent 注册与默认 agent", () => {
  async function runConfig(initial: Record<string, any> = {}) {
    const hooks = await BbSpec({
      directory: "/tmp",
      $: {} as any,
    } as any)
    const cfg = initial
    await hooks.config?.(cfg as any)
    return cfg
  }

  test("manager 注册为 primary agent 且成为 default_agent", async () => {
    const cfg = await runConfig()
    expect(cfg.agent.manager.mode).toBe("primary")
    expect(cfg.agent.manager.permission).toEqual({ edit: "allow", bash: "allow" })
    expect(cfg.default_agent).toBe("manager")
  })

  test("subagent 仍带 bb-spec- 前缀且 edit:deny 硬化", async () => {
    const cfg = await runConfig()
    expect(cfg.agent["bb-spec-spec-reviewer"].mode).toBe("subagent")
    expect(cfg.agent["bb-spec-spec-reviewer"].permission).toEqual({ edit: "deny" })
    expect(cfg.agent["bb-spec-impl-engineer"].permission).toBeUndefined()
  })

  test("用户预设 default_agent 时不覆盖", async () => {
    const cfg = await runConfig({ default_agent: "plan" })
    expect(cfg.default_agent).toBe("plan")
  })
})

describe("tool.execute.after 钩子：git 状态查询的目录锚点", () => {
  test("cd 相对路径场景，状态查询目录基于会话 directory 拼接为绝对路径而非裸相对路径", async () => {
    const dirs: string[] = []
    const $ = ((_strings: TemplateStringsArray, ...values: unknown[]) => {
      dirs.push(String(values[0]))
      return { quiet: () => ({ nothrow: () => ({ text: async () => "feat-x\n" }) }) }
    }) as any
    const hooks = await BbSpec({ directory: "/session/repo", $ } as any)
    await hooks["tool.execute.after"]?.(
      { tool: "bash", args: { command: "cd sub && git commit -m m" } } as any,
      { output: "" } as any,
    )
    expect(dirs).not.toContain("sub")
    expect(dirs).toContain("/session/repo/sub")
  })
})
