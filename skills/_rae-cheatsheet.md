# RaE 速查表

下面只列写作 skill 时需要回顾的细节。如果有不确定的语法或语义，先回看 `AGENTS.md` 和 `README.md`。

## CLI 形式

```bash
dune exec rae -- <script.rae> <binary_file> [-o out]   # 脚本模式
dune exec rae -- "<inline schema + expr>" <bin> [-o out] # 内联模式
cat file.bin | dune exec rae -- <script.rae> [-o out]   # stdin
```

- 第一个参数以 `.rae` / `.RaE` 结尾视为文件路径，否则视为脚本字符串
- 后续位置参数是 binary 文件路径；若没给则从 stdin 读
- `-o <path>` 把顶层 `result` 若是 `VBytes` 写到指定路径（**不** 用 `@write`）

## Schema 核心规则

字段声明：

```
name: type @ offset_expr [== expected] [attrs];
name: type [attrs] [== expected];   # @ 可省略 → 自动 After ""
```

- `type`：`u8..u64`、`i8..i64`、`f32`、`f64`、`string`、`bytes(n)`、`array<T>`、结构体名、`template<T1, T2, ...>` 实参化
- `offset_expr`：`0xN` | `after(field)` | `align(expr)` | `(expr)`
- `attrs`：`[endian = le|be]`、`[count = expr]`、`[if = expr]`、`[validate = expr]`、`[checksum = expr]`
- 字符串/字节字段用 `count = expr` 决定长度
- 变体：`variant(tag_field) { pattern => { ...fields... } }`，pattern 是表达式
- 字段可不写 `@` —— 默认顺序排布，紧跟前一个字段结尾

## 表达式

| 形式 | 含义 |
|------|------|
| `.field` | 当前根对象的字段访问 |
| `.a.b.c` | 链式访问 |
| `.arr[0]` | 数组下标 |
| `.arr[]` | 数组展开 |
| `expr \| expr` | 管道 |
| `.a = v` | 原地赋值 |
| `new Type { k = v, ... }` | 按 schema 构造二进制，返回 `VBytes` |
| `@echo(v)` | 打印 |
| `@write("path")` | 写出 current |
| `@checksum(v)` | 16 位字节和 |
| `@crc32(v)` | CRC32（`VInt32`） |
| `@bswap16(v)` / `@bswap32(v)` | 字节序翻转 |
| `@align(v, n)` | 向上对齐 |
| `@select(cond)` | 数组过滤 |
| `@block { let x = .a; ... }` | 顺序表达式 |
| `@each(item in .arr) { body }` | 映射数组 |

### 运算符

| 类别 | 符号 | 备注 |
|------|------|------|
| 算术 | `+ - * /` | `VInt`/`VInt32`/`VInt64` 之间互转 |
| 比较 | `== != < <= > >=` | 全实现 |
| 逻辑 | `&& \|\|` | 短路求值（`And`/`Or` 实现于 engine.ml:207-208） |
| 位运算 | `& ^ << >>` 和一元 `~` | **已实现**（`lexer.mll:80-90`，`engine.ml:209-220`） |
| 一元 | `!` `-` `~` | `!`/`-`/`~` 全实现（`engine.ml:168-179`） |
| 赋值 | `=` | 配合路径表达式 |

## 多语句

顶层用 `;` 串联；最后一句的值作为脚本返回值。

## 写出策略（重要变化）

- 改字段后 current 是修改过的树
- `@write` 对 `VObj` 会触发 `construct_binary`（`engine.ml:259-267`），**自动按 schema 重新编码为字节**——前提是 `call_env` 里有 `__file__`（main.ml 自动注入 file 名）。`@write` 的参数是输出路径字符串。
- `-o` 参数：当顶层 result 是 `VBytes` 时直接落盘；不需要在脚本里写 `@write`
- 仍然：**先 `new T {...}` 拿到 `VBytes` 再写** 是最稳的回写路径

## 输出当前值

`main.ml` 总是打印最终 `current`：

- `VInt` → `%d`、`VInt32` → `%ld`、`VInt64` → `%Ld`
- `VFloat` → `%f`、`VString` → 原样
- `VBytes` → `<bytes>`、`VArray` → `<array N>`、`VObj` → `<obj N>`、`VNull` → 啥都不打

要看实际内容用 `@echo(...)`。

## 当前仍缺的

- 字符串拼接运算符（`@concat(a, b)` 没有；用 `Bytes.to_string` 也得靠 schema 写）
- 字符串字面量转 int（`"0x1234"` 不会自动解析；`IntLit` 来自 lexer 的字面量）
- 数组/对象字面量 `[1,2,3]` / `{a=1}`
- 变长元素数组 `array<string>` / `array<bytes>` 的 stride 仍要求 size_of 返回 0
- 压缩/解压 DEFLATE/LZMA
- 实时 stdin 持续流（只能一次性读到 EOF）
