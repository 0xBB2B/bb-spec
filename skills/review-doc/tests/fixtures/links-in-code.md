# 代码块与行内代码中的链接不应被检查

正文里的真链接：指向一个不存在的 [缺失文件](./really-missing.md)。

下面代码块里的 "链接" 是示例，不应被当成真链接检查：

```markdown
这里写一个示例：[示例](./does-not-exist.md)
还有 [示例锚点](#never-existed)
```

行内代码里的示例 `[x](./fake.md)` 也不应检查。

正常外部链接：[Anthropic](https://anthropic.com)。
