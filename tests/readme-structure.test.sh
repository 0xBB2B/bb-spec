#!/usr/bin/env bash
# 五份 README 的章节结构、主页徽章、顶部导航锚点和阶段一览格式校验
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

read -r -d '' PYSRC <<'PY' || true
import re, sys, unicodedata
from pathlib import Path

root = Path(sys.argv[1])
FILES = ["README.md", "README.en.md", "README.zh-TW.md", "README.ja.md", "README.ko.md"]
EMOJIS = ["✨", "📦", "🚀", "🔁", "🧩", "🔄", "🪝", "🛠", "💡", "🧪", "⬆", "📜"]
HOME = "https://bb-spec.0xbb.me/"
ZH_TITLES = ["**三 Agent 隔离执行**", "**磁盘文档作为唯一交接物**", "**代码 ⇄ PRD 经 git 双向可查**"]
SWITCH = {
    "README.md": "跳过后台脚本提示",
    "README.en.md": "Skip the background-script prompt",
    "README.zh-TW.md": "跳過背景腳本提示",
    "README.ja.md": "バックグラウンドスクリプトの通知をスキップ",
    "README.ko.md": "백그라운드 스크립트 알림 건너뛰기",
}
COMMANDS = ["/git-clone", "/prd", "/plan", "/exec", "/doc-update", "/git-push", "/revise", "/test-webview", "/test-api"]


def out(kind, msg=""):
    print(f"{kind}\t{msg}")


def check(cond, msg):
    out("PASS" if cond else "FAIL", "" if cond else msg)


def read_lines(name):
    p = root / name
    return p.read_text(encoding="utf-8").split("\n") if p.exists() else None


def outside_code(lines):
    """返回 [(行号, 行文本, 是否在代码块外)]。"""
    res, fence = [], 0
    for i, l in enumerate(lines):
        cb = fence > 0
        m = re.match(r"^(`+)", l)
        if m and len(m.group(1)) >= 3:
            k = len(m.group(1))
            if not fence:
                fence, cb = k, True
            elif k >= fence and re.match(r"^`+[ \t]*$", l):
                fence, cb = 0, True
        res.append((i, l, not cb))
    return res


def headings(info):
    return [(i, l) for i, l, o in info if o and re.match(r"^#{1,6} ", l)]


def first_char(title):
    t = title.replace("️", "")
    return t[0] if t else ""


def sections(lines, info):
    """按代码块外的 ## 切成 [(标题文字, 首字符, 起始行, 结束行(不含))]。"""
    h2 = [(i, l) for i, l in headings(info) if l.startswith("## ")]
    res = []
    for n, (i, l) in enumerate(h2):
        end = h2[n + 1][0] if n + 1 < len(h2) else len(lines)
        res.append((l[3:], first_char(l[3:]), i, end))
    return res


def slug(text):
    t = re.sub(r"^#+ ", "", text).lower()
    t = "".join(c for c in t if unicodedata.category(c)[0] in "LN" or c in "_- ")
    return t.replace(" ", "-")


def anchor_map(info):
    seen, res = {}, {}
    for i, l in headings(info):
        s = slug(l)
        n = seen.get(s, 0)
        res[i] = s if n == 0 else f"{s}-{n}"
        seen[s] = n + 1
    return res


def anchors(info):
    return set(anchor_map(info).values())


data = {}
out("GROUP", "文件存在")
for f in FILES:
    lines = read_lines(f)
    check(lines is not None, f"{f} 不存在")
    if lines is not None:
        info = outside_code(lines)
        data[f] = (lines, info, sections(lines, info))

out("GROUP", "主页徽章")
for f, (lines, info, secs) in data.items():
    first_h2 = secs[0][2] if secs else len(lines)
    top = "\n".join(lines[:first_h2])
    check(re.search(r'<a href="' + re.escape(HOME) + r'"[^>]*>\s*<img', top) is not None,
          f"{f}: 文件开头没有指向 {HOME} 的主页徽章")
    check("0xbb2b.github.io" not in "\n".join(lines), f"{f}: 仍出现旧主页地址 0xbb2b.github.io")

