---
name: 01-preview-shell-template
description: 随插件发布统一的原型外壳文件，并用测试保住它的排版和切换行为
---
# 原型外壳文件

## 目标

插件带一个固定的 HTML 外壳，复制后只填内容，就能得到左栏切换、框里只放正式页面、底部写说明的原型。

## 业务规则（来源：PRD 01-preview-shell）

外壳分三块：左栏在左，框在右上，底部说明在框的下方。框里的内容才要做进产品，框里与外壳完全隔开，框里读不到「设计说明」「被设计的页面」「只在原型里成立」「当前看的是」这些文字，框里的链接和表单不会让框离开当前页面。

- 外观：深色外壳、琥珀色竖线分隔左右、选中项琥珀底、框周围浅灰；外壳颜色不随框里内容变化。
- 左栏顶部：标签「设计说明 · 不属于页面」、原型标题、「第 N 版 · 这一栏上线后不存在」。下面是「切换要看的内容」，分「页面」和「状态」两组；多步交互页面的第二组叫「步骤」。
- 框上方：左边「▼ 被设计的页面：只有这个框里的内容要实现」，右边「<页面名> · <状态名>」。
- 底部：标签「设计说明 · 不属于页面」和「这一块上线后不存在」，三列标题依次是「这个画面的说明」「只在原型里成立」「还没确认的问题」。后两列没内容或漏写时显示「无」。
- 底部固定占窗口高度 26%，切换时框高度不变，说明太长只在底部内部滚动。
- 点左栏按钮，框、框上方提示、底部说明都更新。框里的页面自己跳转时，这三处同步更新，当前方案保持不变。
- 2 个及以上方案：左栏在标题下方、其他切换按钮上方显示单独描边的切换框，标题「有 N 个方案，点这里切换对比」；框上方提示语后显示「当前看的是 <方案名>」。切方案时页面和状态不变。只有 1 个方案时，切换框和方案标签都不显示。
- 多方案时，「这个画面的说明」第一条写当前方案的取舍；各方案没差别的画面写「各方案在这个画面上一样。」
- 多方案时，「还没确认的问题」第一条自动生成：2 个方案写「选方案 A 还是方案 B」，3 个及以上写「选方案 A、方案 B 还是方案 C」。
- 终端界面：内容从左上角开始（8 像素边距），底色铺满框，等宽字体，80 列换行，内容没超出时没有滚动条。
- 原型内容填错时（语法错误、某个方案缺内容等），框里显示「原型填写有误，这不是正式页面。」和错误原因，框上方右边显示「原型填写有误」，不出现空白页。填写内容用了和外壳内部相同的名字时，原型照常显示。
- 一个 HTML 文件，双击打开，不联网、不构建，不引用外部资源。窗口窄于 960 像素时横向滚动，三块布局不变。

## 涉及文件

- `plugins/bb-spec-workflow/templates/ui-preview-shell.html`（新建）
- `tests/ui-preview-shell.test.sh`（新建）

## 成品定义

`plugins/bb-spec-workflow/templates/ui-preview-shell.html` 按下面内容原样落盘。这份内容和用户确认过的预览外观一致，自带的订单数据是填写示例。

