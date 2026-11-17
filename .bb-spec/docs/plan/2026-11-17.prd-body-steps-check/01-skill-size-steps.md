---
name: skill-size-steps
description: skill-size 测试去掉 prd references 文件数上限，改为按小节检查步骤 0 到 5 的关键句、步骤 1 到 5 不许有先读提示
---
# skill-size 测试：查步骤 0 到 5 留在正文

## 目标
`tests/skill-size.test.sh` 不再限制 `prd/references/` 的文件个数；改为检查 `prd/SKILL.md` 步骤 0 到 5 的标题都在、各自关键句在自己的小节里、步骤 1 到 5 的小节里没有"走到这一步先读"。

## 业务规则（来源：PRD 2026-11-17.prd-body-steps-check 的 body-steps-check）
- 不再限制 `prd/references/` 下的文件个数。
- 6 个标题必须在正文：`### 步骤 0：读取配置 + 现状扫描`、`### 步骤 1：意图定性`、`### 步骤 2：质疑（对用户可见）`、`### 步骤 3：澄清与发散`、`### 步骤 4：收敛与拆解`、`### 步骤 5：方案质检`；缺哪个就失败并写明。
- 关键句必须在所属小节（标题行到下一个同级或更高级标题之前，只看 SKILL.md）：步骤 0 `**重叠判定**`；步骤 1 `用一句话复述**要解决的问题**`；步骤 2 `有没有更便宜的替代`；步骤 3 `**怎么呈现选项**`；步骤 4 `钉死**目标**与**非目标**`；步骤 5 `是否可证伪`。不在就失败并写明哪一步缺哪句。
- 步骤 1 到 5 的小节出现"走到这一步先读"就失败并写明哪一步；步骤 0 不查。
- 其余检查不变：正文字节上限、references 每个文件 ≥ 600 字节、正文指到的 references 路径存在、每个 references 文件名在正文出现、`## 四样东西各管什么` 和 `**一条约束放哪**` 在正文。
- 理由：文件数只是近似，挡住合理拆分、拦不住把步骤搬出去；只查"正文里出现过"会被别处的同一句话骗过；搬步骤一定留下先读提示。

## 涉及文件
- `tests/skill-size.test.sh`（修改）
- `tests/prd-body-steps-guard.test.sh`（新建，由测试子代理写：复制被测文件到临时目录、改坏后跑 skill-size 测试看结果）

## 成品定义（`tests/skill-size.test.sh` 的改动，原样落盘）

1. 删掉第 8 行 `PRD_MAX_REFS=4`。
2. 删掉整段「prd/references 文件数不超过」检查：从 `echo "[prd/references 文件数不超过 ${PRD_MAX_REFS}]"` 起，到 `if [[ "$prd_refs" -le "$PRD_MAX_REFS" ]]; then pass; else fail ...; fi` 这一行止（含两端）。
3. 把「prd 每次都走的步骤全文留在正文」那段（`echo "[prd 每次都走的步骤全文留在正文]"` 起到对应 `done` 止）整段替换为：

```bash
echo "[prd 正文保留的总览段落]"
for t in '## 四样东西各管什么' '**一条约束放哪**'; do
  has_skill prd "$t"
done
```

4. 在「先读提示放在对应步骤」那段（以 `echo "[先读提示放在对应步骤]"` 开头、以 `has_skill git-push 'references/ocr-review.md'` 结尾）之后，空一行，插入：

```bash
# 每项是「步骤标题|这一步的关键句」；关键句必须在这一步自己的小节里
PRD_STEPS=(
  '### 步骤 0：读取配置 + 现状扫描|**重叠判定**'
  '### 步骤 1：意图定性|用一句话复述**要解决的问题**'
  '### 步骤 2：质疑（对用户可见）|有没有更便宜的替代'
  '### 步骤 3：澄清与发散|**怎么呈现选项**'
  '### 步骤 4：收敛与拆解|钉死**目标**与**非目标**'
  '### 步骤 5：方案质检|是否可证伪'
)

echo "[prd 步骤 0 到 5 的关键句在各自小节里]"
for e in "${PRD_STEPS[@]}"; do
  section_has prd "${e%%|*}" "${e#*|}"
done

echo "[prd 步骤 1 到 5 的小节里没有先读提示]"
for e in "${PRD_STEPS[@]:1}"; do
  head="${e%%|*}"
  body="$(skill_section prd "$head")"
  if [[ -z "$body" ]]; then fail "prd/SKILL.md 找不到标题：${head}"; continue; fi
  if printf '%s\n' "$body" | grep -F -- '走到这一步先读' >/dev/null; then
    fail "prd/SKILL.md「${head}」一节不应出现：走到这一步先读"
  else
    pass
  fi
done
```

说明：`grep` 不用 `-q`，与已有 `section_has` 一致——`set -o pipefail` 下 `grep -q` 提前退出会让 `printf` 收到 SIGPIPE、整条管道判失败。

## 函数清单
### tests/skill-size.test.sh
| 函数名 | 职责 |
|---|---|
| `skill_section`（已有，不改） | 取 SKILL.md 里某个标题到下一个同级或更高级标题之间的内容 |
| `section_has`（已有，不改） | 标题找不到或小节里没有指定文字时记失败 |

## 协作关系
新增两段检查复用已有的 `skill_section`、`section_has`、`pass`、`fail`，必须放在这些函数定义之后。

## 验证方式
- 测试入口：新建 `tests/prd-body-steps-guard.test.sh`，写法仿照 `tests/rule-test-missing-file.test.sh`（`mktemp -d` 建临时目录，把 `tests/skill-size.test.sh` 和 `plugins/bb-spec-workflow/skills/{git-push,prd,revise}` 按原相对路径复制进去，在副本上改坏后用 `bash <副本>/tests/skill-size.test.sh` 跑，看退出码和输出；每个场景用全新副本；结束清理临时目录；PASS/FAIL 计数，有失败非 0 退出）。
- 场景与预期：
  1. 不改动 → 退出码 0；输出不含 `文件数不超过`。
  2. 在副本 `prd/references/` 新建 `extra.md`（第一行 `> 用在 /prd 步骤 7：测试用`，总共不少于 1200 字节），并在副本 `prd/SKILL.md` 的 `### 步骤 7：落盘` 一节末尾加一行 `走到这一步先读 \`references/extra.md\`（相对本 skill 目录）。` → 退出码 0。
  3. 副本 `prd/SKILL.md` 中 `### 步骤 2：质疑（对用户可见）` 与 `### 步骤 3：澄清与发散` 之间的内容整体换成一行 `走到这一步先读 \`references/repo-layout.md\`（相对本 skill 目录）。` → 退出码非 0；输出含 `「### 步骤 2：质疑（对用户可见）」一节缺少：有没有更便宜的替代`，并含 `「### 步骤 2：质疑（对用户可见）」一节不应出现：走到这一步先读`。
  4. 把含 `用一句话复述**要解决的问题**` 的那一行从步骤 1 小节删掉、加到步骤 3 小节里 → 退出码非 0；输出含 `「### 步骤 1：意图定性」一节缺少：用一句话复述**要解决的问题**`。
  5. 把 `### 步骤 4：收敛与拆解` 改成 `### 步骤 4：收敛` → 退出码非 0；输出含 `找不到标题：### 步骤 4：收敛与拆解`。
  6. 在步骤 0 小节已有两句先读提示的现状下（场景 1）不因步骤 0 失败——由场景 1 覆盖。
- [ ] `bash tests/prd-body-steps-guard.test.sh` 全过
- [ ] `bash tests/skill-size.test.sh` 全过
