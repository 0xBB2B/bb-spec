#!/usr/bin/env bash
# Stop hook：任务结束前注入一次"临时文件管理 + 改动范围自检"提示，强制 AI 复查一轮。
# 防循环：依赖 stop_hook_active 字段，若为 true 表示本会话已经触发过一次自检，直接放行。
# 输入：标准 Stop stdin JSON
# 输出：首次触发输出 decision:block（让 AI 接着复查）；二次触发静默放行。

set -euo pipefail

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
ACTIVE=$(jq -r '.stop_hook_active // false' <<<"$INPUT")
if [ "$ACTIVE" = "true" ]; then
  # 已经触发过一次自检，避免死循环
  exit 0
fi

REASON=$(cat <<'EOF'
任务结束前必须完成下列自检，逐条核对后才能停下。如本回合未涉及编码改动，仅口头核对即可：

1. **临时文件管理**：本次任务产生的任何临时文件（测试输出、日志、缓存、临时打包/脚本文件等）必须统一创建在系统临时目录 `/tmp` 下，禁止散落在项目工作区；任务结束前确认这些临时文件已全部清除，未清除的立即清除。
2. **改动范围**：检查本次 diff 是否仅限本次需求所必须，是否混入了"顺手优化"/无关重构/相邻代码风格调整。若有，回滚无关改动。
3. **孤立残留**：本次改动导致的不再使用的 import / 变量 / 函数是否已清掉。
4. **历史包袱**：是否在文档或代码里写了"保留原 X 以兼容"/"加注释标记已废弃"/"新旧并列"等过渡式表述。若有，按 No Legacy Baggage 原则直接清掉。

逐条核对完成后再停下。
EOF
)

jq -nc --arg reason "$REASON" '{
  "decision": "block",
  "reason": $reason
}'
