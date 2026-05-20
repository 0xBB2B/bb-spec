/**
 * Markdown 链接有效性检查
 *
 * 输入：一组已解析的 ParsedDoc
 * 输出：CheckResult { broken, external, referenced, checked }
 *
 * 检查范围：
 *  - 本地文件链接（相对/绝对路径）：验证文件是否存在
 *  - 锚点链接（#section 或 file.md#section）：验证目标文档是否包含对应标题
 *  - 外部 URL（http/https/mailto）：仅记录，不主动访问
 *  - Reference-style 链接（[text][label] + [label]: url）：按定义解析后按上述规则检查
 *
 * 围栏代码块、inline code 内的"链接"不算真链接，已被忽略。
 *
 * referenced：所有解析后存在的本地 .md 目标绝对路径（去重，便于上游
 * 把"显式引用的关联文档"机械化纳入审查范围）。
 */
import fs from "node:fs/promises";
import path from "node:path";
import { type ParsedDoc, parseDocument } from "./parse-doc";

/** 断链记录 */
export interface BrokenLink {
  /** 出现该链接的源文件 */
  source: string;
  /** 链接文本 */
  text: string;
  /** 链接目标（原始字符串；reference-style 未定义时为 "[label]"） */
  target: string;
  /** 失败原因 */
  reason: "file-not-found" | "anchor-not-found" | "reference-not-defined";
  /** 行号（1-based） */
  line: number;
}

/** 外部链接记录 */
export interface ExternalLink {
  source: string;
  text: string;
  url: string;
  line: number;
}

/** 检查结果 */
export interface CheckResult {
  broken: BrokenLink[];
  external: ExternalLink[];
  /** 主审查范围中所有引用到的本地 .md 文件（绝对路径，已存在，去重排序） */
  referenced: string[];
  /** 实际被检查的源文档绝对路径列表 */
  checked: string[];
}

/** Inline 链接：[text](target)；target 不含括号 */
const INLINE_LINK_RE = /\[([^\]]*)\]\(([^)]+)\)/g;
/** Reference-style 链接：[text][label]；label 可为空（shortcut 形式用 text 作 label） */
const REF_LINK_RE = /\[([^\]]+)\]\[([^\]]*)\]/g;

/** 把一行中的 inline code `...` 片段用等长空格替换，保留列位置 */
function stripInlineCode(line: string): string {
  return line.replace(/`[^`]*`/g, (m) => " ".repeat(m.length));
}

/** 判断 target 是否外部 URL（http/https/mailto） */
function isExternalUrl(target: string): boolean {
  return /^(https?:|mailto:)/i.test(target);
}

/** 取或加载某个文件的 anchors。docs 内已预填，外部目标按需 lazy 解析。 */
async function getAnchors(
  absPath: string,
  cache: Map<string, Set<string>>,
): Promise<Set<string>> {
  const cached = cache.get(absPath);
  if (cached) return cached;
  let content = "";
  try {
    content = await fs.readFile(absPath, "utf-8");
  } catch {
    cache.set(absPath, new Set());
    return cache.get(absPath)!;
  }
  const parsed = parseDocument(absPath, content);
  cache.set(absPath, parsed.anchors);
  return parsed.anchors;
}

/** target 解析与校验结果 */
interface TargetCheck {
  status: "ok" | "file-not-found" | "anchor-not-found";
  /** 解析后的目标文件绝对路径；纯锚点链接（#xxx）时为空 */
  resolved?: string;
  /** 目标文件是否实际存在 */
  fileExists: boolean;
}

/**
 * 检查一条已解析（非外部）的 target，返回状态。
 */
async function checkTarget(
  absSource: string,
  target: string,
  anchorCache: Map<string, Set<string>>,
): Promise<TargetCheck> {
  const [filePart, anchorPart] = target.split("#", 2);
  // 纯锚点：在当前文件内查找
  if (filePart === "") {
    if (!anchorPart) return { status: "ok", fileExists: true };
    const anchors = anchorCache.get(absSource) ?? new Set();
    return {
      status: anchors.has(anchorPart) ? "ok" : "anchor-not-found",
      fileExists: true,
    };
  }
  const resolved = path.isAbsolute(filePart)
    ? filePart
    : path.resolve(path.dirname(absSource), filePart);
  const fileExists = await fs
    .stat(resolved)
    .then((s) => s.isFile())
    .catch(() => false);
  if (!fileExists) return { status: "file-not-found", resolved, fileExists };
  if (anchorPart) {
    const anchors = await getAnchors(resolved, anchorCache);
    if (!anchors.has(anchorPart)) {
      return { status: "anchor-not-found", resolved, fileExists };
    }
  }
  return { status: "ok", resolved, fileExists };
}

/**
 * 检查一组已解析文档的所有链接
 */
export async function checkLinks(docs: ParsedDoc[]): Promise<CheckResult> {
  const broken: BrokenLink[] = [];
  const external: ExternalLink[] = [];
  const referenced = new Set<string>();
  const checked = docs.map((d) => d.absPath);

  // 预填 anchor 缓存：docs 内文档的 anchors 已解析好
  const anchorCache = new Map<string, Set<string>>();
  for (const doc of docs) anchorCache.set(doc.absPath, doc.anchors);

  for (const doc of docs) {
    const { absPath, lines, inFence, refDefs, refDefLines } = doc;

    for (let i = 0; i < lines.length; i++) {
      if (inFence[i]) continue;
      if (refDefLines.has(i + 1)) continue;
      const line = stripInlineCode(lines[i]);

      // 1) inline 链接 [text](target)
      INLINE_LINK_RE.lastIndex = 0;
      let m: RegExpExecArray | null;
      while ((m = INLINE_LINK_RE.exec(line)) !== null) {
        const [, text, target] = m;
        if (isExternalUrl(target)) {
          external.push({ source: absPath, text, url: target, line: i + 1 });
          continue;
        }
        const r = await checkTarget(absPath, target, anchorCache);
        if (r.fileExists && r.resolved && r.resolved.toLowerCase().endsWith(".md")) {
          referenced.add(r.resolved);
        }
        if (r.status !== "ok") {
          broken.push({
            source: absPath,
            text,
            target,
            reason: r.status,
            line: i + 1,
          });
        }
      }

      // 2) reference-style 链接 [text][label]
      REF_LINK_RE.lastIndex = 0;
      while ((m = REF_LINK_RE.exec(line)) !== null) {
        const [, text, rawLabel] = m;
        // 空 label 走 collapsed-style，用 text 作为 label
        const label = (rawLabel.trim() || text).toLowerCase();
        const def = refDefs.get(label);
        if (!def) {
          broken.push({
            source: absPath,
            text,
            target: `[${rawLabel || text}]`,
            reason: "reference-not-defined",
            line: i + 1,
          });
          continue;
        }
        if (isExternalUrl(def.target)) {
          external.push({
            source: absPath,
            text,
            url: def.target,
            line: i + 1,
          });
          continue;
        }
        const r = await checkTarget(absPath, def.target, anchorCache);
        if (r.fileExists && r.resolved && r.resolved.toLowerCase().endsWith(".md")) {
          referenced.add(r.resolved);
        }
        if (r.status !== "ok") {
          broken.push({
            source: absPath,
            text,
            target: def.target,
            reason: r.status,
            line: i + 1,
          });
        }
      }
    }
  }

  return {
    broken,
    external,
    referenced: Array.from(referenced).sort(),
    checked,
  };
}
