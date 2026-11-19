#!/usr/bin/env bash
# site/ 主页校验：静态中文内容、无外部资源、样式关键值、双语文案、语言选择、切换与复制行为（假 DOM + vm）
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." >/dev/null && pwd)"
SITE="$ROOT/site"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 本机没有 node，行为测试无法运行（需要 node 自带的 vm 模块）"
  exit 1
fi

echo "[文件存在与语法]"
missing=0
for f in index.html style.css app.js; do
  if [[ -f "$SITE/$f" ]]; then pass; else fail "缺少 site/$f"; missing=1; fi
done
if [[ "$missing" == "1" ]]; then
  echo "ERROR: 主页文件不全，请先新增 site/index.html、site/style.css、site/app.js 再跑本测试"
  echo "通过: $PASS, 失败: $FAIL"
  exit 1
fi
if node --check "$SITE/app.js" 2>/dev/null; then pass; else fail "node --check site/app.js 未通过"; fi

TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_T"' EXIT
JS="$TMPDIR_T/homepage.js"

cat > "$JS" <<'JSEOF'
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const SITE = path.join(process.env.ROOT, 'site');
const HTML = fs.readFileSync(path.join(SITE, 'index.html'), 'utf8');
const CSS = fs.readFileSync(path.join(SITE, 'style.css'), 'utf8');
const APP = fs.readFileSync(path.join(SITE, 'app.js'), 'utf8');

let pass = 0, fail = 0;
const ok = (cond, label) => {
  if (cond) pass++;
  else { fail++; console.log('  FAIL: ' + label); }
};
const eq = (got, want, label) =>
  ok(JSON.stringify(got) === JSON.stringify(want),
    `${label}：预期 ${JSON.stringify(want)}，实际 ${JSON.stringify(got)}`);
const group = (name, fn) => {
  console.log('[' + name + ']');
  try { fn(); } catch (err) { fail++; console.log('  FAIL: 异常：' + (err && err.stack || err)); }
};
const groupAsync = async (name, fn) => {
  console.log('[' + name + ']');
  try { await fn(); } catch (err) { fail++; console.log('  FAIL: 异常：' + (err && err.stack || err)); }
};

const ENT = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', rarr: '→', larr: '←', mdash: '—', ndash: '–', middot: '·', hellip: '…' };
const decode = (s) => s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
  if (e[0] === '#') return String.fromCodePoint(e[1].toLowerCase() === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10));
  return e in ENT ? ENT[e] : m;
});
const stripTags = (s) => decode(s.replace(/<[^>]*>/g, ''));

const kebabToCamel = (s) => s.replace(/-([a-z])/g, (_, c) => c.toUpperCase());
const camelToKebab = (s) => s.replace(/[A-Z]/g, (c) => '-' + c.toLowerCase());

