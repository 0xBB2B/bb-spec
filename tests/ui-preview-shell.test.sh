#!/usr/bin/env bash
# ui-preview-shell.html 校验：固定文案、无外部引用、行为（假 DOM + vm）、框内与外壳隔离
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHELL_HTML="$ROOT/plugins/bb-spec-workflow/templates/ui-preview-shell.html"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

if [[ ! -f "$SHELL_HTML" ]]; then
  echo "ERROR: 界面原型外壳不存在：$SHELL_HTML"
  echo "请先新增 plugins/bb-spec-workflow/templates/ui-preview-shell.html 再跑本测试"
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 本机没有 node，行为测试无法运行（需要 node 自带的 vm 模块）"
  exit 1
fi

echo "[固定文案]"
for phrase in \
  "设计说明 · 不属于页面" \
  "这一栏上线后不存在" \
  "▼ 被设计的页面：只有这个框里的内容要实现"; do
  if grep -qF -- "$phrase" "$SHELL_HTML"; then pass; else fail "缺少固定文案「${phrase}」"; fi
done
for phrase in "这一块上线后不存在" "这个画面的说明" "只在原型里成立" "还没确认的问题"; do
  if grep -qF -- "$phrase" "$SHELL_HTML"; then fail "不应再有固定文案「${phrase}」"; else pass; fi
done
if awk '/<aside/,/<\/aside>/' "$SHELL_HTML" | grep -qE '<h2[ >]'; then fail "左栏里不应有小标题 <h2>：当前方案下面直接是页面和状态切换"; else pass; fi

echo "[单文件、不联网、不引用外部资源]"
for pattern in 'http://' 'https://' '<link' '<script[^>]*[[:space:]]src[[:space:]]*=' '@import'; do
  if grep -qiE -- "$pattern" "$SHELL_HTML"; then fail "出现外部资源引用：$pattern"; else pass; fi
done

echo "[结构：iframe、填写区标记、单套配色]"
if grep -qE '<iframe[^>]*id="stage"|<iframe[^>]*id='"'"'stage'"'" "$SHELL_HTML"; then pass; else fail "正式页面没有放在 id=stage 的 iframe 里"; fi
if grep -qE 'prefers-color-scheme' "$SHELL_HTML"; then fail "外壳不应有 prefers-color-scheme"; else pass; fi
if grep -qF '[data-theme="dark"]' "$SHELL_HTML"; then fail "外壳不应有 [data-theme=\"dark\"] 样式块"; else pass; fi
if [[ "$(grep -cF '/* PROTOTYPE-START' "$SHELL_HTML")" == "1" ]]; then pass; else fail "填写区起点标记应恰好出现一次"; fi
if [[ "$(grep -cF '/* PROTOTYPE-END */' "$SHELL_HTML")" == "1" ]]; then pass; else fail "填写区终点标记应恰好出现一次"; fi

echo "[外壳里的元素都写在 HTML 里]"
for id in schemeBar schemeCurrent schemePick pagePick statePick stateLabel frameTitle stage sideTitle sideVersion; do
  if grep -qE "<[a-z0-9]+[^>]*[[:space:]]id=\"${id}\"" "$SHELL_HTML"; then pass; else fail "HTML 里没有 id=\"${id}\" 的元素"; fi
done
for id in schemeBox schemeHint frameScheme dock noteList fakeList openList themeLight themeDark; do
  if grep -qF "id=\"${id}\"" "$SHELL_HTML"; then fail "HTML 里不应有 id=\"${id}\""; else pass; fi
done

TMPDIR_T="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_T"' EXIT
JS="$TMPDIR_T/behavior.js"

cat > "$JS" <<'JSEOF'
const fs = require('fs');
const vm = require('vm');

const HTML = fs.readFileSync(process.env.SHELL_HTML, 'utf8');
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

class El {
  constructor(tag) {
    this.tagName = String(tag).toUpperCase();
    this.children = [];
    this.parent = null;
    this.attributes = {};
    this.listeners = {};
    this.hidden = false;
    this.srcdoc = '';
    this._text = '';
  }
  get textContent() { return this.children.length ? this.children.map((c) => c.textContent).join('') : this._text; }
  set textContent(v) { this.children = []; this._text = String(v); }
  get dataset() {
    const out = {};
    Object.keys(this.attributes).filter((k) => k.startsWith('data-')).forEach((k) => {
      out[k.slice(5).replace(/-(\w)/g, (_, c) => c.toUpperCase())] = this.attributes[k];
    });
    return out;
  }
  setAttribute(k, v) { this.attributes[k] = String(v); }
  getAttribute(k) { return k in this.attributes ? this.attributes[k] : null; }
  replaceChildren(...ns) {
    this.children = ns;
    ns.forEach((n) => { n.parent = this; });
    this._text = '';
  }
  addEventListener(t, f) { (this.listeners[t] = this.listeners[t] || []).push(f); }
  click() {
    const ev = { type: 'click', target: this, preventDefault() {}, stopPropagation() {} };
    (this.listeners.click || []).forEach((f) => f(ev));
  }
  closest(selector) {
    const parts = selector.split(',').map((s) => s.trim());
    for (let n = this; n; n = n.parent) {
      if (parts.some((p) => n.matches(p))) return n;
    }
    return null;
  }
  matches(sel) {
    const m = /^([a-z]*)(?:\[([\w-]+)\])?$/i.exec(sel);
    if (!m) throw new Error('假 DOM 不支持选择器 ' + sel);
    return (!m[1] || this.tagName === m[1].toUpperCase()) && (!m[2] || m[2] in this.attributes);
  }
}

class Doc extends El {
  constructor(html) {
    super('#document');
    this.title = '';
    this.byId = {};
    this.documentElement = new El('html');
    const markup = html.slice(0, Math.max(html.indexOf('<script'), 0));
    for (const m of markup.matchAll(/<(\w+)([^>]*)>/g)) {
      const id = /\bid="([^"]+)"/.exec(m[2]);
      if (!id) continue;
      const e = new El(m[1]);
      e.id = id[1];
      e.hidden = /(?:^|\s)hidden(?=[\s>]|$)/.test(m[2]);
      if (m[1] === 'iframe') e.contentWindow = { __stage: true };
      this.byId[id[1]] = e;
    }
  }
  createElement(tag) { return new El(tag); }
  getElementById(id) { return this.byId[id] || null; }
}

const runScripts = (ctx, scripts, onError) => {
  vm.createContext(ctx);
  scripts.forEach((code, i) => {
    try { new vm.Script(code, { filename: 'script-' + i + '.js' }).runInContext(ctx); } catch (err) { onError(err); }
  });
};
const extractScripts = (html) => {
  const out = [];
  const re = /<script(?![^>]*\bsrc\b)[^>]*>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) out.push(m[1]);
  return out;
};

const START = '/* PROTOTYPE-START';
const END = '/* PROTOTYPE-END */';
const withFill = (code) => {
  const s = HTML.indexOf(START);
  const e = HTML.indexOf(END);
  if (s < 0 || e < 0) throw new Error('填写区标记缺失');
  return HTML.slice(0, s) + code + HTML.slice(e + END.length);
};
const withData = (data, extra = '') => withFill('const PROTOTYPE = ' + JSON.stringify(data) + ';' + extra);

const makeMedia = (initial) => {
  const subs = [];
  const mql = {
    matches: initial,
    media: '(prefers-color-scheme: dark)',
    addEventListener: (type, fn) => { if (type === 'change') subs.push(fn); },
    listenerCount: () => subs.length,
    set: (next) => {
      mql.matches = next;
      subs.forEach((fn) => fn({ matches: next, media: mql.media }));
    },
  };
  return mql;
};

