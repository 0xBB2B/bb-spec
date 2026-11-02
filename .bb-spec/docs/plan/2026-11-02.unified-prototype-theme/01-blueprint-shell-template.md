---
name: 01-blueprint-shell-template
description: 外壳改成蓝图样式，内置默认页面样式，底部高度跟着说明走，并更新外壳测试
---
# 蓝图外壳

## 目标

外壳文件改成用户确认的蓝图样式，框里没有项目样式时用内置默认样式，底部高度正好放下最长的说明。

## 业务规则（来源：PRD 01-blueprint-shell）

- 外壳：藏蓝底 `#12264a` 加细网格，等宽字体，方角；分界用青色 `#7fd4ff` 虚线（左栏和右边之间、框的外面、底部说明的上面、方案切换框）。
- 「设计说明 · 不属于页面」标签是青色虚线框、青色字、无填充。按钮未选中是细线框、透明底，选中是浅青色实心底、深色字。
- 框上方：左边「▼ 被设计的页面：只有这个框里的内容要实现」；右边依次是方案标签和「<页面名> · <状态名>」。方案标签只写方案名，如「方案 A：表格」，只有 1 个方案时不显示。
- 切换框标题是「这份原型有 N 个方案，点这里切换对比」。
- 「只在原型里成立」「还没确认的问题」没内容时显示不带序号的「无」。
- 填写区 `css` 留空或不写时，框里用默认页面样式（白底、蓝色按钮，有标题栏、卡片、表格、提示条、占位条）。写了 `css` 时框里只有项目样式，默认样式完全不生效。
- 框里的任何样式都不改变外壳，外壳样式也不进入框里，包括强制生效的全局规则。
- 终端固定配色：底色 `#0b1730`，文字 `#d7e6ff`，绿、黄、蓝、红分别是 `#7ee7c1`、`#ffd479`、`#7fd4ff`、`#ff8f8f`。
- 底部高度等于这份原型所有画面里最长说明的高度，说明最长的画面下方只留 8 像素。切换时底部和框的高度都不变。最长说明超过窗口高度 30% 时，底部高 30%，内部滚动。窗口大小改变时重新计算，当前画面的说明不变。
- 外壳现有行为全部保留：框的隔离、链接拦截、填写出错提示、多方案、名字不冲突、长文本不破坏布局。

## 涉及文件

- `plugins/bb-spec-workflow/templates/ui-preview-shell.html`（修改）
- `tests/ui-preview-shell.test.sh`（修改）

## 成品定义

`plugins/bb-spec-workflow/templates/ui-preview-shell.html` 按下面内容原样落盘，这份内容已在真实浏览器验证过，外观和用户确认的预览一致。

