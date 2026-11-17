const COPY = {
  zh: {
    title: 'bb-spec — PRD 驱动的 Claude Code 流水线',
    nav: { problem: '[解决什么]', pipeline: '[流水线]', install: '[安装]', github: '[GitHub]' },
    kicker: '# Claude Code 插件',
    tag: '一条 PRD 驱动的 Claude Code 流水线，把模糊需求一路带到可交付的代码。',
    sub: '每个阶段可追溯、可断点恢复、经对抗验证。',
    ctaInstall: '安装', ctaGithub: '在 GitHub 上查看',
    copy: '复制', copied: '已复制',
    problemTitle: '它解决什么问题',
    problemLead: '每次交接物都是磁盘上的文档，不是会话里的临时记忆。所以它能断点续、能换 AI 接手、能逐级追溯。',
    problems: [
      ['三 Agent 隔离执行', '写实现的 Agent 看不到 PRD，只看测试，没法“照着意图蒙混”。测试、实现、审查由互相看不见的三方分别完成。'],
      ['磁盘文档是唯一交接物', '每个阶段交接的是文件，不是会话记忆。跨会话、/clear 之后，甚至换一个模型接手，都能无损续接。'],
      ['代码和 PRD 经 git 双向可查', '代码是唯一事实来源，PRD 只写为什么。每个 commit 带需求标记，从功能能找到代码，从函数能查回当时的需求与取舍。'],
    ],
    pipeTitle: '流水线怎么走',
    pipeLead: '你读完 PRD 批准一次，/plan、/exec、/doc-update 自动接着跑；/git-push 由你手动触发。',
    stages: [
      ['/prd', '做什么', '质疑、澄清、拆解，落盘 PRD，请你读完确认。'],
      ['/plan', '怎么做', '把 PRD 变成函数级实施计划。只有要引入新技术时才停下问你。'],
      ['/exec', 'Red → Green → Review', '三个互相隔离的 Agent 依次写测试、写实现、做审查。进度写进 PROGRESS.md，中断后能接着跑。'],
      ['/doc-update', '文档追平代码', '代码是事实，让本次 PRD 和 README 等文档追平实际交付。'],
      ['/git-push', 'pre-review + 开 PR', '分支规范自查，推送，开 PR。'],
    ],
    once: '唯一一次批准', auto: '自动衔接', manual: '由你手动触发',
    revise: '/revise 随时介入：有 bug 或结果和预期不符时，按根因诊断、定向修正、回归验证。',
    installTitle: '安装',
    installLead: '在 Claude Code 里执行这三行：',
    installNote: '这两个子插件给你纪律和工作流。后端、前端的技术栈约束按需再装。',
    th: ['子插件', '装了得到什么'],
    plugins: [
      ['bb-spec-core', '推荐基座', 'TDD / 版本策略 / Git 纪律，加 3 个被动 hook'],
      ['bb-spec-workflow', '核心功能', 'prd → plan → exec → doc-update → revise → git-push，加 8 个 subagent'],
      ['bb-spec-backend', '', 'Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理 / 配置约束'],
      ['bb-spec-frontend', '', 'Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定'],
    ],
    more: '完整说明在 README →',
    readme: 'https://github.com/0xBB2B/bb-spec#readme',
  },
  en: {
    title: 'bb-spec — A PRD-driven Claude Code pipeline',
    nav: { problem: '[Why]', pipeline: '[Pipeline]', install: '[Install]', github: '[GitHub]' },
    kicker: '# Claude Code plugin',
    tag: 'A PRD-driven Claude Code pipeline that carries fuzzy requirements all the way to shipped code.',
    sub: 'Every stage traceable, resumable, and adversarially verified.',
    ctaInstall: 'Install', ctaGithub: 'View on GitHub',
    copy: 'Copy', copied: 'Copied',
    problemTitle: 'What it solves',
    problemLead: 'Every handoff is a file on disk, not a memory in the chat. That is what makes it resumable, AI-swappable, and auditable end to end.',
    problems: [
      ['Three-agent isolated execution', 'The Impl agent never sees the PRD, only the tests, so it cannot quietly “teach to intent”. Tests, implementation, and review are written by mutually-blind agents.'],
      ['Disk documents as the only handoff', 'Every stage hands off a file, not chat memory, so a run resumes losslessly across sessions, /clear, or even a different model picking up the work.'],
      ['Code and PRD, traceable both ways through git', 'Code is the single source of truth and the PRD only records why. Every commit carries a requirement trailer, so you can go from a feature to its code and from a function back to the requirement and trade-offs behind it.'],
    ],
    pipeTitle: 'How the pipeline runs',
    pipeLead: 'You read the PRD and approve once. /plan, /exec and /doc-update then run on their own; /git-push is triggered by you.',
    stages: [
      ['/prd', 'what', 'Challenge, clarify, break down, then write the PRD for you to read and confirm.'],
      ['/plan', 'how', 'Turns the PRD into a function-level plan. Stops only when new tech is needed.'],
      ['/exec', 'Red → Green → Review', 'Three isolated agents write tests, implementation and review in turn. Progress goes to PROGRESS.md, so an interrupted run resumes.'],
      ['/doc-update', 'docs sync', 'Code is the truth: this PRD and docs like README are mirrored to what was actually delivered.'],
      ['/git-push', 'pre-review + open PR', 'Branch self-check, push, open the PR.'],
    ],
    once: 'the only approval', auto: 'chained automatically', manual: 'triggered by you',
    revise: '/revise anytime: for a bug or results that don’t match expectations, diagnose by root cause, apply a targeted fix, run a regression check.',
    installTitle: 'Install',
    installLead: 'Run these three lines inside Claude Code:',
    installNote: 'These two sub-plugins give you the disciplines and the workflow. Add the backend and frontend stack constraints when you need them.',
    th: ['Sub-plugin', 'What it gives you'],
    plugins: [
      ['bb-spec-core', 'recommended base', 'TDD / version-policy / git-workflow discipline, plus 3 passive hooks'],
      ['bb-spec-workflow', 'core', 'prd → plan → exec → doc-update → revise → git-push, plus 8 subagents'],
      ['bb-spec-backend', '', 'Go / REST API / DB / authN / authZ / observability / service / config constraints'],
      ['bb-spec-frontend', '', 'Vue 3 + TS + Vite + Tailwind + bun stack & engineering conventions'],
    ],
    more: 'Full details are in the README →',
    readme: 'https://github.com/0xBB2B/bb-spec/blob/main/README.en.md',
  },
};
const COMMANDS = [
  '/plugin marketplace add 0xBB2B/bb-spec',
  '/plugin install bb-spec-core@0xbb2b',
  '/plugin install bb-spec-workflow@0xbb2b',
];

