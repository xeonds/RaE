# RaE TODO

## 核心语言

- [ ] **位运算与逻辑运算实现**
  - 表达式加 `& | ^ ~ << >>`
  - 实现 `And` / `Or` BinaryOp（`engine.ml:152` 缺分支）
  - 实现 `UnaryOp Neg` / `Not`（`engine.ml:148` 直接返回 VNull）
  - 影响：IPv4 version/IHL、TCP flags、Fragment Offset 解析全部走不通
- [ ] **比较运算符补全**：`!=`、`<=`、`>=`（parser 缺）
- [ ] **字符串拼接与转换函数**：`concat`、`str_to_int` / `int_to_str`、`hex()` / `oct()` 解析器
  - 影响：IP 地址 dotted-quad、DNS name、TAR octal size 都要外部脚本
- [ ] **数组/对象字面量**：parser 加 `[...]` / `{...}` 作为 primary_expr
- [ ] **多语句返回语义**：`@write` 后返回值处理、`current` 在 `;` 链中的传播

## 序列化

- [ ] **`@write` 按 schema 重新编码** `VObj`（`engine.ml:60-65` 当前按 key=value 文本拼接，**不会** 写回原二进制布局）
  - 目标：基于 struct schema 把 `VObj` 重新组装为二进制
- [ ] **`VFloat` 写出用 IEEE 754**（`engine.ml:66` 当前用 `string_of_float`）
- [ ] **`VArray` 写出支持 `VObj` 元素**（`engine.ml:52-59` 当前忽略）
- [ ] **`serialize_value` 处理嵌套 struct array**

## 字段定位

- [ ] **动态偏移能引用同 struct 字段**：`compute_offset` 的 env 应该是当前 struct 累积 env（`engine.ml:260`）
- [ ] **`[count = expr]` 的 expr 能引用同 struct 字段**（`engine.ml:323` 当前是空 env）
- [ ] **变体 case 字段独立子结构**：合入 env 的方式导致 `set_path` 行为混乱

## 数组

- [ ] **变长元素数组**：`array<bytes>` / `array<string>` 的 stride 由 `[size = expr]` 给出

## 校验和 / 哈希

- [ ] **CRC32**（PNG/ZIP/Ethernet 必需）
- [ ] **CRC16-CCITT**（HDLC/PPP 常用）
- [ ] **MD5 / SHA1**（完整性校验）
- [ ] **字节序 swap helper**：`@bswap16` / `@bswap32`

## 模块化

- [ ] **import 命名空间**：`import 'file.rae'` 加 scope/namespace，避免类型名冲突
- [ ] **多形参模板**：`template<T, U>`
- [ ] **枚举值查表**：`enum` 值在 expression 中按名引用

## CLI

- [ ] **stdin 支持**：`cat file.bin | rae script.rae` 形式
- [ ] **多 binary 输入**：`rae script.rae file1.bin file2.bin`
- [ ] **`-o` 输出参数**统一 `@write` 行为
