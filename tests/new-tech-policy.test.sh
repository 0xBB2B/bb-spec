#!/usr/bin/env bash
# 新技术审批规则校验：version-policy 写明清单与批准流程，golang-constraints、vue-constraints 只调用它
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VP="$ROOT/plugins/bb-spec-core/skills/version-policy/SKILL.md"
GO="$ROOT/plugins/bb-spec-backend/skills/golang-constraints/SKILL.md"
VUE="$ROOT/plugins/bb-spec-frontend/skills/vue-constraints/SKILL.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local file="$1" text="$2"
  if grep -qF -- "$text" "$file" 2>/dev/null; then pass; else fail "$(basename "$(dirname "$file")") 缺少：${text}"; fi
}

lacks() {
  local file="$1" text="$2"
  local rc=0
  grep -qF -- "$text" "$file" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "$(basename "$(dirname "$file")") 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${file}" ;;
  esac
}

echo "[version-policy 正文]"
for t in '项目里原来没有的外部东西' '插件默认栈' '用户点名' 'Claude 提议' \
  '现有手段为什么不够' '替代方案为什么不选' '上面 N 项新技术，你同意引入吗？' \
  '全部同意，继续' '否决其中几项' '只替换被否决的项' '"业界常用""更优雅""更流行"' \
  '「新增技术」表' '容器镜像' 'CI Action' '外部服务接口'; do
  has "$VP" "$t"
done

echo "[version-policy 的 frontmatter]"
FM="$(awk '/^---[[:space:]]*$/{n++; next} n==1{print} n>=2{exit}' "$VP" 2>/dev/null || true)"
DESC="$(printf '%s\n' "$FM" | grep '^description:' || true)"
for t in '新技术' '插件默认栈和用户点名的也一样'; do
  if printf '%s\n' "$DESC" | grep -qF -- "$t"; then pass; else fail "version-policy 的 description 缺少：${t}"; fi
done

echo "[version-policy 不含的说法]"
for t in '视为已同意' '批准即同意' '新增第三方库的同意流程'; do
  lacks "$VP" "$t"
done

echo "[golang-constraints]"
has "$GO" '新技术清单'
has "$GO" '用户点名的库也一样'
lacks "$GO" '视为已同意'

echo "[vue-constraints]"
has "$VUE" '新技术清单'
has "$VUE" '来源标"插件默认栈"'
lacks "$VUE" '统一使用以下技术栈，**不接受个人偏好替代**'

echo "[version-policy：扩展库与间接依赖、追问、类别、流程]"
for t in '不在标准库里的官方扩展库' 'golang.org/x/*' '间接依赖' '没写编号时，追问一次' \
  '项目里原来没有 bun 时，它也是新技术' '本次没有新技术时跳过前三条' \
  '编程语言' '运行时' '数据库' '中间件' '构建或测试工具' '用户点名的项也要写' \
  '整份清单再列一遍、再弹一次窗' '用户不要任何新技术' \
  '用户选"全部同意，继续"之前，不改依赖文件和配置文件' \
  '不管是在执行计划、修 bug 还是普通对话中' '每项七项内容齐全'; do
  has "$VP" "$t"
done
for t in '不在本 skill 范围内' '语言官方库'; do
  lacks "$VP" "$t"
done

echo "[vue-constraints：与新规则冲突的说法已清除]"
for t in '用户否决默认栈中的哪一项，就按用户的选择换掉' 'X 是项目里原来没有的新技术时' \
  '对这个项目是新技术' '默认栈各项已列进新技术清单'; do
  has "$VUE" "$t"
done
for t in ' 自动改为 `bun add X` 执行' '不接受"个人偏好"作为偏离依据' '新项目强制' \
  '| 新建项目 | **bun**（强制） |' '## 1. 默认技术栈（强制）' '除非有明确业务必要并经用户确认'; do
  lacks "$VUE" "$t"
done

for t in '含用户批准用 bun 的新建项目' '新项目按用户批准的清单'; do has "$VUE" "$t"; done
for t in '（含新建项目）' '新项目 bun；'; do lacks "$VUE" "$t"; done

echo "[golang-constraints：官方扩展库]"
has "$GO" 'golang.org/x/*'
lacks "$GO" '确需新增第三方库时'

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