function parseCompound(s) {
  const c = { tag: null, id: null, classes: [], attrs: [] };
  let rest = s;
  while (rest) {
    let m;
    if ((m = /^([a-zA-Z][\w-]*|\*)/.exec(rest))) c.tag = m[1] === '*' ? null : m[1].toLowerCase();
    else if ((m = /^#([\w-]+)/.exec(rest))) c.id = m[1];
    else if ((m = /^\.([\w-]+)/.exec(rest))) c.classes.push(m[1]);
    else if ((m = /^\[([\w-]+)(?:([~|^$*]?=)(?:"([^"]*)"|'([^']*)'|([^\]]*)))?\]/.exec(rest))) {
      c.attrs.push({ name: m[1], op: m[2] || null, val: m[3] ?? m[4] ?? m[5] ?? '' });
    } else { c.unsupported = true; return c; }
    rest = rest.slice(m[0].length);
  }
  return c;
}

class El {
  constructor(tag) {
    this.tagName = String(tag).toUpperCase();
    this._attrs = new Map();
    this.children = [];
    this.parentElement = null;
    this._html = null;
    this._l = {};
    this.style = {};
    const self = this;
    this.classList = {
      add: (...n) => { const s = new Set(self._classes()); n.forEach((x) => s.add(x)); self._attrs.set('class', [...s].join(' ')); },
      remove: (...n) => { const s = new Set(self._classes()); n.forEach((x) => s.delete(x)); self._attrs.set('class', [...s].join(' ')); },
      toggle: (n, force) => {
        const has = self._classes().includes(n);
        const want = force === undefined ? !has : !!force;
        if (want) self.classList.add(n); else self.classList.remove(n);
        return want;
      },
      contains: (n) => self._classes().includes(n),
    };
    this.dataset = new Proxy({}, {
      get: (_, k) => (typeof k === 'string' && self._attrs.has('data-' + camelToKebab(k))) ? self._attrs.get('data-' + camelToKebab(k)) : undefined,
      set: (_, k, v) => { self._attrs.set('data-' + camelToKebab(k), String(v)); return true; },
    });
  }
  _classes() { return (this._attrs.get('class') || '').split(/\s+/).filter(Boolean); }
  get tag() { return this.tagName.toLowerCase(); }
  getAttribute(n) { return this._attrs.has(n) ? this._attrs.get(n) : null; }
  setAttribute(n, v) { this._attrs.set(n, String(v)); }
  removeAttribute(n) { this._attrs.delete(n); }
  hasAttribute(n) { return this._attrs.has(n); }
  get href() { return this.getAttribute('href') || ''; }
  set href(v) { this.setAttribute('href', v); }
  get lang() { return this.getAttribute('lang') || ''; }
  set lang(v) { this.setAttribute('lang', v); }
  get id() { return this.getAttribute('id') || ''; }
  set id(v) { this.setAttribute('id', v); }
  get className() { return this.getAttribute('class') || ''; }
  set className(v) { this.setAttribute('class', v); }
  get textContent() {
    if (this._html !== null) return stripTags(this._html);
    return this.children.map((c) => (typeof c === 'string' ? c : c.textContent)).join('');
  }
  set textContent(v) { this.children = [String(v)]; this._html = null; }
  get innerHTML() { return this._html !== null ? this._html : this.textContent; }
  set innerHTML(v) { this._html = String(v); this.children = []; }
  addEventListener(t, fn) { (this._l[t] = this._l[t] || []).push(fn); }
  removeEventListener(t, fn) { this._l[t] = (this._l[t] || []).filter((f) => f !== fn); }
  dispatch(t, ev) { (this._l[t] || []).slice().forEach((f) => f.call(this, ev || { type: t, target: this, preventDefault() {} })); }
  focus() {}
  scrollIntoView() {}
  matches(sel) { return matchSel(this, sel); }
  closest(sel) { for (let e = this; e; e = e.parentElement) if (e.matches && matchSel(e, sel)) return e; return null; }
  contains(o) { for (let e = o; e; e = e.parentElement) if (e === this) return true; return false; }
  querySelectorAll(sel) { return this._descendants().filter((e) => matchSel(e, sel)); }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
  _descendants() {
    const out = [];
    const walk = (e) => e.children.forEach((c) => { if (typeof c !== 'string') { out.push(c); walk(c); } });
    walk(this);
    return out;
  }
}

function matchCompound(el, c) {
  if (c.unsupported) return false;
  if (c.tag && el.tag !== c.tag) return false;
  if (c.id && el.getAttribute('id') !== c.id) return false;
  if (!c.classes.every((k) => el.classList.contains(k))) return false;
  return c.attrs.every((a) => {
    const v = el.getAttribute(a.name);
    if (v === null) return false;
    switch (a.op) {
      case null: return true;
      case '=': return v === a.val;
      case '^=': return v.startsWith(a.val);
      case '$=': return v.endsWith(a.val);
      case '*=': return v.includes(a.val);
      case '~=': return v.split(/\s+/).includes(a.val);
      default: return false;
    }
  });
}
function matchSel(el, sel) {
  return sel.split(',').some((one) => {
    const parts = one.trim().split(/\s+/).filter((p) => p !== '>').map(parseCompound);
    if (!parts.length || !matchCompound(el, parts[parts.length - 1])) return false;
    let anc = el.parentElement, i = parts.length - 2;
    while (i >= 0 && anc) { if (anc.matches && matchCompound(anc, parts[i])) i--; anc = anc.parentElement; }
    return i < 0;
  });
}

const VOID = new Set(['meta', 'link', 'br', 'img', 'input', 'hr', 'source', 'wbr']);
const RAW = new Set(['script', 'style']);

function parseHTML(src) {
  const root = new El('#document');
  const all = [];
  const stack = [root];
  const re = /<!--[\s\S]*?-->|<![^>]*>|<\/([a-zA-Z][\w-]*)\s*>|<([a-zA-Z][\w-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>/g;
  let last = 0, m;
  while ((m = re.exec(src))) {
    const top = stack[stack.length - 1];
    const text = src.slice(last, m.index);
    if (text) top.children.push(decode(text));
    last = re.lastIndex;
    if (m[1]) {
      const t = m[1].toLowerCase();
      for (let i = stack.length - 1; i > 0; i--) {
        if (stack[i].tag === t) { stack.length = i; break; }
      }
    } else if (m[2]) {
      const t = m[2].toLowerCase();
      const el = new El(t);
      let attrSrc = m[3];
      const selfClose = /\/\s*$/.test(attrSrc);
      if (selfClose) attrSrc = attrSrc.replace(/\/\s*$/, '');
      const ar = /([^\s=\/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
      let a;
      while ((a = ar.exec(attrSrc))) el._attrs.set(a[1].toLowerCase(), decode(a[2] ?? a[3] ?? a[4] ?? ''));
      el.parentElement = top.tagName === '#DOCUMENT' ? null : top;
      top.children.push(el);
      all.push(el);
      if (!VOID.has(t) && !selfClose) {
        stack.push(el);
        if (RAW.has(t)) {
          const end = src.toLowerCase().indexOf('</' + t, last);
          if (end >= 0) { el.children.push(src.slice(last, end)); re.lastIndex = last = end; }
        }
      }
    }
  }
  return { root, all };
}

function makeDocument(src) {
  const { root, all } = parseHTML(src);
  const doc = new El('#document');
  doc.children = root.children;
  const find = (t) => all.find((e) => e.tag === t) || null;
  let titleText = null;
  const titleEl = find('title');
  Object.defineProperty(doc, 'title', {
    get: () => (titleText !== null ? titleText : (titleEl ? titleEl.textContent : '')),
    set: (v) => { titleText = String(v); },
  });
  doc.documentElement = find('html');
  doc.body = find('body');
  doc.head = find('head');
  doc.readyState = 'complete';
  doc._descendants = () => all;
  doc.getElementById = (id) => all.find((e) => e.getAttribute('id') === id) || null;
  doc.createElement = (t) => new El(t);
  doc.all = all;
  return doc;
}

const unhandled = [];
process.on('unhandledRejection', (e) => unhandled.push(e));
process.on('uncaughtException', (e) => unhandled.push(e));
const flush = async () => { for (let i = 0; i < 5; i++) await new Promise((r) => setImmediate(r)); };

function boot(opts = {}) {
  const { saved = null, languages = ['zh-CN'], storage = 'ok', clipboard = 'ok' } = opts;
  const store = new Map();
  if (saved !== null) store.set('bb-spec-lang', saved);
  const writes = [];
  const timers = [];
  let now = 0, seq = 0;
  const doc = makeDocument(HTML);
  const nav = { languages, language: languages[0] };
  if (clipboard === 'ok') nav.clipboard = { writeText: (t) => { writes.push(t); return Promise.resolve(); } };
  if (clipboard === 'reject') nav.clipboard = { writeText: (t) => { writes.push(t); return Promise.reject(new Error('denied')); } };
  const lsObj = storage === 'methods-throw'
    ? { getItem() { throw new Error('denied'); }, setItem() { throw new Error('denied'); }, removeItem() { throw new Error('denied'); } }
    : { getItem: (k) => (store.has(k) ? store.get(k) : null), setItem: (k, v) => { store.set(k, String(v)); }, removeItem: (k) => { store.delete(k); } };
  const sandbox = {
    document: doc, navigator: nav, console, location: { href: 'http://localhost/', hash: '', search: '' },
    setTimeout: (fn, ms) => { const id = ++seq; timers.push({ id, at: now + (ms || 0), fn }); return id; },
    clearTimeout: (id) => { const i = timers.findIndex((t) => t.id === id); if (i >= 0) timers.splice(i, 1); },
    addEventListener() {}, removeEventListener() {},
  };
  sandbox.window = sandbox;
  if (storage === 'getter-throw') {
    Object.defineProperty(sandbox, 'localStorage', { get() { throw new Error('SecurityError'); }, configurable: true });
  } else sandbox.localStorage = lsObj;
  const ctx = vm.createContext(sandbox);
  let loadError = null;
  try {
    vm.runInContext(APP, ctx, { filename: 'app.js' });
    doc.dispatch('DOMContentLoaded');
  } catch (e) { loadError = e; }
  return {
    win: sandbox, doc, store, writes, loadError,
    api: sandbox.BBHomepage,
    advance(ms) {
      now += ms;
      timers.sort((a, b) => a.at - b.at);
      while (timers.length && timers[0].at <= now) timers.shift().fn();
    },
  };
}

const norm = (s) => s.replace(/^#+\s*/, '').replace(/\s+/g, '');
const T = (zh, en) => ({ zh, en });
const PIECES = [
  T('bb-spec — PRD 驱动的 Claude Code 流水线', 'bb-spec — A PRD-driven Claude Code pipeline'),
  T('# Claude Code 插件', '# Claude Code plugin'),
  T('一条 PRD 驱动的 Claude Code 流水线，把模糊需求一路带到可交付的代码。', 'A PRD-driven Claude Code pipeline that carries fuzzy requirements all the way to shipped code.'),
  T('每个阶段可追溯、可断点恢复、经对抗验证。', 'Every stage traceable, resumable, and adversarially verified.'),
  T('## 它解决什么问题', '## What it solves'),
  T('每次交接物都是磁盘上的文档，不是会话里的临时记忆。所以它能断点续、能换 AI 接手、能逐级追溯。', 'Every handoff is a file on disk, not a memory in the chat. That is what makes it resumable, AI-swappable, and auditable end to end.'),
  T('三 Agent 隔离执行', 'Three-agent isolated execution'),
  T('写实现的 Agent 看不到 PRD，只看测试，没法“照着意图蒙混”。测试、实现、审查由互相看不见的三方分别完成。', 'The Impl agent never sees the PRD, only the tests, so it cannot quietly “teach to intent”. Tests, implementation, and review are written by mutually-blind agents.'),
  T('磁盘文档是唯一交接物', 'Disk documents as the only handoff'),
  T('每个阶段交接的是文件，不是会话记忆。跨会话、/clear 之后，甚至换一个模型接手，都能无损续接。', 'Every stage hands off a file, not chat memory, so a run resumes losslessly across sessions, /clear, or even a different model picking up the work.'),
  T('代码和 PRD 经 git 双向可查', 'Code and PRD, traceable both ways through git'),
  T('代码是唯一事实来源，PRD 只写为什么。每个 commit 带需求标记，从功能能找到代码，从函数能查回当时的需求与取舍。', 'Code is the single source of truth and the PRD only records why. Every commit carries a requirement trailer, so you can go from a feature to its code and from a function back to the requirement and trade-offs behind it.'),
  T('## 流水线怎么走', '## How the pipeline runs'),
  T('你读完 PRD 批准需求；要用新技术时先问你，plan 里新增或修改表结构、接口、数据格式、配置时再确认一次，其余自动跑完。/git-push 由你手动触发。', 'You read the PRD and approve the requirement. New tech is confirmed with you before the plan is written, and any new or changed table schema, API, data format or config is confirmed once the plan is done; everything else runs on its own. /git-push is triggered by you.'),
  T('做什么', 'what'),
  T('质疑、澄清、拆解，落盘 PRD，请你读完确认。', 'Challenge, clarify, break down, then write the PRD for you to read and confirm.'),
  T('怎么做', 'how'),
  T('把 PRD 变成函数级实施计划。要用新技术时先问你；新增或修改表结构、接口、数据格式、配置时，列成清单请你确认。', 'Turns the PRD into a function-level plan. Asks before bringing in new tech, and lists any new or changed table schema, API, data format or config for you to confirm.'),
  T('Red → Green → Review', 'Red → Green → Review'),
  T('三个互相隔离的 Agent 依次写测试、写实现、做审查。进度写进 PROGRESS.md，中断后能接着跑。', 'Three isolated agents write tests, implementation and review in turn. Progress goes to PROGRESS.md, so an interrupted run resumes.'),
  T('文档追平代码', 'docs sync'),
  T('代码是事实，让本次 PRD 和 README 等文档追平实际交付。', 'Code is the truth: this PRD and docs like README are mirrored to what was actually delivered.'),
  T('pre-review + 开 PR', 'pre-review + open PR'),
  T('分支规范自查，推送，开 PR。', 'Branch self-check, push, open the PR.'),
  T('自动衔接', 'chained automatically'),
  T('由你手动触发', 'triggered by you'),
  T('/revise 随时介入：有 bug 或结果和预期不符时，按根因诊断、定向修正、回归验证。', '/revise anytime: for a bug or results that don’t match expectations, diagnose by root cause, apply a targeted fix, run a regression check.'),
  T('## 安装', '## Install'),
  T('在 Claude Code 里执行这三行：', 'Run these three lines inside Claude Code:'),
  T('这两个子插件给你纪律和工作流。后端、前端的技术栈约束按需再装。', 'These two sub-plugins give you the disciplines and the workflow. Add the backend and frontend stack constraints when you need them.'),
  T('推荐基座', 'recommended base'),
  T('TDD / 版本策略 / Git 纪律，加 3 个被动 hook', 'TDD / version-policy / git-workflow discipline, plus 3 passive hooks'),
  T('核心功能', 'core'),
  T('prd → plan → exec → doc-update → revise → git-push，加 8 个 subagent', 'prd → plan → exec → doc-update → revise → git-push, plus 8 subagents'),
  T('Go / REST API / 数据库 / 认证 / 授权 / 可观测性 / 服务治理 / 配置约束', 'Go / REST API / DB / authN / authZ / observability / service / config constraints'),
  T('Vue 3 + TS + Vite + Tailwind + bun 技术栈与工程约定', 'Vue 3 + TS + Vite + Tailwind + bun stack & engineering conventions'),
  T('完整说明在 README →', 'Full details are in the README →'),
  T('复制', 'Copy'),
  T('已复制', 'Copied'),
];

const COMMANDS_EXPECTED = [
  '/plugin marketplace add 0xBB2B/bb-spec',
  '/plugin install bb-spec-core@0xbb2b',
  '/plugin install bb-spec-workflow@0xbb2b',
];
const TITLE = { zh: 'bb-spec — PRD 驱动的 Claude Code 流水线', en: 'bb-spec — A PRD-driven Claude Code pipeline' };
const URL_GH = 'https://github.com/0xBB2B/bb-spec';
const URL_LICENSE = 'https://github.com/0xBB2B/bb-spec/blob/main/LICENSE';
const URL_REL = 'https://github.com/0xBB2B/bb-spec/releases';
const URL_README = { zh: 'https://github.com/0xBB2B/bb-spec#readme', en: 'https://github.com/0xBB2B/bb-spec/blob/main/README.en.md' };

const leaves = (o, out = []) => {
  if (typeof o === 'string') out.push(o);
  else if (o && typeof o === 'object') Object.values(o).forEach((v) => leaves(v, out));
  return out;
};
const shape = (o) => {
  if (typeof o === 'string') return 'str';
  if (Array.isArray(o)) return o.map(shape);
  if (o && typeof o === 'object') return Object.fromEntries(Object.keys(o).sort().map((k) => [k, shape(o[k])]));
  return typeof o;
};
const resolvePath = (o, p) => p.split('.').reduce((a, k) => (a == null ? undefined : a[k]), o);

const bodyEl = (() => { const d = makeDocument(HTML); return d.body || d; })();
const bodyText = norm(bodyEl.textContent);
const staticDoc = makeDocument(HTML);

const click = (b, el) => {
  const ev = { type: 'click', target: el, preventDefault() {}, stopPropagation() {} };
  for (let e = el; e; e = e.parentElement) { ev.currentTarget = e; (e._l.click || []).slice().forEach((f) => f.call(e, ev)); }
  ev.currentTarget = b.doc;
  (b.doc._l.click || []).slice().forEach((f) => f.call(b.doc, ev));
};

const main = async () => {
  group('静态中文页面', () => {
    ok(/<html[^>]*\blang\s*=\s*["']zh-CN["']/i.test(HTML), '<html> 缺少 lang="zh-CN"');
    eq(norm(staticDoc.title), norm(TITLE.zh), '静态 title');
    for (const p of PIECES) {
      if (p.zh === TITLE.zh || p.zh === '已复制') continue;
      ok(bodyText.includes(norm(p.zh)), `index.html 缺少中文文案「${p.zh}」`);
    }
    ok(!staticDoc.all.some((e) => e.hasAttribute('hidden') && e.textContent.trim() === '已复制'), 'index.html 不应有 hidden 且文字为「已复制」的元素');
    for (const c of COMMANDS_EXPECTED) ok(bodyText.includes(norm(c)), `index.html 缺少命令「${c}」`);
    for (const f of ['MIT License', 'GitHub', 'Releases', 'README']) ok(bodyText.includes(norm(f)), `页脚缺少「${f}」`);
    for (const id of ['problem', 'pipeline', 'install']) ok(staticDoc.getElementById(id) !== null, `缺少锚点 id="${id}"`);
    const idx = (id) => staticDoc.all.indexOf(staticDoc.getElementById(id));
    ok(idx('problem') >= 0 && idx('problem') < idx('pipeline') && idx('pipeline') < idx('install'), '三个区块顺序应为 problem → pipeline → install');
    const pos = (t) => bodyText.indexOf(norm(t));
    const order = ['Claude Code 插件', '每次交接物都是磁盘上的文档', '你读完 PRD 批准需求', '在 Claude Code 里执行这三行', 'MIT License'].map(pos);
    ok(order.every((v, i) => v >= 0 && (i === 0 || v > order[i - 1])), `页面从上到下顺序应为 标题区、问题、流水线、安装、页脚，实际位置 ${JSON.stringify(order)}`);
    const topLinks = staticDoc.all.filter((e) => e.tag === 'a' && e.getAttribute('href') === '#top');
    const topEl = staticDoc.getElementById('top');
    ok(topLinks.length >= 1, '缺少 href="#top" 的链接（顶栏 bb-spec）');
    ok(topEl !== null && topLinks.length >= 1 && (topEl.tag === 'body' || topEl.contains(topLinks[0])), 'id="top" 应在 <body> 上，或在包含顶栏的祖先元素上');
    const hrefs = staticDoc.all.filter((e) => e.tag === 'a').map((e) => e.getAttribute('href'));
    ok(hrefs.filter((h) => h === URL_GH).length >= 3, '指向 GitHub 的链接应至少 3 处（顶栏、按钮、页脚）');
    ok(hrefs.includes(URL_REL), '缺少 Releases 链接');
    const mit = staticDoc.all.filter((e) => e.tag === 'a' && e.textContent.trim() === 'MIT License');
    ok(mit.length >= 1, '缺少文字为 MIT License 的链接');
    ok(mit.every((e) => e.getAttribute('href') === URL_LICENSE), `MIT License 链接 href 应为 ${URL_LICENSE}，实际 ${JSON.stringify(mit.map((e) => e.getAttribute('href')))}`);
    ok(hrefs.filter((h) => h === URL_README.zh).length >= 2, '静态中文 README 链接应至少 2 处（导语、页脚）');
    ok(/<link[^>]*rel\s*=\s*["']stylesheet["'][^>]*href\s*=\s*["']style\.css["']|<link[^>]*href\s*=\s*["']style\.css["'][^>]*rel\s*=\s*["']stylesheet["']/i.test(HTML), '缺少 <link rel="stylesheet" href="style.css">');
    ok(/<script[^>]*\bsrc\s*=\s*["']app\.js["'][^>]*\bdefer\b|<script[^>]*\bdefer\b[^>]*\bsrc\s*=\s*["']app\.js["']/i.test(HTML), '缺少 <script src="app.js" defer>');
  });

  group('只加载站内文件', () => {
    for (const [name, text] of [['index.html', HTML], ['style.css', CSS], ['app.js', APP]]) {
      ok(!/\bsrc\s*=\s*["']?\s*(https?:)?\/\//i.test(text), `${name} 有指向站外的 src=`);
      ok(!/<link[^>]*\bhref\s*=\s*["']?\s*(https?:)?\/\//i.test(text), `${name} 有指向站外的 <link href>`);
      ok(!/@import/i.test(text), `${name} 含 @import`);
      ok(!/url\(\s*["']?\s*(https?:)?\/\//i.test(text), `${name} 有指向站外的 url(`);
    }
  });

  group('样式关键值', () => {
    for (const v of ['#0D1117', '#D97757', '#58A6FF', '#E1937A', '#D25D37']) ok(CSS.toLowerCase().includes(v.toLowerCase()), `style.css 缺少色值 ${v}`);
    ok(/@media\s*\(\s*max-width\s*:\s*640px\s*\)/i.test(CSS), 'style.css 缺少 @media (max-width: 640px)');
    const mq = /@media\s*\(\s*max-width\s*:\s*960px\s*\)\s*\{/i.exec(CSS);
    ok(mq !== null, 'style.css 缺少 @media (max-width: 960px)');
    if (mq) {
      let depth = 1, i = mq.index + mq[0].length;
      while (i < CSS.length && depth > 0) { if (CSS[i] === '{') depth++; else if (CSS[i] === '}') depth--; i++; }
      const block = CSS.slice(mq.index + mq[0].length, i - 1);
      ok(staticDoc.querySelectorAll('.legend').length >= 1 && staticDoc.querySelectorAll('.pipe').length === 1, 'index.html 里应有 .legend 图例和唯一的 .pipe 流水线容器');
      ok(/\.legend\s*\{[^}]*display\s*:\s*none/.test(block), '960px 媒体查询内应隐藏 .legend（display: none）');
      ok(/\.pipe\s*\{[^}]*(grid-template-columns\s*:\s*(minmax\(\s*0\s*,\s*1fr\s*\)|1fr)\s*[;}]|flex-direction\s*:\s*column)/.test(block), '960px 媒体查询内 .pipe 应改为单列');
    }
    ok(/prefers-reduced-motion/.test(CSS), 'style.css 缺少 prefers-reduced-motion');
    ok(/:focus-visible/.test(CSS), 'style.css 缺少 :focus-visible');
  });

  group('BBHomepage 公开入口与文案', () => {
    const b = boot();
    ok(!b.loadError, `加载 app.js 抛错：${b.loadError && b.loadError.message}`);
    const api = b.api;
    ok(api && typeof api === 'object', 'window.BBHomepage 未暴露');
    if (!api) return;
    for (const k of ['pickLang', 'applyLang', 'copyCommands']) ok(typeof api[k] === 'function', `BBHomepage.${k} 应为函数`);
    ok(api.COPY && api.COPY.zh && api.COPY.en, 'BBHomepage.COPY 应含 zh 与 en');
    eq(api.COMMANDS, COMMANDS_EXPECTED, 'COMMANDS');
    if (!(api.COPY && api.COPY.zh && api.COPY.en)) return;
    eq(shape(api.COPY.zh), shape(api.COPY.en), 'COPY.zh 与 COPY.en 键结构');
    for (const lang of ['zh', 'en']) {
      const set = new Set(leaves(api.COPY[lang]).map(norm));
      for (const p of PIECES) {
        ok(set.has(norm(p[lang])), `COPY.${lang} 缺少文案「${p[lang]}」`);
      }
    }
  });

  group('流水线确认文案', () => {
    ok(staticDoc.querySelectorAll('.node .badge').length === 0, 'index.html 的 .node 内不应有 .badge 元素');
    ok(!/\.node\s+\.badge/.test(CSS), 'style.css 不应含 .node .badge');
    ok(/\.badge\s*\{/.test(CSS), 'style.css 仍应含 .badge {');
    const b = boot();
    if (!b.api || !b.api.COPY) { ok(false, 'BBHomepage.COPY 不可用'); return; }
    for (const lang of ['zh', 'en']) ok(!('once' in b.api.COPY[lang]), `COPY.${lang} 不应有 once 键`);
    const banned = { zh: ['唯一一次批准', '批准一次', '只有要引入新技术时才停下'], en: ['the only approval', 'approve once', 'Stops only when new tech'] };
    for (const lang of ['zh', 'en']) {
      b.api.applyLang(lang);
      const text = norm((b.doc.body || b.doc).textContent);
      for (const w of banned[lang]) ok(!text.includes(norm(w)), `${lang} 页面文字不应含「${w}」`);
      for (const p of PIECES.filter((q) => /批准需求|函数级实施计划/.test(q.zh))) ok(text.includes(norm(p[lang])), `${lang} 页面文字缺少「${p[lang]}」`);
    }
    const allText = norm(leaves(b.api.COPY).join('') + bodyText);
    for (const w of [...banned.zh, ...banned.en]) ok(!allText.includes(norm(w)), `文案中不应出现「${w}」`);
  });

  group('pickLang', () => {
    const { api } = boot();
    if (!api || typeof api.pickLang !== 'function') { ok(false, 'pickLang 不可用'); return; }
    const cases = [
      [null, ['zh-CN'], 'zh'], [null, ['zh-TW'], 'zh'], [null, ['ZH'], 'zh'],
      [null, ['en-US'], 'en'], [null, ['ja-JP'], 'en'], [null, [], 'en'],
      ['en', ['zh-CN'], 'en'], ['zh', ['en-US'], 'zh'], ['fr', ['en-US'], 'en'],
    ];
    for (const [saved, langs, want] of cases) eq(api.pickLang(saved, langs), want, `pickLang(${JSON.stringify(saved)}, ${JSON.stringify(langs)})`);
  });

  group('打开时语言', () => {
    const cases = [
      [{ languages: ['en-US'] }, 'en', 'en'],
      [{ languages: ['zh-CN'] }, 'zh', 'zh-CN'],
      [{ languages: ['zh-TW'] }, 'zh', 'zh-CN'],
      [{ languages: ['ja-JP'] }, 'en', 'en'],
      [{ languages: ['zh-CN'], saved: 'en' }, 'en', 'en'],
      [{ languages: ['en-US'], saved: 'zh' }, 'zh', 'zh-CN'],
    ];
    for (const [opts, lang, htmlLang] of cases) {
      const b = boot(opts);
      const tag = JSON.stringify(opts);
      ok(!b.loadError, `${tag} 加载抛错：${b.loadError && b.loadError.message}`);
      eq(b.doc.documentElement.getAttribute('lang'), htmlLang, `${tag} <html lang>`);
      eq(b.doc.title, TITLE[lang], `${tag} document.title`);
    }
  });

  group('applyLang', () => {
    const b = boot({ languages: ['zh-CN'] });
    const api = b.api;
    if (!api || typeof api.applyLang !== 'function') { ok(false, 'applyLang 不可用'); return; }
    const doc = b.doc;
    const i18nEls = doc.querySelectorAll('[data-i18n]');
    ok(i18nEls.length >= 10, `带 data-i18n 的元素应不少于 10 个，实际 ${i18nEls.length}`);
    const readmeLinks = doc.all.filter((e) => e.tag === 'a' && e.getAttribute('href') === URL_README.zh);
    ok(readmeLinks.length >= 2, `切换前中文 README 链接应至少 2 处，实际 ${readmeLinks.length}`);

    for (const lang of ['en', 'zh']) {
      api.applyLang(lang);
      let resolved = 0;
      for (const el of i18nEls) {
        const key = el.getAttribute('data-i18n');
        const want = resolvePath(api.COPY[lang], key);
        if (typeof want === 'string') {
          resolved++;
          eq(el.textContent, want, `applyLang('${lang}') 后 data-i18n="${key}" 的文字`);
        }
      }
      ok(resolved >= 10, `applyLang('${lang}')：data-i18n 键能在 COPY.${lang} 里解析到文案的元素应不少于 10 个，实际 ${resolved}`);
      eq(doc.title, TITLE[lang], `applyLang('${lang}') 后 document.title`);
      eq(doc.documentElement.getAttribute('lang'), lang === 'zh' ? 'zh-CN' : 'en', `applyLang('${lang}') 后 <html lang>`);
      for (const a of readmeLinks) eq(a.getAttribute('href'), URL_README[lang], `applyLang('${lang}') 后 README 链接 href`);
    }
  });

  group('存储读写抛异常', () => {
    for (const storage of ['methods-throw', 'getter-throw']) {
      const b = boot({ languages: ['en-US'], storage });
      ok(!b.loadError, `${storage}：加载 app.js 抛错：${b.loadError && b.loadError.message}`);
      const api = b.api;
      if (!api) { ok(false, `${storage}：BBHomepage 未暴露`); continue; }
      let thrown = null;
      try { api.applyLang('zh'); } catch (e) { thrown = e; }
      ok(!thrown, `${storage}：applyLang 抛错：${thrown && thrown.message}`);
      eq(b.doc.documentElement.getAttribute('lang'), 'zh-CN', `${storage}：<html lang> 仍应切换`);
      eq(b.doc.title, TITLE.zh, `${storage}：document.title 仍应切换`);
    }
  });

  // 约定：copyCommands(button) 的参数是被点击的复制按钮元素，由它改写按钮文字
  await groupAsync('copyCommands', async () => {
    const lastLabels = { zh: ['复制', '已复制'], en: ['Copy', 'Copied'] };
    for (const lang of ['zh', 'en']) {
      const [idle, done] = lastLabels[lang];
      const b = boot({ languages: [lang === 'zh' ? 'zh-CN' : 'en-US'] });
      const api = b.api;
      if (!api || typeof api.copyCommands !== 'function') { ok(false, 'copyCommands 不可用'); return; }
      api.applyLang(lang);
      const btn = new El('button');
      btn.textContent = idle;
      unhandled.length = 0;
      let thrown = null;
      try { api.copyCommands(btn); } catch (e) { thrown = e; }
      await flush();
      ok(!thrown, `${lang}：copyCommands 抛错：${thrown && thrown.message}`);
      eq(b.writes, [COMMANDS_EXPECTED.join('\n')], `${lang}：writeText 收到的内容`);
      ok(!b.writes.some((w) => w.includes('❯')), `${lang}：剪贴板内容不应带 ❯`);
      eq(btn.textContent, done, `${lang}：成功后按钮文字`);
      b.advance(1599);
      eq(btn.textContent, done, `${lang}：1599ms 时按钮文字仍应为「${done}」`);
      b.advance(1);
      eq(btn.textContent, idle, `${lang}：1600ms 后按钮文字应复原`);
      eq(unhandled.length, 0, `${lang}：成功路径不应有未捕获异常`);
    }

    for (const clipboard of ['reject', 'missing']) {
      const b = boot({ languages: ['zh-CN'], clipboard });
      const api = b.api;
      if (!api) { ok(false, `${clipboard}：BBHomepage 未暴露`); continue; }
      const btn = new El('button');
      btn.textContent = '复制';
      unhandled.length = 0;
      let thrown = null;
      try { api.copyCommands(btn); } catch (e) { thrown = e; }
      await flush();
      ok(!thrown, `${clipboard}：copyCommands 同步抛错：${thrown && thrown.message}`);
      eq(btn.textContent, '复制', `${clipboard}：写剪贴板失败时按钮文字应保持`);
      b.advance(2000);
      eq(btn.textContent, '复制', `${clipboard}：失败后过 2000ms 按钮文字仍应为复制`);
      eq(unhandled.length, 0, `${clipboard}：不应有未捕获异常`);
    }
  });

  // 事件接线契约：语言按钮是带 data-lang="zh"/"en" 的元素，当前语言的按钮 aria-pressed="true"、另一个 "false"；
  // 复制按钮是带 data-copy 的元素（两个终端窗口各一个）；bb-spec-lang 只在点击语言按钮时写入
  await groupAsync('事件接线', async () => {
    const b0 = boot({ languages: ['en-US'] });
    ok(!b0.loadError, `加载 app.js 抛错：${b0.loadError && b0.loadError.message}`);
    ok(!b0.store.has('bb-spec-lang'), '仅加载页面不应写入 bb-spec-lang');

    const b = boot({ languages: ['en-US'] });
    const zhBtns = b.doc.querySelectorAll('[data-lang="zh"]');
    const enBtns = b.doc.querySelectorAll('[data-lang="en"]');
    ok(zhBtns.length >= 1 && enBtns.length >= 1, `缺少 [data-lang="zh"] 或 [data-lang="en"] 按钮：${zhBtns.length}/${enBtns.length}`);
    if (zhBtns.length && enBtns.length) {
      const pressed = (els) => els.map((e) => e.getAttribute('aria-pressed'));
      eq(pressed(enBtns).concat(pressed(zhBtns)), enBtns.map(() => 'true').concat(zhBtns.map(() => 'false')), '英文打开时 aria-pressed');
      click(b, zhBtns[0]);
      eq(b.doc.documentElement.getAttribute('lang'), 'zh-CN', '点中文后 <html lang>');
      eq(b.doc.title, TITLE.zh, '点中文后 document.title');
      eq(b.store.get('bb-spec-lang'), 'zh', '点中文后 bb-spec-lang');
      eq(pressed(zhBtns).concat(pressed(enBtns)), zhBtns.map(() => 'true').concat(enBtns.map(() => 'false')), '点中文后 aria-pressed');
      click(b, enBtns[0]);
      eq(b.doc.documentElement.getAttribute('lang'), 'en', '点 English 后 <html lang>');
      eq(b.doc.title, TITLE.en, '点 English 后 document.title');
      eq(b.store.get('bb-spec-lang'), 'en', '点 English 后 bb-spec-lang');
      eq(pressed(enBtns).concat(pressed(zhBtns)), enBtns.map(() => 'true').concat(zhBtns.map(() => 'false')), '点 English 后 aria-pressed');
    }

    for (const [lang, langs, idle, done] of [['zh', ['zh-CN'], '复制', '已复制'], ['en', ['en-US'], 'Copy', 'Copied']]) {
      const c = boot({ languages: langs });
      const btns = c.doc.querySelectorAll('[data-copy]');
      eq(btns.length, 2, `${lang}：index.html 里 [data-copy] 的个数`);
      if (!btns.length) continue;
      unhandled.length = 0;
      let thrown = null;
      try { click(c, btns[0]); } catch (e) { thrown = e; }
      await flush();
      ok(!thrown, `${lang}：点复制抛错：${thrown && thrown.message}`);
      eq(c.writes, [COMMANDS_EXPECTED.join('\n')], `${lang}：点复制后 writeText 收到的内容`);
      eq(btns[0].textContent, done, `${lang}：点复制后按钮文字`);
      c.advance(1600);
      eq(btns[0].textContent, idle, `${lang}：1600ms 后按钮文字`);
      eq(unhandled.length, 0, `${lang}：点复制不应有未捕获异常`);
    }

    {
      const c = boot({ languages: ['zh-CN'] });
      const btn = c.doc.querySelectorAll('[data-copy]')[0];
      if (!btn) ok(false, '连点复制：缺少 [data-copy]');
      else {
        click(c, btn); await flush();
        c.advance(1000);
        click(c, btn); await flush();
        c.advance(1000);
        eq(btn.textContent, '已复制', '连点复制：第二次点击后 1000ms（距第一次 2000ms）仍应为已复制');
        c.advance(600);
        eq(btn.textContent, '复制', '连点复制：距第二次点击 1600ms 后应复原');
      }
    }

    {
      const c = boot({ languages: ['zh-CN'] });
      const [b0, b1] = c.doc.querySelectorAll('[data-copy]');
      if (!b0 || !b1) ok(false, '两个复制按钮：缺少 [data-copy]');
      else {
        click(c, b0); await flush();
        c.advance(1000);
        click(c, b1); await flush();
        c.advance(600);
        eq([b0.textContent, b1.textContent], ['复制', '已复制'], '两个复制按钮：距第一次 1600ms 时各自文字');
        c.advance(1000);
        eq([b0.textContent, b1.textContent], ['复制', '复制'], '两个复制按钮：距第二次 1600ms 时各自文字');
      }
    }

    for (const [from, to, fromLangs, doneNew, idleNew] of [['zh', 'en', ['zh-CN'], 'Copied', 'Copy'], ['en', 'zh', ['en-US'], '已复制', '复制']]) {
      const tag = `${from}→${to}`;
      const sw = boot({ languages: fromLangs });
      const [b0, b1] = sw.doc.querySelectorAll('[data-copy]');
      const toBtn = sw.doc.querySelectorAll(`[data-lang="${to}"]`)[0];
      if (!b0 || !b1 || !toBtn) { ok(false, `${tag}：缺少 [data-copy] 或 [data-lang="${to}"]`); continue; }
      click(sw, b0); await flush();
      sw.advance(500);
      click(sw, toBtn); await flush();
      eq(b0.textContent, doneNew, `${tag}：显示已复制时切语言，该按钮文字`);
      eq(b1.textContent, idleNew, `${tag}：显示已复制时切语言，另一个复制按钮文字`);
      sw.advance(1099);
      eq(b0.textContent, doneNew, `${tag}：距点击 1599ms 仍应为「${doneNew}」`);
      sw.advance(1);
      eq(b0.textContent, idleNew, `${tag}：距点击满 1600ms 应为「${idleNew}」`);
      eq(b1.textContent, idleNew, `${tag}：满 1600ms 后另一个复制按钮文字`);

      const fresh = boot({ languages: fromLangs });
      const fb = fresh.doc.querySelectorAll('[data-copy]');
      click(fresh, fresh.doc.querySelectorAll(`[data-lang="${to}"]`)[0]);
      eq(fb.map((e) => e.textContent), [idleNew, idleNew], `${tag}：没点过复制时切语言，两个复制按钮文字`);
    }

    for (const storage of ['methods-throw', 'getter-throw']) {
      const d = boot({ languages: ['en-US'], storage });
      const zh = d.doc.querySelectorAll('[data-lang="zh"]');
      if (!zh.length) { ok(false, `${storage}：缺少 [data-lang="zh"]`); continue; }
      let thrown = null;
      try { click(d, zh[0]); } catch (e) { thrown = e; }
      ok(!thrown, `${storage}：点语言按钮抛错：${thrown && thrown.message}`);
      eq(d.doc.documentElement.getAttribute('lang'), 'zh-CN', `${storage}：点中文后 <html lang>`);
    }
  });

  console.log(`node 部分 通过: ${pass}, 失败: ${fail}`);
  process.exit(fail > 0 ? 1 : 0);
};
main();
JSEOF

NODE_STATUS=0
ROOT="$ROOT" node "$JS" || NODE_STATUS=$?
if [[ "$NODE_STATUS" != "0" ]]; then FAIL=$((FAIL + 1)); fi

echo "shell 部分 通过: $PASS, 失败: $FAIL"
[[ "$FAIL" == "0" ]]