````html
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>界面原型</title>
<style>
  :root {
    --shell-bg: #12264a;
    --shell-line: #2f4a77;
    --shell-text: #e6f1ff;
    --shell-muted: #9fb6d9;
    --accent: #7fd4ff;
    --accent-ink: #0a1f3f;
    --grid: rgba(127, 212, 255, .07);
  }
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }
  html, body { height: 100%; margin: 0; }
  body {
    min-width: 960px;
    display: grid;
    grid-template-columns: 240px 1fr;
    font: 12px/1.6 ui-monospace, Menlo, "PingFang SC", "Microsoft YaHei", monospace;
    color: var(--shell-text);
    background-color: var(--shell-bg);
    background-image: linear-gradient(var(--grid) 1px, transparent 1px), linear-gradient(90deg, var(--grid) 1px, transparent 1px);
    background-size: 24px 24px;
  }
  .tag {
    display: inline-block;
    padding: 1px 8px;
    border: 1px dashed var(--accent);
    color: var(--accent);
    font-size: 12px;
    font-weight: 600;
  }

  .side {
    height: 100vh;
    overflow-y: auto;
    border-right: 1px dashed var(--accent);
  }
  .side-head { padding: 12px 14px; border-bottom: 1px solid var(--shell-line); }
  .side-head h1 { margin: 10px 0 2px; font-size: 14px; }
  .side-head p { margin: 0; font-size: 11px; color: var(--shell-muted); }
  .scheme {
    margin: 12px 10px 0;
    padding: 10px;
    border: 1px dashed var(--accent);
  }
  .scheme h2 { margin: 0 0 8px; font-size: 12px; font-weight: 600; color: var(--accent); }
  .side-body { padding: 14px 12px; }
  .side-body h2 { margin: 0 0 6px; font-size: 12px; font-weight: 500; color: var(--shell-muted); }
  .side-body h3 { margin: 14px 0 6px; font-size: 12px; font-weight: 500; color: var(--shell-muted); }
  .pick { display: flex; flex-direction: column; gap: 4px; }
  .pick button {
    padding: 5px 10px;
    border: 1px solid var(--shell-line);
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
  }
  .pick button:hover { border-color: var(--accent); }
  .pick button[aria-pressed="true"] { border-color: var(--accent); background: var(--accent); color: var(--accent-ink); font-weight: 600; }

  main {
    display: grid;
    grid-template-rows: auto minmax(0, 1fr) auto;
    height: 100vh;
    min-width: 0;
    padding: 0 6px 6px;
  }
  .frame-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
    padding: 5px 2px 6px;
    overflow: hidden;
    font-size: 12px;
    white-space: nowrap;
  }
  .frame-bar strong { flex: none; font-weight: 600; }
  .frame-right { display: flex; align-items: center; gap: 10px; min-width: 0; }
  .frame-right .tag { flex: none; }
  #frameTitle { min-width: 0; overflow: hidden; text-overflow: ellipsis; color: var(--shell-muted); }
  iframe {
    display: block;
    width: 100%;
    height: 100%;
    border: 0;
    outline: 1px dashed var(--accent);
    outline-offset: 2px;
    background: #fff;
  }

  .dock {
    max-height: 30vh;
    overflow-y: auto;
    margin-top: 9px;
    padding: 8px 12px;
    border-top: 1px dashed var(--accent);
  }
  .dock-head { display: flex; align-items: center; gap: 8px; color: var(--shell-muted); font-size: 12px; }
  .dock-cols { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-top: 6px; }
  .dock h2 { margin: 0 0 2px; font-size: 12px; font-weight: 500; color: var(--shell-muted); }
  .dock ul, .dock ol { margin: 0; padding-left: 18px; }
</style>
</head>
<body>
  <aside class="side" aria-label="切换要看的内容">
    <div class="side-head">
      <span class="tag">设计说明 · 不属于页面</span>
      <h1 id="sideTitle"></h1>
      <p id="sideVersion"></p>
    </div>
    <div class="scheme" id="schemeBox" hidden>
      <h2 id="schemeHint"></h2>
      <div class="pick" id="schemePick"></div>
    </div>
    <div class="side-body">
      <h2>切换要看的内容</h2>
      <h3>页面</h3>
      <div class="pick" id="pagePick"></div>
      <h3 id="stateLabel"></h3>
      <div class="pick" id="statePick"></div>
    </div>
  </aside>

  <main>
    <div class="frame-bar">
      <strong>▼ 被设计的页面：只有这个框里的内容要实现</strong>
      <div class="frame-right">
        <span class="tag" id="frameScheme" hidden></span>
        <span id="frameTitle"></span>
      </div>
    </div>
    <iframe id="stage" title="被设计的页面" sandbox="allow-scripts"></iframe>
    <section class="dock" id="dock" aria-label="页面说明">
      <div class="dock-head">
        <span class="tag">设计说明 · 不属于页面</span>
        <span>这一块上线后不存在</span>
      </div>
      <div class="dock-cols">
        <div><h2>这个画面的说明</h2><ul id="noteList"></ul></div>
        <div><h2>只在原型里成立</h2><ul id="fakeList"></ul></div>
        <div><h2>还没确认的问题</h2><ol id="openList"></ol></div>
      </div>
    </section>
  </main>

