/**
 * check-structure 脚本单元测试
 * 验证 Markdown 结构性机械检查：标题层级跳跃与表格列数一致性
 */
import { describe, expect, test } from "bun:test";
import { checkStructure } from "../scripts/check-structure";
import { loadDocs } from "../scripts/parse-doc";
import path from "node:path";

const FIXTURES = path.join(import.meta.dir, "fixtures");

async function load(...names: string[]) {
  return loadDocs(names.map((n) => path.join(FIXTURES, n)));
}

describe("checkStructure", () => {
  test("检测 H1 → H3 的标题层级跳跃", async () => {
    const result = checkStructure(await load("structure.md"));
    const headingIssues = result.issues.filter(
      (i) => i.kind === "heading-skip",
    );
    // fixture 中有一次 H1 -> H3
    expect(headingIssues.length).toBeGreaterThanOrEqual(1);
    const first = headingIssues[0];
    expect(first.from).toBe(1);
    expect(first.to).toBe(3);
    expect(first.line).toBeGreaterThan(0);
  });

  test("正常的 H2 → H3 → H4 序列不产生误报", async () => {
    const result = checkStructure(await load("structure.md"));
    const headingIssues = result.issues.filter(
      (i) => i.kind === "heading-skip",
    );
    // 不应把 H2 → H3 或 H3 → H4 之类的正常下钻报成跳级
    for (const issue of headingIssues) {
      expect(issue.to - issue.from).toBeGreaterThanOrEqual(2);
    }
  });

  test("检测表格行列数与 header 列数不匹配", async () => {
    const result = checkStructure(await load("structure.md"));
    const tableIssues = result.issues.filter(
      (i) => i.kind === "table-column-mismatch",
    );
    // fixture 中第一张表有两行列数不匹配（2 列和 4 列，header 3 列）
    expect(tableIssues.length).toBe(2);
    const expected = tableIssues.find((i) => i.expected === 3);
    expect(expected).toBeDefined();
    const actuals = tableIssues.map((i) => i.actual).sort();
    expect(actuals).toEqual([2, 4]);
  });

  test("正常表格不产生误报", async () => {
    // fixture 中第二张"正常表格"有 2 列且每行 2 列，不应上报
    const result = checkStructure(await load("structure.md"));
    const tableIssues = result.issues.filter(
      (i) => i.kind === "table-column-mismatch" && i.expected === 2,
    );
    expect(tableIssues).toEqual([]);
  });

  test("输出可序列化为 JSON", async () => {
    const result = checkStructure(await load("structure.md"));
    const json = JSON.stringify(result);
    const parsed = JSON.parse(json);
    expect(parsed).toHaveProperty("issues");
    expect(parsed).toHaveProperty("checked");
  });
});
