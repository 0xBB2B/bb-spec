# 执行进度
| 序号 | Plan | 状态 | 完成时间 |
|---|---|---|---|
| 01 | show-prototype-script | done | 2026-11-19 |
| 02 | prototype-rule | pending | — |
## 当前
准备执行 `02-prototype-rule.md`。
## 阻塞
（无）
## 重试与自修（每次记一条）
- show-prototype-script 自修第 1 轮：Chrome/Safari 写在同一段 AppleScript，没装 Chrome 时编译失败、Safari 分支跑不到；地址转换比 Chrome 实测多转了 `!$&'()*+,=@:` → 结果：已改为两次独立 osascript 调用、按 Chrome 实测调整保留字符；测试 39/39 通过；真机 Chrome（特殊字符路径）与 Safari 均实测 reloaded、标签数不变，用户确认窗口提到最前
- show-prototype-script 自修第 2 轮：设了 CDPATH 且传相对路径时 `cd` 输出污染目录（show-prototype.sh:8，同类 branch-prds.sh:9）；补 `{}^`|"<>` 地址用例 → 结果：两处改为 `CDPATH= cd -- … >/dev/null`，补 CDPATH 与字符用例；show-prototype 41/41、branch-prds 11/11 通过；复审 7/7 合规
## 无关发现（发现一条记一条）
- tests/*.test.sh 第 5 行 `$(cd "$(dirname "$0")/.." && pwd)`：设了 CDPATH 时 ROOT 被污染、测试误报；只影响开发者跑测试；估计 10 分钟
