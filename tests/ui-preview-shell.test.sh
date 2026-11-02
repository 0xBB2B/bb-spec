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
  "切换要看的内容" \
  "▼ 被设计的页面：只有这个框里的内容要实现" \
  "这一块上线后不存在" \
  "这个画面的说明" \
  "只在原型里成立" \
  "还没确认的问题"; do
  if grep -qF -- "$phrase" "$SHELL_HTML"; then pass; else fail "缺少固定文案「$phrase」"; fi
done

echo "[单文件、不联网、不引用外部资源]"
for pattern in 'http://' 'https://' '<link' '<script[^>]*[[:space:]]src[[:space:]]*=' '@import'; do
  if grep -qiE -- "$pattern" "$SHELL_HTML"; then fail "出现外部资源引用：$pattern"; else pass; fi
done

echo "[结构：iframe、底部 26vh、填写区标记]"
if grep -qE '<iframe[^>]*id="stage"|<iframe[^>]*id='"'"'stage'"'" "$SHELL_HTML"; then pass; else fail "正式页面没有放在 id=stage 的 iframe 里"; fi
if grep -qF '26vh' "$SHELL_HTML"; then pass; else fail "底部高度没有写成 26vh"; fi
if [[ "$(grep -cF '/* PROTOTYPE-START' "$SHELL_HTML")" == "1" ]]; then pass; else fail "填写区起点标记应恰好出现一次"; fi
if [[ "$(grep -cF '/* PROTOTYPE-END */' "$SHELL_HTML")" == "1" ]]; then pass; else fail "填写区终点标记应恰好出现一次"; fi

echo "[外壳里的 14 个元素都写在 HTML 里]"
for id in schemeBox schemeHint schemePick pagePick statePick stateLabel frameScheme frameTitle stage noteList fakeList openList sideTitle sideVersion; do
  if grep -qE "<[a-z0-9]+[^>]*[[:space:]]id=\"${id}\"" "$SHELL_HTML"; then pass; else fail "HTML 里没有 id=\"${id}\" 的元素"; fi
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

const loadHtml = (html) => {
  const doc = new Doc(html);
  const L = {};
  const errors = [];
  const ctx = { document: doc, console };
  ctx.window = ctx;
  ctx.addEventListener = (t, f) => { (L[t] = L[t] || []).push(f); };
  const fireError = (message) => (L.error || []).forEach((f) => f({ message }));
  const raise = (err) => { errors.push(err); fireError(err.message); };
  runScripts(ctx, extractScripts(html), raise);

  const $ = (id) => doc.getElementById(id);
  const buttons = (g) => $(g).children.filter((c) => c.tagName === 'BUTTON');
  const api = {
    $,
    buttons,
    errors,
    fireError,
    broken: () => ctx.prototypeBroken,
    txt: (id) => $(id).textContent,
    texts: (id) => $(id).children.map((c) => c.textContent),
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
      scheme: $('frameScheme').textContent,
      schemeHidden: $('frameScheme').hidden,
      srcdoc: $('stage').srcdoc,
      notes: api.texts('noteList'),
      fakes: api.texts('fakeList'),
      opens: api.texts('openList'),
      pressed: [api.pressed('schemePick'), api.pressed('pagePick'), api.pressed('statePick')],
    }),
  };
  return api;
};
const load = (data) => loadHtml(data ? withData(data) : HTML);

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

const FORBIDDEN = ['设计说明', '被设计的页面', '只在原型里成立', '当前看的是'];
const SAME = '各方案在这个画面上一样。';