const loadHtml = (html, media) => {
  const doc = new Doc(html);
  const L = {};
  const errors = [];
  const ctx = { document: doc, console };
  ctx.window = ctx;
  if (media) ctx.matchMedia = () => media;
  ctx.addEventListener = (t, f) => { (L[t] = L[t] || []).push(f); };
  const fireError = (message) => (L.error || []).forEach((f) => f({ message }));
  const raise = (err) => { errors.push(err); fireError(err.message); };
  runScripts(ctx, extractScripts(html), raise);

  const $ = (id) => doc.getElementById(id);
  const buttons = (g) => $(g).children.filter((c) => c.tagName === 'BUTTON');
  const api = {
    $,
    run: (code) => vm.runInContext(code, ctx),
    buttons,
    errors,
    fireError,
    broken: () => ctx.prototypeBroken,
    txt: (id) => $(id).textContent,
    theme: () => doc.documentElement.getAttribute('data-theme'),
    pick: (g, i) => {
      const b = buttons(g)[i];
      if (!b) throw new Error(`${g} 没有第 ${i} 个按钮（共 ${buttons(g).length} 个）`);
      try { b.click(); } catch (err) { raise(err); }
    },
    pressed: (g) => buttons(g).map((b) => b.getAttribute('aria-pressed') === 'true'),
    srcdoc: () => $('stage').srcdoc,
    post: (go, source) => {
      const ev = { source: source === undefined ? $('stage').contentWindow : source, data: { go } };
      try { (L.message || []).forEach((f) => f(ev)); } catch (err) { raise(err); }
    },
    snap: () => JSON.stringify({
      title: $('frameTitle').textContent,
      current: $('schemeCurrent').textContent,
      barHidden: $('schemeBar').hidden,
      currentHidden: $('schemeCurrent').hidden,
      srcdoc: $('stage').srcdoc,
      pressed: [api.pressed('schemePick'), api.pressed('pagePick'), api.pressed('statePick')],
    }),
    shellText: () => Object.values(doc.byId).map((e) => e.textContent).join('\n'),
  };
  return api;
};
const load = (data, media) => loadHtml(data ? withData(data) : HTML, media);

const frameOf = (srcdoc) => {
  const doc = new Doc('');
  const L = {};
  const posts = [];
  const errors = [];
  const parent = { postMessage: (m) => posts.push(m) };
  const ctx = { document: doc, console, parent, top: parent };
  ctx.window = ctx;
  ctx.addEventListener = (t, f) => { (L[t] = L[t] || []).push(f); };
  runScripts(ctx, extractScripts(srcdoc), (err) => errors.push(err));
  const fire = (type, target) => {
    const ev = { type, target, prevented: 0, preventDefault() { ev.prevented++; }, stopPropagation() {} };
    [].concat(doc.listeners[type] || [], L[type] || []).forEach((f) => f(ev));
    return ev;
  };
  return { posts, errors, fire };
};
const elem = (tag, attrs) => {
  const e = new El(tag);
  Object.entries(attrs || {}).forEach(([k, v]) => e.setAttribute(k, v));
  return e;
};

const FORBIDDEN = ['设计说明', '被设计的页面', '只在原型里成立', '--shell-bg', '--accent',
  'var(--', '--shell-', '--grid', 'ui-monospace', '.tag', '.dock', '.pick'];

const SCH = [
  { id: 'a', label: '方案 A', desc: '表格' },
  { id: 'b', label: '方案 B', desc: '卡片' },
  { id: 'c', label: '方案 C', desc: '列表' },
];
const schemeLabels = (a) => a.buttons('schemePick').map((b) => b.textContent);
const mk = (n, over) => {
  const schemes = SCH.slice(0, n).map((scheme) => ({ ...scheme }));
  return Object.assign({
    title: '自定义标题',
    version: 3,
    css: '.CSS_MARK_XYZ{color:#123456}',
    schemes,
    pages: [
      {
        id: 'p1', name: '页一', states: [
          { id: 's1', name: '态一', html: Object.fromEntries(schemes.map((s) => [s.id, '<p>HTML_' + s.id + '</p>'])) },
          { id: 's2', name: '态二', html: '<p>SAME</p><a data-go="p2:t2">跳</a>' },
        ],
      },
      {
        id: 'p2', name: '页二', states: [
          { id: 't1', name: '甲', html: '<p>P2T1</p>' },
          { id: 't2', name: '乙', html: '<p>P2T2</p>' },
        ],
      },
      {
        id: 'p3', name: '终端页', stateLabel: '步骤', terminal: true, states: [
          { id: 'u1', name: '第一步', html: 'TERM_LINE_ONE' },
        ],
      },
    ],
  }, over || {});
};

group('默认数据：初始画面', () => {
  const a = load();
  eq(a.txt('sideTitle'), '订单导出（示例）', '左栏标题');
  eq(a.txt('sideVersion'), '第 1 版 · 这一栏上线后不存在', '版本文字');
  eq(a.txt('schemeCurrent'), '当前：方案 A：表格', '左栏当前方案');
  eq(schemeLabels(a), ['方案 A：表格', '方案 B：卡片'], '框上方方案按钮文字');
  eq(a.txt('frameTitle'), '订单列表 · 正常', '框上方左侧标题');
  eq(a.txt('stateLabel'), '状态', '普通页面的第二组标题');
  ok(a.$('schemeBar').hidden === false, '2 个方案时框上方方案区显示');
  ok(a.$('schemeCurrent').hidden === false, '2 个方案时左栏当前方案显示');
  eq([a.buttons('schemePick').length, a.buttons('pagePick').length, a.buttons('statePick').length], [2, 3, 4], '按钮数量');
  eq([a.pressed('schemePick'), a.pressed('pagePick'), a.pressed('statePick')],
    [[true, false], [true, false, false], [true, false, false, false]], '选中态 aria-pressed');
  ok(a.srcdoc().length > 0, '正式页面写入了 srcdoc');
});

group('默认数据：方案、页面、状态切换', () => {
  const a = load();
  const before = a.srcdoc();
  a.pick('schemePick', 1);
  eq(a.txt('schemeCurrent'), '当前：方案 B：卡片', '切方案后左栏当前方案');
  eq(a.txt('frameTitle'), '订单列表 · 正常', '切方案后页面和状态不变');
  ok(a.srcdoc() !== before, '各方案不同的画面切方案后 srcdoc 变化');

  a.pick('statePick', 1);
  a.pick('schemePick', 0);
  eq(a.txt('schemeCurrent'), '当前：方案 A：表格', '切回方案 A');

  a.pick('statePick', 3);
  eq(a.txt('frameTitle'), '订单列表 · 出错', '切状态');
  a.pick('pagePick', 1);
  eq(a.txt('frameTitle'), '订单详情 · 正常', '切页面后状态回到第一项');
  eq(a.buttons('statePick').length, 3, '详情页状态数');
  a.pick('pagePick', 2);
  eq(a.txt('stateLabel'), '步骤', '终端页面第二组叫步骤');
  ok(a.txt('frameTitle').startsWith('终端界面（举例） · '), '终端页框上方标题');
  eq(a.buttons('statePick').length, 3, '终端页步骤数');
  a.pick('pagePick', 0);
  eq(a.txt('stateLabel'), '状态', '回到普通页面叫状态');
});

