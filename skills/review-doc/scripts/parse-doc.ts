#!/usr/bin/env bun
/**
 * Markdown 文档解析层
 *
 * 集中处理 IO 与共享解析（围栏代码块状态、标题 anchor、reference 定义），
 * 让 check-links / extract-terms / check-structure 在同一组解析结果上工作，
 * 避免每个检查重复读文件 + 重复跑代码块状态机。
 */
import fs from "node:fs/promises";
import path from "node:path";

/** 单篇文档的解析结果 */
export interface ParsedDoc {
  /** 绝对路径 */
  absPath: string;
  /** 按行拆分（split('\n')） */
  lines: string[];
  /** 与 lines 等长；行处于围栏代码块内或为围栏行本身时为 true */
  inFence: boolean[];
  /** 标题 slug 集合（GitHub 风格） */
  anchors: Set<string>;
  /** Reference-style 链接定义：lowercased label → { target, line(1-based) } */
  refDefs: Map<string, { target: string; line: number }>;
  /** ref 定义所在行号（1-based），用于扫描时跳过这些行 */
  refDefLines: Set<number>;
}

/** Reference 定义行：[label]: url */
export const REF_DEF_RE = /^\s*\[([^\]]+)\]:\s*(\S+)/;

/**
 * GitHub 风格 anchor slug：
 * 去掉 Markdown 符号、转小写、空白合并为 `-`，保留单词字符与基本汉字平面。
 */
export function slugify(heading: string): string {
  return heading
    .trim()
    .toLowerCase()
    .replace(/^#+\s*/, "")
    .replace(/[`*_~]/g, "")
    .replace(/\s+/g, "-")
    .replace(/[^\w一-鿿-]/g, "");
}

/**
 * 解析单篇文档；纯函数，无 IO。
 */
export function parseDocument(absPath: string, content: string): ParsedDoc {
  const lines = content.split("\n");
  const inFence: boolean[] = new Array(lines.length).fill(false);
  const anchors = new Set<string>();
  const refDefs = new Map<string, { target: string; line: number }>();
  const refDefLines = new Set<number>();

  let fenced = false;
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];
    if (/^\s*(```+|~~~+)/.test(raw)) {
      // 围栏行本身视作"在代码块"，常规扫描应跳过
      inFence[i] = true;
      fenced = !fenced;
      continue;
    }
    inFence[i] = fenced;
    if (fenced) continue;

    const headingMatch = raw.match(/^(#{1,6})\s+(.+?)\s*$/);
    if (headingMatch) {
      anchors.add(slugify(headingMatch[2]));
    }

    const refMatch = raw.match(REF_DEF_RE);
    if (refMatch) {
      const lineNo = i + 1;
      refDefs.set(refMatch[1].toLowerCase(), {
        target: refMatch[2],
        line: lineNo,
      });
      refDefLines.add(lineNo);
    }
  }

  return { absPath, lines, inFence, anchors, refDefs, refDefLines };
}

/**
 * 读取并解析一组 Markdown 文件。
 * 读失败的文件以空内容解析（不抛错），让上游统一处理。
 */
export async function loadDocs(files: string[]): Promise<ParsedDoc[]> {
  return Promise.all(
    files.map(async (f) => {
      const abs = path.resolve(f);
      let content = "";
      try {
        content = await fs.readFile(abs, "utf-8");
      } catch {
        // 留空内容
      }
      return parseDocument(abs, content);
    }),
  );
}
