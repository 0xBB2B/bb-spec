---
name: 02-pages-deploy
description: 新增 .github/workflows/pages.yml，site/ 或该文件改动推到 main 时把 site/ 发布到 GitHub Pages，附静态校验测试
---
# 主页自动部署 workflow

## 目标
`site/` 下文件或部署 workflow 本身的改动推到 main 后，GitHub Actions 自动把 `site/` 目录（且只有它）发布到 `https://0xbb2b.github.io/bb-spec/`。

## 业务规则（来源：PRD 02-pages-deploy）
- 推送到 main 且改动了 `site/**` 或 `.github/workflows/pages.yml` → 部署；其他推送到 main → 不部署；PR 事件、推送其他分支 → 不部署。
- 失败时运行显示失败，线上保留上一次成功版本（Pages 部署机制本身保证：失败的部署不会替换线上内容）。
- 先后触发多次时线上最终是最后一次推送的内容，同一时刻最多一次在发布：用 `concurrency` 组 `pages`、`cancel-in-progress: false`（GitHub 只保留最新一个排队运行，进行中的跑完再跑最新的）。
- 只发布 `site/` 目录：访问 `/README.md`、`/.bb-spec/` 返回 404。
- 权限只拿 `contents: read`、`pages: write`、`id-token: write`，没有 `contents: write`。
- 不改 `ci.yml`、`release-please.yml`。
- 仓库 Pages 来源需设为 GitHub Actions：这是仓库设置，不在本 plan 的文件改动里；/exec 收尾前由主对话征得用户同意后用 `gh api` 设置，或请用户在 Settings → Pages 里改。

## 涉及文件
- `.github/workflows/pages.yml` 新建
- `tests/pages-workflow.test.sh` 新建（Test Agent 写）

## 成品定义
`.github/workflows/pages.yml` 原样落盘；`@v5` 两处在落盘前经官方 releases 页确认对应大版本标签存在且为最新稳定大版本（`actions/upload-pages-artifact` 最新 v5.0.0、`actions/deploy-pages` 最新 v5.0.1，2026-11-17 用 `gh release view` 查得），`actions/checkout@v6` 与 `ci.yml` 一致：

```yaml
name: Deploy homepage

# 只有主页文件或本文件有改动、并推到 main 时才部署
on:
  push:
    branches: [main]
    paths:
      - 'site/**'
      - '.github/workflows/pages.yml'

permissions:
  contents: read
  pages: write
  id-token: write

# 排队时只保留最新一次，进行中的部署不打断，保证线上最终是最后一次推送的内容
concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Upload site
        uses: actions/upload-pages-artifact@v5
        with:
          path: site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v5
```

## 新增技术
| 名称 | 类别 | 来源 | 用途 | 现有手段为什么不够 | 替代方案为什么不选 | 版本策略 |
|---|---|---|---|---|---|---|
| `actions/upload-pages-artifact` | CI Action | Claude 提议 | 只把 `site/` 打成 Pages 构件，保证仓库其他文件不被发布 | `actions/checkout` 只签出代码，Pages 只接收特定格式的构件 | 自己 `tar` + `actions/upload-artifact`：要手写 Pages 打包格式，格式变了就坏，且同样引入新 Action | 最新稳定版 |
| `actions/deploy-pages` | CI Action | Claude 提议 | 把构件发布到 `0xbb2b.github.io/bb-spec` 并在 Actions 显示成败 | 现有 Action 都不能发布到 Pages | 从 `gh-pages` 分支部署：workflow 要拿写仓库权限往分支推提交，违反"不拿写仓库内容权限" | 最新稳定版 |

## 函数清单
无过程式代码（workflow 为声明式成品）。

## 协作关系
`build` job 签出仓库 → 上传 `site/` 为 Pages 构件 → `deploy` job 依赖 `build`，在 `github-pages` 环境里发布。依赖 GitHub Pages 服务与仓库 Pages 来源设置为 GitHub Actions。

## 验证方式
- 测试入口：`bash tests/pages-workflow.test.sh`（解析 YAML 用 `python3`；本机 python3 没有 PyYAML 时用逐行文本匹配，不引入新依赖）。
- 测试输入：`.github/workflows/pages.yml`、`.github/workflows/ci.yml`、`.github/workflows/release-please.yml`。
- 预期结果：
  - `pages.yml` 触发器只有 `push`，`branches` 只有 `main`，`paths` 恰为 `site/**` 和 `.github/workflows/pages.yml`；不含 `pull_request`、`workflow_dispatch`、`release`、`schedule`。
  - `permissions` 为 `contents: read`、`pages: write`、`id-token: write`，全文不含 `contents: write`。
  - `concurrency.group` 为 `pages`，`cancel-in-progress: false`。
  - 上传步骤 `path: site`；使用 `actions/upload-pages-artifact@` 与 `actions/deploy-pages@`，且全文用到的 `uses:` 只有 `actions/checkout`、`actions/upload-pages-artifact`、`actions/deploy-pages` 三种。
  - `deploy` job 有 `needs: build` 和 `environment.name: github-pages`。
  - `ci.yml`、`release-please.yml` 未引用 `pages`、`deploy-pages`（部署与 CI、发版互不牵连）。
- [ ] 以上断言全部通过
- [ ] 合并后线上验证（PR 合并后由用户 / `/git-push` 收尾执行）：Actions 出现部署运行并成功；`https://0xbb2b.github.io/bb-spec/` 显示主页；`/README.md` 返回 404
