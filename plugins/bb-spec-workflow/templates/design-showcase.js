/* 设计规范展示页的固定部分。
   用法：把本文件全文复制到原型填写区 PROTOTYPE-START 那段说明的下面，再写项目自己的内容。
   - 项目样式 css 的末尾拼上 DS_CSS；终端页的 terminalCss 末尾拼上 DS_TERMINAL_CSS。
   - 项目样式里要按每套主题定义这 6 个变量，DS_CSS 靠它们跟着主题变：
     --ds-surface 卡片背景色、--ds-divider 分隔线色、--ds-text 正文文字色、
     --ds-text-2 次要文字色、--ds-border 控件边框色、--ds-accent 主色。
   - 对比框和标签的颜色是固定的，不要改。 */

// 按 WCAG 相对亮度公式算两个 #RRGGBB 颜色的对比度，返回保留一位小数的字符串
const dsLum = (hex) => {
  const c = [1, 3, 5]
    .map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((x) => (x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const dsContrast = (a, b) => ((Math.max(dsLum(a), dsLum(b)) + 0.05) / (Math.min(dsLum(a), dsLum(b)) + 0.05)).toFixed(1);

// 标签。kind：bad 现状不达标、good 建议或改之后、old 改之前、chg 本次修改或本次新增
const dsTag = (kind, text) => `<span class="ds-tag ds-tag-${kind}">${text}</span>`;

// 对比框。kind：bad 不达标（橙色虚线）、chg 本次修改或新增（紫色虚线）
// title：这一项的名字和所属主题；before、after：左右两格里的样例 HTML
// side：这一项所属主题的颜色，两格固定用它，不随右上角切换
const dsPair = (kind, title, before, after, side = { bg: '#FFFFFF', fg: '#0F172A', sub: '#475569', line: '#E2E8F0' }) => {
  const st = `background:${side.bg};color:${side.fg};border-color:${side.line};--ds-side-sub:${side.sub}`;
  return `<div class="ds-pair ds-pair-${kind}">
  <div class="ds-pair-title">${title}</div>
  <div class="ds-side" style="${st}">${dsTag(kind === 'bad' ? 'bad' : 'old', kind === 'bad' ? '现状 · 不达标' : '改之前')}${before}</div>
  <div class="ds-arrow">→</div>
  <div class="ds-side" style="${st}">${dsTag('good', kind === 'bad' ? '建议 · 本页按这个画' : '改之后')}${after}</div>
</div>`;
};
// 对比框里写值和原因的那一行
const dsWhy = (text) => `<p class="ds-why">${text}</p>`;

const DS_CSS = `
.ds-page{max-width:1040px;margin:0 auto;padding:24px;color:var(--ds-text)}
.ds-summary{margin-top:16px;padding:12px 16px;border-radius:8px;background:var(--ds-surface);border:1px solid var(--ds-divider)}
.ds-summary-bad{border:2px dashed #D97706}
.ds-summary-chg{border:2px dashed #6366F1}
.ds-summary p{margin:0}.ds-summary ol{margin:8px 0;padding-left:24px}
.ds-sec{margin-top:32px}
.ds-note{margin:0 0 12px;color:var(--ds-text-2);font-size:12px;line-height:20px}
.ds-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(184px,1fr));gap:12px}
.ds-swatch{background:var(--ds-surface);border:1px solid var(--ds-divider);border-radius:8px;overflow:hidden}
.ds-chip{height:56px;border-bottom:1px solid var(--ds-divider)}
.ds-meta{padding:8px 12px}
.ds-meta code,.ds-meta span,.ds-box-wrap code,.ds-box-wrap span{display:block;color:var(--ds-text-2);font-size:12px;line-height:20px}
.ds-rows{display:grid;gap:8px}
.ds-row{display:grid;grid-template-columns:160px 1fr;align-items:center;gap:12px}
.ds-label{color:var(--ds-text-2);font-size:12px;line-height:20px}.ds-label small{display:block;font-size:12px}
.ds-bar{display:block;height:16px;background:var(--ds-accent);border-radius:4px}
.ds-box-wrap strong{display:block;margin-top:8px}
.ds-box{height:64px;background:var(--ds-surface);border:1px solid var(--ds-border)}
.ds-move{transition-property:transform,background-color;transition-timing-function:ease-out}
.ds-move:hover{transform:translateX(24px);background:var(--ds-accent)}
.ds-states{display:grid;grid-template-columns:96px repeat(5,minmax(0,1fr));gap:16px 12px;align-items:center}
.ds-th{color:var(--ds-text-2);font-size:12px;line-height:20px;font-weight:600}
.ds-none{color:var(--ds-text-2);font-size:12px;line-height:20px}
.ds-mask{background:rgba(15,23,42,.48);border-radius:8px;padding:32px;display:flex;justify-content:center}
.ds-stack{display:grid;gap:8px}
.ds-tag{display:inline-block;font:600 12px/20px system-ui,sans-serif;padding:0 8px;border-radius:4px;vertical-align:middle}
.ds-tag-bad{background:#FDE68A;color:#422006}
.ds-tag-good{background:#BBF7D0;color:#052E16}
.ds-tag-old{background:#E2E8F0;color:#0F172A}
.ds-tag-chg{background:#C7D2FE;color:#1E1B4B}
.ds-pair{display:grid;grid-template-columns:1fr 24px 1fr;gap:12px;align-items:stretch;border-radius:8px;padding:12px;margin-top:12px}
.ds-pair-bad{border:2px dashed #D97706}
.ds-pair-chg{border:2px dashed #6366F1}
.ds-pair-title{grid-column:1/-1;font-weight:600}
.ds-pair-title .ds-tag{margin-left:8px}
.ds-arrow{align-self:center;text-align:center;color:var(--ds-text-2)}
.ds-side{border:1px solid;border-radius:8px;padding:12px}
.ds-side>.ds-tag{margin-bottom:12px}
.ds-side p{margin:0 0 4px}
.ds-side code{display:block;color:var(--ds-side-sub);margin-top:8px}
.ds-side .ds-why,.ds-side .ds-none{color:var(--ds-side-sub);font-size:12px;line-height:20px;margin:4px 0 0}
`;

// 终端展示页里的标签：<span class="ds-t-bad"> 现状 · 不达标 </span> 这样用
const DS_TERMINAL_CSS = `
.ds-t-bad{background:#FDE68A;color:#422006}
.ds-t-good{background:#BBF7D0;color:#052E16}
.ds-t-old{background:#E2E8F0;color:#0F172A}
.ds-t-chg{background:#C7D2FE;color:#1E1B4B}
`;
