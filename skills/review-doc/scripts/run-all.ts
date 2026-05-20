#!/usr/bin/env bun
/**
 * 三类机械检查的统一入口
 *
 * 单次读取并解析 Markdown 文件，把同一组 ParsedDoc 喂给 checkLinks /
 * extractTerms / checkStructure，避免每个检查重复读文件。
 *
 * 使用方式：
 *   bun run run-all.ts <file1.md> [file2.md] ...
 *
 * 输出 JSON：
 *   { links: CheckResult, terms: ExtractResult, structure: CheckStructureResult }
 *
 * 退出码：链接断裂或结构问题任一非空时为 1，便于 shell 判断；纯术语不一致不影响退出码。
 */
import { loadDocs } from "./parse-doc";
import { checkLinks } from "./check-links";
import { extractTerms } from "./extract-terms";
import { checkStructure } from "./check-structure";

if (import.meta.main) {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error("用法: bun run run-all.ts <file1.md> [file2.md] ...");
    process.exit(2);
  }
  const docs = await loadDocs(args);
  const links = await checkLinks(docs);
  const terms = extractTerms(docs);
  const structure = checkStructure(docs);
  console.log(JSON.stringify({ links, terms, structure }, null, 2));
  process.exit(links.broken.length > 0 || structure.issues.length > 0 ? 1 : 0);
}