const SCH = [
  { id: 'a', label: '方案 A', desc: '表格', note: 'A取舍' },
  { id: 'b', label: '方案 B', desc: '卡片', note: 'B取舍' },
  { id: 'c', label: '方案 C', desc: '列表', note: 'C取舍' },
];
const mk = (n, over) => {
  const schemes = SCH.slice(0, n);
  return Object.assign({
    title: '自定义标题',
    version: 3,
    css: '.CSS_MARK_XYZ{color:#123456}',
    openQuestions: ['Q1'],
    schemes,
    pages: [
      {
        id: 'p1', name: '页一', fake: ['F1'], states: [
          { id: 's1', name: '态一', note: ['N1'], html: Object.fromEntries(schemes.map((s) => [s.id, '<p>HTML_' + s.id + '</p>'])) },
          { id: 's2', name: '态二', note: ['N2'], html: '<p>SAME</p><a data-go="p2:t2">跳</a>' },
        ],
      },
      {
        id: 'p2', name: '页二', fake: [], states: [
          { id: 't1', name: '甲', note: ['M1'], html: '<p>P2T1</p>' },
          { id: 't2', name: '乙', note: ['M2'], html: '<p>P2T2</p>' },
        ],
      },
      {
        id: 'p3', name: '终端页', fake: ['F3'], stateLabel: '步骤', terminal: true, states: [
          { id: 'u1', name: '第一步', note: ['U1'], html: 'TERM_LINE_ONE' },
        ],
      },
    ],
  }, over || {});
};

group('默认数据：初始画面', () => {
  const a = load();
  eq(a.txt('sideTitle'), '订单导出（示例）', '左栏标题');
  eq(a.txt('sideVersion'), '第 1 版 · 这一栏上线后不存在', '版本文字');
  eq(a.txt('schemeHint'), '有 2 个方案，点这里切换对比', '方案切换提示');
  eq(a.txt('frameScheme'), '当前看的是 方案 A：表格', '框上方方案标签');
  eq(a.txt('frameTitle'), '订单列表 · 正常', '框上方右侧标题');
  eq(a.txt('stateLabel'), '状态', '普通页面的第二组标题');
  ok(a.$('schemeBox').hidden === false, '2 个方案时切换框显示');
  ok(a.$('frameScheme').hidden === false, '2 个方案时方案标签显示');
  eq([a.buttons('schemePick').length, a.buttons('pagePick').length, a.buttons('statePick').length], [2, 3, 4], '按钮数量');
  eq([a.pressed('schemePick'), a.pressed('pagePick'), a.pressed('statePick')],
    [[true, false], [true, false, false], [true, false, false, false]], '选中态 aria-pressed');
  eq(a.texts('openList')[0], '选方案 A 还是方案 B', '默认数据 openList 第一条');
  ok(a.srcdoc().length > 0, '正式页面写入了 srcdoc');
});

