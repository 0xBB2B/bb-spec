/**
 * 术语提取与不一致聚合
 *
 * 输入：一组已解析的 ParsedDoc
 * 输出：ExtractResult { inconsistentTerms, checked }
 *
 * 核心设计：
 *  - 只扫描"叙述正文"。围栏代码块、inline code、Markdown 链接的 URL 部分全部跳过。
 *    这保证结果对上游 100% 可信，避免 LLM 二次过滤变量名/路径。
 *  - 通过 lowercase 归一化聚合；归一化后只有一种写法或被 stopwords 命中的不输出。
 *  - STOPWORDS 覆盖常见英文普通词（user/file/data/config/path/name/type/value 等），
 *    只保留真正像"术语"的 token。
 */
import type { ParsedDoc } from "./parse-doc";

/** 单个术语的某个写法 */
export interface TermVariant {
  /** 该写法的原文 */
  text: string;
  /** 出现次数（等于 occurrences.length） */
  count: number;
  /** 所有出现位置，按文件+行号顺序 */
  occurrences: { file: string; line: number }[];
}

/** 同一术语下的多种写法分组 */
export interface InconsistentTerm {
  /** 归一化键（小写） */
  key: string;
  /** 该术语的所有写法 */
  variants: TermVariant[];
}

/** 提取结果 */
export interface ExtractResult {
  inconsistentTerms: InconsistentTerm[];
  checked: string[];
}

/**
 * 英文术语候选正则：至少 2 个字符，以字母开头，可含数字
 * 例如：API, gRPC, RESTful, http2, OAuth2
 */
const TOKEN_RE = /[A-Za-z][A-Za-z0-9]{1,}/g;

/**
 * 跳过清单：常见英文虚词 + 普通名词/形容词/动词。
 * 在技术文档里这些词大概率是叙述用语而非术语，保留它们只会产生噪声。
 */
const STOPWORDS = new Set([
  // 冠词/代词/助动词
  "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
  "and", "or", "but", "if", "then", "else", "for", "of", "to", "in", "on",
  "at", "by", "with", "as", "this", "that", "these", "those", "it", "its",
  "we", "you", "he", "she", "they", "i", "me", "us", "them",
  "do", "does", "did", "have", "has", "had", "will", "would", "can", "could",
  "should", "may", "might", "must", "not", "no", "yes", "so", "too", "than",
  // 技术文档里高频普通词，不构成"术语"概念
  "user", "users", "file", "files", "data", "config", "configs", "path",
  "paths", "name", "names", "type", "types", "value", "values", "key", "keys",
  "input", "output", "result", "results", "error", "errors", "item", "items",
  "option", "options", "param", "params", "arg", "args", "flag", "flags",
  "field", "fields", "line", "lines", "text", "code", "method", "methods",
  "step", "steps", "case", "cases", "note", "notes", "example", "examples",
  "true", "false", "null", "none", "ok",
]);

/** 一行中被 inline code 包裹的片段，逐段替换为等长空格。 */
function stripInlineCode(line: string): string {
  return line.replace(/`[^`]*`/g, (m) => " ".repeat(m.length));
}

/** 一行中的 Markdown 链接 URL 部分 `](url)` 用等长空格替换，保留文本部分。 */
function stripLinkUrls(line: string): string {
  return line.replace(/\]\([^)]*\)/g, (m) => " ".repeat(m.length));
}

/**
 * 判断一个写法是否"像术语"：
 *  - 全大写且长度 ≥2（API、GRPC）
 *  - 含数字（http2、OAuth2）
 *  - 除首字母外仍含大写（gRPC、RESTful、OAuth）——即不是"全小写"或"首字母大写余小写"
 *
 * 不满足以上任一的视为普通英文词（Context、Database、service），不构成术语候选。
 */
function isTermLike(text: string): boolean {
  if (/[0-9]/.test(text)) return true;
  if (/^[A-Z]{2,}$/.test(text)) return true;
  if (/[A-Z]/.test(text) && !/^[A-Z][a-z]*$/.test(text)) return true;
  return false;
}

export function extractTerms(docs: ParsedDoc[]): ExtractResult {
  // key（小写） -> 写法 -> TermVariant
  const buckets = new Map<string, Map<string, TermVariant>>();
  const checked = docs.map((d) => d.absPath);

  for (const doc of docs) {
    const { absPath, lines, inFence } = doc;
    for (let i = 0; i < lines.length; i++) {
      if (inFence[i]) continue;
      const line = stripLinkUrls(stripInlineCode(lines[i]));
      TOKEN_RE.lastIndex = 0;
      let m: RegExpExecArray | null;
      while ((m = TOKEN_RE.exec(line)) !== null) {
        const text = m[0];
        const key = text.toLowerCase();
        if (STOPWORDS.has(key)) continue;
        let bucket = buckets.get(key);
        if (!bucket) {
          bucket = new Map<string, TermVariant>();
          buckets.set(key, bucket);
        }
        const variant = bucket.get(text);
        if (variant) {
          variant.count++;
          variant.occurrences.push({ file: absPath, line: i + 1 });
        } else {
          bucket.set(text, {
            text,
            count: 1,
            occurrences: [{ file: absPath, line: i + 1 }],
          });
        }
      }
    }
  }

  // 只保留有 ≥2 种写法、且至少存在一个"像术语"的变体的桶
  const inconsistentTerms: InconsistentTerm[] = [];
  for (const [key, bucket] of buckets) {
    if (bucket.size < 2) continue;
    const variants = Array.from(bucket.values());
    if (!variants.some((v) => isTermLike(v.text))) continue;
    inconsistentTerms.push({
      key,
      variants: variants.sort((a, b) => b.count - a.count),
    });
  }
  // 按出现总次数降序，便于优先关注高频术语
  inconsistentTerms.sort((a, b) => {
    const ca = a.variants.reduce((s, v) => s + v.count, 0);
    const cb = b.variants.reduce((s, v) => s + v.count, 0);
    return cb - ca;
  });

  return { inconsistentTerms, checked };
}
