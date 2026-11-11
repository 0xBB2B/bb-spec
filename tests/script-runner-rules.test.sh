#!/usr/bin/env bash
# 跑脚本子代理规则校验：子代理定义、三个流程 SKILL 的分流规则、子代理数量与 README 清单
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PL="$ROOT/plugins"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

skill_scope() {
  case "$1" in
    */skills/git-push/SKILL.md|*/skills/prd/SKILL.md|*/skills/revise/SKILL.md) dirname "$1" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

skill_cat() {
  cat "$1" || return
  case "$1" in
    */skills/git-push/SKILL.md|*/skills/prd/SKILL.md|*/skills/revise/SKILL.md)
      local r
      for r in "$(dirname "$1")"/references/*.md; do
        if [ -f "$r" ]; then cat "$r"; fi
      done ;;
  esac
  return 0
}

has() {
  local file="$1" text="$2"
  if grep -rqF -- "$text" "$(skill_scope "$PL/$file")" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

has_root() {
  local file="$1" text="$2"
  if grep -qF -- "$text" "$ROOT/$file" 2>/dev/null; then pass; else fail "${file} 缺少：${text}"; fi
}

lacks() {
  local file="$1" text="$2"
  local rc=0
  grep -rqF -- "$text" "$(skill_scope "$PL/$file")" 2>/dev/null || rc=$?
  case "$rc" in
    0) fail "${file} 不应含：${text}" ;;
    1) pass ;;
    *) fail "读不到 ${PL}/${file}" ;;
  esac
}

AG=bb-spec-workflow/agents
SK=bb-spec-workflow/skills
RUN="$AG/script-runner.md"

echo "[跑脚本子代理定义]"
for t in 'model: sonnet' 'agent-type: general-purpose' '成功：报告不超过 800 字符' \
  '报告不超过 3,000 字符' '输出文件连续 30 分钟大小没有变化' '不设总时长上限' \
  '不重试，直接报告启动失败和错误信息' 'kill -- -<进程组号>' 'set -m' \
  'echo $? > "<输出文件>.exit"' '退出码是 126 或 127 → 按「启动失败」报告' \
  '没有给输出文件目录' '启动前检查' \
  '不改项目文件，不操作 git' '输出文件：<完整路径>' '## 安全基线'; do
  has "$RUN" "$t"
done
lacks "$RUN" 'mktemp'
lacks "$RUN" 'pkill -P'
lacks "$RUN" '第一个词'
has "$RUN" '命令找不到的情况由第 7 步按退出码判断'

echo "[exec / revise / git-push：跑脚本分流规则]"
for s in exec revise git-push; do
  for t in '**跑脚本**' '预计 2 分钟内能跑完 → 主窗口用前台 Bash 直接跑' \
    'bb-spec-workflow:script-runner' '主窗口不执行循环等待脚本结束的命令' \
    '没有可做的就结束回合，报告交回后继续' \
    '常驻服务（dev server、watch、`tail -f`）由主窗口自己用后台方式启动'; do
    has "$SK/$s/SKILL.md" "$t"
  done
done

section_has() {
  local file="$1" head="$2" text="$3" body
  body="$(skill_cat "$PL/$file" 2>/dev/null | awk -v h="$head" 'index($0, h) == 1 { on = 1; next } on && /^## / { exit } on' || true)"
  if grep -qF -- "$text" <<<"$body"; then pass; else fail "${file} 的「${head}」节缺少：${text}"; fi
}

GP="$SK/git-push/SKILL.md"
echo "[git-push 4.2 ocr 审查与 4.3 全量测试]"
for t in 'bb-spec-workflow:script-runner' '<cache_dir>/ocr/<branch>.json' 'reports'; do
  section_has "$GP" '## 4.2' "$t"
done
for t in '**跑脚本**' '预计 2 分钟内能跑完 → 主窗口用前台 Bash 直接跑'; do
  section_has "$GP" '## 4.3' "$t"
done

echo "[git-push：旧的前台循环等待已删除]"
lacks "$SK/git-push/SKILL.md" '每次前台调用最多等 2 分钟'
lacks "$SK/git-push/SKILL.md" '循环等 ocr 进程退出'

echo "[子代理数量与目录文件数一致]"
N="$(ls "$PL"/bb-spec-workflow/agents/*.md | wc -l | tr -d ' ')"
has bb-spec-workflow/.claude-plugin/plugin.json "${N} 个编排 subagent"
has_root .claude-plugin/marketplace.json "${N} 个编排 subagent"

echo "[五份 README 列出 script-runner]"
for r in README.md README.en.md README.ja.md README.ko.md README.zh-TW.md; do
  has_root "$r" 'script-runner'
done
WAIT_ROW="$(grep -F '`background-script-wait`' "$ROOT/README.md" | grep -F '| Stop |' | head -1 || true)"
if [[ -n "$WAIT_ROW" ]]; then pass; else fail "README.md 缺少同时含 background-script-wait 和 | Stop | 的行"; fi
if [[ -n "$WAIT_ROW" && "$WAIT_ROW" != *'前台循环'* ]]; then pass; else fail "README.md 的 background-script-wait 行应存在且不含：前台循环"; fi
if [[ "$WAIT_ROW" == *'不循环等待'* ]]; then pass; else fail "README.md 的 background-script-wait 行应含：不循环等待"; fi

echo
echo "通过：${PASS}，失败：${FAIL}"
[ "$FAIL" -eq 0 ]