out("GROUP", "二级标题 emoji 顺序")
seqs = {}
for f, (lines, info, secs) in data.items():
    seqs[f] = [s[1] for s in secs]
    check(seqs[f] == EMOJIS, f"{f}: 二级标题 emoji 序列为 {''.join(seqs[f])}，应为 {''.join(EMOJIS)}")
check(len({tuple(v) for v in seqs.values()}) == 1 and len(seqs) == len(FILES), "五份 README 的二级标题 emoji 序列不一致")
h3_counts = {f: [sum(1 for i, l in headings(info) if l.startswith("### ") and s[2] < i < s[3]) for s in secs]
             for f, (lines, info, secs) in data.items()}
check(len({tuple(v) for v in h3_counts.values()}) == 1 and len(h3_counts) == len(FILES),
      f"五份 README 各章节下的三级标题数量不一致: {h3_counts}")


def sec(f, emoji):
    lines, info, secs = data[f]
    for title, e, a, b in secs:
        if e == emoji:
            return lines[a:b]
    return None


out("GROUP", "✨ 与 💡 的差异点")
for f in data:
    s1, s2 = sec(f, "✨"), sec(f, "💡")
    if s1 is None or s2 is None:
        check(False, f"{f}: 缺少 ✨ 或 💡 章节")
        continue
    bold = []
    for _, l, o in outside_code(s1):
        m = re.match(r"^\s*(?:[-*]\s+)?(\*\*[^*]+\*\*)", l)
        if o and m:
            bold.append(m.group(1))
    bold = list(dict.fromkeys(bold))
    check(len(bold) >= 3, f"{f}: ✨ 章节的粗体差异点只有 {len(bold)} 条，应至少 3 条")
    if f == "README.md":
        for t in ZH_TITLES:
            check(t in "\n".join(s1), f"{f}: ✨ 章节缺少 {t}")
    text2 = "\n".join(s2)
    for t in bold:
        check(t not in text2, f"{f}: 💡 章节仍含 ✨ 的差异点标题 {t}")

out("GROUP", "安装章节")
for f in data:
    lines = data[f][0]
    s = sec(f, "📦")
    cmd = "/plugin marketplace add 0xBB2B/bb-spec"
    check(sum(l.count(cmd) for l in lines) == 1, f"{f}: {cmd} 在全文出现次数不是 1")
    check(s is not None and sum(l.count(cmd) for l in s) == 1, f"{f}: {cmd} 不在 📦 章节内")
    total = sum(l.count('"extraKnownMarketplaces"') for l in lines)
    inside = sum(l.count('"extraKnownMarketplaces"') for l in s) if s else 0
    check(total >= 1 and inside == total, f"{f}: settings.json 示例（extraKnownMarketplaces）不在 📦 章节内")

out("GROUP", "Hooks 章节")
for f in data:
    s = sec(f, "🪝")
    text = "\n".join(s) if s else ""
    check(any(l.startswith("| `background-script-wait` |") for l in (s or [])), f"{f}: 🪝 章节缺少 background-script-wait 表格行")
    check(SWITCH[f] in text, f"{f}: 🪝 章节缺少开关速查（{SWITCH[f]}）")
    rows = s or []
    hook = next((i for i, l in enumerate(rows) if l.startswith("| `background-script-wait` |")), None)
    sw = next((i for i, l in enumerate(rows) if SWITCH[f] in l and l.startswith("|")), None)
    if hook is None or sw is None:
        check(False, f"{f}: 🪝 章节缺少 hook 表或开关速查表，无法判断相邻")
        continue
    hook_end = hook
    while hook_end + 1 < len(rows) and rows[hook_end + 1].startswith("|"):
        hook_end += 1
    sw_start = sw
    while sw_start > 0 and rows[sw_start - 1].startswith("|"):
        sw_start -= 1
    between = rows[hook_end + 1:sw_start]
    stray = [l for l in between if l.strip() and not l.startswith("### ")]
    check(sw_start > hook_end and not stray, f"{f}: hook 表和开关速查表之间有其他内容: {stray[:2]}")

