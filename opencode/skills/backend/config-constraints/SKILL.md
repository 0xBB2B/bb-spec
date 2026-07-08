---
name: config-constraints
description: 后端配置载体三分——env/secret 装启动必需且不热更、yaml/configmap 装可热更且有默认值、DB+API 装业务方可改的动态配置；核心凭据默认只能 secret/KMS，下沉 DB 必须 envelope encryption；热更失败保留旧值 + 告警禁崩溃。触发：设计/实现配置加载、密钥存储、热更机制、新增 env/yaml/DB 配置项、k8s secret/configmap 编排。跳过：配置加载后的运行时治理（→service-constraints）、可观测性脱敏（→observability-constraints）。
---

# 后端配置载体约束

适用于：后端服务**配置的载体选择、密钥分层、热更机制**的设计、实现、编排（k8s manifest / Helm values）与 review。**原则技术栈无关**，示例用 Go + k8s。

> 边界（去耦合）：配置加载完成后的"启动 fail-fast / 优雅关闭 / 幂等 / 超时重试"等运行时治理 → `service-constraints`；日志中凭证脱敏 → `observability-constraints`；DB schema 与访问 → `database-constraints`。本 skill 只管"配置放哪里、密钥怎么分层、热更怎么 fail-safe"。

> 定位：**钉死配置载体选择规则与密钥安全底线（【硬】必守），不规定具体配置项与热更轮询周期等参数（【软】项目自定）。**

## 0. 触发与跳过

**TRIGGER**：新增/修改配置项时选择载体；设计密钥存储与轮换；接入 k8s secret/configmap；实现 yaml/DB 热更；review 配置编排与密钥处理。
**SKIP**：配置加载后的服务运行时治理（→ service-constraints）、日志脱敏（→ observability）、DB schema 设计（→ database）。

---

## 1. 配置三类载体【硬】

按「是否热更 + 是否涉密 + 是否业务方维护」三个维度二选一落到对应载体，禁混用：

- **env / k8s secret**：启动期必需、运行期不热更的基础配置。例：DB 连接串、`APP_ENV`、JWT 签名密钥、第三方 API 凭据。**env 注入后进程内固化**，刷新只能重启。
- **yaml / k8s configmap**：需要运行期热更、且**缺该文件能用代码默认值裸启动**的运维参数。例：代理 IP 白名单、HTTP 超时阈值、限流参数、特性开关。configmap 挂载为 volume 文件，kubelet 同步后由应用 reload。
- **DB + 后台 API**：业务方/管理员通过后台界面修改、需要审计与回滚的动态配置。例：租户级费率表、白名单条目、动态规则表。

判定流程：**启动必需 且 不热更 → env**；**热更 且 运维改 且 有默认值 → yaml**；**业务方改 或 需审计/回滚 或 量大 → DB**。

环境差异（dev/test/sand/prod）用 profile 表达，**代码只有一份**，禁按环境分支写 `if env == "prod"` 类硬编码。

---

## 2. yaml vs DB 判定矩阵【硬】

热更场景下两者边界：

| 维度 | yaml (configmap) | DB + API |
|---|---|---|
| 改动主体 | 运维 / SRE | 业务方 / 管理员 |
| 变更频率 | 低（按发布或工单） | 中高（按业务节奏） |
| 变更入口 | git PR + CI | 后台界面 |
| 审计与回滚 | 走 git 历史 | 走业务审计表 |
| 条目规模 | 小（几行到几十行） | 大（几百到百万行） |

满足"业务方改 / 后台界面 / 审计回滚 / 大量条目"任一项 → 必须 DB+API，禁塞 configmap。

---

## 3. 涉密分层【硬】

「涉密 + 热更」**不是**把密钥下沉到 configmap 或 DB 明文的理由。按密钥等级分两档：

