#!/usr/bin/env bash
# 规则测试里的 lacks 断言：被测文件读不到时必须失败并提示"读不到"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

COPY="$(mktemp -d)"
COPY="$(cd "$COPY" && pwd -P)"
trap 'rm -rf "$COPY"' EXIT

copy_repo() {
  local dst="$1" item
  mkdir -p "$dst"
  for item in "$ROOT"/* "$ROOT"/.[!.]*; do
    case "$(basename "$item")" in .git|.bb-spec) continue ;; esac
    [[ -e "$item" ]] && cp -R "$item" "$dst/"
  done
}

echo "[policy：删掉 vue-constraints]"
copy_repo "$COPY/policy"
rm -f "$COPY/policy/plugins/bb-spec-frontend/skills/vue-constraints/SKILL.md"
if (cd "$COPY/policy" && bash tests/new-tech-policy.test.sh >"$COPY/policy.out" 2>&1); then
  fail "删掉 vue-constraints 后 new-tech-policy 应退出非 0"
else
  pass
fi
if grep -F '读不到' "$COPY/policy.out" | grep -F 'vue-constraints' >/dev/null; then pass; else fail "输出应有同时含 读不到 和 vue-constraints 的行"; fi

echo "[workflow：删掉 plan]"
copy_repo "$COPY/workflow"
rm -f "$COPY/workflow/plugins/bb-spec-workflow/skills/plan/SKILL.md"
if (cd "$COPY/workflow" && bash tests/new-tech-workflow.test.sh >"$COPY/workflow.out" 2>&1); then
  fail "删掉 plan 后 new-tech-workflow 应退出非 0"
else
  pass
fi
if grep -F '读不到' "$COPY/workflow.out" | grep -F 'plan/SKILL.md' >/dev/null; then pass; else fail "输出应有同时含 读不到 和 plan/SKILL.md 的行"; fi

echo "[正常仓库]"
copy_repo "$COPY/ok"
for t in new-tech-policy new-tech-workflow; do
  if (cd "$COPY/ok" && bash "tests/$t.test.sh" >"$COPY/ok-$t.out" 2>&1); then pass; else fail "$t 在完整仓库应退出 0"; fi
  if grep -qF '读不到' "$COPY/ok-$t.out"; then fail "$t 在完整仓库输出不应含 读不到"; else pass; fi
done

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