<script>
  window.addEventListener('error', (e) => {
    window.prototypeBroken = true;
    const reason = String(e.message).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    document.getElementById('frameTitle').textContent = '原型填写有误';
    document.getElementById('stage').srcdoc = `<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0;padding:16px;font:14px/1.6 Menlo,Consolas,monospace;color:#b42318;background:#fff"><strong>原型填写有误，这不是正式页面。</strong><br>${reason}</body></html>`;
  });
</script>

<script>
/* PROTOTYPE-START
   只改 PROTOTYPE-START 到 PROTOTYPE-END 之间的内容，这段之外是外壳，一律不改。

   title：原型标题。version：第几版，每次按用户意见改完加 1。
   css：项目有自己的设计时，在这里写项目的样式，写了之后默认页面样式完全不生效。
     项目没有自己的设计时不写这一项，框里用默认页面样式，可以直接用的元素有
     header、h1、main、.card、table、button、button.plain、.center、.alert、.bar、dl、.cards。
     终端页面固定用外壳自带的样式。
   openQuestions：还没确认的问题。多方案时外壳会自动在最前面加上"选哪个方案"。
   schemes：方案列表。id 用于 html 取值，label 是"方案 A"这样的短名，desc 是方案特点，
     note 是方案取舍。只有一个方案时只留一项，外壳不显示任何方案切换。
   pages：要设计的页面，每页一项。
     id、name：页面标识和名字。fake：这页只在原型里成立的内容（假数据、假操作）。
     stateLabel：第二组按钮的名字，多步交互写"步骤"，其他情况不写。
     terminal：终端界面写 true。这时 html 写终端里的文字，颜色用
       <span class="g">绿</span>、<span class="y">黄</span>、<span class="b">蓝</span>、<span class="r">红</span>。
       终端文字里的 < 和 & 要写成 &lt; 和 &amp;，否则会被当成标签吞掉。
     states：这页的状态或步骤，每项有 id、name、note（说明，每条一句）、html（框里的内容）。
       html 各方案相同时写字符串；不同时写 { 方案id: 内容 }，比如 { a: '...', b: '...' }，每个方案都要写。
     note、fake、openQuestions 都是数组，每条一句，没内容写 []。

   框里的跳转：给元素加 data-go="页面id:状态id"，点击后框和左栏一起切换。
   框里的普通链接和表单不会跳走，alert、localStorage 也用不了，这些效果都用 data-go 切换状态来演示。
   html 里需要 script 结束标签时，斜杠前要加反斜杠，写成 <\/script>，否则这段脚本会提前结束。
*/
const orderRows = [
  ['A1024', '王小明', '¥ 320'],
  ['A1023', '李华', '¥ 128'],
  ['A1022', '张伟', '¥ 2,450'],
];
const skeleton = '<div class="card"><div class="bar"></div><div class="bar"></div><div class="bar"></div><div class="bar"></div></div>';
const listHead = (withExport) => `<header><h1>订单</h1>${withExport ? '<button>导出</button>' : ''}</header>`;
const detailHead = '<header><h1>订单 A1024</h1><button class="plain" data-go="list:normal">返回订单列表</button></header>';