- **核心凭据**（DB 密码、JWT 签名密钥、加密主密钥 KEK、跨服务 mTLS 私钥、CA 私钥）→ **只能 k8s secret / KMS / Vault / HSM**；需要热更走 secret reloader 或 external-secrets，**禁明文落 configmap 或 DB**。
- **业务侧凭据**（第三方 API token、webhook secret、业务方维护的代理账号等）→ 允许走 yaml / DB，但仍需走环境隔离与最小权限。

**核心凭据下沉 DB 的唯一例外**：当且仅当出现「多租户独立密钥 / 多版本轮换共存 / 业务流程颁发」等扩展需求时，可下沉 DB，但**必须 envelope encryption**——DB 只存 `KMS.Encrypt(key)` 密文，KEK 留在 secret/KMS/HSM。**KEK 本身永不落 DB，CA 根私钥永不落 DB**。

---

## 4. 热更 fail-safe【硬】

yaml reload 与 DB 拉取的失败处理统一约束：

- **新值解析 / 校验失败 → 保留旧值 + 告警**，禁崩溃、禁回退到代码默认（避免一次错误 push 让全集群裸奔）。
- **reload 必须原子**：构造新配置对象成功后整体替换指针，禁字段级局部更新到一半被读到。
- **reload 频率与机制有显式入口**：yaml 走 fsnotify 或 SIGHUP，DB 走 TTL 缓存或订阅推送，禁散落多处定时器各自拉取。
- **首次加载与热更走同一路径**：启动期解析失败仍然 fail-fast（呼应 `service-constraints` 启动校验），运行期解析失败仅保留旧值，两种行为分流但代码同源。

---

## 5. 留给项目的【软】

框架不钉死，由各项目按业务定：具体配置项归类、yaml/DB 各自的 schema、reload 机制选型（fsnotify / SIGHUP / Watch API / TTL）、热更轮询周期、KMS 选型（云厂商 KMS / Vault Transit / HSM）、envelope 加密算法。

---

## 6. 反面示例

```yaml
# ❌ DB 密码进 configmap（明文落 etcd，权限边界错）
apiVersion: v1
kind: ConfigMap
data:
  db_password: "p@ssw0rd"

# ✅ secret 注入 env，热更靠重启
apiVersion: v1
kind: Secret
data:
  db_password: cEBzc3cwcmQ=
```

```go
// ❌ yaml 缺失直接 panic，违反"有默认值裸启动"
cfg := MustLoadYAML("/etc/app/rate.yaml")

// ✅ 缺失走代码默认，存在则覆盖
cfg := DefaultRateConfig()
if data, err := os.ReadFile("/etc/app/rate.yaml"); err == nil {
    _ = yaml.Unmarshal(data, &cfg)
}

// ❌ reload 解析失败把配置置空，全集群裸奔
func onReload(data []byte) { current = parse(data) }

// ✅ 解析失败保留旧值 + 告警
func onReload(data []byte) {
    next, err := parse(data)
    if err != nil { log.Error("reload failed, keep old", err); return }
    current.Store(next)
}
```

---

## 7. 自检清单

- [ ] 配置项按"启动必需+不热更 / 热更+有默认值 / 业务方改"三选一落到 env / yaml / DB，无混用
- [ ] 核心凭据（DB 密码 / JWT 密钥 / KEK / mTLS 私钥）只在 secret/KMS，未明文进 configmap 或 DB
- [ ] 核心凭据下沉 DB 的场景，DB 只存密文，KEK 留在 secret/KMS；KEK 与 CA 根私钥未落 DB
- [ ] yaml/DB 判定按"改动主体/频率/审计/规模"矩阵选择，未把业务方改的条目塞 configmap
- [ ] yaml 缺失能用代码默认值裸启动；configmap 仅装真正需要热更的项
- [ ] 热更 reload：解析失败保留旧值 + 告警，原子替换，与首次加载同源
- [ ] 环境差异用 profile 表达，代码只有一份，无 `if env == "prod"` 类硬编码
- [ ] 具体配置项归类、reload 机制选型、KMS 选型已按项目定
