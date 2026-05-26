---
name: golang-testing
description: Go testing patterns including table-driven tests, subtests, benchmarks, fuzzing, and test coverage. Follows TDD methodology with idiomatic Go practices.
---

# Go 测试模式

Go 语言测试的惯用法与组织方式，配合 `tdd-workflow` skill 的通用纪律使用。

## 触发与跳过

**TRIGGER**：编写 / 审查 Go 函数或方法、补充测试覆盖、创建 benchmark / fuzz test。
**SKIP**：生成代码、vendor、纯配置。

---

## 1. Table-Driven Tests（默认模式）

所有 Go 测试优先使用 table-driven 模式：

```go
func TestParseConfig(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    *Config
        wantErr bool
    }{
        {"valid", `{"host":"localhost"}`, &Config{Host: "localhost"}, false},
        {"invalid JSON", `{bad}`, nil, true},
        {"empty", "", nil, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseConfig(tt.input)
            if tt.wantErr {
                if err == nil { t.Error("expected error") }
                return
            }
            if err != nil { t.Fatalf("unexpected error: %v", err) }
            if !reflect.DeepEqual(got, tt.want) {
                t.Errorf("got %+v; want %+v", got, tt.want)
            }
        })
    }
}
```

---

## 2. 测试组织

- **Subtests**：用 `t.Run` 组织相关测试，支持 `-run "TestUser/Create"` 选择性运行
- **Parallel**：独立测试用 `t.Parallel()` 并行（注意捕获循环变量）
- **Helper**：辅助函数开头调 `t.Helper()`，错误信息指向调用处
- **Cleanup**：用 `t.Cleanup(fn)` 注册清理（替代手动 defer）
- **TempDir**：用 `t.TempDir()` 创建临时目录（自动清理）

---

## 3. Mock 写法

定义 interface → 写 mock struct（字段为 `XxxFunc func(...)`）→ 测试中注入。mock 策略（优先级、禁止项）遵循 `golang-constraints` §3.9。

---

## 4. Golden Files

测试输出对比用 `testdata/*.golden`：
- 正常运行读 golden 文件比对
- `go test -update` 更新 golden 文件（用 `flag.Bool("update", ...)` 控制）

---

## 5. HTTP Handler 测试

用 `httptest.NewRequest` + `httptest.NewRecorder`，table-driven 覆盖不同 method/path/body/status。

---

## 6. Benchmark

```go
func BenchmarkProcess(b *testing.B) {
    data := generateTestData(1000)
    b.ResetTimer()
    for i := 0; i < b.N; i++ { Process(data) }
}
```

用 `b.Run` 做不同规模的 sub-benchmark。运行：`go test -bench=. -benchmem ./...`

---

## 7. Fuzzing (Go 1.18+)

```go
func FuzzParseJSON(f *testing.F) {
    f.Add(`{"name":"test"}`)
    f.Fuzz(func(t *testing.T, input string) {
        var result map[string]any
        if err := json.Unmarshal([]byte(input), &result); err != nil { return }
        if _, err := json.Marshal(result); err != nil {
            t.Errorf("Marshal failed after Unmarshal: %v", err)
        }
    })
}
```

运行：`go test -fuzz=FuzzParseJSON -fuzztime=30s`

---

## 8. 覆盖率

```bash
go test -coverprofile=coverage.out ./...   # 生成
go tool cover -html=coverage.out            # 浏览器查看
go tool cover -func=coverage.out            # 按函数查看
```

| 代码类型 | 目标 |
|---|---|
| 核心业务逻辑 | 100% |
| 公共 API | 90%+ |
| 一般代码 | 80%+ |
| 生成代码 | 排除 |

---

## 9. 常用命令速查

```bash
go test ./...                    # 全量
go test -v ./...                 # 详细输出
go test -run TestAdd ./...       # 按名过滤
go test -run "TestUser/Create"   # 子测试
go test -race ./...              # 竞态检测
go test -short ./...             # 跳过慢测试
go test -count=10 ./...          # 重复运行（检测 flaky）
```

---

## 10. 核心纪律

TDD 流程（Red-Green-Refactor、先测试后实现）遵循 `tdd-workflow` skill。Go 特有补充：
- 测试名格式 `TestUser_CreateUser`（`Test<类型>_<方法>`）
- 禁止 `time.Sleep` / 忽略 flaky test / mock everything
