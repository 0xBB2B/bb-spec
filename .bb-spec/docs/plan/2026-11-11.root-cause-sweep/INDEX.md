# root-cause-sweep 实施计划
## 阶段 1：同根因位置
- [01-same-cause-fix](01-same-cause-fix.md) — /revise 搜全同根因位置并一起修；代码纪律写明范围；实现子代理上报表外位置
## 阶段 2：审查与收尾
- [02-review-completeness](02-review-completeness.md) — 审查附同类位置；测试缺口当轮补；分支自查的测试缺口推送前补 [依赖: 01-same-cause-fix]
- [03-unrelated-findings](03-unrelated-findings.md) — 无关发现只记不改，收尾合成清单一次问 [依赖: 02-review-completeness]