const PROTOTYPE = {
  title: '订单导出（示例）',
  version: 1,
  openQuestions: [
    '导出的文件用 CSV 还是 Excel',
    '订单超过一万笔时怎么导出',
    '哪些角色可以导出订单',
  ],
  schemes: [
    { id: 'a', label: '方案 A', desc: '表格', note: '方案 A 用表格，一屏能看到更多订单，方便比较金额。' },
    { id: 'b', label: '方案 B', desc: '卡片', note: '方案 B 用卡片，金额更醒目，但一屏看到的订单更少。' },
  ],
  pages: [
    {
      id: 'list',
      name: '订单列表',
      fake: ['订单都是编的假数据。', '点「导出」在这个原型里没有反应。'],
      states: [
        {
          id: 'normal',
          name: '正常',
          note: ['用户打开页面后看到的样子。', '点任意一笔订单，进入订单详情，左栏的选中项也跟着变。'],
          html: {
            a: listHead(true) + `<main><div class="card"><table>
              <thead><tr><th>订单号</th><th>客户</th><th>金额</th></tr></thead>
              <tbody>${orderRows.map(([id, who, money]) => `<tr data-go="detail:normal"><td>${id}</td><td>${who}</td><td>${money}</td></tr>`).join('')}</tbody>
            </table></div></main>`,
            b: listHead(true) + `<main><div class="cards">${orderRows.map(([id, who, money]) => `<div class="card" data-go="detail:normal"><strong>${money}</strong>${who}<br><span>${id}</span></div>`).join('')}</div></main>`,
          },
        },
        {
          id: 'empty',
          name: '空数据',
          note: ['一笔订单都没有时的样子。', '此时没有东西可导出，右上角不显示「导出」按钮。'],
          html: listHead(false) + '<main><div class="card center">还没有订单</div></main>',
        },
        {
          id: 'loading',
          name: '加载中',
          note: ['数据还没回来时，用灰色条占位，页面不会突然跳动。'],
          html: listHead(false) + `<main>${skeleton}</main>`,
        },
        {
          id: 'error',
          name: '出错',
          note: ['加载失败时说清楚发生了什么，并给「重试」按钮。', '点「重试」回到正常状态。'],
          html: listHead(false) + '<main><div class="alert">订单加载失败，请检查网络后重试。</div><p><button data-go="list:normal">重试</button></p></main>',
        },
      ],
    },
    {
      id: 'detail',
      name: '订单详情',
      fake: ['订单内容是编的假数据。', '点「重试」只切换这个原型的显示，不发请求。'],
      states: [
        {
          id: 'normal',
          name: '正常',
          note: ['这一页只有一笔订单，不存在空数据的情况，所以少一个状态。', '点「返回订单列表」回到订单列表。'],
          html: detailHead + `<main><div class="card"><dl>
            <dt>客户</dt><dd>王小明</dd><dt>金额</dt><dd>¥ 320</dd><dt>下单时间</dt><dd>2026-11-01 10:24</dd>
          </dl></div></main>`,
        },
        {
          id: 'loading',
          name: '加载中',
          note: ['详情还没回来时的占位样子。'],
          html: detailHead + `<main>${skeleton}</main>`,
        },
        {
          id: 'error',
          name: '出错',
          note: ['这笔订单读取失败时的样子。', '点「重试」回到正常状态。'],
          html: detailHead + '<main><div class="alert">这笔订单读取失败。</div><p><button data-go="detail:normal">重试</button></p></main>',
        },
      ],
    },
    {
      id: 'cli',
      name: '终端界面（举例）',
      stateLabel: '步骤',
      terminal: true,
      fake: ['命令 shop export 是编的举例。', '进度和文件名都是假数据，不会真的生成文件。'],
      states: [
        {
          id: 'step1',
          name: '第 1 步：确认',
          note: ['终端界面也用同一个外框。', '框里就是终端全屏的样子：内容从左上角开始，按 80 列换行。', '多步交互放在左栏按步骤切换。'],
          html: '<span class="b">$</span> shop export --month 2026-10\n\n本次导出 <span class="y">312</span> 笔订单，继续吗？(y/N) ',
        },
        {
          id: 'step2',
          name: '第 2 步：进度',
          note: ['用户按 y 之后显示进度条。'],
          html: '<span class="b">$</span> shop export --month 2026-10\n\n本次导出 <span class="y">312</span> 笔订单，继续吗？(y/N) y\n\n[<span class="g">████████████</span>        ] 60%  187/312',
        },
        {
          id: 'step3',
          name: '第 3 步：完成',
          note: ['导出结束后告诉用户文件存在哪里。'],
          html: '<span class="b">$</span> shop export --month 2026-10\n\n本次导出 <span class="y">312</span> 笔订单，继续吗？(y/N) y\n\n<span class="g">✓ 导出完成</span>  orders-2026-10.csv',
        },
      ],
    },
  ],
};
/* PROTOTYPE-END */
</script>

