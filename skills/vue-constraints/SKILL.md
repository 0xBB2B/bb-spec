---
name: vue-constraints
description: 前端项目技术栈与工具链强制约束——默认技术栈统一为 Vue 3 + TypeScript + Vite + Tailwind CSS，包管理器统一为 bun（禁用 npm / yarn / pnpm）。TRIGGER when：新建前端项目、编辑 package.json / vite.config.* / tailwind.config.* / tsconfig.json / .vue / .ts / .tsx 文件、运行前端构建或安装命令、用户提到"前端"/"vue"/"vite"/"tailwind"/"npm install"/"yarn add"/"pnpm" 等场景。
user-invocable: false
---

# 前端技术栈约束

适用于：**所有前端项目**——含新建项目、为既有项目添加功能、升级或迁移工具链。

> 核心理念：**统一技术栈降低跨项目认知负担。** 偏离默认栈必须有明确业务理由并经用户确认，不接受"个人偏好"作为偏离依据。

## 0. 触发场景

**TRIGGER**（命中任一即应应用本约束）：

- **新建前端项目**：用户要求"做个前端"/"起个 Vue 项目"/"搭个管理后台"/"建个网站" 等
- **编辑前端关键文件**：
  - `package.json`、`bun.lockb`
  - `vite.config.ts` / `vite.config.js`
  - `tailwind.config.ts` / `tailwind.config.js`
  - `tsconfig.json` / `tsconfig.*.json`
  - `*.vue`、`*.ts`、`*.tsx`（前端项目内）
  - `index.html`（Vite 项目根入口）
- **运行前端命令**：安装依赖、启动 dev server、构建、跑测试等
- **用户口语触发**：
  - "前端" / "frontend" / "UI"
  - "vue" / "vite" / "tailwind" / "ts"
  - "npm install X" / "yarn add X" / "pnpm add X"（应纠正为 bun）

**SKIP**（以下情况本约束不适用）：

- 纯后端 / CLI / 工具项目
- 用户明确说明"这个项目用 React" / "这个用 Nuxt" / "这个用 Svelte" 等其他栈，并征得理解后

---

## 1. 默认技术栈（强制）

新建前端项目，统一使用以下技术栈，**不接受个人偏好替代**：

| 维度 | 默认选择 |
|---|---|
| 框架 | **Vue 3** |
| 语言 | **TypeScript** |
| 构建工具 | **Vite** |
| CSS | **Tailwind CSS** |
| 包管理器 | **bun** |

### 1.1 Vue 3

- 使用 Composition API（`<script setup>`）作为默认风格
- **禁止** Vue 2 / Options API 风格新代码（既有项目维护除外）

### 1.2 TypeScript

- **禁止** 纯 JavaScript（`.js` / `.jsx`）作为前端源文件
- 启用 `strict: true`（含 `strictNullChecks`、`noImplicitAny` 等）
- `*.vue` 文件 `<script>` 必须带 `lang="ts"`

### 1.3 Vite

- **禁止**直接配置 webpack / rollup 替代 Vite
- 复杂构建需求优先用 Vite 插件生态满足

### 1.4 Tailwind CSS

- 优先使用 Tailwind utility class
- **禁止**引入 styled-components / emotion / 纯手写 SCSS 体系 等替代 CSS 方案
- 复杂组件样式优先抽组件，**不要**依赖 `@apply` 堆叠

---

## 2. 禁止替代清单

以下替代方案**禁止**使用，除非有明确业务必要并经用户确认：

| 不得使用 | 应使用 | 原因 |
|---|---|---|
| Vue 2 | Vue 3 | Vue 2 已 EOL，Composition API 是主流 |
| 纯 JavaScript（无类型） | TypeScript | 类型安全、IDE 体验、重构友好 |
| webpack / rollup 直配 | Vite | HMR 速度、配置复杂度、开箱即用 |
| styled-components / emotion / 手写 SCSS 体系 | Tailwind CSS | 设计系统一致性、原子类心智模型 |
| Vuex | Pinia | Vue 3 官方推荐，TS 支持更好 |
| npm / yarn / pnpm | bun | 速度、统一工具链（详见第 3 节） |

如确需引入额外方案，**必须先与用户确认**，并在 PR 描述中写明：
- 业务必要性
- 评估过的替代方案与放弃原因

---

## 3. 包管理器：bun（强制）

### 3.1 唯一指定

所有前端项目**必须使用 `bun`** 作为包管理器和脚本运行工具。

### 3.2 禁止使用

`npm` / `yarn` / `pnpm` **一律禁止**用于前端项目：

- ❌ `npm install <pkg>` / `npm run <script>` / `npx <cmd>`
- ❌ `yarn add <pkg>` / `yarn <script>` / `yarn dlx <cmd>`
- ❌ `pnpm add <pkg>` / `pnpm <script>` / `pnpm dlx <cmd>`

### 3.3 标准命令对照

| 操作 | bun 命令 |
|---|---|
| 安装所有依赖 | `bun install` |
| 添加依赖 | `bun add <pkg>` |
| 添加 dev 依赖 | `bun add -d <pkg>` |
| 移除依赖 | `bun remove <pkg>` |
| 升级依赖 | `bun update <pkg>` |
| 运行脚本 | `bun run <script>` |
| 执行临时命令 | `bunx <cmd>`（等价于 `npx`） |
| 跑测试 | `bun test`（Bun 内置）或 `bun run test` |

### 3.4 lockfile

- 提交 `bun.lockb` 进版本控制
- **禁止**同时存在 `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`（发现立即删除）

### 3.5 用户口语自动纠正

当用户说 "`npm install X`" / "`yarn add X`" / "`pnpm add X`" 时，Agent 应：
1. 自动改为 `bun add X` 执行
2. 在回复中**简短提示一次**（不重复唠叨）："已使用 bun 替代，按前端规范"

---

## 4. 与其他规范的协作

- **依赖版本选择**：所有新增 / 升级依赖时，版本号选择遵循 `version-policy` skill（先查官方最新版本，不凭记忆填写）。
- **TypeScript 函数注释**：遵循 JSDoc/TSDoc 风格，使用中文（详见全局编码风格）。
- **Git 工作流**：前端项目同样遵循 `git-workflow` skill（分支策略、PR 三段式等）。

---

## 5. 新建项目脚手架命令

新建项目时推荐使用 Vite 官方脚手架：

```bash
# 创建 Vue 3 + TS 项目
bun create vite@latest <project-name> -- --template vue-ts

# 进入项目并安装依赖
cd <project-name>
bun install

# 添加 Tailwind CSS（按官方 Vite 集成指南）
bun add -d tailwindcss @tailwindcss/vite
# 后续配置 vite.config.ts 与全局 css，详见 https://tailwindcss.com/docs/installation/using-vite

# 启动 dev server
bun run dev
```

> ⚠️ 实际依赖版本号必须按 `version-policy` skill 要求**先查官方最新版本**再写入，不要凭记忆。

---

## 6. 自检清单

新建前端项目或为前端项目添加依赖前，对照以下清单：

- [ ] 框架是 **Vue 3**（不是 Vue 2）
- [ ] 语言是 **TypeScript**（启用 strict）
- [ ] 构建工具是 **Vite**（不是 webpack/rollup 直配）
- [ ] CSS 方案是 **Tailwind CSS**（不是 styled-components / 手写 SCSS 体系）
- [ ] 包管理器是 **bun**（不是 npm/yarn/pnpm）
- [ ] `bun.lockb` 已提交，无其他 lockfile 残留
- [ ] 偏离默认栈的部分已与用户确认并写明原因