group('默认数据：框内跳转', () => {
  const a = load();
  const viaBtn = load();
  a.pick('schemePick', 1);
  a.pick('statePick', 3);
  a.post('detail:normal');
  viaBtn.pick('schemePick', 1);
  viaBtn.pick('pagePick', 1);
  eq(a.txt('frameTitle'), '订单详情 · 正常', '跳转后标题');
  eq(a.txt('schemeCurrent'), '当前：方案 B：卡片', '跳转后方案不变');
  eq(a.snap(), viaBtn.snap(), '跳转与点按钮结果一致（框、提示两处同步）');
  const b = load();
  b.pick('schemePick', 1);
  b.pick('statePick', 2);
  const snap = b.snap();
  ['nope:normal', 'detail:nope', 'garbage', ''].forEach((go) => {
    b.post(go);
    eq(b.snap(), snap, `go=${JSON.stringify(go)} 不变化`);
  });
  [123, {}, ['detail', 'normal'], null, true].forEach((go) => {
    b.post(go);
    eq(b.snap(), snap, `非字符串 go=${JSON.stringify(go)} 不变化`);
  });
  b.post('detail:normal', {});
  eq(b.snap(), snap, '来源不是 stage.contentWindow 时不变化');
  b.post('detail:normal', undefined);
  eq(b.txt('frameTitle'), '订单详情 · 正常', '来源为 stage.contentWindow 时生效');
});

group('自定义数据：初始画面', () => {
  const a = load(mk(2));
  eq(a.txt('sideTitle'), '自定义标题', '标题');
  eq(a.txt('sideVersion'), '第 3 版 · 这一栏上线后不存在', '版本');
  eq(a.txt('schemeCurrent'), '当前：方案 A：表格', '左栏当前方案');
  eq(schemeLabels(a), ['方案 A：表格', '方案 B：卡片'], '方案按钮文字');
  eq(a.txt('frameTitle'), '页一 · 态一', '框上方标题');
  ok(a.srcdoc().includes('HTML_a') && !a.srcdoc().includes('HTML_b'), '方案 A 的内容');
  ok(a.srcdoc().includes('CSS_MARK_XYZ'), '普通页面带 PROTOTYPE.css');
});

group('自定义数据：切换保持与重置', () => {
  const a = load(mk(2));
  a.pick('schemePick', 1);
  ok(a.srcdoc().includes('HTML_b') && !a.srcdoc().includes('HTML_a'), '方案 B 的内容');
  a.pick('statePick', 1);
  ok(a.srcdoc().includes('SAME'), '相同画面内容');
  a.pick('schemePick', 0);
  eq(a.txt('frameTitle'), '页一 · 态二', '切方案页面和状态不变');
  eq(a.pressed('statePick'), [false, true], '状态选中态保持');
  a.pick('schemePick', 1);
  a.pick('pagePick', 1);
  eq(a.txt('frameTitle'), '页二 · 甲', '切页面回到第一项');
  eq(a.txt('schemeCurrent'), '当前：方案 B：卡片', '切页面方案不变');
  eq(a.pressed('pagePick'), [false, true, false], '页面选中态');
  a.pick('pagePick', 0);
  eq(a.txt('frameTitle'), '页一 · 态一', '回到页一');
});