````html
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>界面原型</title>
<style>
  :root {
    --shell-bg: #141c28;
    --shell-raised: #1f2a3a;
    --shell-line: #2c3a4e;
    --shell-text: #e6eaf0;
    --shell-muted: #9aa7b8;
    --amber: #f0b64f;
    --amber-ink: #2a1d05;
    --frame-bg: #c9cdd6;
    --frame-text: #2a3240;
  }
  * { box-sizing: border-box; }
  [hidden] { display: none !important; }
  html, body { height: 100%; margin: 0; }
  body {
    min-width: 960px;
    display: grid;
    grid-template-columns: 240px 1fr;
    font: 13px/1.6 -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif;
    background: var(--frame-bg);
  }
  .tag {
    display: inline-block;
    padding: 1px 8px;
    border-radius: 4px;
    background: var(--amber);
    color: var(--amber-ink);
    font-size: 12px;
    font-weight: 600;
  }

  .side {
    height: 100vh;
    overflow-y: auto;
    background: var(--shell-bg);
    color: var(--shell-text);
    border-right: 4px solid var(--amber);
  }
  .side-head { padding: 14px 14px 12px; border-bottom: 1px solid var(--shell-line); }
  .side-head h1 { margin: 10px 0 2px; font-size: 15px; }
  .side-head p { margin: 0; font-size: 12px; color: var(--shell-muted); }
  .scheme {
    margin: 12px 14px 0;
    padding: 10px;
    border: 2px solid var(--amber);
    border-radius: 8px;
  }
  .scheme h2 { margin: 0 0 8px; font-size: 13px; font-weight: 600; color: var(--amber); }
  .side-body { padding: 14px; }
  .side-body h2 { margin: 0 0 6px; font-size: 12px; font-weight: 500; color: var(--shell-muted); }
  .side-body h3 { margin: 14px 0 6px; font-size: 12px; font-weight: 500; color: var(--shell-muted); }
  .pick { display: flex; flex-direction: column; gap: 5px; }
  .pick button {
    padding: 6px 10px;
    border: 0;
    border-radius: 6px;
    background: var(--shell-raised);
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: pointer;
  }
  .pick button:hover { background: var(--shell-line); }
  .pick button[aria-pressed="true"] { background: var(--amber); color: var(--amber-ink); font-weight: 600; }

  main {
    display: grid;
    grid-template-rows: auto minmax(0, 1fr) auto;
    height: 100vh;
    min-width: 0;
    padding: 0 10px 10px;
  }
  .frame-bar {
    display: flex;
    justify-content: space-between;
    gap: 16px;
    padding: 5px 2px;
    overflow: hidden;
    color: var(--frame-text);
    font-size: 12px;
    white-space: nowrap;
  }
  .frame-bar strong { font-weight: 600; }
  .frame-left { display: flex; flex: none; align-items: center; gap: 8px; }
  #frameTitle { min-width: 0; overflow: hidden; text-overflow: ellipsis; }
  iframe {
    display: block;
    width: 100%;
    height: 100%;
    border: 1px solid #8f96a3;
    border-radius: 4px;
    background: #fff;
  }

  .dock {
    height: 26vh;
    overflow-y: auto;
    margin-top: 10px;
    padding: 10px 14px 12px;
    border-top: 3px solid var(--amber);
    border-radius: 0 0 4px 4px;
    background: var(--shell-bg);
    color: var(--shell-text);
  }
  .dock-head { display: flex; align-items: center; gap: 8px; color: var(--shell-muted); font-size: 12px; }
  .dock-cols { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; margin-top: 8px; }
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
      <div class="frame-left">
        <strong>▼ 被设计的页面：只有这个框里的内容要实现</strong>
        <span class="tag" id="frameScheme" hidden></span>
      </div>
      <span id="frameTitle"></span>
    </div>
    <iframe id="stage" title="被设计的页面" sandbox="allow-scripts"></iframe>
    <section class="dock" aria-label="页面说明">
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
   css：框里普通页面的样式。终端页面用外壳自带的样式。
   openQuestions：还没确认的问题。多方案时外壳会自动在最前面加上"选哪个方案"。
   schemes：方案列表。id 用于 html 取值，label 是"方案 A"这样的短名，desc 是方案特点，
     note 是方案取舍。只有一个方案时只留一项，外壳不显示任何方案切换。
   pages：要设计的页面，每页一项。
     id、name：页面标识和名字。fake：这页只在原型里成立的内容（假数据、假操作）。
     stateLabel：第二组按钮的名字，多步交互写"步骤"，其他情况不写。
     terminal：终端界面写 true。这时 html 写终端里的文字，颜色用
       <span class="g">绿</span>、<span class="y">黄</span>、<span class="b">蓝</span>。
       终端文字里的 < 和 & 要写成 &lt; 和 &amp;，否则会被当成标签吞掉。
     states：这页的状态或步骤，每项有 id、name、note（说明，每条一句）、html（框里的内容）。
       html 各方案相同时写字符串；不同时写 { 方案id: 内容 }，比如 { a: '...', b: '...' }，每个方案都要写。
     note、fake、openQuestions 都是数组，每条一句，没内容写 []。

   框里的跳转：给元素加 data-go="页面id:状态id"，点击后框和左栏一起切换。
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
  css: `
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
  `,
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

    const TERMINAL_CSS = `
      body { box-sizing: border-box; margin: 0; min-height: 100vh; padding: 8px; background: #15181e; }
      pre { width: 80ch; max-width: 100%; margin: 0; color: #d7dde4; font: 14px/1.5 Menlo, Consolas, monospace; white-space: pre-wrap; overflow-wrap: anywhere; }
      .g { color: #7ee787; } .y { color: #e3b341; } .b { color: #79c0ff; }
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
      const css = page.terminal ? TERMINAL_CSS : PROTOTYPE.css;
      const body = page.terminal ? `<pre>${html}</pre>` : html;
      return `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body>${body}${FRAME_BRIDGE}</body></html>`;
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
      el('schemeHint').textContent = `有 ${schemes.length} 个方案，点这里切换对比`;
      el('frameScheme').textContent = `当前看的是 ${schemeName(scheme)}`;
      pickButtons(el('schemePick'), schemes, scheme, schemeName, (item) => select(item, page, state));
      pickButtons(el('pagePick'), pages, page, (item) => item.name, (item) => select(scheme, item, item.states[0]));
      pickButtons(el('statePick'), page.states, state, (item) => item.name, (item) => select(scheme, page, item));
      el('stateLabel').textContent = page.stateLabel || '状态';
      el('frameTitle').textContent = `${page.name} · ${state.name}`;
      const schemeNote = !hasChoice ? [] : [differsByScheme(state) ? scheme.note : '各方案在这个画面上一样。'];
      fillList(el('noteList'), [...schemeNote, ...(state.note ?? [])]);
      fillList(el('fakeList'), page.fake ?? []);
      fillList(el('openList'), [...(hasChoice ? [chooseSchemeQuestion()] : []), ...(PROTOTYPE.openQuestions ?? [])]);
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
    render();
  })();
</script>
</body>
</html>
````

## 函数清单

外壳的函数已在成品定义里写全，这里只说明职责。

### plugins/bb-spec-workflow/templates/ui-preview-shell.html

| 函数名 | 职责 |
|---|---|
| `pickButtons` | 生成一组切换按钮并标出选中项 |
| `fillList` | 填一列说明，没有内容时显示「无」 |
| `differsByScheme` | 判断这个画面各方案是否不同 |
| `chooseSchemeQuestion` | 生成"选哪个方案"的问题 |
| `frameDoc` | 拼出框里的独立页面 |
| `select` | 记下当前方案、页面、状态并刷新 |
| `render` | 按当前选择刷新左栏、框上方提示、框和底部说明 |
| `error` 事件监听（填写区之前的脚本） | 把填写错误显示在框里 |

## 协作关系

点左栏按钮或框里的 `data-go` 元素 → `select` → `render` → `frameDoc`。框里的点击通过 `postMessage` 传给外壳，框里的脚本拦下链接跳转，框的权限限制挡住表单提交。外壳脚本包在立即执行函数里，名字不和填写区冲突。无外部依赖。

## 验证方式

- 测试入口：`bash tests/ui-preview-shell.test.sh`，退出码 0 为通过；和其他测试脚本一样由 CI 的 `tests/*.sh` 循环自动执行。
- 测试输入：外壳文件 `plugins/bb-spec-workflow/templates/ui-preview-shell.html`。文件里 `/* PROTOTYPE-START` 到 `/* PROTOTYPE-END */` 之间是可替换的填写区，要定义 `const PROTOTYPE`，结构如下：`{ title, version, css, openQuestions: [文字], schemes: [{ id, label, desc, note }], pages: [{ id, name, fake: [文字], stateLabel?, terminal?, states: [{ id, name, note: [文字], html: 字符串或 { 方案id: 字符串 } }] }] }`。
- 外壳稳定的元素 id：`schemeBox`、`schemeHint`、`schemePick`、`pagePick`、`statePick`、`stateLabel`、`frameScheme`、`frameTitle`、`stage`（iframe，内容写在 `srcdoc`）、`noteList`、`fakeList`、`openList`、`sideTitle`、`sideVersion`。按钮选中时 `aria-pressed="true"`。框里的元素加 `data-go="页面id:状态id"`，点击后框里向外壳发 `postMessage({ go: '页面id:状态id' })`。
- 行为测试用 Node 自带的 `vm` 加载文件里的脚本，自己写一个最小的假 DOM，不装任何第三方包；本机没有 `node` 时报错退出，不要跳过。
- 预期结果：
  - [ ] 文件含全部固定文案：「设计说明 · 不属于页面」「这一栏上线后不存在」「切换要看的内容」「▼ 被设计的页面：只有这个框里的内容要实现」「这一块上线后不存在」「这个画面的说明」「只在原型里成立」「还没确认的问题」。
  - [ ] 文件不引用外部资源：没有 `http://`、`https://`、`<link`、`<script src`、`@import`。
  - [ ] 正式页面放在 iframe 里，底部高度写成 `26vh`，`body` 最小宽度写成 `960px`。
  - [ ] 默认数据下：标题、版本文字正确；`schemeHint` 是「有 2 个方案，点这里切换对比」；`frameScheme` 是「当前看的是 方案 A：表格」；`frameTitle` 是「订单列表 · 正常」。
  - [ ] 切方案后页面和状态不变；切页面后状态回到该页第一项；切页面后 `stateLabel` 在普通页面是「状态」，在终端页面是「步骤」。
  - [ ] 收到 `{ go: 'detail:normal' }` 后三处内容同步，当前方案不变；`go` 指向不存在的页面或状态时不变化。
  - [ ] 各方案不同的画面，`noteList` 第一条是当前方案的 `note`；相同的画面第一条是「各方案在这个画面上一样。」
  - [ ] 2 个方案时 `openList` 第一条是「选方案 A 还是方案 B」；3 个方案时是「选方案 A、方案 B 还是方案 C」。
  - [ ] 只留 1 个方案时，`schemeBox`、`frameScheme` 都是隐藏的，`noteList`、`openList` 不出现方案相关内容。
  - [ ] `fake`、`openQuestions` 都为空且只有 1 个方案时，`fakeList`、`openList` 各显示一条「无」。
  - [ ] 终端页面的 `srcdoc` 含 `<pre>`、`80ch`、`box-sizing: border-box`，不含 `PROTOTYPE.css` 的内容；普通页面的 `srcdoc` 含 `PROTOTYPE.css` 的内容。
  - [ ] 任何组合下 `srcdoc` 都不含「设计说明」「被设计的页面」「只在原型里成立」「当前看的是」。
