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
