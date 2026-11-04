# new-tech-approval 实施计划
## 阶段 1：规则与守卫（三份互不依赖、文件不重叠，可并行）
- [01-version-policy-rules](01-version-policy-rules.md) — version-policy 管所有新技术，写清清单格式和批准方式；Go、前端规则跟着改
- [02-plan-exec-flow](02-plan-exec-flow.md) — /plan 列清单一次批准、七栏「新增技术」表；/exec 与实现子代理按表拦截
- [03-dep-hook-reminder](03-dep-hook-reminder.md) — 依赖文件钩子提示加"没批准就撤回、先列清单"
