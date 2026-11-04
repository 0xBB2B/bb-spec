#!/usr/bin/env bash
# 新技术审批规则校验：plan 列清单并一次弹窗、exec 与 impl-engineer 遇到表外新技术先停、prd 确认说明写明会中途停下
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/plugins/bb-spec-workflow"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

has() {
  local file="$1" text="$2"
  if grep -qF -- "$text" "$WF/$file" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

lacks() {
  local file="$1" text="$2"
  local rc=0
  grep -qF -- "$text" "$WF/$file" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "${file} 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${WF}/${file}" ;;
  esac
}

PLAN=skills/plan/SKILL.md
EXEC=skills/exec/SKILL.md
IMPL=agents/impl-engineer.md
PRD=skills/prd/SKILL.md

echo "[plan 列清单并一次弹窗]"
for t in '只在需要引入新技术时停下问用户' '上面 N 项新技术，你同意引入吗？' \
  '选项依次是"同意"、"不同意"' '在正文追问要改哪几项、改成什么' \
  '插件默认栈和用户点名的也列' '## 新增技术（仅本 plan 引入新技术时存在）' \
  '| 名称 | 类别 | 来源 | 用途 | 现有手段为什么不够 | 替代方案为什么不选 | 版本策略 |'; do
  has "$PLAN" "$t"
done
for t in '新增第三方依赖' '| 库名 | 用途 | 版本策略 |' '全部同意，继续' '否决其中几项'; do lacks "$PLAN" "$t"; done

echo "[exec 的新技术守卫]"
for t in '新增技术表' '新技术守卫' 'compose.yaml' '.github/workflows/*' '这一步不算完成'; do has "$EXEC" "$t"; done
for t in '新增第三方依赖' '依赖守卫'; do lacks "$EXEC" "$t"; done
has "$EXEC" '按 `version-policy` 的「批准方式」处理：用户最终选"同意"'
has "$EXEC" '用户不要任何新技术 → 令子代理改用标准库'
lacks "$EXEC" '用户不同意 → 令子代理改用标准库'

echo "[impl-engineer 只引入表内技术]"
for t in '「新增技术」表' '没有这张表就一项都不能引入' '方案问题'; do has "$IMPL" "$t"; done
for t in '新增第三方库' '装清单外依赖'; do lacks "$IMPL" "$t"; done

echo "[prd 确认弹窗说明]"
has "$PRD" '需要引入新技术或遇到设计判断时停下问你'
lacks "$PRD" '需要新增第三方依赖'

TEST=agents/test-engineer.md
REVISE=skills/revise/SKILL.md

echo "[exec：整份清单一次批准、子代理上报表外新技术]"
for t in '| 新增技术表（plan「新增技术」区，如有） | ✅ | ✅ | ❌ |' '2a、2b 每次子代理返回后都做' \
  '本主题全部 plan 的「新增技术」表合起来' '不进下方「归因」' '先补进对应 plan 的「新增技术」表' \
  '本步骤补过「新增技术」表的 plan 文件' 'golang.org/x/*'; do
  has "$EXEC" "$t"
done
lacks "$EXEC" '| 新增技术表（plan「新增技术」区，如有） | ❌ | ✅ | ❌ |'
for t in '以及本 plan 文件里引用它们的代码' '只撤这些，同组其他 plan 的改动不动'; do has "$EXEC" "$t"; done
lacks "$EXEC" '只撤这些项'

echo "[plan：改清单、写文档时机、自检]"
for t in '只替换提到的项，整份清单再列一遍' '直到用户选"同意"；在此之前不写 plan 文档' '用户已选"同意"（没有新技术则未询问）' '用户不要任何新技术' '没有新技术 → 不列清单、不问' \
  '七栏内容和清单一致' '两条理由写的是具体原因、不是"业界常用""更优雅""更流行"'; do
  has "$PLAN" "$t"
done
for t in '弹窗前先自查' '不合格的先改好' '代码里直接引用的间接依赖也算'; do has "$PLAN" "$t"; done

echo "[impl-engineer：新技术判定范围]"
for t in 'golang.org/x/*' '间接依赖' '升级已在用依赖的版本不算'; do has "$IMPL" "$t"; done

echo "[test-engineer 只引入表内技术]"
for t in 'new_tech_table' '「新增技术」表' '测试库、测试工具也算' '没有这张表就一项都不能引入'; do has "$TEST" "$t"; done

echo "[revise 拦新技术]"
for t in '+ 不引入新技术。' 'version-policy' '把用户在本次 revise 里批准的项作为「新增技术」表一起传过去' \
  '同样先列清单弹窗，不进归因' '新增技术表（本次批准的，如有）+ 项目测试惯例' '新增技术表（本次批准的，如有）+ 项目约束'; do
  has "$REVISE" "$t"
done

echo ""
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
