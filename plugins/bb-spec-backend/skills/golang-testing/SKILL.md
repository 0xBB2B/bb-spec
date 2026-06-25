---
name: golang-testing
description: Go 测试惯用法（配合 tdd-workflow）——测试文件必须 1:1 对应实现文件（foo_test.go 必有 foo.go）；默认 table-driven + t.Run 子测试；独立测试 t.Parallel；benchmark/fuzz 用 testing 内置工具。触发：编写/审查 Go 函数或方法、新增 *_test.go、补充测试覆盖、创建 benchmark/fuzz test。跳过：生成代码、vendor、纯配置、非 Go 项目。
user-invocable: false
---

# Go 测试模式

Go 语言测试的惯用法与组织方式，配合 `tdd-workflow` skill 的通用纪律使用。

## 触发与跳过

**TRIGGER**：编写 / 审查 Go 函数或方法、新增或重命名 `*_test.go`、补充测试覆盖、创建 benchmark / fuzz test。
**SKIP**：生成代码、vendor、纯配置。

---

## 0. 测试文件 1:1 对应实现文件（硬规则）

每个 `*_test.go` 必须有同目录、同 basename 的实现文件 `*.go`，且只测这个文件里的导出/包内符号。

- `foo.go` ↔ `foo_test.go`（同包白盒）或 `foo_test.go` 声明 `package foo_test`（黑盒），二者都合法，但都必须存在 `foo.go`
- **禁止创建无对应实现的 `*_test.go`**：例如单开 `helpers_test.go` / `extra_test.go` / `integration_test.go` / `utils_test.go` 把多文件的测试塞进去——一律拆回各自的 `<原文件>_test.go`
- 跨文件共享的测试夹具（fixture / mock / builder）放在被测包内的 **正式 `.go`** 文件里（如 `testing.go`，用 `//go:build test` 或单独子包），不要藏在游离的 `_test.go`

**例外**（必须有明确理由，PR 描述里说明）：
- `main_test.go` 承载 `TestMain` 入口——仍对应 `main.go` / package main
- 集成 / e2e 测试集中在专门目录（如 `test/integration/`、`e2e/`），与单测分离；该目录下的 `_test.go` 不要求对应同名 `.go`，但必须有清晰的目录约定
- 同名实现文件被合并 / 重命名时，对应的 `_test.go` 必须同步合并 / 重命名，禁止留游离测试

**为什么**：
- 测试与实现一一对应才能让"删 `foo.go` 时 `foo_test.go` 也跟着删"成为机械动作，不会留下指向已死代码的孤儿测试
- 多文件混塞一个 `*_test.go` 会让覆盖率与失败定位都失焦，也容易演变成放任何"看起来像测试"的临时代码的垃圾桶
- 与 [[tdd-workflow]] 的 Red → Green → Refactor 配套：先写 `foo_test.go` 就强制先决定 `foo.go` 这个文件存在

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
golangci-lint run ./...          # lint（详见 golang-constraints §3.12）
```

**`test` 入口必须串联 lint**：项目级"跑测试"的统一入口（`Makefile` 的 `test` target / `package.json` 的 `test` script / CI 的 `test` job）必须把 `golangci-lint run` 和 `go test` 一起跑，任一失败即整体失败。示例 Makefile：

```makefile
.PHONY: test
test:
	golangci-lint run ./...
	go test -race ./...
```

理由：lint 单开 job 容易在赶进度时被关掉或被忽视，串进 `test` 才能保证"本地一条命令、CI 一个门"都跑得到。

---

## 10. 核心纪律

TDD 流程（Red-Green-Refactor、先测试后实现）遵循 `tdd-workflow` skill。Go 特有补充：
- 测试名格式 `TestUser_CreateUser`（`Test<类型>_<方法>`）
- 禁止 `time.Sleep` / 忽略 flaky test / mock everything
