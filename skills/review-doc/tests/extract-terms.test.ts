/**
 * extract-terms 脚本单元测试
 * 验证术语提取与大小写/拼写差异聚合的核心行为
 */
import { describe, expect, test } from "bun:test";
import { extractTerms } from "../scripts/extract-terms";
import { loadDocs } from "../scripts/parse-doc";
import path from "node:path";

const FIXTURES = path.join(import.meta.dir, "fixtures");

async function load(...names: string[]) {
  return loadDocs(names.map((n) => path.join(FIXTURES, n)));
}

describe("extractTerms", () => {
  test("识别同一英文术语的大小写差异（gRPC / grpc / GRPC）仅来自正文", async () => {
    // 正文中 gRPC / grpc / GRPC 各出现 1 次；代码块/inline/URL 中的变体应被剔除
    const result = extractTerms(await load("terms.md"));
    const grpcGroup = result.inconsistentTerms.find((g) =>
      g.variants.some((v) => v.text === "gRPC"),
    );
    expect(grpcGroup).toBeDefined();
    const variantTexts = grpcGroup!.variants.map((v) => v.text).sort();
    // 因为代码块/inline/URL 全部被忽略，正文里只剩 gRPC/grpc/GRPC 各 1 次
    expect(variantTexts).toEqual(["GRPC", "gRPC", "grpc"]);
    for (const v of grpcGroup!.variants) {
      expect(v.count).toBe(1);
    }
  });

  test("识别 RESTful / RESTFUL 大小写差异，并独立聚合 API/api", async () => {
    const result = extractTerms(await load("terms.md"));
    const restGroup = result.inconsistentTerms.find((g) =>
      g.variants.some((v) => v.text === "RESTful"),
    );
    expect(restGroup).toBeDefined();
    expect(restGroup!.variants.map((v) => v.text).sort()).toEqual([
      "RESTFUL",
      "RESTful",
    ]);

    const apiGroup = result.inconsistentTerms.find((g) =>
      g.variants.some((v) => v.text === "API"),
    );
    expect(apiGroup).toBeDefined();
    expect(apiGroup!.variants.map((v) => v.text).sort()).toEqual([
      "API",
      "api",
    ]);
  });

  test("纯中文段落不应产生英文术语聚合误报", async () => {
    const result = extractTerms(await load("terms.md"));
    for (const g of result.inconsistentTerms) {
      for (const v of g.variants) {
        expect(/^[一-鿿]+$/.test(v.text)).toBe(false);
      }
    }
  });

  test("扩展的 STOPWORDS：user / file 等普通词不进入候选", async () => {
    // terms.md 中刻意写了 "叙述中 user 和 file 应该被视为普通词"
    const result = extractTerms(await load("terms.md"));
    const hasUser = result.inconsistentTerms.some((g) => g.key === "user");
    const hasFile = result.inconsistentTerms.some((g) => g.key === "file");
    expect(hasUser).toBe(false);
    expect(hasFile).toBe(false);
  });

  test("fenced 代码块中的术语变体不污染正文分组", async () => {
    // 代码块里的 grpc / GRPC_HOST 不应被计入 grpc 分组
    const result = extractTerms(await load("terms.md"));
    const grpcGroup = result.inconsistentTerms.find((g) => g.key === "grpc");
    expect(grpcGroup).toBeDefined();
    // grpc 分组中所有变体总次数应等于正文出现次数（每种 1 次），若代码块被统计会 >1
    const total = grpcGroup!.variants.reduce((s, v) => s + v.count, 0);
    expect(total).toBe(3);
  });

  test("inline code 中的术语被跳过", async () => {
    // fixture 中 `grpc.Dial()` 是 inline code，不应计入
    const result = extractTerms(await load("terms.md"));
    const grpcGroup = result.inconsistentTerms.find((g) => g.key === "grpc");
    // 若 inline 被计入，grpc 变体 count 会 > 1；此处应 = 1
    const grpcVariant = grpcGroup!.variants.find((v) => v.text === "grpc");
    expect(grpcVariant!.count).toBe(1);
  });

  test("Markdown 链接 URL 部分的术语被跳过", async () => {
    // [示例](https://example.com/GRPC/path) 里的 GRPC 不应计入
    const result = extractTerms(await load("terms.md"));
    const grpcGroup = result.inconsistentTerms.find((g) => g.key === "grpc");
    const upperVariant = grpcGroup!.variants.find((v) => v.text === "GRPC");
    expect(upperVariant!.count).toBe(1);
  });

  test("输出可序列化为 JSON", async () => {
    const result = extractTerms(await load("terms.md"));
    const json = JSON.stringify(result);
    const parsed = JSON.parse(json);
    expect(parsed).toHaveProperty("inconsistentTerms");
    expect(parsed).toHaveProperty("checked");
  });

  test("术语度启发：普通英文词（Context/context、Database/database）不应被报", async () => {
    // 两种写法都没有全大写、内部驼峰、数字 → 视为普通词，不是术语，不应进入分组
    const result = extractTerms(await load("terms.md"));
    expect(result.inconsistentTerms.some((g) => g.key === "context")).toBe(
      false,
    );
    expect(result.inconsistentTerms.some((g) => g.key === "database")).toBe(
      false,
    );
  });

  test("术语度启发：含全大写/驼峰/数字的变体仍应报（gRPC、API、RESTful）", async () => {
    const result = extractTerms(await load("terms.md"));
    expect(result.inconsistentTerms.some((g) => g.key === "grpc")).toBe(true);
    expect(result.inconsistentTerms.some((g) => g.key === "api")).toBe(true);
    expect(result.inconsistentTerms.some((g) => g.key === "restful")).toBe(
      true,
    );
  });

  test("输出 occurrences：每个变体列出所有出现位置而不是仅 firstSeen", async () => {
    // 每个 variant 给出 occurrences 数组，列出全部位置
    const result = extractTerms(await load("terms.md"));
    const grpcGroup = result.inconsistentTerms.find((g) => g.key === "grpc");
    expect(grpcGroup).toBeDefined();
    for (const v of grpcGroup!.variants) {
      expect(Array.isArray(v.occurrences)).toBe(true);
      expect(v.occurrences.length).toBe(v.count);
      for (const occ of v.occurrences) {
        expect(typeof occ.file).toBe("string");
        expect(typeof occ.line).toBe("number");
      }
    }
  });
});
