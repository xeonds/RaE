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

## 写新 skill 的建议

如果发现新场景但本目录没有覆盖，参考现有 skill 的结构：

1. 何时使用 / 不适用
2. 最小事实（写 schema 前要知道的关键字段与字节序）
3. 最小可运行 schema
4. 典型任务模板（每个任务一段：场景 + schema + 表达式）
5. 常见坑（endian、可变长、校验和、位域等 RaE 当前限制）
6. 与其它 skill 的边界

## 已知 RaE 限制（影响所有 skill）

- 表达式仅 `+ - * / == < >`，**无位运算、无字符串拼接、无数组字面量**
- `@write` 不会按 schema 重新编码 `VObj`；要"修改后落盘"必须 `new T {...}` 得 `VBytes` 再写
- 校验和：仅 16 位 byte sum（`@checksum`），无 CRC32/MD5/SHA1
- 动态偏移 `@ (expr)` 不能引用同 struct 内其他字段
- 压缩/解压：`new` 不执行 DEFLATE/LZMA；需要外部 CLI 配合
- 数组元素大小：`array<T>` 的 T 必须是定长结构体
