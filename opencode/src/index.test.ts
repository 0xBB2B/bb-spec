import { describe, expect, test } from "bun:test"
import { BbSpec } from "./index"

function userText(sessionID: string, text: string) {
  return {
    message: { id: "m", sessionID, role: "user", time: { created: 1 }, agent: "build", model: { providerID: "p", modelID: "m" } },
    parts: [{ id: "p", sessionID, messageID: "m", type: "text", text }],
  } as any
}

describe("stop self-check", () => {
  test("连续 idle 只注入一次，直到真实用户消息解除", async () => {
    const prompts: any[] = []
    const hooks = await BbSpec({
      client: {
        session: {
          get: async () => ({ data: { id: "s" } }),
          prompt: async (input: any) => prompts.push(input),
        },
      },
      directory: "/tmp",
      $: {} as any,
    } as any)

    await hooks.event?.({ event: { type: "session.idle", properties: { sessionID: "s" } } as any })
    await hooks.event?.({ event: { type: "session.idle", properties: { sessionID: "s" } } as any })

    expect(prompts).toHaveLength(1)

    const selfCheck = prompts[0].body.parts[0].text
    await hooks["chat.message"]?.({ sessionID: "s" } as any, userText("s", selfCheck))
    await hooks.event?.({ event: { type: "session.idle", properties: { sessionID: "s" } } as any })

    expect(prompts).toHaveLength(1)

    await hooks["chat.message"]?.({ sessionID: "s" } as any, userText("s", "继续处理下一个问题"))
    await hooks.event?.({ event: { type: "session.idle", properties: { sessionID: "s" } } as any })

    expect(prompts).toHaveLength(2)

    await hooks.event?.({ event: { type: "command.executed", properties: { sessionID: "s", name: "review", arguments: "", messageID: "m" } } as any })
    await hooks.event?.({ event: { type: "session.idle", properties: { sessionID: "s" } } as any })

    expect(prompts).toHaveLength(3)
  })
})
