# RaE Known Limitations

从当前实现归纳。

## 表达式层
- **无 `|` 位或** — `|` 被管道占用，需用 `a + b` 替代（无进位场景同效）
- **无字符串拼接/转换函数** — `concat`, `str_to_int`, `hex()` 等
- **无数组/对象字面量** — `[...]` / `{...}` 只能用 schema 解析得到

## 序列化
- **VArray 写出 VObj 元素** — `construct_binary` 数组分支未处理 VObj per-element
- **无 CRC/hash** — 只有 16 位字节和

## 字段定位
- **变体 case 字段合入 struct env** — `set_path` 行为可能与直觉不符

## 数组
- **变长元素数组** — `array<bytes>` / `array<string>` stride 无实现

## 校验和
- **无 CRC16/CRC32/MD5/SHA1**
- **无 endian swap helper**

## 字符串与字节
- **`string(n)` / `bytes(n)` 长度 n 必须是字面量**

## 模块化
- **模板仅单形参**
- **枚举值只是语法糖**
- **`import` 无命名空间**

## CLI
- **不支持 stdin / `-o`**