<script>
  (() => {
    if (window.prototypeBroken) return;

    const DEFAULT_PAGE_CSS = `
    * { box-sizing: border-box; }
    body { margin: 0; font: 14px/1.6 -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif; color: #1f2933; background: #f5f7fa; }
    header { display: flex; align-items: center; justify-content: space-between; padding: 14px 24px; background: #fff; border-bottom: 1px solid #e4e7eb; }
    h1 { margin: 0; font-size: 18px; }
    main { padding: 24px; }
    .card { padding: 20px; background: #fff; border: 1px solid #e4e7eb; border-radius: 8px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #e4e7eb; }
    th { color: #616e7c; font-weight: 500; }
    tbody tr { cursor: pointer; }
    tbody tr:hover { background: #f0f4f8; }
    button { padding: 6px 14px; border: 0; border-radius: 6px; background: #2563eb; color: #fff; font: inherit; cursor: pointer; }
    button.plain { background: #e4e7eb; color: #1f2933; }
    .center { padding: 56px 0; text-align: center; color: #616e7c; }
    .alert { padding: 12px 14px; border-radius: 6px; background: #fdecea; color: #b42318; }
    .bar { height: 14px; margin: 14px 0; border-radius: 4px; background: #e4e7eb; animation: pulse 1.2s infinite; }
    @keyframes pulse { 50% { opacity: .45; } }
    dl { display: grid; grid-template-columns: 90px 1fr; gap: 8px; margin: 0; }
    dt { color: #616e7c; } dd { margin: 0; }
    .cards { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; }
    .cards .card { cursor: pointer; }
    .cards .card:hover { background: #f0f4f8; }
    .cards strong { display: block; font-size: 18px; }
    .cards span { color: #616e7c; }
    `;
    const TERMINAL_CSS = `
      body { box-sizing: border-box; margin: 0; min-height: 100vh; padding: 8px; background: #0b1730; }
      pre { width: 80ch; max-width: 100%; margin: 0; color: #d7e6ff; font: 14px/1.5 Menlo, Consolas, monospace; white-space: pre-wrap; overflow-wrap: anywhere; }
      .g { color: #7ee7c1; } .y { color: #ffd479; } .b { color: #7fd4ff; } .r { color: #ff8f8f; }
    `;
    const FRAME_BRIDGE = `<script>document.addEventListener('click', (e) => {
      if (e.target.closest('a[href]')) e.preventDefault();
      const target = e.target.closest('[data-go]');
      if (target) parent.postMessage({ go: target.dataset.go }, '*');
    });<\/script>`;

    const { schemes, pages } = PROTOTYPE;
    const hasChoice = schemes.length > 1;
    const incomplete = hasChoice && schemes.find((scheme) => !scheme.note || !scheme.desc);
    if (incomplete) throw new Error(`${incomplete.label} 缺少 note 或 desc`);
    const el = (id) => document.getElementById(id);
    const schemeName = (scheme) => `${scheme.label}：${scheme.desc}`;
    const current = { scheme: schemes[0], page: pages[0], state: pages[0].states[0] };

    function pickButtons(box, items, selected, nameOf, onPick) {
      box.replaceChildren(...items.map((item) => {
        const button = document.createElement('button');
        button.textContent = nameOf(item);
        button.setAttribute('aria-pressed', String(item === selected));
        button.addEventListener('click', () => onPick(item));
        return button;
      }));
    }

    function fillList(box, lines) {
      box.replaceChildren(...(lines.length ? lines : ['无']).map((line) => {
        const item = document.createElement('li');
        item.textContent = line;
        if (!lines.length) item.style.listStyle = 'none';
        return item;
      }));
    }

    function differsByScheme(state) {
      return typeof state.html === 'object';
    }

    function chooseSchemeQuestion() {
      const labels = schemes.map((scheme) => scheme.label);
      return `选${labels.slice(0, -1).join('、')} 还是${labels[labels.length - 1]}`;
    }

    function frameDoc(page, state, scheme) {
      const html = differsByScheme(state) ? state.html[scheme.id] : state.html;
      if (html === undefined) throw new Error(`「${page.name} · ${state.name}」缺少${scheme.label} 的内容`);
      const css = page.terminal ? TERMINAL_CSS : PROTOTYPE.css || DEFAULT_PAGE_CSS;
      const body = page.terminal ? `<pre>${html}</pre>` : html;
      return `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body>${body}${FRAME_BRIDGE}</body></html>`;
    }

    function fillNotes(scheme, page, state) {
      const schemeNote = !hasChoice ? [] : [differsByScheme(state) ? scheme.note : '各方案在这个画面上一样。'];
      fillList(el('noteList'), [...schemeNote, ...(state.note ?? [])]);
      fillList(el('fakeList'), page.fake ?? []);
      fillList(el('openList'), [...(hasChoice ? [chooseSchemeQuestion()] : []), ...(PROTOTYPE.openQuestions ?? [])]);
    }

    function fitDock() {
      const dock = el('dock');
      dock.style.height = 'auto';
      let tallest = 0;
      for (const scheme of schemes) {
        for (const page of pages) {
          for (const state of page.states) {
            fillNotes(scheme, page, state);
            tallest = Math.max(tallest, dock.offsetHeight);
          }
        }
      }
      dock.style.height = `${tallest}px`;
      fillNotes(current.scheme, current.page, current.state);
    }

    function select(scheme, page, state) {
      Object.assign(current, { scheme, page, state });
      render();
    }

    function render() {
      const { scheme, page, state } = current;
      const doc = frameDoc(page, state, scheme);
      el('schemeBox').hidden = !hasChoice;
      el('frameScheme').hidden = !hasChoice;
      el('schemeHint').textContent = `这份原型有 ${schemes.length} 个方案，点这里切换对比`;
      el('frameScheme').textContent = schemeName(scheme);
      pickButtons(el('schemePick'), schemes, scheme, schemeName, (item) => select(item, page, state));
      pickButtons(el('pagePick'), pages, page, (item) => item.name, (item) => select(scheme, item, item.states[0]));
      pickButtons(el('statePick'), page.states, state, (item) => item.name, (item) => select(scheme, page, item));
      el('stateLabel').textContent = page.stateLabel || '状态';
      el('frameTitle').textContent = `${page.name} · ${state.name}`;
      fillNotes(scheme, page, state);
      el('stage').srcdoc = doc;
    }

    window.addEventListener('message', (e) => {
      if (e.source !== el('stage').contentWindow || typeof e.data?.go !== 'string') return;
      const [pageId, stateId] = e.data.go.split(':');
      const page = pages.find((item) => item.id === pageId);
      const state = page?.states.find((item) => item.id === stateId);
      if (state) select(current.scheme, page, state);
    });

    document.title = `${PROTOTYPE.title} · 原型`;
    el('sideTitle').textContent = PROTOTYPE.title;
    el('sideVersion').textContent = `第 ${PROTOTYPE.version} 版 · 这一栏上线后不存在`;
    window.addEventListener('resize', fitDock);
    render();
    fitDock();
  })();