const LANG_KEY = 'bb-spec-lang';
const COPIED_RESET_MS = 1600;
let currentLang = 'zh';

function pickLang(saved, languages) {
  if (saved === 'zh' || saved === 'en') return saved;
  const first = languages && languages[0];
  return typeof first === 'string' && /^zh/i.test(first) ? 'zh' : 'en';
}

function readSavedLang() {
  try {
    return localStorage.getItem(LANG_KEY);
  } catch (e) {
    return null;
  }
}

function saveLang(lang) {
  try {
    localStorage.setItem(LANG_KEY, lang);
  } catch (e) {}
}

function applyLang(lang) {
  currentLang = lang;
  const copy = COPY[lang];
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    el.textContent = el.getAttribute('data-i18n').split('.').reduce((o, k) => o[k], copy);
  });
  document.querySelectorAll('[data-readme]').forEach((a) => a.setAttribute('href', copy.readme));
  document.querySelectorAll('[data-lang]').forEach((b) => b.setAttribute('aria-pressed', String(b.getAttribute('data-lang') === lang)));
  document.title = copy.title;
  document.documentElement.setAttribute('lang', lang === 'zh' ? 'zh-CN' : 'en');
}

function copyCommands(button) {
  if (!navigator.clipboard) return;
  navigator.clipboard.writeText(COMMANDS.join('\n')).then(() => {
    button.textContent = COPY[currentLang].copied;
    clearTimeout(button.resetTimer);
    button.resetTimer = setTimeout(() => { button.textContent = COPY[currentLang].copy; }, COPIED_RESET_MS);
  }, () => {});
}

function init() {
  const languages = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language];
  applyLang(pickLang(readSavedLang(), languages));
  document.querySelectorAll('[data-lang]').forEach((b) => b.addEventListener('click', () => {
    const lang = b.getAttribute('data-lang');
    applyLang(lang);
    saveLang(lang);
  }));
  document.querySelectorAll('[data-copy]').forEach((b) => b.addEventListener('click', () => copyCommands(b)));
}

window.BBHomepage = { COPY, COMMANDS, pickLang, applyLang, copyCommands };
init();
