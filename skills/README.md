# RaE Skills

本目录包含一组针对 RaE（awk/jq for binary files）的场景化 skill。每个 skill 给出特定二进制格式的最小可运行 schema 与典型任务模式。

## 通用速查

写任何 skill 的 RaE 内容前，先看 [`_rae-cheatsheet.md`](./_rae-cheatsheet.md) 复习语法、CLI、表达式与已知实现限制。

## Skills 列表

| Skill | 触发场景 | 不适用 |
|-------|---------|--------|
| [`elf-analysis`](./elf-analysis/SKILL.md) | 解析/修改 ELF 可执行文件、.so、.o | PE/COFF、Mach-O、固件裸二进制 |
| [`media-metadata`](./media-metadata/SKILL.md) | JPEG/PNG/MP4/WAV 容器层元数据 | 像素/采样解码、H.264/AAC bitstream |
| [`archive-inspect`](./archive-inspect/SKILL.md) | ZIP/TAR/GZIP/7z 头与条目列表 | 完整解压（用 unzip/tar CLI）、DEB/RPM |
| [`network-protocol`](./network-protocol/SKILL.md) | PCAP/PCAPNG/IPv4/IPv6/TCP/UDP/DNS | HTTP/TLS/QUIC、实时抓包、加密 payload |

## 当前 RaE 能力速查

**已实现**（上次更新后新增的）：

- 位运算：`& ^ << >>` 和一元 `~`（`engine.ml:209-220`）
- 完整比较运算符：`== != < <= > >=`
- 逻辑 `&&` `||`、`!`
- 自动 offset：字段不写 `@` 默认 `After ""` 顺序堆叠（`parser.mly:131-138`）
- `[checksum = expr]` 字段 attr：`construct_binary` 时按 expr 写入 CRC32
- `@crc32(v)` 内置函数（`engine.ml:248-249`）
- `@bswap16` / `@bswap32` 内置函数
- 多形参模板：`template<T, U>`
- stdin 输入 / `-o` 输出参数
- `@write` 对 `VObj` 触发 `construct_binary` 重编码（不再"key=value 文本拼接"）

**仍未实现**：

- 字符串拼接运算符、字符串字面量转 int
- 数组/对象字面量 `[1,2,3]` / `{a=1}`
- 变长元素数组 `array<string>` / `array<bytes>` 的 stride
- 压缩/解压 DEFLATE/LZMA
- 实时 stdin 持续流（只能一次性读到 EOF）
- `@ (expr)` 动态偏移 env 仍为空，不能引用同 struct 兄弟字段（`engine.ml:346`）

## 写新 skill 的建议

如果发现新场景但本目录没有覆盖，参考现有 skill 的结构：

1. 何时使用 / 不适用
2. 最小事实（写 schema 前要知道的关键字段与字节序）
3. 最小可运行 schema（尽量用自动 offset）
4. 典型任务模板（每个任务一段：场景 + schema + 表达式）
5. 常见坑（endian、可变长、校验和、位域等 RaE 当前限制）
6. 与其它 skill 的边界
