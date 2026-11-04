---
name: 01-remove-bun-hook
description: 前端插件不再拦截包管理器命令，选法只由前端规则决定，插件说明同步
date: 2026-11-04
---

# 删掉 bun 钩子

## 用户故事
### P0：作为用 bb-spec 做前端项目的用户，我想让包管理器按我的项目和我的决定来选，以便不被插件硬塞 bun

**用例（主路径：已有项目）**
- 场景：用户克隆了一个只有 `yarn.lock` 的项目，让 Claude 加一个依赖。
- 操作：Claude 按前端规则选择包管理器。
- 预期：Claude 用 yarn 安装；终端里没有任何前端插件的钩子提示或确认窗。

**用例（新项目）**
- 场景：用户在空目录里让 Claude 新建一个前端项目。
- 操作：用户在新技术清单里否决 bun，写"用 npm"。
- 预期：Claude 先在新技术清单里列出包管理器（默认建议 bun），用户改用 npm 后 Claude 直接用 npm 安装；没有钩子弹出的确认窗。

## 约束
- 前端插件不注册任何会在 Claude 执行命令前介入的钩子：Claude 跑 npm、yarn、pnpm、bun 的任何命令，前端插件都不拦截、不弹窗。
- 包管理器的选法由前端规则决定，且规则里写明：已有 `bun.lock` / `bun.lockb` 用 bun，已有 `package-lock.json` 用 npm，已有 `yarn.lock` 用 yarn，已有 `pnpm-lock.yaml` 用 pnpm；没有 lockfile 的新项目默认建议 bun，按新技术清单列出、用户批准后才用。
- README（五种语言）和插件描述不再提 bun 钩子；README 里写的被动 hook 数量和实际注册的钩子数量一致。

## 验收
- [ ] 前端插件里没有任何钩子注册，也没有 bun 钩子脚本；仓库里没有针对它的测试。
- [ ] 前端规则里仍然写着上面四种 lockfile 对应的工具，以及新项目默认 bun、经用户批准。
- [ ] 五份 README、前端插件描述、插件市场描述都不含 `block-non-bun-pm`、`bun hook`、`bun 钩子` 这类说法；README 里的被动 hook 数量与实际一致。

## 验证路径
1. 在前端插件目录里查钩子注册 → 没有。
2. 读前端规则的包管理器判定表 → 四种 lockfile 和新项目的选法都在。
3. 在 README 和插件描述里搜 `block-non-bun-pm` → 没有结果。
