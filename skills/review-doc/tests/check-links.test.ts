/**
 * check-links 脚本单元测试
 * 验证 Markdown 链接有效性检查器的核心行为
 */
import { describe, expect, test } from "bun:test";
import { checkLinks } from "../scripts/check-links";
import { loadDocs } from "../scripts/parse-doc";
import path from "node:path";

const FIXTURES = path.join(import.meta.dir, "fixtures");

/** 加载若干 fixture 文件为 ParsedDoc 数组 */
async function load(...names: string[]) {
  return loadDocs(names.map((n) => path.join(FIXTURES, n)));
}

describe("checkLinks", () => {
  test("good.md 中所有本地链接都有效，外部链接被标记为未验证", async () => {
    // 对干净文档进行检查
    const result = await checkLinks(await load("good.md"));
    // 不应产生 broken 报错
    expect(result.broken).toEqual([]);
    // 外部链接应进入 external 列表（不验证）
    expect(result.external.length).toBe(1);
    expect(result.external[0].url).toBe("https://anthropic.com");
  });

  test("bad.md 中缺失文件链接和缺失锚点都被报告为 broken", async () => {
    const result = await checkLinks(await load("bad.md"));
    // 应至少包含两个 broken：missing.md 和 #ghost-section
    const reasons = result.broken.map((b) => b.reason);
    const targets = result.broken.map((b) => b.target);
    expect(targets).toContain("./missing.md");
    expect(targets.some((t) => t.includes("ghost-section"))).toBe(true);
    // 类型应明确区分文件缺失与锚点缺失
    expect(reasons).toContain("file-not-found");
    expect(reasons).toContain("anchor-not-found");
  });

  test("bad.md 中存在的本地链接不会被误报", async () => {
    const result = await checkLinks(await load("bad.md"));
    // 指向 other.md 的链接应被识别为有效
    const brokenTargets = result.broken.map((b) => b.target);
    expect(brokenTargets).not.toContain("./other.md");
  });

  test("输出 JSON 形式，便于上游消费", async () => {
    const result = await checkLinks(await load("good.md"));
    // 必须是可序列化的纯对象结构
    const json = JSON.stringify(result);
    expect(typeof json).toBe("string");
    const parsed = JSON.parse(json);
    expect(parsed).toHaveProperty("broken");
    expect(parsed).toHaveProperty("external");
    expect(parsed).toHaveProperty("referenced");
    expect(parsed).toHaveProperty("checked");
  });

  test("fenced 代码块内的链接不应被检查（误报断链）", async () => {
    // links-in-code.md 在代码块里写了 [示例](./does-not-exist.md) 和锚点链接
    // 这些是示例，不应被当作真链接，不应出现在 broken 中
    const result = await checkLinks(await load("links-in-code.md"));
    const targets = result.broken.map((b) => b.target);
    expect(targets).not.toContain("./does-not-exist.md");
    expect(targets.some((t) => t.includes("never-existed"))).toBe(false);
  });

  test("inline code 内的链接不应被检查", async () => {
    // links-in-code.md 在行内代码里写了 `[x](./fake.md)`
    const result = await checkLinks(await load("links-in-code.md"));
    const targets = result.broken.map((b) => b.target);
    expect(targets).not.toContain("./fake.md");
  });

  test("fenced 代码块外的真断链仍应被报告", async () => {
    // links-in-code.md 正文里 [缺失文件](./really-missing.md) 必须被报
    const result = await checkLinks(await load("links-in-code.md"));
    const targets = result.broken.map((b) => b.target);
    expect(targets).toContain("./really-missing.md");
  });

  test("reference-style 链接：定义指向存在文件视为有效", async () => {
    // refs.md 中 [其他][ok] + [ok]: ./other.md 应视为有效链接
    const result = await checkLinks(await load("refs.md"));
    const targets = result.broken.map((b) => b.target);
    // 不应出现 ./other.md（它存在）
    expect(targets).not.toContain("./other.md");
  });

  test("reference-style 链接：定义指向缺失文件应被报为断链", async () => {
    const result = await checkLinks(await load("refs.md"));
    const targets = result.broken.map((b) => b.target);
    // [坏链][miss] 定义为 ./really-missing.md，应被报
    expect(targets).toContain("./really-missing.md");
  });

  test("reference-style 链接：定义指向存在文件但锚点不存在应被报", async () => {
    const result = await checkLinks(await load("refs.md"));
    const reasons = result.broken
      .filter((b) => b.target.includes("other.md#nowhere"))
      .map((b) => b.reason);
    expect(reasons).toContain("anchor-not-found");
  });

  test("reference-style 链接：未定义的标签应被报为断链", async () => {
    const result = await checkLinks(await load("refs.md"));
    // [孤儿][undefined-label] 无对应定义行，应被报
    const hasUndefinedRef = result.broken.some(
      (b) => b.reason === "reference-not-defined",
    );
    expect(hasUndefinedRef).toBe(true);
  });

  test("referenced 列出所有已存在的本地 .md 引用（绝对路径，去重排序）", async () => {
    // good.md 仅引用 ./other.md（存在）
    const result = await checkLinks(await load("good.md"));
    expect(result.referenced).toEqual([path.join(FIXTURES, "other.md")]);
  });

  test("referenced 不包含 file-not-found 的目标", async () => {
    // bad.md 引用 ./missing.md（不存在）和 ./other.md（存在）
    const result = await checkLinks(await load("bad.md"));
    expect(result.referenced).toContain(path.join(FIXTURES, "other.md"));
    expect(result.referenced.some((p) => p.endsWith("missing.md"))).toBe(false);
  });

  test("referenced 收录 reference-style 链接解析后的目标", async () => {
    // refs.md ref-style: [ok]: ./other.md 与 [ghost]: ./other.md#nowhere 都指向 other.md（存在）
    const result = await checkLinks(await load("refs.md"));
    expect(result.referenced).toContain(path.join(FIXTURES, "other.md"));
  });
});
