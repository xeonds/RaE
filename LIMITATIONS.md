# RaE Known Limitations

从当前实现归纳。写示例时需注意。

## 表达式层
- **无位或** — `|` 被管道占用，位或用 `@bor` 函数或 `a + b` 替代。
- **无字符串拼接/转换函数** — 需外部脚本。
- **无数组/对象字面量** — primary_expr 不接受 `[...]` / `{...}`，只能用 schema 解析得到。
- **比较 `!= <= >=` 已支持** ✅
- **位运算 `& ^ ~ << >>` 已支持** ✅
- **逻辑运算 `&& ||` 已支持** ✅
- **`UnaryOp Neg/Not` 已实现** ✅

## 序列化
- **`@write` 不按 schema 重编码 VObj** — 当前用 `value_to_bytes` 做 key=value 文本拼接。要正确回写必须用 `new T {...}` 重新构造。
- **VArray 写出 VObj 元素** — 序列化为文本 key=value，非二进制布局。
- **VFloat 写出用 `string_of_float`** — 非 IEEE 754 编码。

## 字段定位
- **动态偏移 `@ (expr)` 不能引用同 struct 字段** — env 是外层 env，非当前 struct 逐字段 env。
- **`@ after(field)` 只看 `field_ends`** — 不递归跨结构查找。
- **`[count = expr]` expr 求值环境为空** — 不能引用同 struct 字段。
- **变体 case 字段合入 struct env** — `set_path` 行为可能与直觉不符。

## 数组
- **`array<T>` 要求 T 是定长类型** — `string`/`bytes`/嵌套 array 元素 size=0，循环不前进。
- **`[count = expr]` 不能引用同 struct 字段**。

## 校验和
- **只有 16 位字节和** — 无 CRC16/CRC32/MD5/SHA1。
- **无 endian swap helper**。

## 字符串与字节
- **`string(n)` / `bytes(n)` 长度 n 必须是字面量** — 不能由表达式给出。

## 模块化
- **模板仅单形参** — `template<T>`。
- **枚举值只是语法糖** — `enum` 没人查表。
- **`import` 无命名空间** — 纯文本拼接。

## CLI
- **必须是 `<script> <binary>` 两参数** — 不支持 stdin / `-o`。
