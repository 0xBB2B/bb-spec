#!/usr/bin/env bash
# PostToolUse/Write|Edit：命中"会钉死外部资产版本号"的文件时，注入版本号自检提示。
# 依赖策略（dependency-version-policy）：写入版本号前必须通过官方渠道查询最新版，禁止凭训练记忆。
# 输入：标准 PostToolUse stdin JSON
# 输出：仅在命中时输出 additionalContext；不命中静默退出 0。

set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<<"$INPUT")
case "$TOOL" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' <<<"$INPUT")
[ -n "$FILE" ] || exit 0

BASENAME=$(basename "$FILE")
HIT=0

# 文件名精确匹配
case "$BASENAME" in
  package.json|go.mod|requirements.txt|Pipfile|pyproject.toml|Cargo.toml|pom.xml|build.gradle|build.gradle.kts|.nvmrc|.tool-versions|Chart.yaml|.python-version|Gemfile)
    HIT=1 ;;
esac

# 模式匹配
if [ "$HIT" -eq 0 ]; then
  case "$BASENAME" in
    Dockerfile|Dockerfile.*|*.dockerfile)
      HIT=1 ;;
    docker-compose.yml|docker-compose.yaml|compose.yml|compose.yaml)
      HIT=1 ;;
    requirements-*.txt|requirements_*.txt)
      HIT=1 ;;
  esac
fi

# 路径片段匹配（GitHub Actions / GitLab CI / Terraform）
if [ "$HIT" -eq 0 ]; then
  case "$FILE" in
    *.github/workflows/*.yml|*.github/workflows/*.yaml)
      HIT=1 ;;
    *.gitlab-ci.yml|*.gitlab-ci.yaml)
      HIT=1 ;;
    *.tf|*.tf.json)
      HIT=1 ;;
  esac
fi

[ "$HIT" -eq 1 ] || exit 0

MSG=$(printf '依赖版本号自检（dependency-version-policy）：刚改动了 `%s`。\n若本次改动写入或更新了任何外部资产的版本号（npm/Go/PyPI/Cargo/Maven/Actions/容器镜像/IaC provider/Helm/CLI 等），请确认每个版本号都通过**官方渠道**查询过最新稳定版（npm view / go list -m -versions / pip index versions / cargo search / docker manifest 等），未凭训练记忆填写。\n若仅改动非版本字段（脚本、依赖名、配置 key 等），请忽略本提示。' "$FILE")

jq -nc --arg msg "$MSG" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": $msg
  }
}'
