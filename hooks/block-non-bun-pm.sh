#!/usr/bin/env bash
# 拦截 npm / yarn / pnpm 的"包管理动作"（install / add / i / ci），强制改用 bun。
# 设计原则：
#   - 仅拦截会改动 lockfile / node_modules 的命令；脚本执行（run / test / start）等不拦。
#   - 既有项目跟随现存 lockfile：从 cwd 向上找到与命令匹配的 lockfile
#     （npm→package-lock.json / yarn→yarn.lock / pnpm→pnpm-lock.yaml）即放行，不强制迁移 bun。
#   - 命中即 deny，并在 reason 里给出等价的 bun 替代命令。
# 输入：标准 PreToolUse stdin JSON
# 输出：仅在命中时输出 JSON；不命中静默退出 0 让其他 hook 与默认权限继续生效。

set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")
[ "$TOOL" = "Bash" ] || exit 0

CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -n "$CMD" ] || exit 0

# 取首个 token；剥掉可能的 env 前缀（FOO=bar npm i ...）以及 sudo / nohup
read -r FIRST REST <<<"$CMD" || true
while [[ "$FIRST" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || [[ "$FIRST" == "sudo" ]] || [[ "$FIRST" == "nohup" ]]; do
  read -r FIRST REST <<<"$REST" || true
  [ -z "$FIRST" ] && break
done

case "$FIRST" in
  npm|yarn|pnpm) ;;
  *) exit 0 ;;
esac

# 取动作子命令
read -r SUB _ <<<"$REST" || true

# 仅拦截"会改 lockfile / node_modules"的子命令
BLOCK=0
case "$FIRST:$SUB" in
  npm:install|npm:i|npm:add|npm:ci|npm:isntall|npm:uninstall|npm:un|npm:rm|npm:remove|npm:update|npm:up|npm:upgrade)
    BLOCK=1; SUGGEST="bun add / bun install / bun remove / bun update" ;;
  yarn:install|yarn:add|yarn:remove|yarn:upgrade|yarn:upgrade-interactive)
    BLOCK=1; SUGGEST="bun install / bun add / bun remove / bun update" ;;
  pnpm:install|pnpm:i|pnpm:add|pnpm:remove|pnpm:rm|pnpm:un|pnpm:uninstall|pnpm:update|pnpm:up|pnpm:upgrade)
    BLOCK=1; SUGGEST="bun install / bun add / bun remove / bun update" ;;
esac

# yarn / pnpm 在没有子命令时默认就是 install
if [ "$BLOCK" -eq 0 ] && [ -z "${SUB:-}" ]; then
  case "$FIRST" in
    yarn|pnpm) BLOCK=1; SUGGEST="bun install" ;;
  esac
fi

[ "$BLOCK" -eq 1 ] || exit 0

# 既有项目跟随现存 lockfile：从命令的 cwd 向上查找与该工具匹配的 lockfile，
# 找到即放行（旧项目不强求迁移 bun）；越过 .git（仓库边界）或到根目录为止。
case "$FIRST" in
  npm)  WANTED_LOCK="package-lock.json" ;;
  yarn) WANTED_LOCK="yarn.lock" ;;
  pnpm) WANTED_LOCK="pnpm-lock.yaml" ;;
esac
DIR=$(jq -r '.cwd // empty' <<<"$INPUT")
[ -d "$DIR" ] || DIR=$PWD
while :; do
  [ -f "$DIR/$WANTED_LOCK" ] && exit 0
  [ -d "$DIR/.git" ] && break
  [ "$DIR" = "/" ] && break
  DIR=$(dirname "$DIR")
done

REASON=$(printf '前端约束（vue-constraints）：禁止使用 %s 做包管理动作，请改用 bun 等价命令：%s。如确实需要保留原命令，请在本回合明确说明理由再继续。' "$FIRST" "$SUGGEST")

jq -nc --arg reason "$REASON" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": $reason
  }
}'