group('默认数据：方案、页面、状态切换', () => {
  const a = load();
  const before = a.srcdoc();
  const noteA = a.texts('noteList')[0];
  a.pick('schemePick', 1);
  eq(a.txt('frameScheme'), '当前看的是 方案 B：卡片', '切方案后标签');
  eq(a.txt('frameTitle'), '订单列表 · 正常', '切方案后页面和状态不变');
  ok(a.srcdoc() !== before, '各方案不同的画面切方案后 srcdoc 变化');
  ok(a.texts('noteList')[0] !== noteA && a.texts('noteList')[0] !== SAME, '各方案不同的画面第一条是当前方案的取舍');

  a.pick('statePick', 1);
  eq(a.texts('noteList')[0], SAME, '空数据画面（各方案相同）第一条');
  a.pick('schemePick', 0);
  eq(a.texts('noteList')[0], SAME, '切回方案 A 后仍是各方案一样');
  eq(a.txt('frameScheme'), '当前看的是 方案 A：表格', '切回方案 A');

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
  eq(a.txt('frameScheme'), '当前看的是 方案 B：卡片', '跳转后方案不变');
  eq(a.snap(), viaBtn.snap(), '跳转与点按钮结果一致（框、提示、说明三处同步）');
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

group('自定义数据：初始画面与说明', () => {
  const a = load(mk(2));
  eq(a.txt('sideTitle'), '自定义标题', '标题');
  eq(a.txt('sideVersion'), '第 3 版 · 这一栏上线后不存在', '版本');
  eq(a.txt('schemeHint'), '有 2 个方案，点这里切换对比', '提示');
  eq(a.txt('frameScheme'), '当前看的是 方案 A：表格', '方案标签');
  eq(a.txt('frameTitle'), '页一 · 态一', '框上方标题');
  eq(a.texts('noteList')[0], 'A取舍', '说明第一条是当前方案取舍');
  ok(a.texts('noteList').includes('N1'), '说明含画面自己的说明');
  eq(a.texts('fakeList'), ['F1'], '只在原型里成立');
  eq(a.texts('openList')[0], '选方案 A 还是方案 B', '自动生成的问题');
  ok(a.texts('openList').includes('Q1'), '问题含手写问题');
  ok(a.srcdoc().includes('HTML_a') && !a.srcdoc().includes('HTML_b'), '方案 A 的内容');
  ok(a.srcdoc().includes('CSS_MARK_XYZ'), '普通页面带 PROTOTYPE.css');
});

group('自定义数据：切换保持与重置', () => {
  const a = load(mk(2));
  a.pick('schemePick', 1);
  ok(a.srcdoc().includes('HTML_b') && !a.srcdoc().includes('HTML_a'), '方案 B 的内容');
  eq(a.texts('noteList')[0], 'B取舍', '方案 B 取舍');
  a.pick('statePick', 1);
  eq(a.texts('noteList')[0], SAME, '相同画面第一条');
  ok(a.srcdoc().includes('SAME'), '相同画面内容');
  a.pick('schemePick', 0);
  eq(a.txt('frameTitle'), '页一 · 态二', '切方案页面和状态不变');
  eq(a.pressed('statePick'), [false, true], '状态选中态保持');
  a.pick('schemePick', 1);
  a.pick('pagePick', 1);
  eq(a.txt('frameTitle'), '页二 · 甲', '切页面回到第一项');
  eq(a.txt('frameScheme'), '当前看的是 方案 B：卡片', '切页面方案不变');
  eq(a.texts('fakeList'), ['无'], '没有假内容时显示无');
  eq(a.texts('noteList')[0], SAME, '相同画面第一条（页二）');
  eq(a.pressed('pagePick'), [false, true, false], '页面选中态');
  a.pick('pagePick', 0);
  eq(a.txt('frameTitle'), '页一 · 态一', '回到页一');
  eq(a.texts('fakeList'), ['F1'], '回到页一后假内容恢复');
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
  ok(s.includes('background: #15181e'), '终端 srcdoc 有深色背景 #15181e');
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
  eq(a.txt('frameScheme'), '当前看的是 方案 B：卡片', '跳转方案不变');
  eq(a.pressed('pagePick'), [false, true, false], '跳转后页面选中');
  eq(a.pressed('statePick'), [false, true], '跳转后状态选中');
  ok(a.srcdoc().includes('P2T2'), '跳转后内容');
  eq(a.texts('noteList'), [SAME, 'M2'], '跳转后说明');
});

group('3 个方案', () => {
  const a = load(mk(3));
  eq(a.txt('schemeHint'), '有 3 个方案，点这里切换对比', '提示');
  eq(a.texts('openList')[0], '选方案 A、方案 B 还是方案 C', '3 个方案的问题');
  a.pick('schemePick', 2);
  eq(a.txt('frameScheme'), '当前看的是 方案 C：列表', '方案 C 标签');
  eq(a.texts('noteList')[0], 'C取舍', '方案 C 取舍');
  eq(a.texts('openList')[0], '选方案 A、方案 B 还是方案 C', '切方案后问题不变');
});

group('只有 1 个方案', () => {
  const a = load(mk(1));
  ok(a.$('schemeBox').hidden === true, 'schemeBox 隐藏');
  ok(a.$('frameScheme').hidden === true, 'frameScheme 隐藏');
  eq(a.texts('noteList'), ['N1'], '说明里没有方案相关内容');
  eq(a.texts('openList'), ['Q1'], '问题里没有方案相关内容');
  a.pick('statePick', 1);
  eq(a.texts('noteList'), ['N2'], '相同画面不写各方案一样');
  eq(a.texts('openList'), ['Q1'], '问题仍无方案相关内容');
  const b = load(mk(1, { openQuestions: [] }));
  b.pick('pagePick', 1);
  eq(b.texts('fakeList'), ['无'], 'fake 空时显示无');
  eq(b.texts('openList'), ['无'], 'openQuestions 空时显示无');
});

group('多方案下问题为空时 fake 仍显示无', () => {
  const a = load(mk(2, { openQuestions: [] }));
  a.pick('pagePick', 1);
  eq(a.texts('fakeList'), ['无'], 'fake 空');
  eq(a.texts('openList')[0], '选方案 A 还是方案 B', '自动问题仍在');
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

group('省略的字段', () => {
  const d = mk(1);
  delete d.openQuestions;
  delete d.pages[0].fake;
  const a = load(d);
  eq(a.errors.length, 0, '省略 fake、openQuestions 不报错');
  eq(a.texts('fakeList'), ['无'], '省略 fake 显示无');
  eq(a.texts('openList'), ['无'], '省略 openQuestions 显示无');

  const n = mk(1);
  delete n.pages[0].states[0].note;
  const b = load(n);
  eq(b.errors.length, 0, '省略 note 不报错');
  eq(b.texts('noteList'), ['无'], '省略 note 按空处理');
  b.pick('statePick', 1);
  eq(b.texts('noteList'), ['N2'], '其他画面说明不受影响');

  const m = mk(2);
  delete m.pages[0].states[0].note;
  eq(load(m).texts('noteList'), ['A取舍'], '多方案省略 note 时只剩方案取舍');
});

const ERR_TEXT = '原型填写有误，这不是正式页面。';
const ERR_TITLE = '原型填写有误';
const TEXT_IDS = ['schemeHint', 'frameScheme', 'stateLabel', 'noteList', 'fakeList', 'openList'];
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
  eq(a.$('schemeBox').hidden, true, '首屏出错时切换框隐藏');
  eq(a.$('frameScheme').hidden, true, '首屏出错时方案标签隐藏');

  const c = mk(2);
  c.pages[0].states[0].html = { a: '<p>only a</p>' };
  const b = load(c);
  eq(b.errors.length, 0, '当前方案有内容时不报错');
  const scheme = b.txt('frameScheme');
  const notes = b.texts('noteList');
  b.pick('schemePick', 1);
  eq(b.errors.length, 1, '切到缺内容的方案时抛错');
  ok(b.errors.length === 1 && b.errors[0].message.includes('缺少方案 B 的内容'), '错误信息含缺少方案 B 的内容');
  ok(b.srcdoc().includes(ERR_TEXT), '切换后框里显示固定提示');
  eq(b.txt('frameScheme'), scheme, '抛错前没有更新方案标签');
  eq(b.texts('noteList'), notes, '抛错前没有更新说明');

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

group('方案字段漏写', () => {
  const clone = () => JSON.parse(JSON.stringify(mk(2)));
  const noNote = clone();
  delete noNote.schemes[1].note;
  const a = load(noNote);
  eq(a.errors.length, 1, '多方案漏写 note 时加载抛错');
  const am = a.errors.length ? a.errors[0].message : '';
  ok(am.includes('方案 B') && am.includes('缺少'), `错误信息含方案 label 和缺少：${am}`);

  const noDesc = clone();
  delete noDesc.schemes[0].desc;
  const b = load(noDesc);
  eq(b.errors.length, 1, '多方案漏写 desc 时加载抛错');
  const bm = b.errors.length ? b.errors[0].message : '';
  ok(bm.includes('方案 A') && bm.includes('缺少'), `错误信息含方案 label 和缺少：${bm}`);

  const single = JSON.parse(JSON.stringify(mk(1)));
  delete single.schemes[0].note;
  delete single.schemes[0].desc;
  eq(load(single).errors.length, 0, '只有 1 个方案时漏写 note、desc 不报错');
});

group('出错时方案区隐藏', () => {
  const tag = (id) => (new RegExp('<\\w+[^>]*\\sid="' + id + '"[^>]*>').exec(HTML) || [''])[0];
  ok(/\shidden(?=[\s>])/.test(tag('schemeBox')), 'HTML 里 schemeBox 开始标签带 hidden');
  ok(/\shidden(?=[\s>])/.test(tag('frameScheme')), 'HTML 里 frameScheme 开始标签带 hidden');

  const bad = loadHtml(withFill('const PROTOTYPE = 1 2;'));
  ok(bad.$('schemeBox').hidden === true, '语法错误时 schemeBox 隐藏');
  ok(bad.$('frameScheme').hidden === true, '语法错误时 frameScheme 隐藏');

  const good = load(mk(2));
  ok(good.$('schemeBox').hidden === false, '多方案正常加载后 schemeBox 不隐藏');
  ok(good.$('frameScheme').hidden === false, '多方案正常加载后 frameScheme 不隐藏');
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
  const dock = (/<section class="dock"[\s\S]*?<\/section>/.exec(HTML) || [''])[0];
  ok(aside.includes('设计说明 · 不属于页面'), '左栏有设计说明标签');
  ok(aside.includes('<h3>页面</h3>'), '左栏有页面小标题');
  ok(dock.includes('设计说明 · 不属于页面'), '底部有设计说明标签');
  ok(dock.includes('这一块上线后不存在'), '底部有上线后不存在的说明');
  const order = ['这个画面的说明', '只在原型里成立', '还没确认的问题'].map((p) => dock.indexOf(p));
  ok(order.every((i, k) => i >= 0 && (k === 0 || i > order[k - 1])), `底部三列标题按顺序出现：${order}`);

  const css = (/<style>([\s\S]*?)<\/style>/.exec(HTML) || ['', ''])[1];
  const block = (sel) => [...css.matchAll(new RegExp('(?:^|[\\s,}])' + sel + '\\s*\\{([^}]*)\\}', 'g'))].map((m) => m[1]).join('\n');
  ok(/(^|[\s;{])height:\s*26vh/.test(block('\\.dock')), '.dock 高度 26vh');
  ok(/overflow-y:\s*auto/.test(block('\\.dock')), '.dock 内容多时滚动');
  ok(/\[hidden\]\s*\{\s*display:\s*none\s*!important;?\s*\}/.test(css), '[hidden] 强制隐藏');
  ok(/border-right:\s*4px solid var\(--amber\)/.test(block('\\.side')), '.side 右边 4px 琥珀色线');
  ok(/background:\s*var\(--shell-bg\)/.test(block('\\.side')), '.side 背景用 --shell-bg');
  ok(/background:\s*var\(--frame-bg\)/.test(block('body')), 'body 背景用 --frame-bg');
  const pressed = (/[^{}]*aria-pressed="true"[^{}]*\{([^}]*)\}/.exec(css) || ['', ''])[1];
  ok(/background:\s*var\(--amber\)/.test(pressed), '选中按钮背景用 --amber');

  ok(/min-width:\s*960px/.test(block('body')), 'body 规则块里有 min-width: 960px');
  ok(/grid-template-columns:\s*240px 1fr/.test(block('body')), 'body 规则块里有 grid-template-columns: 240px 1fr');
  ok(/grid-template-rows:\s*auto minmax\(0, 1fr\) auto/.test(block('main')), 'main 规则块里有 grid-template-rows: auto minmax(0, 1fr) auto');
  const bar = block('\\.frame-bar');
  ok(/white-space:\s*nowrap/.test(bar) && /overflow:\s*hidden/.test(bar), '.frame-bar 有 white-space: nowrap 和 overflow: hidden');
  ok(/flex:\s*none/.test(block('\\.frame-left')), '.frame-left 有 flex: none');
  const title = block('#frameTitle');
  ok(/min-width:\s*0/.test(title) && /overflow:\s*hidden/.test(title) && /text-overflow:\s*ellipsis/.test(title), '#frameTitle 有 min-width: 0、overflow: hidden、text-overflow: ellipsis');

  const at = (needle, from = 0) => HTML.indexOf(needle, from);
  ok(at('<aside') >= 0 && at('<aside') < at('<main>'), '<aside 在 <main> 之前');
  ok(at('class="frame-bar"') >= 0 && at('class="frame-bar"') < at('id="stage"'), 'frame-bar 在 stage 之前');
  ok(at('id="stage"') >= 0 && at('id="stage"') < at('class="dock"'), 'stage 在 dock 之前');
  const side = [aside.indexOf('id="sideTitle"'), aside.indexOf('id="schemeBox"'), aside.indexOf('id="pagePick"')];
  ok(side.every((i, k) => i >= 0 && (k === 0 || i > side[k - 1])), `左栏里 sideTitle、schemeBox、pagePick 依次出现：${side}`);
  const barAt = at('class="frame-bar"');
  const top = [at('被设计的页面', barAt), at('id="frameScheme"', barAt), at('id="frameTitle"', barAt)];
  ok(top.every((i, k) => i >= 0 && (k === 0 || i > top[k - 1])), `框上方：被设计的页面、frameScheme、frameTitle 依次出现：${top}`);
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
