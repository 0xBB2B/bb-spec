---
name: 01-remove-bun-hook
description: 删掉前端插件的 bun 钩子及其注册、测试，插件描述不再提它
---
# 删掉 bun 钩子

## 目标
前端插件不再在 Claude 执行命令前介入；包管理器的选法只由前端规则决定。

## 业务规则（来源：PRD 2026-11-04.remove-bun-hook / 01-remove-bun-hook）
- 前端插件不注册任何会在 Claude 执行命令前介入的钩子：Claude 跑 npm、yarn、pnpm、bun 的任何命令，前端插件都不拦截、不弹窗。
- 包管理器的选法由前端规则决定，规则里写明：已有 `bun.lock` / `bun.lockb` 用 bun，已有 `package-lock.json` 用 npm，已有 `yarn.lock` 用 yarn，已有 `pnpm-lock.yaml` 用 pnpm；没有 lockfile 的新项目默认建议 bun，按新技术清单列出、用户批准后才用。（规则现已写在 vue-constraints §3.1，本 plan 不改它，只用测试锁住。）
- 前端插件描述、插件市场描述不再提 bun 钩子。README 由收尾的文档同步处理。

## 涉及文件
- `plugins/bb-spec-frontend/hooks/block-non-bun-pm.sh` 删除
- `plugins/bb-spec-frontend/hooks/hooks.json` 删除（插件只有这一个钩子，`hooks/` 目录随之删除）
- `tests/block-non-bun-pm.test.sh` 删除
- `plugins/bb-spec-frontend/.claude-plugin/plugin.json` 修改
- `.claude-plugin/marketplace.json` 修改
- `tests/new-tech-policy.test.sh` 修改（Test Agent）

## 成品定义
两个 JSON 里 bb-spec-frontend 的 description 中 A：`；含 block-non-bun-pm hook：无 lockfile 时询问用户，lockfile 与命令不匹配时拒绝。` → B：`。`（整句变为 `BB-Spec 前端技术框架约束：Vue 3 + TypeScript + Vite + Tailwind + bun 技术栈与前端工程约定。`）

## 函数清单
### 上述文件
| 动作 | 职责 |
|---|---|
| 删除钩子脚本、hooks.json、钩子测试 | 去掉拦截 |
| 改两处 description | 按成品定义 |

## 协作关系
`tests/validate.sh` 只在 `hooks/hooks.json` 存在时校验钩子，删掉后自动跳过；`tests/mktemp-failure-safety.test.sh` 按文件动态扫描，删掉钩子测试不影响它。

## 验证方式
- 测试入口：`bash tests/new-tech-policy.test.sh`、`bash tests/validate.sh`
- 预期结果：
- [ ] `plugins/bb-spec-frontend/hooks/` 目录不存在；`tests/block-non-bun-pm.test.sh` 不存在
- [ ] 两个 JSON 的前端 description 不含 `block-non-bun-pm`、`hook`；仍是合法 JSON
- [ ] vue-constraints 仍含 `| 既有项目，有 \`bun.lock\` / \`bun.lockb\` | **bun**（强制） |`、`| 既有项目，有 \`package-lock.json\` | **npm**`、`| 既有项目，有 \`yarn.lock\` | **yarn**`、`| 既有项目，有 \`pnpm-lock.yaml\` | **pnpm**`、`| 新建项目 | **bun**（默认，引入前按 version-policy 列清单经用户批准） |`
- [ ] `tests/new-tech-policy.test.sh` 里原来断言 description 含 `无 lockfile 时询问用户` 的两条改为断言不含 `block-non-bun-pm`