out("GROUP", "快速开始指向安装章节")
for f, (lines, info, secs) in data.items():
    install_line = next((i for t, e, i, j in secs if e == "📦"), None)
    quick = sec(f, "🚀")
    if install_line is None or quick is None:
        check(False, f"{f}: 缺少 📦 或 🚀 章节")
        continue
    amap = anchor_map(info)
    target = amap[install_line]
    quick_text = "\n".join(l for _, l, o in outside_code(quick) if o)
    links = re.findall(r"\]\(#([^)]*)\)", quick_text) + re.findall(r'href="#([^"]*)"', quick_text)
    check(target in links, f"{f}: 🚀 章节没有指向 📦 章节锚点 #{target} 的链接")

out("GROUP", "阶段一览")
totals = {}
for f in data:
    s = sec(f, "🔁")
    if s is None:
        check(False, f"{f}: 缺少 🔁 章节")
        continue
    info = outside_code(s)
    start = next((i for i, l, o in info if o and l.startswith("### 🎯")), None)
    check(start is not None, f"{f}: 🔁 章节内没有 ### 🎯 小节")
    if start is None:
        continue
    end = next((i for i, l, o in info if o and i > start and re.match(r"^#{1,3} ", l)), len(s))
    block = s[start:end]
    check(sum(l.count("<details") for l in block) >= 9, f"{f}: 阶段一览里 <details> 少于 9 个")
    item_idx = [i for i, l in enumerate(block) if re.match(r"^- \*\*", l)]
    for cmd in COMMANDS:
        pat = re.compile(r"^- \*\*`?" + re.escape(cmd) + r"`?\*\*")
        idx = next((i for i in item_idx if pat.match(block[i])), None)
        if idx is None:
            check(False, f"{f}: 阶段一览缺少命令条目 {cmd}")
            continue
        nxt = next((i for i in item_idx if i > idx), len(block))
        body = block[idx + 1:nxt]
        d = next((i for i, l in enumerate(body) if "<details" in l), len(body))
        n = sum(1 for l in body[:d] if l.startswith("  - "))
        check(n <= 3, f"{f}: {cmd} 在 <details> 之前有 {n} 条要点，应不超过 3 条")
        totals.setdefault(cmd, {})[f] = sum(1 for l in body if l.startswith("  - "))

out("GROUP", "阶段一览五份对应")
for cmd in COMMANDS:
    per = totals.get(cmd, {})
    check(len(per) == len(FILES) and len(set(per.values())) == 1, f"{cmd} 的二级要点总数在五份 README 间不一致: {per}")

out("GROUP", "顶部导航锚点")
for f, (lines, info, secs) in data.items():
    first_h2 = secs[0][2] if secs else len(lines)
    hrefs = re.findall(r'href="#([^"]*)"', "\n".join(lines[:first_h2]))
    check(len(hrefs) > 0, f"{f}: 文件开头没有导航锚点")
    have = anchors(info)
    for h in hrefs:
        check(h in have, f"{f}: 导航锚点 #{h} 没有对应标题")
PY

if ! command -v python3 >/dev/null 2>&1; then
  fail "找不到 python3"
else
  PYRC=0
  PYOUT="$(python3 -I -c "$PYSRC" "$ROOT")" || PYRC=$?
  [ "$PYRC" -eq 0 ] || fail "python3 校验脚本异常退出（退出码 ${PYRC}）"
  while IFS=$'\t' read -r kind msg; do
    case "$kind" in
      GROUP) echo "[$msg]" ;;
      PASS) pass ;;
      FAIL) fail "$msg" ;;
    esac
  done <<<"$PYOUT"
fi

[ "$PASS" -gt 0 ] || fail "没有任何断言通过"

echo
echo "通过 ${PASS}，失败 ${FAIL}"
[ "$FAIL" -eq 0 ]