</script>
</body>
</html>
````

## 函数清单

外壳的函数已写在成品定义里，这里只说明本次新增的部分。

### plugins/bb-spec-workflow/templates/ui-preview-shell.html

| 函数名 | 职责 |
|---|---|
| `fillNotes` | 填底部三列说明 |
| `fitDock` | 量出所有画面里最高的底部高度并固定下来 |

## 协作关系

`render` → `fillNotes`。加载时 `render` 之后调用 `fitDock`，窗口大小变化时也调用。`frameDoc` 在普通页面用 `PROTOTYPE.css`，没写时用 `DEFAULT_PAGE_CSS`。无外部依赖。

## 验证方式

- 测试入口：`bash tests/ui-preview-shell.test.sh`，退出码 0 为通过；这个测试已存在，当前 461 项全过，要按新规则更新。
- 稳定契约：底部元素新增 id `dock`，外壳用 `el('dock')` 取它，读 `offsetHeight`，写 `style.height`。`window.addEventListener('resize', ...)` 注册重新计算。列表项空时 `li.style.listStyle` 为 `none`。`PROTOTYPE.css` 可以不写。
- 假 DOM 要给元素加 `style` 对象和 `offsetHeight`：`dock` 的 `offsetHeight` 可以按 `noteList`、`fakeList`、`openList` 里最多的条数算，比如 `40 + 条数 * 20`。
- 预期结果：
  - [ ] 文案更新：`schemeHint` 是「这份原型有 2 个方案，点这里切换对比」（3 个方案时是 3）；`frameScheme` 是「方案 A：表格」，切换后是「方案 B：卡片」，不再含「当前看的是」。隔离检查的外壳文字列表去掉「当前看的是」。
  - [ ] 框上方顺序：`被设计的页面` 文字在 `id="frameScheme"` 之前，`id="frameScheme"` 在 `id="frameTitle"` 之前，后两者都在 `class="frame-right"` 里。
  - [ ] 蓝图 CSS：`--shell-bg: #12264a`、`--accent: #7fd4ff`；`body` 规则块含 `background-image` 和等宽字体 `ui-monospace`；`.side` 规则块含 `border-right: 1px dashed var(--accent)`；`.tag`、`.scheme` 规则块含 `dashed`；`iframe` 规则块含 `outline: 1px dashed var(--accent)`；`.dock` 规则块含 `border-top: 1px dashed var(--accent)`；选中按钮规则含 `background: var(--accent)`；未选中按钮规则含 `background: transparent`；文件的外壳 CSS 不含 `border-radius`。
  - [ ] `.dock` 规则块含 `max-height: 30vh` 和 `overflow-y: auto`，不含 `height: 26vh`。
  - [ ] 默认样式：`PROTOTYPE.css` 不写、写空字符串时，普通页面 `srcdoc` 都含默认样式（比如 `.card`、`.alert`、`#2563eb`）；写了 `css` 时 `srcdoc` 含项目样式、不含默认样式的 `#2563eb`。外壳自带的示例数据不写 `css`。
  - [ ] 隔离：`srcdoc` 不含外壳的 `--shell-bg`、`--accent`；iframe 仍带 `sandbox="allow-scripts"`。
  - [ ] 终端：`srcdoc` 含 `background: #0b1730`、`#d7e6ff`、`#7ee7c1`、`#ffd479`、`#7fd4ff`、`#ff8f8f`，不含项目样式，也不含默认样式。
  - [ ] 空列：`fake`、`openQuestions` 都没内容时显示一条「无」，这条 `li` 的 `style.listStyle` 是 `none`；有内容时不是。
  - [ ] 底部高度：加载后 `dock.style.height` 等于所有方案、页面、状态里最大的 `offsetHeight`，并带 `px`；切换方案、页面、状态后 `dock.style.height` 不变；加载后 `noteList` 显示当前画面的说明，不是最后量过的画面。
  - [ ] 窗口变化：触发 `resize` 后重新计算，`noteList` 仍是当前画面的说明。
  - [ ] 首屏 render 抛错时不调用高度计算，错误提示不被覆盖，`noteList` 保持空。
  - [ ] 原有分组继续通过：框内跳转、链接拦截、填写错误、名字冲突、方案字段漏写、位置顺序。
