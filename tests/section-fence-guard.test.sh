#!/usr/bin/env bash
# 守护规则测试的取段逻辑：代码块里的标题行、分隔线、加粗步骤行、编号行既不能当成一段的结束行，也不能当成起始行
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

WF=plugins/bb-spec-workflow

new_copy() {
  local dst="$TMP/$1" item
  mkdir -p "$dst"
  for item in "$ROOT"/* "$ROOT"/.[!.]*; do
    case "$(basename "$item")" in .git|.bb-spec) continue ;; esac
    [[ -e "$item" ]] && cp -R "$item" "$dst/"
  done
  echo "$dst"
}

# 在文件 $1 里第一个以 $2 开头的行后面插入一个代码块（$3 非空时是外层四个反引号、内层三个的嵌套代码块），块里放各种会被当成结束行的内容
inject_fence() {
  python3 - "$1" "$2" "${3:-}" <<'PY'
import sys
p, prefix, nested = sys.argv[1:4]
lines = open(p, encoding="utf-8").read().split("\n")
i = next(k for k, l in enumerate(lines) if l.startswith(prefix))
block = ["```", "---", "# 注释", "## 注释", "### 注释", "#### 注释",
         "9. 注释", "**2z. 注释**", "**7z. 注释**", "**步骤 9：注释**", "```"]
if nested:
    block = ["````markdown", "```bash"] + block[1:-1] + ["```", "````"]
lines[i + 1:i + 1] = block
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
}

# 在文件 $1 里第一个以 $2 开头的行前面插入一个代码块，块里放 $4 这一行（$3 非空时用嵌套代码块）
inject_before() {
  python3 - "$1" "$2" "${3:-}" "$4" <<'PY'
import sys
p, prefix, nested, text = sys.argv[1:5]
lines = open(p, encoding="utf-8").read().split("\n")
i = next(k for k, l in enumerate(lines) if l.startswith(prefix))
block = ["```", text, "```"]
if nested:
    block = ["````markdown", "```bash", text, "```", "````"]
lines[i:i] = block
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
}

# 在文件末尾追加一个代码块，块里有一行假的起始标题和一句本不该出现的话
append_fake_start() {
  printf '\n```\n%s\n%s\n```\n' "$2" "$3" >>"$1"
}

run_rules() {
  local dst="$1" name="$2" rc=0
  bash "$dst/tests/$name.test.sh" >"$dst/out.txt" 2>&1 || rc=$?
  return "$rc"
}

check() {
  local label="$1" dst="$2" name="$3"
  if run_rules "$dst" "$name"; then
    pass
  else
    fail "${label}：代码块里的行被当成了结束行"
    grep -F 'FAIL' "$dst/out.txt" | sed 's/^/    /' | head -n 20
  fi
}

echo "[场景 1：design-doc-rules 的 DESIGN.md 模板各小节开头放代码块]"
d="$(new_copy s1)"
for h in '## 2. 颜色' '## 4. 间距' '## 5. 圆角、边框、阴影' '## 7. 组件' '### 按钮' '## 10. 终端界面'; do
  inject_fence "$d/$WF/templates/DESIGN.md" "$h"
done
check design-doc-rules-模板 "$d" design-doc-rules

echo "[场景 2：design-doc-rules 的各规程文件小节开头放代码块]"
d="$(new_copy s2)"
inject_fence "$d/$WF/skills/prd/SKILL.md" '### 步骤 6'
inject_fence "$d/$WF/skills/revise/SKILL.md" '### 步骤 4'
inject_fence "$d/$WF/skills/revise/references/fix-by-type.md" '#### 3a.'
inject_fence "$d/$WF/skills/revise/references/fix-by-type.md" '#### 3b.'
inject_fence "$d/$WF/skills/revise/references/fix-by-type.md" '## Agent 隔离规则'
inject_fence "$d/$WF/skills/exec/SKILL.md" '**信息隔离矩阵**'
inject_fence "$d/$WF/skills/doc-update/SKILL.md" '## 四类发现'
check design-doc-rules-规程 "$d" design-doc-rules

echo "[场景 3：prototype-dispatch-rules 的 prd 小节开头放代码块]"
d="$(new_copy s3)"
inject_fence "$d/$WF/skills/prd/SKILL.md" '### 步骤 6'
check prototype-dispatch-rules "$d" prototype-dispatch-rules

echo "[场景 4：report-limit-rules 的小节开头放嵌套代码块]"
d="$(new_copy s4)"
inject_fence "$d/$WF/skills/revise/SKILL.md" '### 步骤 5' nested
inject_fence "$d/$WF/skills/test-webview/SKILL.md" '### 步骤 6' nested
inject_fence "$d/$WF/skills/git-push/SKILL.md" '## 4.5' nested
check report-limit-rules "$d" report-limit-rules

echo "[场景 5：prototype-agent-rules 的小节开头放代码块、代码块里有假的起始标题]"
d="$(new_copy s5)"
inject_fence "$d/$WF/agents/prototype-designer.md" '## 确认内容清单'
append_fake_start "$d/$WF/agents/prototype-designer.md" '## 出原型' '缓存目录'
check prototype-agent-rules "$d" prototype-agent-rules

echo "[场景 6：script-runner-rules 的 git-push 4.2、4.3 小节开头放代码块]"
d="$(new_copy s6)"
inject_fence "$d/$WF/skills/git-push/SKILL.md" '## 4.2'
inject_fence "$d/$WF/skills/git-push/SKILL.md" '## 4.3'
check script-runner-rules "$d" script-runner-rules

echo "[场景 7：ui-preview-rules 的小节开头放代码块]"
d="$(new_copy s7)"
inject_fence "$d/$WF/skills/prototype/SKILL.md" '## 两种模式都先做'
inject_fence "$d/$WF/agents/prototype-designer.md" '## 取证顺序'
check ui-preview-rules "$d" ui-preview-rules

echo "[场景 8：design-doc-rules 的 DESIGN.md 模板开头部分放代码块]"
d="$(new_copy s8)"
inject_fence "$d/$WF/templates/DESIGN.md" '# DESIGN.md'
check design-doc-rules-开头 "$d" design-doc-rules

echo "[场景 9：design-doc-rules、prototype-dispatch-rules 的被测小节开头放嵌套代码块]"
d="$(new_copy s9)"
inject_fence "$d/$WF/templates/DESIGN.md" '## 2. 颜色' nested
inject_fence "$d/$WF/skills/prd/SKILL.md" '### 步骤 6' nested
check design-doc-rules-嵌套 "$d" design-doc-rules
check prototype-dispatch-rules-嵌套 "$d" prototype-dispatch-rules

echo "[场景 10：ui-preview-rules 的第 8 步开头放含 9. 编号行的代码块]"
d="$(new_copy s10)"
inject_fence "$d/$WF/agents/prototype-designer.md" '8. 原型文件写好后交回报告'
check ui-preview-rules-第8步 "$d" ui-preview-rules

echo "[场景 11：report-limit-rules 比较标题先后，代码块里的后一个标题副本放在前一个标题之前]"
d="$(new_copy s11)"
inject_before "$d/$WF/agents/test-engineer.md" '## 报告长度' '' '## 安全基线'
inject_before "$d/$WF/agents/prototype-designer.md" '## 报告长度' '' '## 安全基线'
check report-limit-rules-标题先后 "$d" report-limit-rules

echo "[场景 12：ui-preview-rules 找标题行号，代码块里的「## 出原型」副本放在设计规范之前]"
d="$(new_copy s12)"
inject_before "$d/$WF/agents/prototype-designer.md" '## 设计规范（DESIGN.md）' '' '## 出原型'
check ui-preview-rules-标题行号 "$d" ui-preview-rules

echo "[场景 13：fix-scope-rules 统计标题，嵌套代码块里的「## 5. 推送到远程」副本放在 4.6 之前]"
d="$(new_copy s13)"
inject_before "$d/$WF/skills/git-push/SKILL.md" '## 4.6 ' nested '## 5. 推送到远程'
check fix-scope-rules-标题计数 "$d" fix-scope-rules

echo "[场景 14：design-showcase-rules 找标题行号，代码块里的「## 取证顺序」副本放在设计规范之前]"
d="$(new_copy s14)"
inject_before "$d/$WF/agents/prototype-designer.md" '## 设计规范（DESIGN.md）' '' '## 取证顺序'
check design-showcase-rules-标题行号 "$d" design-showcase-rules

echo "[场景 15：design-doc-rules 找模板标题行号，嵌套代码块里的标题副本放在「## 7. 组件」之前]"
d="$(new_copy s15)"
inject_before "$d/$WF/templates/DESIGN.md" '## 2. 颜色' '' '## 3. 字体与字号'
inject_before "$d/$WF/templates/DESIGN.md" '## 7. 组件' nested '## 8. 动效'
inject_before "$d/$WF/templates/DESIGN.md" '## 7. 组件' '' '### 按钮'
check design-doc-rules-模板标题行号 "$d" design-doc-rules

echo "[场景 16：ui-preview-rules 找步骤行，代码块里的第 1 条副本放在「## 出原型」之前]"
d="$(new_copy s16)"
inject_before "$d/$WF/agents/prototype-designer.md" '## 出原型' '' '1. 按「设计规范（DESIGN.md）」先过一遍 DESIGN.md'
check ui-preview-rules-步骤行 "$d" ui-preview-rules

echo "[场景 17：ui-preview-rules 在取证顺序里找编号条目，嵌套代码块里的第 3 条副本放在第 1 条之前]"
d="$(new_copy s17)"
inject_before "$d/$WF/agents/prototype-designer.md" '1. **DESIGN.md**：' nested '3. **问用户要不要跑**：'
check ui-preview-rules-编号条目 "$d" ui-preview-rules

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
