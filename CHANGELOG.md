# Changelog

## [11.1.0](https://github.com/0xBB2B/bb-spec/compare/v11.0.0...v11.1.0) (2026-07-06)


### Features

* **git-push:** 禁止 commit 与 PR 描述携带 AI 署名尾注 ([#213](https://github.com/0xBB2B/bb-spec/issues/213)) ([486cfb1](https://github.com/0xBB2B/bb-spec/commit/486cfb1ad682e739a46357bda0e9292948ef464c))

## [11.0.0](https://github.com/0xBB2B/bb-spec/compare/v10.6.0...v11.0.0) (2026-07-03)


### ⚠ BREAKING CHANGES

* **plan,exec,revise:** /plan 删除规模分流与分批 ROADMAP 整条链路（懒生成、批次状态、验证门、ROADMAP.md 产物），一律产出单 topic 计划；/exec 移除路线图衔接与完成简报中的验证门段；/revise 移除「需要 ROADMAP 表达批次门」的流程退出判定。既有项目中的 plan/ROADMAP.md 不再被工作流读取，大规模多领域需求改为按主题多次运行 /plan。

### Features

* **plan,exec,revise:** 移除分批 ROADMAP 模式，plan 仅保留单 topic ([#211](https://github.com/0xBB2B/bb-spec/issues/211)) ([ea0643b](https://github.com/0xBB2B/bb-spec/commit/ea0643b158ec221be8876484ce051c1024596cab))

## [10.6.0](https://github.com/0xBB2B/bb-spec/compare/v10.5.0...v10.6.0) (2026-07-03)


### Features

* **plan:** 启动先 worktree 感知定位 plan 现场，分批续作不再误判无需 plan ([#209](https://github.com/0xBB2B/bb-spec/issues/209)) ([9a92efc](https://github.com/0xBB2B/bb-spec/commit/9a92efca2a558267d9fc3a4989dc4af3b93bdd79))

## [10.5.0](https://github.com/0xBB2B/bb-spec/compare/v10.4.0...v10.5.0) (2026-07-03)


### Features

* **exec,revise:** 启动先 worktree 感知定位执行现场，避免误落 main 工作区 ([#207](https://github.com/0xBB2B/bb-spec/issues/207)) ([5ed2639](https://github.com/0xBB2B/bb-spec/commit/5ed26399fdf4bbbc8a8e691c54c1b1f6071cafd6))

## [10.4.0](https://github.com/0xBB2B/bb-spec/compare/v10.3.0...v10.4.0) (2026-07-03)


### Features

* **test-webview:** webview 测试强制无头模式并加最少调用提速纪律 ([#205](https://github.com/0xBB2B/bb-spec/issues/205)) ([0f42a91](https://github.com/0xBB2B/bb-spec/commit/0f42a91359640d9a023aa9ad408986258bfb8d01))

## [10.3.0](https://github.com/0xBB2B/bb-spec/compare/v10.2.0...v10.3.0) (2026-07-03)


### Features

* **revise:** 已完成 plan 禁止回改，级联修正按 plan 状态分流 ([#203](https://github.com/0xBB2B/bb-spec/issues/203)) ([50ec979](https://github.com/0xBB2B/bb-spec/commit/50ec97927b601177fdaae9442984a7ef5ceed8f4))

## [10.2.0](https://github.com/0xBB2B/bb-spec/compare/v10.1.0...v10.2.0) (2026-07-02)


### Features

* **spec,prd:** 增加 GLOSSARY 术语表机制保障跨语言跨人术语一致 ([#201](https://github.com/0xBB2B/bb-spec/issues/201)) ([1b5fb91](https://github.com/0xBB2B/bb-spec/commit/1b5fb91ae2b131aa81051cf153d60522e958b3a7))

## [10.1.0](https://github.com/0xBB2B/bb-spec/compare/v10.0.0...v10.1.0) (2026-07-02)


### Features

* **spec,prd:** 澄清/发散提问前先自查，能自答的呈现结论求确认 ([#199](https://github.com/0xBB2B/bb-spec/issues/199)) ([953cede](https://github.com/0xBB2B/bb-spec/commit/953cede730b55d9f56cc30ef153da737afd0816a))

## [10.0.0](https://github.com/0xBB2B/bb-spec/compare/v9.7.0...v10.0.0) (2026-07-02)


### ⚠ BREAKING CHANGES

* **plugin:** 移除公开命令 /init-spec 及其专属 subagent rule-extractor。存量项目接入 bb-spec 工作流不再批量反向生成 spec，改为从下一个需求起用 /spec 增量沉淀规则；已有 spec 的长期维护继续走 /doc-update。

### Features

* **plugin:** 删除 /init-spec 与 rule-extractor ([#197](https://github.com/0xBB2B/bb-spec/issues/197)) ([3fdf884](https://github.com/0xBB2B/bb-spec/commit/3fdf884376765576be25b00ff4eee0a0dd7076d0))

## [9.7.0](https://github.com/0xBB2B/bb-spec/compare/v9.6.0...v9.7.0) (2026-07-02)


### Features

* **agents:** rule-extractor 模型升到 fable ([#195](https://github.com/0xBB2B/bb-spec/issues/195)) ([98bba4a](https://github.com/0xBB2B/bb-spec/commit/98bba4af172f38a9f65c140fc16178e17c9faa4a))

## [9.6.0](https://github.com/0xBB2B/bb-spec/compare/v9.5.0...v9.6.0) (2026-07-01)


### Features

* **agents:** 模型标识改用 opus / sonnet 通用别名 ([#194](https://github.com/0xBB2B/bb-spec/issues/194)) ([b7a22e8](https://github.com/0xBB2B/bb-spec/commit/b7a22e8101bf6f5fccc7953d5c49b6b2f55db888))
* **init-spec:** 闭环对齐 /spec，落盘 spec 代码无关 ([#192](https://github.com/0xBB2B/bb-spec/issues/192)) ([158c00d](https://github.com/0xBB2B/bb-spec/commit/158c00d2262092ae0e663e3f029b61f278f2f99b))

## [9.5.0](https://github.com/0xBB2B/bb-spec/compare/v9.4.0...v9.5.0) (2026-07-01)


### Features

* **agents:** rule-extractor 模型升到 opus 4.7 ([#190](https://github.com/0xBB2B/bb-spec/issues/190)) ([83da24a](https://github.com/0xBB2B/bb-spec/commit/83da24ae6a5e2eec32f45e384535ea7f55404305))

## [9.4.0](https://github.com/0xBB2B/bb-spec/compare/v9.3.0...v9.4.0) (2026-07-01)


### Features

* **agents:** 默认模型钉死到具体版本 ID ([#186](https://github.com/0xBB2B/bb-spec/issues/186)) ([c9d9652](https://github.com/0xBB2B/bb-spec/commit/c9d965276372fa52482bcda07d3a36a9db797638))
* **code-constraints,template:** 收紧注释纪律，新增 R1.3-R1.8 禁写模式 ([#188](https://github.com/0xBB2B/bb-spec/issues/188)) ([2538c95](https://github.com/0xBB2B/bb-spec/commit/2538c95ecbf0868d06b130be3f8e235a52657306))


### Bug Fixes

* **plan:** 脱敏根 INDEX 示例中的具象项目名与日期 ([#189](https://github.com/0xBB2B/bb-spec/issues/189)) ([15c6c0b](https://github.com/0xBB2B/bb-spec/commit/15c6c0bae924d494eb66477eb0955cb1b59ea090))

## [9.3.0](https://github.com/0xBB2B/bb-spec/compare/v9.2.0...v9.3.0) (2026-06-30)


### Features

* **code-constraints:** 新增跨语言代码纪律 skill 并接入三 Agent + 轻量修复 ([#184](https://github.com/0xBB2B/bb-spec/issues/184)) ([58a3093](https://github.com/0xBB2B/bb-spec/commit/58a30939415f29a65956f33c10dcf691522c0fcb))

## [9.2.0](https://github.com/0xBB2B/bb-spec/compare/v9.1.0...v9.2.0) (2026-06-30)


### Features

* **revise:** 把 3-Agent 派发提升为硬约束并新增流程归属判定 ([#182](https://github.com/0xBB2B/bb-spec/issues/182)) ([d912cea](https://github.com/0xBB2B/bb-spec/commit/d912cea3a506b6159baac6a78a85b61d2cdb4ba1))

## [9.1.0](https://github.com/0xBB2B/bb-spec/compare/v9.0.0...v9.1.0) (2026-06-30)


### Features

* **review:** 新增鲁棒性 review 维度 ([#177](https://github.com/0xBB2B/bb-spec/issues/177)) ([8c1b2de](https://github.com/0xBB2B/bb-spec/commit/8c1b2ded25d97f27c3a317b286d180000c4e95ad))

## [9.0.0](https://github.com/0xBB2B/bb-spec/compare/v8.15.0...v9.0.0) (2026-06-29)


### ⚠ BREAKING CHANGES

* 用户直接调用的 slash 命令从 /git-push-pr 改为 /git-push；自动化脚本、CLAUDE.md、文档中引用旧名的地方均需替换。功能行为本身未变化。

### Features

* **prd,spec:** PRD 消费后归档到 .archive/ ([#172](https://github.com/0xBB2B/bb-spec/issues/172)) ([50ede26](https://github.com/0xBB2B/bb-spec/commit/50ede26aa5d0ef61afd09753b0a71e2209641fe4))
* 重命名 git-push-pr → git-push 并新增 git-clone onboarding skill ([#174](https://github.com/0xBB2B/bb-spec/issues/174)) ([8a7bc32](https://github.com/0xBB2B/bb-spec/commit/8a7bc324cd8c2d241993ee0648c22194347a7f03))

## [8.15.0](https://github.com/0xBB2B/bb-spec/compare/v8.14.0...v8.15.0) (2026-06-28)


### Features

* **exec:** 默认全部执行,移除执行范围询问 ([#170](https://github.com/0xBB2B/bb-spec/issues/170)) ([8dddf23](https://github.com/0xBB2B/bb-spec/commit/8dddf2314c7a821ff5c0f366551491c0ca94e2ae))

## [8.14.0](https://github.com/0xBB2B/bb-spec/compare/v8.13.0...v8.14.0) (2026-06-28)


### Features

* **git-push-pr,git-workflow:** worktree 感知 + 合并判据收紧 ([#167](https://github.com/0xBB2B/bb-spec/issues/167)) ([e0691dd](https://github.com/0xBB2B/bb-spec/commit/e0691dd71bf80b86edebff2bdb5581b4055a49a3))
* **git-push-pr:** worktree 模式下 gh pr merge/close 禁带 --delete-branch ([#169](https://github.com/0xBB2B/bb-spec/issues/169)) ([3da3a49](https://github.com/0xBB2B/bb-spec/commit/3da3a49056662a1ef8844ff390735664675d0a97))

## [8.13.0](https://github.com/0xBB2B/bb-spec/compare/v8.12.0...v8.13.0) (2026-06-28)


### Features

* README 完善与冗余语言强调清理,stop 自检追加简报收尾 ([#165](https://github.com/0xBB2B/bb-spec/issues/165)) ([94394f5](https://github.com/0xBB2B/bb-spec/commit/94394f52529cd72850ec340a7422eb766bd93ba7))

## [8.12.0](https://github.com/0xBB2B/bb-spec/compare/v8.11.0...v8.12.0) (2026-06-26)


### Features

* **prd,spec:** 澄清提问强制给可横向对比的候选 + 推荐项 ([#163](https://github.com/0xBB2B/bb-spec/issues/163)) ([d1e32f1](https://github.com/0xBB2B/bb-spec/commit/d1e32f149f458d03f4d646a1b5bf7f973528f2d8))

## [8.11.0](https://github.com/0xBB2B/bb-spec/compare/v8.10.0...v8.11.0) (2026-06-26)


### Features

* **prd:** 步骤 0 增加 spec/PRD 冲突重叠扫描并强制呈现 ([#161](https://github.com/0xBB2B/bb-spec/issues/161)) ([900147d](https://github.com/0xBB2B/bb-spec/commit/900147d3014a624b44324236cd741409772633a6))

## [8.10.0](https://github.com/0xBB2B/bb-spec/compare/v8.9.0...v8.10.0) (2026-06-26)


### Features

* **prd,spec:** PRD 产出改为目录结构（OVERVIEW + 子需求文档） ([#159](https://github.com/0xBB2B/bb-spec/issues/159)) ([1127bc3](https://github.com/0xBB2B/bb-spec/commit/1127bc3364c56d43263abf042a63eb8b1dd434c7))

## [8.9.0](https://github.com/0xBB2B/bb-spec/compare/v8.8.0...v8.9.0) (2026-06-25)


### Features

* **spec-backend:** golang 目录结构 config/pkg 提到根，并强制测试文件 1:1 对应实现 ([#156](https://github.com/0xBB2B/bb-spec/issues/156)) ([9c6a81c](https://github.com/0xBB2B/bb-spec/commit/9c6a81c38e5726a87a9da59f97eabbddbf5d468a))

## [8.8.0](https://github.com/0xBB2B/bb-spec/compare/v8.7.0...v8.8.0) (2026-06-25)


### Features

* **review:** /review 支持追加本次审查重点 ([#153](https://github.com/0xBB2B/bb-spec/issues/153)) ([fcab1bc](https://github.com/0xBB2B/bb-spec/commit/fcab1bcf0c01097dcac1c3c8fd27b460c44e8c82))

## [8.7.0](https://github.com/0xBB2B/bb-spec/compare/v8.6.0...v8.7.0) (2026-06-25)


### Features

* **spec-backend:** 强制 golangci-lint 作为唯一 lint 工具并串入 test 入口 ([#151](https://github.com/0xBB2B/bb-spec/issues/151)) ([6229424](https://github.com/0xBB2B/bb-spec/commit/622942449f4c1e2559f02bc3c24024e95cde4c95))

## [8.6.0](https://github.com/0xBB2B/bb-spec/compare/v8.5.0...v8.6.0) (2026-06-25)


### Features

* **test-api,test-webview:** 与被测项目语言解耦 ([#149](https://github.com/0xBB2B/bb-spec/issues/149)) ([f1382fd](https://github.com/0xBB2B/bb-spec/commit/f1382fd2afb56d85d2792193ef44c5f8dfce66f7))

## [8.5.0](https://github.com/0xBB2B/bb-spec/compare/v8.4.0...v8.5.0) (2026-06-25)


### Features

* **spec-backend:** 拆出 config-constraints 收口配置载体三分与密钥分层 ([#147](https://github.com/0xBB2B/bb-spec/issues/147)) ([f0d352c](https://github.com/0xBB2B/bb-spec/commit/f0d352c70ba33b8dab8ba84ae3f16f19036c5315))

## [8.4.0](https://github.com/0xBB2B/bb-spec/compare/v8.3.2...v8.4.0) (2026-06-24)


### Features

* **test-api:** 步骤 4 编译加指纹命中复用——md+模板未变跳过重渲染 ([#145](https://github.com/0xBB2B/bb-spec/issues/145)) ([2e92f39](https://github.com/0xBB2B/bb-spec/commit/2e92f39afc6f0acbd9f783929137a055c9d85a53))

## [8.3.2](https://github.com/0xBB2B/bb-spec/compare/v8.3.1...v8.3.2) (2026-06-24)


### Bug Fixes

* **test-api,version-policy:** docker-compose.* 文件名统一为 compose.* ([#143](https://github.com/0xBB2B/bb-spec/issues/143)) ([d3387ee](https://github.com/0xBB2B/bb-spec/commit/d3387ee9c40b65708b368c99e127ffdabebb5202))

## [8.3.1](https://github.com/0xBB2B/bb-spec/compare/v8.3.0...v8.3.1) (2026-06-24)


### Bug Fixes

* **test-webview,test-api:** references 统一落到各 skill 子目录修复 Claude Code 加载 ([#141](https://github.com/0xBB2B/bb-spec/issues/141)) ([0889ada](https://github.com/0xBB2B/bb-spec/commit/0889adac59dc6282835df35efb4533092868e279))

## [8.3.0](https://github.com/0xBB2B/bb-spec/compare/v8.2.0...v8.3.0) (2026-06-24)


### Features

* 新增 /test-api 后端 API e2e 验证 skill ([#139](https://github.com/0xBB2B/bb-spec/issues/139)) ([ad3244f](https://github.com/0xBB2B/bb-spec/commit/ad3244f60fb2303646fed9add7d07bdae2727a48))

## [8.2.0](https://github.com/0xBB2B/bb-spec/compare/v8.1.0...v8.2.0) (2026-06-24)


### Features

* **doc-update:** 新增 /doc-update 全仓 spec/文档/代码一致性维护 skill ([#137](https://github.com/0xBB2B/bb-spec/issues/137)) ([cc6ccad](https://github.com/0xBB2B/bb-spec/commit/cc6ccad68a5a50717ad77cb0890aa62107ad4ee7))

## [8.1.0](https://github.com/0xBB2B/bb-spec/compare/v8.0.0...v8.1.0) (2026-06-22)


### Features

* **git-workflow:** worktree 路径强约束——description 前置 + hook 拦截非 ~/.bb-spec/worktrees/ 落点 ([#135](https://github.com/0xBB2B/bb-spec/issues/135)) ([37597c3](https://github.com/0xBB2B/bb-spec/commit/37597c358e9afc89090cf7088bbba1e32962c74f))

## [8.0.0](https://github.com/0xBB2B/bb-spec/compare/v7.7.0...v8.0.0) (2026-06-22)


### ⚠ BREAKING CHANGES

* **init-spec:** skill 名 init 改为 init-spec。原 /init 入口失效，请改用 /init-spec（或全名 /bb-spec-workflow:init-spec）。引用 init skill 的外部脚本 / 文档 / 依赖该 skill name 的配置都需同步替换。

### Features

* **init-spec:** 重命名 init skill 为 init-spec 以避开 Claude Code 内置 /init 冲突 ([#133](https://github.com/0xBB2B/bb-spec/issues/133)) ([1e84e55](https://github.com/0xBB2B/bb-spec/commit/1e84e55a5a72b63e3ad47ecce4aa1a47beacc800))

## [7.7.0](https://github.com/0xBB2B/bb-spec/compare/v7.6.0...v7.7.0) (2026-06-20)


### Features

* **spec:** description 全面中文化并改造为「定位+机制+触发+跳过」模板 ([#131](https://github.com/0xBB2B/bb-spec/issues/131)) ([a54556f](https://github.com/0xBB2B/bb-spec/commit/a54556fcf68dbb19dc311ebb3e3256af07cb6da6))

## [7.6.0](https://github.com/0xBB2B/bb-spec/compare/v7.5.0...v7.6.0) (2026-06-17)


### Features

* **git-workflow:** 顶部新增"路径选择决策表"分流多 repo workspace，description 追加触发词 ([#129](https://github.com/0xBB2B/bb-spec/issues/129)) ([7c0ea45](https://github.com/0xBB2B/bb-spec/commit/7c0ea452e9a1bd51a1d9ab4b68ac5c0793b19d8b))

## [7.5.0](https://github.com/0xBB2B/bb-spec/compare/v7.4.0...v7.5.0) (2026-06-17)


### Features

* **hooks:** block-main-commit 升级为 git-workflow-guard，git 流程操作放行并注入 git-workflow 纪律 ([#127](https://github.com/0xBB2B/bb-spec/issues/127)) ([0d0e416](https://github.com/0xBB2B/bb-spec/commit/0d0e41661eb9548887cb462ca7476e7f2b608e54))

## [7.4.0](https://github.com/0xBB2B/bb-spec/compare/v7.3.0...v7.4.0) (2026-06-17)


### Features

* **git-workflow:** 开新任务用 AskUserQuestion 询问 worktree/切分支（默认 worktree），worktree 统一收敛到 ~/.bb-spec/worktrees/ ([#125](https://github.com/0xBB2B/bb-spec/issues/125)) ([390ceca](https://github.com/0xBB2B/bb-spec/commit/390ceca3f3f64b40aed6394e235347e9b33bd574))

## [7.3.0](https://github.com/0xBB2B/bb-spec/compare/v7.2.0...v7.3.0) (2026-06-17)


### Features

* **git-workflow:** 多 repo 工作区统一父目录 + 每 repo 各拉 worktree ([#123](https://github.com/0xBB2B/bb-spec/issues/123)) ([ab92615](https://github.com/0xBB2B/bb-spec/commit/ab92615cd3fa7398053c1f7531b6b62b54ecab1e))

## [7.2.0](https://github.com/0xBB2B/bb-spec/compare/v7.1.0...v7.2.0) (2026-06-17)


### Features

* **spec:** 启动即进入 plan 模式，方案确认后再落盘 ([#121](https://github.com/0xBB2B/bb-spec/issues/121)) ([cf5b277](https://github.com/0xBB2B/bb-spec/commit/cf5b277a6ae11bca9450ef36920daf820cb4f29a))

## [7.1.0](https://github.com/0xBB2B/bb-spec/compare/v7.0.0...v7.1.0) (2026-06-17)


### Features

* **workflow,core,frontend:** 封闭式多选项交互统一改用 AskUserQuestion ([#119](https://github.com/0xBB2B/bb-spec/issues/119)) ([2258f58](https://github.com/0xBB2B/bb-spec/commit/2258f5839d2bee0df8ae279c3e284c5821942790))

## [7.0.0](https://github.com/0xBB2B/bb-spec/compare/v6.4.0...v7.0.0) (2026-06-17)


### ⚠ BREAKING CHANGES

* **plugin:** .bb-spec.yaml 配置键 docs_dir 重命名为 base_dir，值不再含 docs 后缀。 迁移：将 `docs_dir: <path>/docs` 改为 `base_dir: <path>`（去掉键名，值去掉尾部 /docs）。 未创建 .bb-spec.yaml 的项目默认行为不变（仍输出至 .bb-spec/docs/）。

### Features

* **plugin:** 配置上提为 base_dir，docs 与 .cache 平级、瞬态产物收归 .cache ([#117](https://github.com/0xBB2B/bb-spec/issues/117)) ([5f6e1d1](https://github.com/0xBB2B/bb-spec/commit/5f6e1d16124b5b6f9b724627ba75c577956f405b))

## [6.4.0](https://github.com/0xBB2B/bb-spec/compare/v6.3.0...v6.4.0) (2026-06-16)


### Features

* **git-workflow:** 按在途工作状态决定开分支方式 ([#115](https://github.com/0xBB2B/bb-spec/issues/115)) ([b838326](https://github.com/0xBB2B/bb-spec/commit/b838326121f8200d2abc3b27ca6753b965672beb))

## [6.3.0](https://github.com/0xBB2B/bb-spec/compare/v6.2.0...v6.3.0) (2026-06-16)


### Features

* webview 用例产出收归 test-webview、跑前覆盖对齐，回退截图 /tmp 约定 ([#113](https://github.com/0xBB2B/bb-spec/issues/113)) ([8860bd6](https://github.com/0xBB2B/bb-spec/commit/8860bd6269b872f9671cfad8c90ceb2938bde33b))

## [6.2.0](https://github.com/0xBB2B/bb-spec/compare/v6.1.0...v6.2.0) (2026-06-16)


### Features

* **webview-test-runner:** 截图统一收进 /tmp 专属临时目录 ([#111](https://github.com/0xBB2B/bb-spec/issues/111)) ([2aa986e](https://github.com/0xBB2B/bb-spec/commit/2aa986ea5a1786af8da059f39bf843ecd6202eec))


### Bug Fixes

* **hooks:** 回滚临时文件强制 /tmp 约束 ([#110](https://github.com/0xBB2B/bb-spec/issues/110)) ([cc3ca5d](https://github.com/0xBB2B/bb-spec/commit/cc3ca5d3f384e8f5d978823ad143908a7d3e31d2))

## [6.1.0](https://github.com/0xBB2B/bb-spec/compare/v6.0.0...v6.1.0) (2026-06-15)


### Features

* **hooks:** 临时文件统一放 /tmp 并强制清除 ([#108](https://github.com/0xBB2B/bb-spec/issues/108)) ([c73e792](https://github.com/0xBB2B/bb-spec/commit/c73e79282e13b8298ac44c0f09aaeeb66d852b8a))

## [6.0.0](https://github.com/0xBB2B/bb-spec/compare/v5.19.0...v6.0.0) (2026-06-15)


### ⚠ BREAKING CHANGES

* **test-webview,plan:** 用例落盘路径由 webview/<category>/<case>.md 改为 webview/<frontend>/<category>/<case>.md；target 字段由单前端可省改为始终必填且须与顶层目录段一致。已按旧结构生成的用例需迁移到对应 <frontend>/ 目录下才合规。

### Features

* **test-webview,plan:** webview 用例目录统一按前端分层 ([#106](https://github.com/0xBB2B/bb-spec/issues/106)) ([dfa9b86](https://github.com/0xBB2B/bb-spec/commit/dfa9b86a0f1d4bfe312cb8ea787e6192587200f0))

## [5.19.0](https://github.com/0xBB2B/bb-spec/compare/v5.18.0...v5.19.0) (2026-06-15)


### Features

* **test-webview:** 新增网页交互验证工作流，plan/exec 联动生成用例 ([#104](https://github.com/0xBB2B/bb-spec/issues/104)) ([8f7223a](https://github.com/0xBB2B/bb-spec/commit/8f7223a805b3c663c7b464efa315fec0ff357641))

## [5.18.0](https://github.com/0xBB2B/bb-spec/compare/v5.17.0...v5.18.0) (2026-06-15)


### Features

* **git-workflow:** worktree 由禁用改为允许但强制与 repo 隔离存放 ([#102](https://github.com/0xBB2B/bb-spec/issues/102)) ([d741d6b](https://github.com/0xBB2B/bb-spec/commit/d741d6b8b66a76638149b2f4b60f8ef336a979c8))

## [5.17.0](https://github.com/0xBB2B/bb-spec/compare/v5.16.0...v5.17.0) (2026-06-13)


### Features

* **exec:** Review 偏差按归因分流，impl-defect 自决不打断用户 ([#100](https://github.com/0xBB2B/bb-spec/issues/100)) ([b16a3e2](https://github.com/0xBB2B/bb-spec/commit/b16a3e25dab1b959c0d95763b16b9733d784f228))

## [5.16.0](https://github.com/0xBB2B/bb-spec/compare/v5.15.1...v5.16.0) (2026-06-12)


### Features

* **workflow:** 编排 subagent 全部收口 agents/ 并显式定模，pre-review 修复走 /revise ([#98](https://github.com/0xBB2B/bb-spec/issues/98)) ([540f78b](https://github.com/0xBB2B/bb-spec/commit/540f78b2603ce77cd65092dd94768fef9813f025))

## [5.15.1](https://github.com/0xBB2B/bb-spec/compare/v5.15.0...v5.15.1) (2026-06-12)


### Bug Fixes

* **exec,revise:** 修正 subagent 派发名前缀为 bb-spec-workflow ([#96](https://github.com/0xBB2B/bb-spec/issues/96)) ([4939a99](https://github.com/0xBB2B/bb-spec/commit/4939a99294e272c2f60efd6de824d993c2518124))

## [5.15.0](https://github.com/0xBB2B/bb-spec/compare/v5.14.0...v5.15.0) (2026-06-12)


### Features

* **hooks:** 移除 stop-auto-tests / stop-auto-commit 可选 hook ([#93](https://github.com/0xBB2B/bb-spec/issues/93)) ([ea9bc8a](https://github.com/0xBB2B/bb-spec/commit/ea9bc8a5dc04cca9eb1cec9fb380e825d967f72d))
* **review:** 逐个解决模式修复统一走 /revise，文档同步类自动修复，质量/安全优先排序 ([#95](https://github.com/0xBB2B/bb-spec/issues/95)) ([b9603cb](https://github.com/0xBB2B/bb-spec/commit/b9603cb249d6cd64d544059c029d167da77b2652))

## [5.14.0](https://github.com/0xBB2B/bb-spec/compare/v5.13.0...v5.14.0) (2026-06-12)


### Features

* **review:** 逐个解决模式修复后强制跑一遍项目测试 ([#91](https://github.com/0xBB2B/bb-spec/issues/91)) ([ca9a4c7](https://github.com/0xBB2B/bb-spec/commit/ca9a4c7914c48c321fc6ba855aadc0e880763301))

## [5.13.0](https://github.com/0xBB2B/bb-spec/compare/v5.12.0...v5.13.0) (2026-06-12)


### Features

* **review:** finder 与验证者派工钉死 opus 模型 ([#89](https://github.com/0xBB2B/bb-spec/issues/89)) ([52a5f4f](https://github.com/0xBB2B/bb-spec/commit/52a5f4fd0d51ea1ed015740c43cbae14f39976e8))

## [5.12.0](https://github.com/0xBB2B/bb-spec/compare/v5.11.0...v5.12.0) (2026-06-11)


### Features

* **review:** 报告表格 by 列图标后附 finder 文字名 ([#87](https://github.com/0xBB2B/bb-spec/issues/87)) ([755ba77](https://github.com/0xBB2B/bb-spec/commit/755ba77652f730c70dfedb311166fc8219deeec0))

## [5.11.0](https://github.com/0xBB2B/bb-spec/compare/v5.10.0...v5.11.0) (2026-06-11)


### Features

* **review:** 报告简表表格化并为 finder 分配身份图标 ([#85](https://github.com/0xBB2B/bb-spec/issues/85)) ([c880141](https://github.com/0xBB2B/bb-spec/commit/c880141bcce2574a60954eaa51338fa92fc49c77))

## [5.10.0](https://github.com/0xBB2B/bb-spec/compare/v5.9.0...v5.10.0) (2026-06-11)


### Features

* **review:** 逐个解决模式重组为四段展开并新增根源性自检 ([#83](https://github.com/0xBB2B/bb-spec/issues/83)) ([2d77ee1](https://github.com/0xBB2B/bb-spec/commit/2d77ee165038c18be48be7bd0e8e517459e2cda2))

## [5.9.0](https://github.com/0xBB2B/bb-spec/compare/v5.8.0...v5.9.0) (2026-06-11)


### Features

* **review:** review 报告改为逐个对话解决模式 ([#81](https://github.com/0xBB2B/bb-spec/issues/81)) ([4bc4497](https://github.com/0xBB2B/bb-spec/commit/4bc4497beace4c93a8baf758e4be26b4acd714fd))

## [5.8.0](https://github.com/0xBB2B/bb-spec/compare/v5.7.0...v5.8.0) (2026-06-11)


### Features

* 新增 bb-spec-product 插件，/prd 头脑风暴产出 PRD 并打通 /spec 消费 ([#77](https://github.com/0xBB2B/bb-spec/issues/77)) ([2b0d817](https://github.com/0xBB2B/bb-spec/commit/2b0d8174461ebe99fe611987a20bd6b88e6f4799))


### Bug Fixes

* **review:** workflow 输入改为脚本内嵌，砍掉 args 传参通道 ([#80](https://github.com/0xBB2B/bb-spec/issues/80)) ([ab4e65e](https://github.com/0xBB2B/bb-spec/commit/ab4e65e8988bfa39c5f5541723a0718068bcc900))
* validate.sh frontmatter 提取改单进程 awk，消除 CI SIGPIPE 竞态 ([#79](https://github.com/0xBB2B/bb-spec/issues/79)) ([68385b7](https://github.com/0xBB2B/bb-spec/commit/68385b7955777af1222a8067314fdc37d08fc47c))

## [5.7.0](https://github.com/0xBB2B/bb-spec/compare/v5.6.0...v5.7.0) (2026-06-11)


### Features

* **exec,review:** impl-engineer 与各 review agent 固化 model: opus ([#75](https://github.com/0xBB2B/bb-spec/issues/75)) ([b9de213](https://github.com/0xBB2B/bb-spec/commit/b9de213cbe8be8035817505f04ebf8f1e525d329))

## [5.6.0](https://github.com/0xBB2B/bb-spec/compare/v5.5.0...v5.6.0) (2026-06-10)


### Features

* **golang-constraints:** 区分业务分层与支撑包 ([#72](https://github.com/0xBB2B/bb-spec/issues/72)) ([e45642e](https://github.com/0xBB2B/bb-spec/commit/e45642e6a56aa782bbb6e798e063556e345acdfb))

## [5.5.0](https://github.com/0xBB2B/bb-spec/compare/v5.4.0...v5.5.0) (2026-06-10)


### Features

* **plan,exec,version-policy:** plan 批准即授权新增第三方依赖清单，exec 不得超出 ([#70](https://github.com/0xBB2B/bb-spec/issues/70)) ([a444eb6](https://github.com/0xBB2B/bb-spec/commit/a444eb6a2902d468e697ef86236d9d4f43dc93ed))

## [5.4.0](https://github.com/0xBB2B/bb-spec/compare/v5.3.0...v5.4.0) (2026-06-10)


### Features

* **plan,exec:** 声明式产物强制内联成品，禁散文转述 ([#68](https://github.com/0xBB2B/bb-spec/issues/68)) ([551237a](https://github.com/0xBB2B/bb-spec/commit/551237a22240749d93bf1eda860a4388954fc19e))

## [5.3.0](https://github.com/0xBB2B/bb-spec/compare/v5.2.0...v5.3.0) (2026-06-10)


### Features

* **version-policy,golang-constraints:** 官方库优先，新增第三方库须用户同意 ([#66](https://github.com/0xBB2B/bb-spec/issues/66)) ([6a4df87](https://github.com/0xBB2B/bb-spec/commit/6a4df870bacd90a74139805601e3fe4647279dc8))

## [5.2.0](https://github.com/0xBB2B/bb-spec/compare/v5.1.0...v5.2.0) (2026-06-10)


### Features

* **spec,plan,exec:** 断点恢复叙事更新为跨会话续接，裁决点接入 AskUserQuestion ([#64](https://github.com/0xBB2B/bb-spec/issues/64)) ([4205e2b](https://github.com/0xBB2B/bb-spec/commit/4205e2b3dafa0f353afb803680f9d2b3dc7ab742))

## [5.1.0](https://github.com/0xBB2B/bb-spec/compare/v5.0.0...v5.1.0) (2026-06-09)


### Features

* **plan,exec:** plan 模式 gate + 规模分流 + 分批懒生成路线图 ([#61](https://github.com/0xBB2B/bb-spec/issues/61)) ([a352225](https://github.com/0xBB2B/bb-spec/commit/a352225f02bd699476b30832ec5cd75a4a5879bc))

## [5.0.0](https://github.com/0xBB2B/bb-spec/compare/v4.1.0...v5.0.0) (2026-06-08)


### ⚠ BREAKING CHANGES

* **plugin:** 单个 bb-spec plugin 已拆为 bb-spec-core / bb-spec-workflow / bb-spec-backend / bb-spec-frontend 四个子 plugin。老用户需先 /plugin uninstall bb-spec，再按需重装对应子 plugin。

### Features

* **plugin:** 拆分为 core/workflow/backend/frontend 四个可独立安装的子 plugin ([#58](https://github.com/0xBB2B/bb-spec/issues/58)) ([b7de60a](https://github.com/0xBB2B/bb-spec/commit/b7de60a60d0cc7b3ac6e6b6a412cfeff4a6ebeab))
* **spec,init:** 需求澄清改递进式深挖 + 加可证伪红线挡空泛规则 ([#54](https://github.com/0xBB2B/bb-spec/issues/54)) ([faa3c76](https://github.com/0xBB2B/bb-spec/commit/faa3c768bcad61e98c295d0b5e4865ba123f2570))
* 新增全栈技术框架约束套件（认证/授权/可观测/服务工程/前端） ([#56](https://github.com/0xBB2B/bb-spec/issues/56)) ([e636896](https://github.com/0xBB2B/bb-spec/commit/e6368963c14e323f62be13e92b561ff5f204c5bd))


### Bug Fixes

* **auth-constraints:** device_id 不强制 UUID 格式，兼容 Android ID 等平台标识 ([#57](https://github.com/0xBB2B/bb-spec/issues/57)) ([68a9609](https://github.com/0xBB2B/bb-spec/commit/68a9609c51ea31a14d1cfba164bec95752003256))

## [4.1.0](https://github.com/0xBB2B/bb-spec/compare/v4.0.0...v4.1.0) (2026-06-07)


### Features

* **skills:** 拆出 database-constraints，错误码并入 api-design ([#52](https://github.com/0xBB2B/bb-spec/issues/52)) ([642d438](https://github.com/0xBB2B/bb-spec/commit/642d438c18d3d2cdcfdbf9adb0244212bdc67802))

## [4.0.0](https://github.com/0xBB2B/bb-spec/compare/v3.1.0...v4.0.0) (2026-06-05)


### ⚠ BREAKING CHANGES

* **review:** /review 的执行机制由"5 agent 并行 + 主 agent 三维自评分过滤"替换为 Workflow 工具编排——Find 阶段 5 个 finder 并行产出 schema 结构化发现，纯代码去重与交叉验证标记后，每条 BLOCKER/IMPORTANT 发现交由 3 个独立怀疑视角（重要性/根源性/不修风险）对抗验证、多数决定去留。原三维评分公式与"已过滤摘要"机制删除，被否决项改以对抗验证 verdict 单行透明化呈现。本 skill 自此依赖 Workflow 工具，要求 Claude Code ≥ 2.1.154，低于该版本 /review 不可用且不提供降级路径。迁移：升级 Claude Code 至 2.1.154+ 即可，命令用法（/review <base-branch>）不变。另清理 v3.0.0 语言无关化漏改的"输出中文"残留。

### Features

* **review:** /review 改为 Workflow 编排的多维审查 + 对抗性验证 ([#50](https://github.com/0xBB2B/bb-spec/issues/50)) ([b166c71](https://github.com/0xBB2B/bb-spec/commit/b166c710890e331a6f233461958b74125f6cb37d))

## [3.1.0](https://github.com/0xBB2B/bb-spec/compare/v3.0.0...v3.1.0) (2026-06-05)


### Features

* **vue-constraints,hooks:** 既有 lockfile 项目跟随原包管理器，不再强制 bun ([#48](https://github.com/0xBB2B/bb-spec/issues/48)) ([fe1114e](https://github.com/0xBB2B/bb-spec/commit/fe1114eee1d4c0fe9bad6dcac0cf98007b326757))

## [3.0.0](https://github.com/0xBB2B/bb-spec/compare/v2.1.0...v3.0.0) (2026-06-02)


### ⚠ BREAKING CHANGES

* skill 产出的默认语言从「强制中文」变为「跟随用户工作语言」。 同样的 /spec、/plan、/init 等调用，对非中文用户现在会产出其工作语言的文档与注释而非中文； 中文用户行为不变（用中文对话即得中文产出）。如需固定某语言，请在自己的 CLAUDE.md 中声明语言偏好。

### Features

* 工作流产出改为语言无关，不再强制中文输出 ([#45](https://github.com/0xBB2B/bb-spec/issues/45)) ([7107afe](https://github.com/0xBB2B/bb-spec/commit/7107afee985ca9ed5fb8a9eb633025105759b844))

## [2.1.0](https://github.com/0xBB2B/bb-spec/compare/v2.0.0...v2.1.0) (2026-06-02)


### Features

* **skills:** 知识型 skill 从用户斜杠菜单隐藏 ([#43](https://github.com/0xBB2B/bb-spec/issues/43)) ([eccd5b4](https://github.com/0xBB2B/bb-spec/commit/eccd5b49e8f1c89624e0c554d6d22e56fc769e13))

## [2.0.0](https://github.com/0xBB2B/bb-spec/compare/v1.4.0...v2.0.0) (2026-05-29)


### ⚠ BREAKING CHANGES

* user-invocable 命令 /bug 重命名为 /revise，技能目录 skills/bug/ 移至 skills/revise/。迁移：原先输入 /bug 改为 /revise；自然语言触发（"这里有 bug"、"结果不对"等）行为不变。

### Features

* /bug 改名为 /revise 并压缩四个 skill 文档 ([#41](https://github.com/0xBB2B/bb-spec/issues/41)) ([f371f0f](https://github.com/0xBB2B/bb-spec/commit/f371f0f0936d87877d49bf5e3ba84bacc33090fd))

## [1.4.0](https://github.com/0xBB2B/bb-spec/compare/v1.3.0...v1.4.0) (2026-05-28)


### Features

* **gitignore:** 忽略项目根 CLAUDE.md，避免个人项目偏好被分发 ([#39](https://github.com/0xBB2B/bb-spec/issues/39)) ([0343a3f](https://github.com/0xBB2B/bb-spec/commit/0343a3f7174b3ea8bcf9936e217cdc199f4becfc))

## [1.3.0](https://github.com/0xBB2B/bb-spec/compare/v1.2.0...v1.3.0) (2026-05-28)


### Features

* review skill 输出前加自检过滤层，过滤低价值发现 ([#36](https://github.com/0xBB2B/bb-spec/issues/36)) ([3da94b7](https://github.com/0xBB2B/bb-spec/commit/3da94b75cda923b7ea4d01292df593c78c13645e))

## [1.2.0](https://github.com/0xBB2B/bb-spec/compare/v1.1.0...v1.2.0) (2026-05-28)


### Features

* 新增 init skill 反向 spec 化存量项目 ([#34](https://github.com/0xBB2B/bb-spec/issues/34)) ([80217a4](https://github.com/0xBB2B/bb-spec/commit/80217a4faceff09012bb709db675b0563c9aedbe))

## [1.1.0](https://github.com/0xBB2B/bb-spec/compare/v1.0.1...v1.1.0) (2026-05-27)


### Features

* bug skill 轻量修复前须向用户确认是否跳过 3-Agent 隔离 ([#30](https://github.com/0xBB2B/bb-spec/issues/30)) ([6250ede](https://github.com/0xBB2B/bb-spec/commit/6250ede98ee3c72d0fdf7dca10da893c0e3e6e40))
* 用 release-please 替代手动 workflow_dispatch 发版 ([#31](https://github.com/0xBB2B/bb-spec/issues/31)) ([d1da9ec](https://github.com/0xBB2B/bb-spec/commit/d1da9ecd7a0ba5bd25558437be81c9fdadf4d5bd))
