---
name: 02-pages-deploy
description: 主页文件或部署配置的改动合并到 main 后，GitHub Actions 自动把主页发布到 GitHub Pages
date: 2026-11-17
---

# 主页自动部署

## 用户故事
### P0：作为维护者，我想要主页改动合并到 main 后自动上线，以便不用手动发布

**用例（主路径）**
- 场景：维护者改了主页上一段英文文案，开 PR，squash 合并到 main。
- 操作：合并后打开仓库 Actions 页面，等部署运行结束，再打开 `https://0xbb2b.github.io/bb-spec/`。
- 预期：Actions 里出现一次主页部署运行并显示成功；主页显示改后的文案。

**用例（边界 / 异常）**
- 场景：合并的 PR 只改了 `plugins/` 下的文件，没碰主页文件和部署配置。→ 预期：不出现主页部署运行，线上主页不变。
- 场景：release-please 的发版 PR 合并到 main（只改版本号、CHANGELOG）。→ 预期：不出现主页部署运行。
- 场景：一个 PR 改了主页文件，还在评审、没合并。→ 预期：不部署。
- 场景：部署过程中失败（如 GitHub Pages 服务出错）。→ 预期：这次运行在 Actions 页面显示失败；线上保留上一次成功部署的主页。
- 场景：两个都改了主页的 PR 先后在一分钟内合并。→ 预期：最后线上显示的是后合并那个 PR 之后的主页内容。

## 约束
- 推送到 main（含 PR 合并）且这次推送改动了主页文件或部署 workflow 文件本身 → 运行一次部署，把主页发布到 GitHub Pages，`https://0xbb2b.github.io/bb-spec/` 显示 main 上最新的主页。
- 推送到 main 但没有改动主页文件和部署 workflow 文件 → 不运行部署。
- PR 的创建、更新、评审，以及推送到 main 以外的分支 → 不运行部署。
- 部署失败 → 这次运行在 Actions 页面显示失败；线上主页保持上一次成功部署的版本。
- 多次部署先后触发时，线上最终显示的是最后一次推送对应的主页内容；同一时刻最多只有一次部署在发布。
- 发布到 Pages 的只有主页文件：访问 `https://0xbb2b.github.io/bb-spec/README.md`、`https://0xbb2b.github.io/bb-spec/.bb-spec/` 这类仓库里其他文件的地址 → 返回 404。
- 部署运行只拿发布 Pages 所需的权限，不拿写仓库内容的权限。
- 现有的 CI（PR 和推送 main 时跑 `tests/*.sh`）和 release-please 发版照常运行，不受部署影响。
- 仓库 Pages 设置里的来源（Source）是 GitHub Actions。这个设置只需改一次，改之前先征得用户同意。

## 验收
- [ ] 改主页文件的提交推到 main → 出现一次部署运行且成功，线上主页是新内容。
- [ ] 只改部署 workflow 文件的提交推到 main → 出现一次部署运行。
- [ ] 只改 `plugins/` 或 README 的提交推到 main → 没有部署运行。
- [ ] PR 事件、推送非 main 分支 → 没有部署运行。
- [ ] 部署失败时运行显示失败，线上仍是上一版主页。
- [ ] 先后触发两次部署，线上是后一次的内容；不会两次同时发布。
- [ ] 线上访问 `/README.md`、`/.bb-spec/` 返回 404。
- [ ] 部署 workflow 的权限里没有对仓库内容的写权限。
- [ ] CI 和 release-please 的 workflow 行为不变。
- [ ] 仓库 Pages 来源为 GitHub Actions，且是经用户同意后设置的。

## 验证路径
1. 经用户同意，把仓库 Pages 来源设为 GitHub Actions。
2. 本分支 PR squash 合并到 main → Actions 出现部署运行并成功 → 打开 `https://0xbb2b.github.io/bb-spec/` 看到主页。
3. 打开 `https://0xbb2b.github.io/bb-spec/README.md` → 404。
4. 下一次只改 `plugins/` 的 PR 合并后 → Actions 里没有新的部署运行。
