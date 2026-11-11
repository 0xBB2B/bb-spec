# AGENTS.md

## 查功能、查问题的规矩
> 本节由 /prd 按 bb-spec 插件模板整节维护，手改会被覆盖；项目自己的规矩写进「项目约束」。

1. 先读代码再回答：凡是"系统现在怎么做"的结论，必须来自本次实际读过的代码，或调查子代理本次交回的带 `文件:行号` 的结论，并给出 `文件:行号`；还没有依据就说"还没确认"，不许猜。
2. 按功能找代码：有 `ARCHITECTURE.md` 先读它，按模块地图找到相关模块和目录；再用 `grep -l '^features:.*<功能名>' .bb-spec/docs/prd/*/OVERVIEW.md` 找到相关需求目录，再在每个代码仓库里用 `git log --grep "Requirement: <目录名>" --name-only` 查出改过的文件。
3. 查为什么：在该文件所在的仓库里执行 `git log -L :<函数名>:<文件> -s --format='%h %s%n%b' | grep -e '^[0-9a-f]\{7,40\} ' -e '^Requirement:'` 列出改过这个函数的 commit 和各自的 `Requirement` 行，最新的在前；按函数名报 "no match"（如缩进的类方法）时，先读文件确认行号，改用 `git log -L <起始行>,<结束行>:<文件>`。读最新那个 commit 的 `Requirement` 指向的 PRD「决策记录」和 commit 说明正文（squash 合并的 commit 可能有多行 `Requirement`，逐个读）；更早的 PRD 只在需要追溯时才读。commit 没有 `Requirement` 标记的是接入 bb-spec 之前的老代码，没有对应 PRD，只读 commit 说明；查不到原因就如实说"查不到"。
4. 查为什么没做：问"以前为什么没做 X、为什么不这样设计"时，执行 `grep -rln '<关键词>' .bb-spec/docs/prd/` 找到提到它的 PRD，读「非目标」和「决策记录」；搜不到就如实说"没有记录"。
5. PRD 和代码不一致时以代码为准，并在回答里指出哪里不一致。
6. 改代码前按第 3 条查清设计原因，改动不能违背；确实要改设计，新需求走 `/prd`、修正走 `/revise`。
7. 每个 commit 说明末尾单独一行带 `Requirement: <PRD 目录名>`；和任何需求都无关的改动写 `Requirement: none`，并在正文写一句原因。多仓库时每个仓库的 commit 都要带。

## 项目约束
