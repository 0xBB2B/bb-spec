# 术语示例

我们使用 gRPC 来通信。后续也用 grpc 进行通信。再后来又写成 GRPC。

用户登录后可以创建订单。玩家也能够新建订单。账号同样支持添加订单。

API 接口必须遵循 RESTful 规范。api 的设计应当 RESTFUL。

普通的中文段落不应被识别为术语。

叙述中 user 和 file 应该被视为普通词而非术语候选，不进入对比分组。

## 普通英文词不应被报为术语不一致

Context 这个词在一处出现，下文又写成 context，但两者都是普通英文词，不应被报。

Database 与 database 的差异也属于普通英文词，不应报为术语不一致。

## 代码块中出现的变体不应污染术语对比

下面代码块里的 `grpc` 是变量名，不应被视为术语：

```go
grpc := newClient()
GRPC_HOST := "localhost"
```

行内代码 `grpc.Dial()` 里的 `grpc` 同样应被忽略。

Markdown 链接的 URL 片段 [示例](https://example.com/GRPC/path) 中的术语也应跳过。