group('自定义数据：终端页面', () => {
  const a = load(mk(2));
  a.pick('pagePick', 2);
  const s = a.srcdoc();
  eq(a.txt('stateLabel'), '步骤', '步骤标签');
  ok(s.includes('<pre>'), '终端 srcdoc 含 <pre>');
  ok(s.includes('80ch'), '终端 srcdoc 含 80ch');
  ok(s.includes('box-sizing: border-box'), '终端 srcdoc 含 box-sizing: border-box');
  ok(s.includes('monospace'), '终端 srcdoc 用等宽字体');
  ok(/\.r\s*\{\s*color:/.test(s), '终端 srcdoc 有红色');
  ok(s.includes('TERM_LINE_ONE'), '终端内容');
  ok(!s.includes('CSS_MARK_XYZ'), '终端 srcdoc 不含 PROTOTYPE.css');
  ok(s.includes('padding: 8px'), '终端 srcdoc 有 padding: 8px');
  ok(s.includes('white-space: pre-wrap'), '终端 srcdoc 有 white-space: pre-wrap');
  ok(s.includes('background: #0b1730'), '终端 srcdoc 底色 background: #0b1730');
  [['g', '#7ee7c1'], ['y', '#ffd479'], ['b', '#7fd4ff'], ['r', '#ff8f8f']].forEach(([cls, color]) => {
    ok(new RegExp('\\.' + cls + '\\s*\\{\\s*color:\\s*' + color + '\\s*;?\\s*\\}').test(s), `终端 srcdoc 里 .${cls} 的文字色是 ${color}`);
  });
  ok(/pre\s*\{[^}]*(?:^|[;\s])color:\s*#d7e6ff/.test(s), '终端 srcdoc 里 pre 的文字色是 #d7e6ff');
  ok(!s.includes('#2563eb') && !s.includes('.card') && !s.includes('.alert'), '终端 srcdoc 不含默认页面样式');
  ok(s.includes('overflow-wrap: anywhere'), '终端 srcdoc 有 overflow-wrap: anywhere');
  eq(a.txt('frameTitle'), '终端页 · 第一步', '终端框上方标题');
  a.pick('pagePick', 0);
  eq(a.txt('stateLabel'), '状态', '普通页面状态标签');
  ok(a.srcdoc().includes('CSS_MARK_XYZ'), '回普通页面带 css');
});

group('自定义数据：跳转', () => {
  const a = load(mk(2));
  a.pick('schemePick', 1);
  a.post('p2:t2');
  eq(a.txt('frameTitle'), '页二 · 乙', '跳转标题');
  eq(a.txt('schemeCurrent'), '当前：方案 B：卡片', '跳转方案不变');
  eq(a.pressed('pagePick'), [false, true, false], '跳转后页面选中');
  eq(a.pressed('statePick'), [false, true], '跳转后状态选中');
  ok(a.srcdoc().includes('P2T2'), '跳转后内容');
});

group('方案切换在框上方右侧', () => {
  const a = load(mk(2));
  ok(a.$('schemeBar').hidden === false, '2 个方案时 schemeBar 显示');
  eq(schemeLabels(a), ['方案 A：表格', '方案 B：卡片'], '方案按钮文字是「短名：特点」');
  eq(a.buttons('schemePick').map((b) => b.getAttribute('aria-pressed')), ['true', 'false'], '当前方案按钮 aria-pressed 为 true');
  eq(a.txt('schemeCurrent'), '当前：方案 A：表格', '左栏当前方案');
  a.pick('pagePick', 1);
  a.pick('statePick', 1);
  const titleBefore = a.txt('frameTitle');
  a.pick('schemePick', 1);
  eq(a.txt('frameTitle'), titleBefore, '点方案 B 后 frameTitle 不变');
  eq(a.txt('schemeCurrent'), '当前：方案 B：卡片', '点方案 B 后左栏当前方案跟着变');
  eq([a.pressed('pagePick'), a.pressed('statePick')], [[false, true, false], [false, true]], '点方案 B 后页面和状态选中项不变');
  eq(a.pressed('schemePick'), [false, true], '点方案 B 后方案按钮选中项跟着变');

  const b = load(mk(2));
  b.pick('statePick', 0);
  const before = b.srcdoc();
  b.pick('schemePick', 1);
  ok(b.srcdoc().includes('HTML_b') && b.srcdoc() !== before, '方案 A 的状态点方案 B 后 srcdoc 换成方案 B 的内容');
  eq(b.txt('frameTitle'), '页一 · 态一', '框上方标题不变');
});

group('3 个方案', () => {
  const a = load(mk(3));
  eq(schemeLabels(a), ['方案 A：表格', '方案 B：卡片', '方案 C：列表'], '3 个方案按钮文字');
  eq(a.txt('schemeCurrent'), '当前：方案 A：表格', '初始当前方案');
  a.pick('schemePick', 2);
  eq(a.txt('schemeCurrent'), '当前：方案 C：列表', '切到方案 C 后当前方案');
  eq(a.pressed('schemePick'), [false, false, true], '方案 C 选中');
});

group('只有 1 个方案', () => {
  const a = load(mk(1));
  ok(a.$('schemeBar').hidden === true, 'schemeBar 隐藏');
  ok(a.$('schemeCurrent').hidden === true, 'schemeCurrent 隐藏');
  eq(a.errors.length, 0, '1 个方案不报错');
});

const sweep = (a, label) => {
  const schemeCount = a.buttons('schemePick').length;
  const pageCount = a.buttons('pagePick').length;
  for (let i = 0; i < schemeCount; i++) {
    a.pick('schemePick', i);
    for (let j = 0; j < pageCount; j++) {
      a.pick('pagePick', j);
      const stateCount = a.buttons('statePick').length;
      for (let k = 0; k < stateCount; k++) {
        a.pick('statePick', k);
        const s = a.srcdoc();
        ok(s.length > 0, `${label} 方案${i} 页面${j} 状态${k} srcdoc 非空`);
        FORBIDDEN.forEach((w) => ok(!s.includes(w), `${label} 方案${i} 页面${j} 状态${k} 的 srcdoc 含「${w}」`));
      }
    }
  }
};

group('框内与外壳隔离', () => {
  sweep(load(), '默认数据');
  sweep(load(mk(3)), '自定义3方案');
  sweep(load(mk(1)), '自定义1方案');
});

group('框内 data-go 桥接', () => {
  const a = load(mk(2));
  a.pick('statePick', 1);
  const s = a.srcdoc();
  ok(s.includes('data-go="p2:t2"'), 'srcdoc 保留 data-go 元素');
  const f = frameOf(s);
  eq(f.errors.length, 0, '框内脚本运行不报错');
  f.fire('click', elem('a', { 'data-go': 'p2:t2' }));
  ok(f.posts.some((m) => m && m.go === 'p2:t2'), '点击 data-go 元素向外壳 postMessage({ go })');
  const inside = elem('span');
  const holder = elem('div', { 'data-go': 'p2:t2' });
  holder.replaceChildren(inside);
  const g = frameOf(s);
  g.fire('click', inside);
  ok(g.posts.some((m) => m && m.go === 'p2:t2'), '点击 data-go 元素里面的子元素也发消息');
});

group('框内链接不离开页面，不监听 submit', () => {
  const s = load(mk(2)).srcdoc();

  const link = frameOf(s);
  const linkEv = link.fire('click', elem('a', { href: 'next.html' }));
  ok(linkEv.prevented > 0, '点 a[href] 调用了 preventDefault');
  eq(link.posts, [], '普通链接不向外壳发消息');

  const nested = frameOf(s);
  const a = elem('a', { href: 'next.html' });
  const span = elem('span');
  a.replaceChildren(span);
  ok(nested.fire('click', span).prevented > 0, '点链接里面的子元素也调用 preventDefault');

  const plain = frameOf(s);
  const plainEv = plain.fire('click', elem('div'));
  eq(plainEv.prevented, 0, '点普通元素没调 preventDefault');
  eq(plain.posts, [], '点普通元素不发消息');

  const goLink = frameOf(s);
  const goEv = goLink.fire('click', elem('a', { href: '#', 'data-go': 'p2:t2' }));
  ok(goEv.prevented > 0, '带 data-go 的链接调用了 preventDefault');
  ok(goLink.posts.some((m) => m && m.go === 'p2:t2'), '带 data-go 的链接照常发消息');

  ok(!/['"]submit['"]/.test(s), 'srcdoc 里没有 submit 监听');
});

const ERR_TEXT = '原型填写有误，这不是正式页面。';
const ERR_TITLE = '原型填写有误';
const TEXT_IDS = ['schemeCurrent', 'stateLabel'];
const untouched = (a, label) => TEXT_IDS.forEach((id) => eq(a.txt(id), '', `${label}：${id} 在抛错前不应被更新`));

group('错误提示：监听器在填写区之前注册', () => {
  const m = /window\.addEventListener\(\s*['"]error['"]/.exec(HTML);
  ok(m !== null, '文件里注册了 window 的 error 监听器');
  ok(m !== null && m.index < HTML.indexOf(START), 'error 监听器写在填写区之前');
});

group('错误提示：显示原因并转义', () => {
  const a = load();
  a.fireError('原因 <x-reason> & more');
  const s = a.srcdoc();
  ok(s.includes(ERR_TEXT), '框里显示固定提示');
  ok(s.includes('&lt;x-reason&gt;'), '原因里的 < > 被转义');
  ok(s.includes('&amp; more'), '原因里的 & 被转义');
  ok(!s.includes('<x-reason>'), '原因里的标签没有原样出现');
  eq(a.txt('frameTitle'), ERR_TITLE, '框上方右边显示原型填写有误');
});

group('错误提示：缺方案内容、省略 html', () => {
  const d = mk(2);
  d.pages[0].states[0].html = { b: '<p>only b</p>' };
  const a = load(d);
  eq(a.errors.length, 1, '缺当前方案内容时 render 抛错');
  const msg = a.errors.length ? a.errors[0].message : '';
  ok(msg.includes('页一') && msg.includes('态一') && msg.includes('缺少方案 A 的内容'), `错误信息含页面名、状态名、缺少方案 A 的内容：${msg}`);
  ok(a.srcdoc().includes(ERR_TEXT), '框里显示固定提示');
  ok(a.srcdoc().includes(msg), '框里显示错误原因');
  eq(a.txt('frameTitle'), ERR_TITLE, '框上方右边显示原型填写有误');
  untouched(a, '缺方案内容');
  eq(a.$('schemeBar').hidden, true, '首屏出错时框上方方案区隐藏');
  eq(a.$('schemeCurrent').hidden, true, '首屏出错时左栏当前方案隐藏');

  const c = mk(2);
  c.pages[0].states[0].html = { a: '<p>only a</p>' };
  const b = load(c);
  eq(b.errors.length, 0, '当前方案有内容时不报错');
  const current = b.txt('schemeCurrent');
  b.pick('schemePick', 1);
  eq(b.errors.length, 1, '切到缺内容的方案时抛错');
  ok(b.errors.length === 1 && b.errors[0].message.includes('缺少方案 B 的内容'), '错误信息含缺少方案 B 的内容');
  ok(b.srcdoc().includes(ERR_TEXT), '切换后框里显示固定提示');
  eq(b.txt('schemeCurrent'), current, '抛错前没有更新当前方案');

  const e = mk(2);
  delete e.pages[0].states[0].html;
  const h = load(e);
  eq(h.errors.length, 1, '省略 html 时 render 抛错');
  const hm = h.errors.length ? h.errors[0].message : '';
  ok(hm.includes('页一') && hm.includes('态一') && hm.includes('缺少'), `省略 html 的错误信息含页面名、状态名、缺少：${hm}`);
  ok(h.srcdoc().includes(ERR_TEXT), '省略 html 时框里显示固定提示');
  eq(h.txt('frameTitle'), ERR_TITLE, '省略 html 时框上方右边显示原型填写有误');
  untouched(h, '省略 html');
});

group('错误提示：填写区语法错误', () => {
  const a = loadHtml(withFill('const PROTOTYPE = 1 2;'));
  eq(a.errors.length, 1, '只有填写区报错，外壳脚本不报错');
  const msg = a.errors.length ? a.errors[0].message : '';
  ok(a.srcdoc().includes(ERR_TEXT), '框里显示固定提示');
  ok(msg !== '' && a.srcdoc().includes(msg), '框里显示语法错误原因');
  eq(a.txt('frameTitle'), ERR_TITLE, '外壳脚本没有覆盖框上方的错误提示');
  untouched(a, '语法错误');
});

group('错误提示：填写区运行时报错，第一条原因不被盖掉', () => {
  const init = loadHtml(withFill('const PROTOTYPE = { title: skelton };'));
  eq(init.errors.length, 1, 'PROTOTYPE 初始化报错时只有 1 个错误');
  ok(init.srcdoc().includes('skelton is not defined'), '框里显示第一条原因');
  ok(init.srcdoc().includes(ERR_TEXT), '框里显示固定提示');
  eq(init.txt('frameTitle'), ERR_TITLE, '框上方是原型填写有误');
  ok(init.broken() === true, 'error 监听把 window.prototypeBroken 设为 true');

  const later = loadHtml(withData(mk(2), 'boom();'));
  eq(later.errors.length, 1, 'PROTOTYPE 之后报错时只有 1 个错误');
  ok(later.srcdoc().includes('boom is not defined'), '框里显示 boom is not defined');
  ok(later.srcdoc().includes(ERR_TEXT), '外壳没有渲染原型盖掉错误提示');
  eq(later.txt('frameTitle'), ERR_TITLE, '框上方仍是原型填写有误');
  eq(later.txt('sideTitle'), '', '外壳没有继续渲染左栏');

  const missing = loadHtml(withFill('const PROTOTYP = {};'));
  ok(missing.errors.length >= 1, '没有 PROTOTYPE 时外壳脚本抛错');
  ok(missing.srcdoc().includes('PROTOTYPE is not defined'), '框里显示含 PROTOTYPE is not defined 的原因');
  ok(missing.srcdoc().includes(ERR_TEXT), '不是空白页');
  eq(missing.txt('frameTitle'), ERR_TITLE, '框上方是原型填写有误');

  const pre = loadHtml(withFill('window.prototypeBroken = true; const PROTOTYPE = ' + JSON.stringify(mk(2)) + ';'));
  eq(pre.errors.length, 0, 'prototypeBroken 为真时外壳脚本不报错');
  eq(pre.srcdoc(), '', 'prototypeBroken 为真时外壳脚本直接返回，不写框');
  eq(pre.txt('sideTitle'), '', 'prototypeBroken 为真时不渲染左栏');
});

group('错误提示：抛错后能恢复', () => {
  const d = mk(2);
  d.pages[0].states[0].html = { a: '<p>only a</p>' };
  const a = load(d);
  a.pick('schemePick', 1);
  eq(a.errors.length, 1, '切到缺内容的方案时抛错');
  a.pick('statePick', 1);
  eq(a.txt('frameTitle'), '页一 · 态二', '再点别的状态后 frameTitle 恢复');
  ok(a.srcdoc().includes('SAME') && !a.srcdoc().includes(ERR_TEXT), '再点别的状态后 srcdoc 恢复');
  a.pick('pagePick', 1);
  eq(a.txt('frameTitle'), '页二 · 甲', '再点别的页面后 frameTitle 恢复');
  ok(a.srcdoc().includes('P2T1') && !a.srcdoc().includes(ERR_TEXT), '再点别的页面后 srcdoc 恢复');
});

group('旧写法字段：note、fake、openQuestions 照常显示', () => {
  const MARK = 'LEGACY_MARK';
  const cases = [
    ['状态 note 字符串', (d) => { d.pages[0].states[0].note = MARK; }],
    ['状态 note 数组', (d) => { d.pages[0].states[0].note = [MARK]; }],
    ['状态 note 对象', (d) => { d.pages[0].states[0].note = { m: MARK }; }],
    ['状态 note 数字', (d) => { d.pages[0].states[0].note = 5; }],
    ['页面 fake 字符串', (d) => { d.pages[1].fake = MARK; }],
    ['页面 fake 对象', (d) => { d.pages[1].fake = { m: MARK }; }],
    ['页面 fake 数字', (d) => { d.pages[1].fake = 5; }],
    ['页面 fake 数组', (d) => { d.pages[1].fake = [MARK]; }],
    ['openQuestions 字符串', (d) => { d.openQuestions = MARK; }],
    ['openQuestions 对象', (d) => { d.openQuestions = { m: MARK }; }],
    ['openQuestions 数字', (d) => { d.openQuestions = 5; }],
    ['openQuestions 数组', (d) => { d.openQuestions = [MARK]; }],
    ['方案 note 字符串', (d) => { d.schemes[1].note = MARK; }],
    ['方案 note 对象', (d) => { d.schemes[1].note = { m: MARK }; }],
    ['方案 note 数字', (d) => { d.schemes[1].note = 5; }],
    ['方案 note 数组', (d) => { d.schemes[1].note = [MARK]; }],
  ];
  cases.forEach(([label, build]) => {
    const d = mk(2);
    build(d);
    const a = load(d);
    eq(a.errors.length, 0, `${label}：不报错`);
    ok(!a.broken(), `${label}：prototypeBroken 不为真`);
    ok(a.srcdoc().includes('HTML_a') && !a.srcdoc().includes(ERR_TEXT), `${label}：srcdoc 是正常画面，不是错误提示`);
    eq(a.txt('frameTitle'), '页一 · 态一', `${label}：框上方标题`);
    a.pick('schemePick', 1);
    a.pick('pagePick', 1);
    eq(a.errors.length, 0, `${label}：切换后不报错`);
    ok(a.srcdoc().includes('P2T1'), `${label}：切换后画面正常`);
    ok(!a.shellText().includes(MARK) && !a.srcdoc().includes(MARK), `${label}：外壳和框里都不显示这些内容`);
  });
});

group('方案字段：只有 id、label、desc', () => {
  const clone = () => JSON.parse(JSON.stringify(mk(2)));
  const a = load(clone());
  eq(a.errors.length, 0, '方案只有 id、label、desc 时正常显示');
  eq(a.txt('frameTitle'), '页一 · 态一', '方案没有 note 时原型照常显示');

  [[0, '方案 A'], [1, '方案 B']].forEach(([idx, label]) => {
    const d = clone();
    delete d.schemes[idx].desc;
    const b = load(d);
    eq(b.errors.length, 1, `多方案 ${label} 漏写 desc 时加载抛错`);
    const bm = b.errors.length ? b.errors[0].message : '';
    ok(bm.includes(label) && bm.includes('缺少'), `错误信息含方案 label 和缺少：${bm}`);
    ok(b.srcdoc().includes(ERR_TITLE) && b.srcdoc().includes(label), `${label} 漏写 desc 时框里显示「${ERR_TITLE}」和 ${label}`);
  });

  const single = clone();
  single.schemes = single.schemes.slice(0, 1);
  delete single.schemes[0].desc;
  eq(load(single).errors.length, 0, '只有 1 个方案时漏写 desc 不报错');
});

group('出错时方案区隐藏', () => {
  const tag = (id) => (new RegExp('<\\w+[^>]*\\sid="' + id + '"[^>]*>').exec(HTML) || [''])[0];
  ok(/\shidden(?=[\s>])/.test(tag('schemeBar')), 'HTML 里 schemeBar 开始标签带 hidden');
  ok(/\shidden(?=[\s>])/.test(tag('schemeCurrent')), 'HTML 里 schemeCurrent 开始标签带 hidden');

  const bad = loadHtml(withFill('const PROTOTYPE = 1 2;'));
  ok(bad.$('schemeBar').hidden === true, '语法错误时 schemeBar 隐藏');
  ok(bad.$('schemeCurrent').hidden === true, '语法错误时 schemeCurrent 隐藏');

  const good = load(mk(2));
  ok(good.$('schemeBar').hidden === false, '多方案正常加载后 schemeBar 不隐藏');
  ok(good.$('schemeCurrent').hidden === false, '多方案正常加载后 schemeCurrent 不隐藏');
});

group('填写区用了和外壳内部相同的名字', () => {
  const extra = 'const pages = []; const schemes = []; const el = 1; const render = 1; const select = 1; const current = 1;';
  const a = loadHtml(withData(mk(2), extra));
  eq(a.errors.length, 0, '不报错');
  eq(a.txt('frameTitle'), '页一 · 态一', '原型照常显示');
  ok(a.srcdoc().includes('HTML_a'), '框里是方案 A 的内容');
  a.pick('schemePick', 1);
  ok(a.srcdoc().includes('HTML_b'), '切换方案照常工作');
  a.pick('pagePick', 1);
  eq(a.txt('frameTitle'), '页二 · 甲', '切换页面照常工作');
  eq(a.errors.length, 0, '切换后仍不报错');
});

group('结构与样式（按区块）', () => {
  const iframeTag = (/<iframe[^>]*>/.exec(HTML) || [''])[0];
  ok(iframeTag.includes('sandbox="allow-scripts"'), 'iframe 带 sandbox="allow-scripts"');
  ok(!HTML.includes('allow-same-origin'), '文件不含 allow-same-origin');

  const aside = (/<aside[\s\S]*?<\/aside>/.exec(HTML) || [''])[0];
  ok(aside.includes('设计说明 · 不属于页面'), '左栏有设计说明标签');
  ok(aside.includes('<h3>页面</h3>'), '左栏有页面小标题');
  ['这个画面的说明', '只在原型里成立', '还没确认的问题', '这一块上线后不存在'].forEach((p) => ok(!HTML.includes(p), `外壳全文不含「${p}」`));

  const css = (/<style>([\s\S]*?)<\/style>/.exec(HTML) || ['', ''])[1];
  const block = (sel) => [...css.matchAll(new RegExp('(?:^|[\\s,}])' + sel + '\\s*\\{([^}]*)\\}', 'g'))].map((m) => m[1]).join('\n');
  ok(/background-image/.test(block('body')) && /ui-monospace/.test(block('body')), 'body 有网格 background-image 和等宽字体 ui-monospace');
  ok(/border-right:\s*1px dashed var\(--accent\)/.test(block('\\.side')), '.side 右边 1px 强调色虚线');
  const tagCss = block('\\.tag');
  ok(/dashed/.test(tagCss), '.tag 是虚线框');
  ok(/(?:^|[;\s])color:\s*var\(--accent\)/.test(tagCss), '.tag 文字色是 var(--accent)');
  ok(!/background/.test(tagCss), '.tag 没有背景');
  ok(/outline:\s*1px dashed var\(--accent\)/.test(block('iframe')), 'iframe 有 outline: 1px dashed var(--accent)');
  ok(!/\.dock/.test(css), 'CSS 里没有 .dock');
  ok(/\[hidden\]\s*\{\s*display:\s*none\s*!important;?\s*\}/.test(css), '[hidden] 强制隐藏');
  const pressedRule = /([^{}]*aria-pressed="true"[^{}]*)\{([^}]*)\}/.exec(css) || ['', '', ''];
  const pressed = pressedRule[2];
  ok(/border-color:\s*var\(--accent\)/.test(pressed) || /border:[^;]*var\(--accent\)/.test(pressed), '选中按钮边框用 var(--accent)');
  ok(/background:\s*var\(--pick-bg\)/.test(pressed), '选中按钮背景用 var(--pick-bg)');
  ok(/(?:^|[;\s])color:\s*var\(--pick-text\)/.test(pressed), '选中按钮文字色用 var(--pick-text)');
  ok(/font-weight:\s*(?:600|700|bold)/.test(pressed), '选中按钮字加粗');
  ok(/\.pick button/.test(pressedRule[1]), '左栏切换按钮有选中样式');
  const idleRule = [...css.matchAll(/([^{}]+)\{([^}]*)\}/g)].find((m) => /\.pick button\s*(?:,|$)/.test(m[1].trim()));
  ok(idleRule && /background:\s*transparent/.test(idleRule[2]) && /border:\s*1px solid var\(--shell-line\)/.test(idleRule[2]), '左栏切换按钮未选中样式：细线框、透明底');
  ok(!/border-radius/.test(css), '外壳 CSS 不含 border-radius');

  ok(/min-width:\s*960px/.test(block('body')), 'body 规则块里有 min-width: 960px');
  ok(/grid-template-columns:\s*240px 1fr/.test(block('body')), 'body 规则块里有 grid-template-columns: 240px 1fr');
  ok(/grid-template-rows:\s*auto minmax\(0, 1fr\)\s*;/.test(block('main')), 'main 规则块里 grid-template-rows 只有两行：auto minmax(0, 1fr)');
  ok(/padding:\s*0 6px 6px\s*;/.test(block('main')), 'main 下内边距 6px 保留');
  const frameRight = block('\\.frame-right');
  ok(/flex-wrap:\s*wrap/.test(frameRight), '.frame-right 有 flex-wrap: wrap');
  ok(/justify-content:\s*flex-end/.test(frameRight), '.frame-right 有 justify-content: flex-end');
  ok(/flex-wrap:\s*wrap/.test(block('\\.frame-bar')), '.frame-bar 有 flex-wrap: wrap，左边标题太长时右侧按钮组整组换到下一行');
  ok(/min-width:\s*260px/.test(frameRight) && /(?:^|[;\s])flex:\s*1 1 260px/.test(frameRight), '.frame-right 至少保留 260px（flex: 1 1 260px; min-width: 260px），按钮不被挤出窗口');
  const frameLeft = block('\\.frame-left');
  ok(/(?:^|[;\s])flex:\s*0 1 auto/.test(frameLeft) && /min-width:\s*0/.test(frameLeft), '.frame-left 能缩到可用宽度内（flex: 0 1 auto; min-width: 0），超长标题不把页面撑宽');
  ok(!/nowrap/.test(frameLeft) && !/nowrap/.test(block('#frameTitle')), '「页面名 · 状态名」放不下时能折行（.frame-left、#frameTitle 都不写 nowrap）');
  ok(/white-space:\s*nowrap/.test(block('\\.frame-left strong')) && /(?:^|[;\s])flex:\s*none/.test(block('\\.frame-left strong')), '「▼ 被设计的页面…」提示始终一行（flex: none; white-space: nowrap）');
  ok(!/text-overflow:\s*ellipsis/.test(css), 'CSS 里没有 text-overflow: ellipsis');

  const at = (needle, from = 0) => HTML.indexOf(needle, from);
  ok(at('<aside') >= 0 && at('<aside') < at('<main>'), '<aside 在 <main> 之前');
  ok(at('class="frame-bar"') >= 0 && at('class="frame-bar"') < at('id="stage"'), 'frame-bar 在 stage 之前');
  ok(/<iframe[^>]*><\/iframe>\s*<\/main>/.test(HTML), 'stage 是 main 的最后一个子元素：框下面没有说明区');
  ok(!HTML.includes('class="dock"') && !HTML.includes('id="dock"'), 'HTML 里没有 dock');
  const side = [aside.indexOf('id="sideTitle"'), aside.indexOf('id="schemeCurrent"'), aside.indexOf('id="pagePick"')];
  ok(side.every((i, k) => i >= 0 && (k === 0 || i > side[k - 1])), `左栏里 sideTitle、schemeCurrent、pagePick 依次出现：${side}`);
  ok(!aside.includes('id="schemePick"') && !aside.includes('id="schemeBar"'), '左栏里没有方案按钮');
  const leftAt = at('class="frame-left"', at('class="frame-bar"'));
  const rightAt = at('class="frame-right"', leftAt);
  ok(leftAt >= 0 && rightAt > leftAt, `frame-left 在 frame-right 之前：${leftAt},${rightAt}`);
  const left = HTML.slice(leftAt, rightAt);
  const leftOrder = [left.indexOf('被设计的页面'), left.indexOf('id="frameTitle"')];
  ok(leftOrder.every((i, k) => i >= 0 && (k === 0 || i > leftOrder[k - 1])), `.frame-left 里被设计的页面、frameTitle 依次出现：${leftOrder}`);
  const right = HTML.slice(rightAt, at('id="stage"'));
  ok(!right.includes('id="frameTitle"') && !right.includes('被设计的页面'), '.frame-right 里没有 frameTitle 和被设计的页面');
  ok(right.includes('id="schemeBar"'), '.frame-right 里有 schemeBar');
  ok(/id="schemeBar"[^]*?>方案<[^]*?id="schemePick"/.test(right), '#schemeBar 里先是文字「方案」，后面是 #schemePick');
  ok(!right.includes('themeLight') && !right.includes('themeDark') && !/class="theme"/.test(right), '.frame-right 里没有明暗按钮');
});

group('外壳只有一套配色：CSS', () => {
  const css = (/<style>([\s\S]*?)<\/style>/.exec(HTML) || ['', ''])[1];
  const roots = [...css.matchAll(/:root[^{]*\{([^}]*)\}/g)];
  eq(roots.length, 1, 'CSS 里只有一个 :root 规则块');
  eq((css.match(/--shell-bg\s*:/g) || []).length, 1, '--shell-bg 只定义一次');
  const body = roots.length ? roots[0][1] : '';
  const want = {
    '--shell-bg': '#26282c', '--shell-line': '#3a3d43', '--shell-text': '#d4d4d4', '--shell-muted': '#8f949b',
    '--accent': '#8e9aa8', '--pick-bg': '#33363c', '--pick-text': '#e6e6e6', '--grid': 'rgba(255,255,255,.03)',
  };
  Object.entries(want).forEach(([k, v]) => {
    const m = new RegExp('(?:^|[;\\s])' + k + ':\\s*([^;]+);').exec(body);
    eq(m ? m[1].replace(/\s+/g, '') : null, v, k);
  });
  ok(!/prefers-color-scheme/.test(HTML), '文件里没有 prefers-color-scheme');
  ok(!/data-theme/.test(css), 'CSS 里没有 data-theme 样式块');
});

group('外壳不随系统外观变化', () => {
  [[false, '浅色'], [true, '深色']].forEach(([dark, name]) => {
    const m = makeMedia(dark);
    const a = load(null, m);
    eq(a.errors.length, 0, `系统${name}：加载不报错`);
    eq(a.theme(), null, `系统${name}：根元素没有 data-theme`);
    m.set(!dark);
    eq(a.theme(), null, `系统${name}：系统外观变化后根元素仍没有 data-theme`);
    m.set(dark);
    eq(a.theme(), null, `系统${name}：系统外观变回后根元素仍没有 data-theme`);
    eq(m.listenerCount(), 0, `系统${name}：没有注册系统外观 change 监听`);
    eq(load(mk(2), makeMedia(dark)).theme(), null, `系统${name}：自定义数据根元素没有 data-theme`);
  });

  const old = makeMedia(true);
  delete old.addEventListener;
  const o = load(null, old);
  eq(o.errors.length, 0, 'matchMedia 没有 addEventListener 时不报错');
  eq(o.theme(), null, 'matchMedia 没有 addEventListener 时根元素没有 data-theme');

  [['默认数据', loadHtml(HTML)], ['自定义数据', loadHtml(withData(mk(2)))]].forEach(([name, a]) => {
    eq(a.theme(), null, name + '：没有 matchMedia 时根元素没有 data-theme');
    eq(a.errors.length, 0, name + '：没有 matchMedia 时不报错');
    ok(!a.broken(), name + '：没有 matchMedia 时 prototypeBroken 不为真');
    ok(a.srcdoc().length > 0, name + '：没有 matchMedia 时照常渲染');
  });

  const syntax = loadHtml(withFill('const PROTOTYPE = 1 2;'), makeMedia(true));
  eq(syntax.theme(), null, '填写区语法错误时根元素没有 data-theme');
  const data = mk(2);
  delete data.schemes[1].desc;
  const bad = load(data, makeMedia(true));
  ok(bad.broken(), '方案缺 desc 时外壳报错');
  eq(bad.theme(), null, '外壳报错时根元素没有 data-theme');
});

const DEFAULT_MARKS = ['.card', '.alert', '#2563eb'];
const withoutCss = (d) => { const c = JSON.parse(JSON.stringify(d)); delete c.css; return c; };

group('默认页面样式', () => {
  const fill = HTML.slice(HTML.indexOf(START), HTML.indexOf(END));
  ok(!/\bcss\s*:/.test(fill), '外壳自带的示例数据不写 css');
  const sample = load();
  DEFAULT_MARKS.forEach((m) => ok(sample.srcdoc().includes(m), `示例数据普通页面 srcdoc 含默认样式 ${m}`));

  [['不写 css', withoutCss(mk(2))], ['css 为空字符串', mk(2, { css: '' })],
    ['css 只有空格', mk(2, { css: '   ' })], ['css 是换行加空格', mk(2, { css: '\n  ' })]].forEach(([label, d]) => {
    const a = load(d);
    eq(a.errors.length, 0, `${label}不报错`);
    DEFAULT_MARKS.forEach((m) => ok(a.srcdoc().includes(m), `${label}：srcdoc 含默认样式 ${m}`));
    ok(a.srcdoc().includes('HTML_a'), `${label}：页面内容仍在`);
    a.pick('pagePick', 1);
    DEFAULT_MARKS.forEach((m) => ok(a.srcdoc().includes(m), `${label}：切到别的页面仍含默认样式 ${m}`));
  });

  const rule = (src, sel) => { const m = new RegExp('(?:^|[}\\s])' + sel + '\\s*\\{([^}]*)\\}').exec(src); return m ? m[1] : ''; };
  const base = sample.srcdoc();
  ok(/background:\s*#f5f7fa/.test(rule(base, 'body')), '默认页面 body 底色 background: #f5f7fa');
  ok(/background:\s*#fff\b/.test(rule(base, '\\.card')), '默认页面 .card 背景 background: #fff');
  ok(/background:\s*#2563eb/.test(rule(base, 'button')), '默认页面 button 背景 background: #2563eb');

  const own = load(mk(2));
  ok(own.srcdoc().includes('CSS_MARK_XYZ'), '写了 css 时 srcdoc 含项目样式');
  DEFAULT_MARKS.forEach((m) => ok(!own.srcdoc().includes(m), `写了 css 时 srcdoc 不含默认样式 ${m}`));
  own.pick('pagePick', 1);
  ok(!own.srcdoc().includes('#2563eb'), '写了 css 时切页面后仍不含默认样式');

  const commentOnly = load(mk(2, { css: '/* 项目样式 */' }));
  ok(commentOnly.srcdoc().includes('/* 项目样式 */'), 'css 只写了注释也算写了：srcdoc 含这段样式');
  DEFAULT_MARKS.forEach((m) => ok(!commentOnly.srcdoc().includes(m), `css 只写了注释：srcdoc 不含默认样式 ${m}`));

  const term = load(withoutCss(mk(2)));
  term.pick('pagePick', 2);
  DEFAULT_MARKS.forEach((m) => ok(!term.srcdoc().includes(m), `不写 css 时终端页面 srcdoc 也不含默认样式 ${m}`));
});

group('框内与外壳隔离：不写 css 的默认样式', () => {
  sweep(load(withoutCss(mk(2))), '不写css');
  sweep(load(mk(2, { css: '' })), 'css留空');
  sweep(load(mk(2, { css: '  \n ' })), 'css只有空白');
});

const TERM_CSS = 'body{background:#123456} .ok{color:#abcdef}';
const mkTerm = (termCss) => {
  const d = mk(2, { css: '.CSS_MARK_XYZ{color:#654321}' });
  d.pages[2].terminalCss = termCss;
  d.pages[2].states[0].html = 'TERM_A <span class="ok">ok</span> <a data-go="p2:t2">跳</a>';
  d.pages.push({
    id: 'p4', name: '终端页B', terminal: true, states: [
      { id: 'v1', name: '第一步', html: 'TERM_B' },
    ],
  });
  return d;
};
const DEFAULT_TERM = ['#0b1730', '.g { color: #7ee7c1; }'];

group('终端页面：terminalCss 指定项目自己的终端样式', () => {
  const a = load(mkTerm(TERM_CSS));
  eq(a.errors.length, 0, '不报错');
  a.pick('pagePick', 2);
  const s = a.srcdoc();
  ok(s.includes('#123456') && s.includes('.ok{color:#abcdef}'), '终端页 A 的 srcdoc 含 terminalCss');
  ok(!s.includes('#0b1730'), '终端页 A 的 srcdoc 不含外壳默认终端底色');
  ok(!s.includes('CSS_MARK_XYZ'), '终端页 A 的 srcdoc 不含项目 css');
  ok(s.includes('width: 80ch') && s.includes('white-space: pre-wrap') && s.includes('monospace'), '终端页 A 写了 terminalCss 后仍按 80 列换行、用等宽字体');
  ok(s.includes('TERM_A'), '终端页 A 内容仍在');

  a.pick('pagePick', 3);
  const b = a.srcdoc();
  DEFAULT_TERM.forEach((m) => ok(b.includes(m), `终端页 B 的 srcdoc 含默认终端样式 ${m}`));
  ok(!b.includes('#123456'), '终端页 B 的 srcdoc 不含 A 的 terminalCss');

  a.pick('pagePick', 0);
  const c = a.srcdoc();
  ok(c.includes('CSS_MARK_XYZ'), '普通页 C 的 srcdoc 含项目 css');
  ok(!c.includes('#123456') && !c.includes('#0b1730'), '普通页 C 的 srcdoc 不含 terminalCss 和默认终端底色');

  a.pick('pagePick', 2);
  ok(a.srcdoc().includes('#123456') && !a.srcdoc().includes('#0b1730'), '切回终端页 A 仍用 terminalCss');
});

group('终端页面：terminalCss 写了排版属性时外壳的 80 列排版仍生效', () => {
  const layoutCss = 'pre{width:120ch;white-space:pre;font:13px serif}';
  const a = load(mkTerm(layoutCss));
  eq(a.errors.length, 0, '不报错');
  a.pick('pagePick', 2);
  const s = a.srcdoc();
  const own = s.indexOf(layoutCss);
  ok(own >= 0, 'srcdoc 含 terminalCss');
  ['width: 80ch', 'white-space: pre-wrap', 'monospace'].forEach((m) =>
    ok(s.indexOf(m) > own, `外壳排版 ${m} 写在 terminalCss 后面，同一选择器下以它为准`));
});

group('终端页面：terminalCss 为空或只有空白时用默认终端样式', () => {
  ['', '   ', '\n  '].forEach((v) => {
    const a = load(mkTerm(v));
    eq(a.errors.length, 0, `terminalCss=${JSON.stringify(v)} 不报错`);
    a.pick('pagePick', 2);
    DEFAULT_TERM.forEach((m) => ok(a.srcdoc().includes(m), `terminalCss=${JSON.stringify(v)}：srcdoc 含默认终端样式 ${m}`));
    ok(a.srcdoc().includes('TERM_A'), `terminalCss=${JSON.stringify(v)}：内容仍在`);
  });
});

group('终端页面：terminalCss 页面仍包在 pre 里，data-go 可用', () => {
  const a = load(mkTerm(TERM_CSS));
  a.pick('pagePick', 2);
  const s = a.srcdoc();
  ok(/<pre>[^]*TERM_A[^]*<\/pre>/.test(s), '终端页 A 的 html 包在 <pre> 里');
  ok(s.includes('data-go="p2:t2"'), 'srcdoc 保留 data-go 元素');
  const f = frameOf(s);
  eq(f.errors.length, 0, '框内脚本不报错');
  f.fire('click', elem('a', { 'data-go': 'p2:t2' }));
  ok(f.posts.some((m) => m && m.go === 'p2:t2'), '点 data-go 元素向外壳发 go');
  a.post('p2:t2');
  eq(a.txt('frameTitle'), '页二 · 乙', '外壳收到 go 后跳转');
});

group('终端页面：terminalCss 页面不随系统外观变化', () => {
  const open = (dark) => {
    const a = load(mkTerm(TERM_CSS), makeMedia(dark));
    a.pick('pagePick', 2);
    return a;
  };
  const light = open(false);
  const dark = open(true);
  ok(light.srcdoc().includes('#123456'), 'srcdoc 含 terminalCss');
  eq(light.srcdoc() === dark.srcdoc(), true, '系统浅色与深色 srcdoc 相同');
});

group('终端页面：terminalCss 页面通过隔离检查', () => {
  sweep(load(mkTerm(TERM_CSS)), 'terminalCss');
});

group('填写区说明：terminalCss 与 css 的文字', () => {
  const fill = HTML.slice(HTML.indexOf(START), HTML.indexOf(END));
  ['terminalCss', '只对这一页生效', '默认配色只在项目没有命令行输出代码时用',
    '照项目根目录 DESIGN.md 和项目现有样式写', '终端页面用 terminalCss，不用 css。',
    '照 DESIGN.md「终端界面」和项目实际输出写', '只换配色，80 列宽度、等宽字体和自动换行由外壳固定'].forEach((p) => ok(fill.includes(p), `填写区说明含「${p}」`));
  ['项目没有自己的设计时不写这一项', '终端页面固定用外壳自带的样式'].forEach((p) => ok(!HTML.includes(p), `外壳全文不含「${p}」`));
});
group('填写区说明与示例数据：没有 note、fake、openQuestions', () => {
  const fill = HTML.slice(HTML.indexOf(START), HTML.indexOf(END));
  ['note', 'fake', 'openQuestions'].forEach((w) => ok(!new RegExp('\\b' + w + '\\b').test(fill), `填写区里搜不到 ${w}`));
  const a = load();
  eq(a.errors.length, 0, '示例原型不报错');
  const keys = (code) => JSON.parse(a.run(code));
  eq(keys('JSON.stringify(PROTOTYPE.schemes.map((s) => Object.keys(s).sort()))'), [['desc', 'id', 'label'], ['desc', 'id', 'label']], '示例方案只有 id、label、desc');
  eq(keys("JSON.stringify(PROTOTYPE.pages.some((p) => 'fake' in p))"), false, '示例页面没有 fake');
  eq(keys("JSON.stringify(PROTOTYPE.pages.some((p) => p.states.some((s) => 'note' in s)))"), false, '示例状态没有 note');
  eq(keys("JSON.stringify('openQuestions' in PROTOTYPE)"), false, '示例没有 openQuestions');
  eq(keys('JSON.stringify([PROTOTYPE.pages.length, PROTOTYPE.pages.map((p) => p.states.length), PROTOTYPE.pages.some((p) => p.terminal)])'), [3, [4, 3, 3], true], '示例保留 3 个页面、各自状态和终端页面');
});
console.log('RESULT ' + pass + ' ' + fail);
JSEOF

echo "[行为：假 DOM + vm]"
NODE_OUT="$(SHELL_HTML="$SHELL_HTML" node "$JS" 2>&1)" || true
if RESULT_LINE="$(printf '%s\n' "$NODE_OUT" | grep '^RESULT ')"; then
  printf '%s\n' "$NODE_OUT" | grep -v '^RESULT '
  PASS=$((PASS + $(echo "$RESULT_LINE" | awk '{print $2}')))
  FAIL=$((FAIL + $(echo "$RESULT_LINE" | awk '{print $3}')))
else
  printf '%s\n' "$NODE_OUT"
  fail "行为测试脚本异常退出，没有产出结果"
fi

echo
echo "通过 ${PASS}，失败 ${FAIL}"
[[ "$FAIL" -eq 0 ]]
