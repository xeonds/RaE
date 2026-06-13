# RaE Known Limitations

从当前实现归纳。

## 表达式层
- **无字符串拼接/转换函数** — `concat`, `str_to_int`, `hex()` 等，需外部脚本
- **无数组/对象字面量** — `[...]` / `{...}` 只能用 schema 或构造

## 数组
- **变长元素数组** — `array<bytes>` / `array<string>` 无 stride 支持

## 模块化
- **`import` 无命名空间** — 纯文本拼接
- **枚举值只是语法糖** — 按名引用未实现

## CLI
- **不支持 stdin / `-o`**
