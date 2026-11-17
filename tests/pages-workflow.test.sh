#!/usr/bin/env bash
# pages.yml 部署主页工作流的触发器、权限、并发、发布范围校验
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGES="$ROOT/.github/workflows/pages.yml"
CI="$ROOT/.github/workflows/ci.yml"
RELEASE="$ROOT/.github/workflows/release-please.yml"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# 用法：yq_lite <file> <op> <路径，斜杠分隔>
# op: keys=该块直接子键；kv=子键:值；items=列表项（支持 "- x" 与 [a, b]）；scalar=该键行内值
yq_lite() {
  python3 -I - "$@" <<'PY'
import re, sys
path, op, keypath = sys.argv[1], sys.argv[2], sys.argv[3]
rows = []
for raw in open(path, encoding="utf-8"):
    s = re.sub(r"(^|\s)#.*$", "", raw.rstrip("\n"))
    if s.strip():
        rows.append((len(s) - len(s.lstrip(" ")), s.strip()))

def norm(k):
    return k.strip().strip("\"'")

def descend(rows, parent_indent, key):
    for i, (ind, txt) in enumerate(rows):
        m = re.match(r"([^\s:][^:]*):\s*(.*)$", txt)
        if ind > parent_indent and m and norm(m.group(1)) == key:
            kids = []
            for ind2, txt2 in rows[i + 1:]:
                if ind2 > ind or (ind2 == ind and txt2.startswith("- ")):
                    kids.append((ind2, txt2))
                else:
                    break
            return m.group(2).strip(), kids, ind
    return None

cur, inline, parent = rows, "", -1
for key in [k for k in keypath.split("/") if k]:
    found = descend(cur, parent, key)
    if found is None:
        sys.exit(3)
    inline, cur, parent = found

if op == "scalar":
    print(norm(inline))
elif op == "keys" or op == "kv":
    if not cur:
        sys.exit(0)
    base = min(i for i, _ in cur)
    for ind, txt in cur:
        m = re.match(r"([^\s:][^:]*):\s*(.*)$", txt)
        if ind == base and m and not txt.startswith("- "):
            print(norm(m.group(1)) if op == "keys" else norm(m.group(1)) + "=" + norm(m.group(2)))
elif op == "items":
    if inline.startswith("["):
        for x in inline.strip("[]").split(","):
            if x.strip():
                print(norm(x))
    for _, txt in cur:
        if txt.startswith("- "):
            print(norm(txt[2:]))
PY
}

# 失败（含键不存在）输出空串，由断言去判定
yq() { yq_lite "$@" 2>/dev/null | sort | paste -sd, - || true; }

expect() {
  local desc="$1" actual="$2" want="$3"
  if [[ "$actual" == "$want" ]]; then pass; else fail "${desc}：期望 [${want}]，实际 [${actual}]"; fi
}

echo "[发布目录无链接]"
if [[ ! -d "$ROOT/site" ]]; then
  fail "site/ 目录不存在"
elif [[ -n "$(find "$ROOT/site" -type l)" ]]; then
  fail "site/ 下有符号链接：$(find "$ROOT/site" -type l | paste -sd, -)"
else
  pass
fi

echo "[pages.yml 存在]"
if [[ ! -f "$PAGES" ]]; then
  fail ".github/workflows/pages.yml 不存在"
  echo ""
  echo "通过 ${PASS}，失败 ${FAIL}"
  exit 1
fi
pass

echo "[触发器]"
expect "on 只有 push" "$(yq "$PAGES" keys on)" "push"
expect "push 只有 branches 和 paths" "$(yq "$PAGES" keys on/push)" "branches,paths"
expect "branches 只有 main" "$(yq "$PAGES" items on/push/branches)" "main"
expect "paths 恰为 site/** 与 pages.yml" "$(yq "$PAGES" items on/push/paths)" ".github/workflows/pages.yml,site/**"
for ev in pull_request workflow_dispatch release schedule; do
  if grep -Eq "^[[:space:]]*\"?${ev}\"?[[:space:]]*:" "$PAGES"; then fail "pages.yml 含触发器 ${ev}"; else pass; fi
done

echo "[权限]"
expect "顶层 permissions 只有 contents: read" "$(yq "$PAGES" kv permissions)" "contents=read"
BUILD_EFFECTIVE="$(yq "$PAGES" kv permissions),$(yq "$PAGES" kv jobs/build/permissions)"
for perm in pages=write id-token=write; do
  if [[ ",${BUILD_EFFECTIVE}," == *",${perm},"* ]]; then fail "build 的有效权限含 ${perm}"; else pass; fi
done
DEPLOY_PERMS="$(yq "$PAGES" kv jobs/deploy/permissions)"
if [[ "$DEPLOY_PERMS" == "id-token=write,pages=write" || "$DEPLOY_PERMS" == "contents=read,id-token=write,pages=write" ]]; then pass; else fail "deploy 自己的 permissions：期望 pages/id-token 为 write（contents 只能 read），实际 [${DEPLOY_PERMS}]"; fi
if grep -Eq 'contents:[[:space:]]*write' "$PAGES"; then fail "pages.yml 含 contents: write"; else pass; fi

echo "[并发]"
expect "concurrency.group" "$(yq "$PAGES" scalar concurrency/group)" "pages"
expect "concurrency.cancel-in-progress" "$(yq "$PAGES" scalar concurrency/cancel-in-progress)" "false"

echo "[发布范围与 Action]"
if grep -Eq '^[[:space:]]*path:[[:space:]]*"?site/?"?[[:space:]]*$' "$PAGES"; then pass; else fail "上传构件步骤缺少 path: site"; fi
for act in actions/upload-pages-artifact actions/deploy-pages; do
  if grep -Eq "uses:[[:space:]]*${act}@" "$PAGES"; then pass; else fail "缺少 uses: ${act}@<版本>"; fi
done
USES="$(grep -E '^[[:space:]-]*uses:' "$PAGES" | sed -E 's/.*uses:[[:space:]]*//; s/@.*//; s/[[:space:]#].*//' | sort -u | paste -sd, -)"
expect "uses 只有三种 Action" "$USES" "actions/checkout,actions/deploy-pages,actions/upload-pages-artifact"

echo "[job 结构]"
expect "jobs 为 build 与 deploy" "$(yq "$PAGES" keys jobs)" "build,deploy"
expect "deploy.needs" "$(yq "$PAGES" scalar jobs/deploy/needs)" "build"
expect "deploy.environment.name" "$(yq "$PAGES" scalar jobs/deploy/environment/name)" "github-pages"

echo "[ci 与发版互不牵连]"
for f in "$CI" "$RELEASE"; do
  if [[ ! -f "$f" ]]; then fail "$f 不存在"; continue; fi
  if grep -Eqi 'pages|deploy-pages' "$f"; then fail "$(basename "$f") 含 pages 或 deploy-pages"; else pass; fi
done

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 && "$PASS" -gt 0 ]]
