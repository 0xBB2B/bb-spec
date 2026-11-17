# 执行进度
| 序号 | Plan | 状态 | 完成时间 |
|---|---|---|---|
| 01 | 01-homepage-page | in-progress | — |
| 02 | 02-pages-deploy | pending | — |
| 03 | 03-readme-restructure | done | 2026-11-17 |
## 当前
并行组 1：`01-homepage-page` Red 中；`03-readme-restructure` done。之后是组 2：`02-pages-deploy`。
## 阻塞
（无）
## 重试与自修（每次记一条）
- 03-readme-restructure 自修第 1 轮：Review 指出日常命令章节缺"去安装章节"的引导（plan 漏写此条，PRD 有）、测试文件 python 失败时仍判通过、一处跨文件弱引用注释、4 条测试缺口 → 已修复，复查 9/9 合规；用户 2026-11-17 选择不补"旧版链接与命令是新版子集"的常驻测试（CI 浅克隆拿不到旧版，已人工比对通过）
- 03-readme-restructure 自修第 2 轮：复查发现测试失败分支 `$PYRC）` 在 bash 3.2 下报 unbound variable，同类位置 tests/dep-version-check.test.sh:38、:46 → 三处改成 `${…}`，测试通过
## 无关发现（发现一条记一条）
- tests/readme-structure.test.sh:190 变量 install 只用来判断有无 📦 章节，第 196 行又重算一遍安装章节位置，可合并；不处理只是多几行重复代码；约 5 分钟
