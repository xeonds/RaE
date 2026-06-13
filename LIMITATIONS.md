# RaE Known Limitations

下面是从当前实现（`lib/lexer.mll` / `lib/parser.mly` / `lib/engine.ml` / `lib/binlib.ml`）中归纳出的限制。这些项**影响 skill 编写**——写示例时必须绕开或明确标注。

## 表达式层

- **无位运算**：parser 只定义 `+ - * / == < >`（`lib/parser.mly:303-318`），没有 `& | ^ ~ << >>`。
  - 影响：IPv4 version/IHL 拆分、TCP flags 提取、Fragment Offset 解析都做不到位级字段拆解。
- **无字符串拼接运算符**：没有 `.` 用于字符串（`.` 已被 FieldAccess 占用），也没有 `concat`。
  - 影响：把 IP u32 拼成 `"192.168.1.1"`、DNS name 多 label 拼接都得靠外部脚本。
- **无数组/对象字面量**：primary_expr 不接受 `[...]` / `{...}` 当值。
  - 影响：不能写 `let xs = [1, 2, 3]`，只能从 schema 解析得到 `VArray`。
- **无字符串转整数函数**：`IntLit` / `FloatLit` / `StringLit` 是字面量；`bytes(12)` 字段拿到的是 `VString`，转 octal/hex 数字需手写解析。
- **比较运算符仅 `== < >`**，没有 `!= <= >=`。
  - 影响：写条件只能用 `== 0`、`! (a == b)` 反向表达。
- **`and` / `or` 是二元算子**（BinaryOp And/Or），但**没有实际实现**：`eval_binary_op` 也没匹配这两个 case，全部回落到 `VNull`。
  - 影响：复合条件会拿到 null。
- **`UnaryOp` 直接返回 `VNull`**（`engine.ml:148`），包括 `Neg` / `Not`。
  - 影响：`!cond` 和 `-x` 全部失效。

## 序列化 / 写出

- **`@write` 不按 schema 重新编码 `VObj`**（`engine.ml:68` `serialize_value`，`engine.ml:60-65` `value_to_bytes`）。
  - 当前行为：把 `VObj` 的字段按 `key=value` 顺序拼接 `VInt`/`VString` 字节。
  - 影响：修改 `.field` 后 `@write` 出来的字节布局**和原二进制不一样**。要正确回写必须用 `new T {...}` 重新构造得到 `VBytes`。
- **`VArray` 写出时只拼接 `VInt`/`VInt32`/`VInt64`/`VString`**，遇到 `VObj` 元素直接忽略。
  - 影响：含结构体元素的数组 `@write` 出来是空的。
- **`VFloat` 写出用 `string_of_float` 文本**（`engine.ml:66`），**不是 IEEE 754 编码**。
  - 影响：`@write` 一个 `VFloat` 出来的不是浮点字节而是 `"3.14"` 这种文本。
- **二进制 IO 是 OCaml 字符串**：`Bytes.blit` / `Bytes.length` 全程走 string 路径，与 POSIX `mmap`/直接指针访问无关。性能问题不在 skill 关心范围。

## 字段定位

- **动态偏移 `@ (expr)` 不能引用同 struct 内其他字段**：`compute_offset` 调 `eval_expr e env (ref VNull)`，env 是**外层** env，不是当前 struct 的逐字段 env（`engine.ml:260`）。
  - 影响：类似 `@ (header.length * 4)` 这种依赖同结构前序字段的偏移都不能写；只能写表达式字面量或引用 schema 外 env。
- **`@ after(field)` 只看 `field_ends`**，不递归找跨结构字段。
- **变体 case 字段不进入独立子结构**：dispatch 后 case 字段直接合入 struct env（`engine.ml:359-368`），且 case 字段的偏移用**变体 dispatch 时的 base_offset** 重新计算一次——可能导致重复计算或与原二进制不一致。
  - 影响：变体字段的 `set_path` 行为可能和直观不符。

## 数组

- **`array<T>` 要求 T 是定长结构体**：`parse_field` 中 `ArrayType` 元素大小 = `size_of_type elem_type`（`engine.ml:331-336`），遇到 `string` / `bytes` / 嵌套 `array` 元素 size = 0，循环不前进。
  - 影响：变长元素的数组在 schema 层不能直接用 `array<...>`，要用 `bytes` 抓整段再手工切。
- **`[count = expr]` 中 expr 求值环境是空 `[]`**（`engine.ml:323`），不能引用同 struct 字段。
  - 影响：`array<Chunk> @ 0 [count = .num_chunks]` 这种不行。

## 校验和 / 加密

- **只有 16 位字节和**（`@checksum`），无 CRC8/CRC16-CCITT/CRC32/MD5/SHA1。
  - 影响：PNG chunk CRC、ZIP local header CRC、TCP/IP header checksum 全部算不出来。
- **没有** endian swap helper：要从 LE `u16` 转 BE 写只能手写位移。

## 多语句与管道

- **顶层用 `;` 串联**（`bin/main.ml:24`），但 `@write` 之后 `current` 仍可能继续被引用；写多语句时要把 `@write` 放最后一句。

## 字符串与字节

- **`string(n)` 字段长度 n 必须是字面量**（`parser.mly:176`），不能由表达式给出。
- **`bytes(n)` 字段长度 n 也必须是字面量**；变长字节段要用 `[count = expr]`（其中 expr 是字面量或环境变量）配合 `bytes` 字段。
  - 影响：ISO BMFF box payload 这类"长度由前 4 字节决定"的字段，schema 表达起来要绕一圈。

## 模块归属与引用

- **模板仅支持单形参** `template<T>`（`engine.ml:92-98`），多形参无实现。
- **枚举值只是语法糖**：`enum` 定义解析后没人查表，引用 `PacketType.DATA` 等价于裸 `0x01`。
- **`import 'file.rae'`**（`engine.ml:35-44`）只是把被导入文件文本拼接到源文本里，没有命名空间/作用域。

## CLI

- **必须是 `<script> <binary>` 两参数**（`engine.ml:20-25`），不支持 stdin 或多个 binary。
- **无 `-o` 输出参数**：输出文件由 `@write("path")` 决定。
