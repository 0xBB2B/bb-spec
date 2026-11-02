# wait-background-scripts 实施计划

## 阶段 1：钩子
- [01-stop-hook](01-stop-hook.md) — 新增 Stop 钩子，发现新的运行中后台命令就提示一次

## 阶段 2：配套
- [02-docs-and-git-push](02-docs-and-git-push.md) — git-push 改成前台循环等待，同步说明 [依赖: 01-stop-hook]
