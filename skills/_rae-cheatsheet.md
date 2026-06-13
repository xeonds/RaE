# RaE 速查表

下面只列写作 skill 时需要回顾的细节。如果有不确定的语法或语义，先回看 `AGENTS.md` 和 `README.md`。

## CLI 形式

```bash
dune exec rae -- <script.rae> <binary_file>     # 脚本模式
dune exec rae -- "<inline schema + expr>" <bin> # 内联模式
```

内联模式：第一个参数如果以 `.rae` / `.RaE` 结尾则视为文件路径，否则视为脚本字符串。

## Schema 核心规则

字段声明：

```
name: type @ offset_expr [== expected] [attrs];
```

- `type`：`u8..u64`、`i8..i64`、`f32`、`f64`、`string`、`bytes(n)`、`array<T>`、结构体名、`template<T>` 实参化
- `offset_expr`：`0xN` | `after(field)` | `align(expr)` | `(expr)`
- `attrs`：`[endian = le|be]`、`[count = expr]`、`[if = expr]`、`[validate = expr]`
- 字符串/字节字段用 `count = expr` 决定长度
- 变体：`variant(tag_field) { pattern => { ...fields... } }`，pattern 是表达式（如字面量）

注意：当前 parser 的 `==` 必须紧贴字段（不放在 attrs 后面），且每个字段声明以可选 `;` 结束。

## 表达式

| 形式 | 含义 |
|------|------|
| `.field` | 当前根对象的字段访问 |
| `.a.b.c` | 链式访问 |
| `.arr[0]` | 数组下标 |
| `.arr[]` | 数组展开（生成新 current 数组） |
| `expr \| expr` | 管道（左值为 current 输入） |
| `.a = v` | 原地赋值（修改 current 的字段） |
| `new Type { k = v, ... }` | 按 schema 构造二进制（返回 VBytes） |
| `@echo(v)` | 打印 |
| `@write("path")` | 把 current 序列化为字节写出 |
| `@checksum(v)` | 16 位字节和 |
| `@align(v, n)` | 向上对齐 |
| `@select(cond)` | 数组过滤 |
| `@block { let x = .a; ... }` | 顺序表达式，最后一个为值 |
| `@each(item in .arr) { body }` | 映射数组 |

## 多语句

顶层用 `;` 串联；最后一句的值作为脚本返回值。`@write` 必须是顶层动作之一才能落盘。

## 输出当前值

`main.ml` 总是打印最终 `current`：

- `VInt` → `%d`
- `VInt32` → `%ld`，`VInt64` → `%Ld`
- `VFloat` → `%f`
- `VString` → 原样
- `VBytes` → `<bytes>`
- `VArray` → `<array N>`
- `VObj` → `<obj N>`

要看实际内容用 `@echo(...)` 显式打印。

## 当前实现的边界

- `@write` 走 `serialize_value`：对 `VObj` 仅按 key=value 顺序把 `VInt`/`VString` 拼成字节，**不会** 重新按 schema 编码回原结构。要正确回写，**用 `new` 构造** 返回 `VBytes` 再 `@write`。
- 变体（`variant`）解析时按 tag 匹配后把 case 字段合入同一 env；不在 case 里的字段不在 current 上。
- 模板仅支持单形参 `template<T>`，实参必须恰好一个类型。
- 算术仅在 `VInt`/`VInt32`/`VInt64` 之间互转；`VString`、`VObj`、`VArray` 的算术结果是 `VNull`。
- `parse_binary` 中 `@select` 与 `@each` 在 schema 解析阶段不可用（这些是 expression 层算子）。
