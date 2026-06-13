---
name: archive-inspect
description: Use this skill whenever the user wants to inspect, list, extract, or modify entries inside archive/container formats using RaE — primarily ZIP, TAR, GZIP, and 7z (basic). Triggers on "看 zip 里有什么", "提取 tar 某文件", "改 zip comment", "列出 7z entries", "read archive metadata", "extract single file from zip", "read tar header", "GZIP trailer CRC32". Do NOT use for compression algorithm internals (DEFLATE bits, LZMA match finder), full archive extraction to filesystem (use unzip/tar CLI), or installer packages like DEB/RPM/NSIS.
---

# Archive Inspection & Modification with RaE

归档格式的核心是"局部头 + payload"的重复结构。本 skill 给出 ZIP / TAR / GZIP / 7z 的最小 schema。

## 何时使用

- 列出 ZIP 内所有条目（文件名、压缩大小、未压缩大小、CRC、时间）
- 解析 TAR 各条目头（name、size、mode、uid/gid、mtime）
- 读 GZIP 头 + 算 trailer CRC32
- 读 7z 文件头（signature、major/minor）

**不适用**：解 DEFLATE/LZMA 算法本身、把整个归档解到磁盘（用 unzip/tar CLI 更合适）、DEB/RPM/NSIS 等安装包。

## 共同模式

归档 = `[global header][entries...] [central directory][end record]`。

## ZIP

最小事实：

- EOCD 在文件尾部，签名 `50 4B 05 06`
- EOCD 后至少有 22 字节，从中能读到 `cd_offset`（central directory 起点）
- central directory 每条 = 46 字节固定头 + filename + extra + comment
- local file header 签名 `50 4B 03 04`，固定 30 字节头 + filename + extra + (data)

### 动态偏移现在可用

之前 `@ (expr)` 引用同 struct 字段是限制；现在 **`compute_offset` 拿到完整 env**（虽然 expr 求值仍以空 env 跑，但 `parse_fields` 的 new_env 已包含前序字段）。**更稳的做法**是用 `After <field>`：

```rae
file ZIP {
    struct EOCD {
        sig: u32 == 0x06054B50;
        disk: u16;
        cd_disk: u16;
        cd_count: u16;
        cd_total: u16;
        cd_size: u32;
        cd_offset: u32;       // central directory 起始偏移
        comment_len: u16;
        comment: bytes [count = .comment_len];
    }
    struct CDir {
        sig: u32 == 0x02014B50;
        name_len: u16;
        name: bytes [count = .name_len];
    }
    cd: array<CDir> [count = ...];
    eocd: EOCD @ after(cd);   // 自动接在 cd 之后
}
```

注意：实际 ZIP 中 EOCD 不一定紧接 cd（中间可能穿插 zip64 扩展等），但对**简单 ZIP 无 comment** 的常见情形，这套 schema 能跑通。

### 任务：列出 ZIP 条目名

```rae
@block { @each(c in .cd) { @echo(c.name) } }
```

### 任务：CRC32 校验 ZIP local header

ZIP local header 末尾有 CRC32 字段。`@crc32` 现在内置：

```rae
@block {
    @each(c in .cd) {
        let crc_computed = @crc32(c.name);  // 占位：实际 CRC 跨整个 file data
        @echo(crc_computed)
    }
}
```

`@crc32` 接收 `VString` / `VBytes` / `VInt*`（走 `value_to_bytes`），返回 `VInt32`。

## TAR

TAR（POSIX ustar）相对简单：

- 块大小 512 字节
- 文件头前 512 字节：
  - `0..100`: name (null-terminated)
  - `100..108`: mode (octal ascii)
  - `108..116`: uid
  - `116..124`: gid
  - `124..136`: size (octal ascii)
  - `136..148`: mtime (octal ascii)
  - `148..156`: checksum (octal ascii + spaces)
  - `156`: typeflag ('0'/' '=file, '1'=hardlink, '2'=symlink, '5'=dir, ...)
  - `157..257`: linkname
  - `257..262`: magic ("ustar\0")
  - `262..263`: version
- payload 是 `ceil(size/512)*512` 字节

最小 schema（自动 offset）：

```rae
file TAR {
    struct Hdr {
        name: bytes(100);
        mode: bytes(8);
        uid: bytes(8);
        gid: bytes(8);
        size_str: bytes(12);
        mtime_str: bytes(12);
        chksum: bytes(8);
        typeflag: u8;
        magic: bytes(6);
    }
    hdr: Hdr;
    payload: bytes [count = ...];
}
```

## GZIP

最小事实：

- magic: `1F 8B`
- method (1B): 8 = deflate
- flags (1B): bit 0 = FTEXT, bit 1 = FHCRC, bit 2 = FEXTRA, bit 3 = FNAME, bit 4 = FCOMMENT
- mtime (4B LE)
- xfl (1B)
- os (1B)
- 可选 FNAME 是 null-terminated 字符串
- 文件末尾有 8 字节 trailer：`CRC32 (LE u32) + ISIZE (LE u32, uncompressed size mod 2^32)`

### 任务：读 GZIP 头 + 校验 trailer

```rae
file GZIP {
    struct Hdr {
        magic: u16 [endian = le] == 0x8B1F;
        method: u8;
        flags: u8;
        mtime: u32 [endian = le];
        xfl: u8;
        os: u8;
    }
    struct Trailer {
        crc32_field: u32 [endian = le];
        isize: u32 [endian = le];
    }
    hdr: Hdr;
    name: bytes [count = 0];  // 占位
    body: bytes [count = ...];
    trailer: Trailer @ after(body);
}
```

### 任务：构造 GZIP header + trailer 占位

```rae
let out = new Hdr { magic = 0x8B1F, method = 8, flags = 0, mtime = 0, xfl = 0, os = 0 };
@write("/tmp/out.gz")
```

⚠️ **注意**：这会写出**仅 6 字节的头**，没有 DEFLATE 流也没有 trailer。要重打包 GZIP 请用外部 CLI。

### 任务：完整 GZIP（含 trailer CRC32）

GZIP trailer CRC32 是解压后原始数据的 CRC32（不是压缩流的）。校验时：

```rae
@block {
    let actual_crc = @crc32(.body);
    @echo(actual_crc);
    @echo(.trailer.crc32_field)
}
```

## 7z

7z 头复杂（signature、version、crc、crc定义、packInfo、unpackInfo、subStreamsInfo...），完整解析超出本 skill 范围。**最小**：仅校验 7z signature (`37 7A BC AF 27 1C`)，并打印前 32 字节：

```rae
file SEVENZ {
    struct Sig {
        sig: bytes(6) == "7z\xBC\xAF\x27\x1C";
        major: u8;
        minor: u8;
        start_hdr_crc: u32 [endian = le];
    }
    sig: Sig;
}
```

之后要看 7z 内部结构（packInfo / coders / folders）需要大量字段，**目前没有现成 schema**——这是 RaE 的实用边界。要处理 7z 内容请用 `7z l`/`7z e`。

## 典型任务

### 任务 1：列 TAR 条目名

```rae
@each(h in .tars) { @echo(h.name) }
```

`array<Hdr>` 需要 `[count = ...]`，对未知数量 TAR：先抓 hdr，再 payload，再下一个 hdr。**用 `array` 表达不了**——`array` 元素是定大小。

变通：用 `bytes` 抓若干 KB，按 512 字节切分，逐段 `new Hdr`：

```rae
@block {
    @echo(.hdr.name)
}
```

只对**单个条目**能这么写。多条目建议先用 `tar -tf file.tar` 拿到条目列表，再针对每个 entry 写独立 RaE 脚本。

### 任务 2：读 GZIP 头

```rae
@block {
    @echo(.hdr.mtime);
    @echo(.hdr.method);
    @echo(.hdr.os)
}
```

### 任务 3：改 GZIP mtime 后落盘

```rae
let out = new Hdr { magic = 0x8B1F, method = 8, flags = 0, mtime = 0, xfl = 0, os = 0 };
@write("/tmp/out.gz")
```

⚠️ **注意**：这会写出**仅 6 字节的头**，没有 DEFLATE 流。要重打包 GZIP 请用外部 CLI。

## 常见坑

1. **归档长度可变的字段必须显式 count**：`array<...>` 要求 `[count = expr]`，否则长度推断不出来
2. **octal 字符串**：`size_str`/`mtime_str` 是 ASCII octal，要解析为整数需在脚本里手写
3. **`@ (expr)` 动态偏移**：当前实现是 `eval_expr e env (ref VNull)`，env 还是空；不能引用同 struct 字段（参见 `engine.ml:346`）—— 用 `After <field>` 替代
4. **CRC32**：现在内置；ZIP/PNG/GZIP 的 CRC 都能算
5. **解压**：`@write` 不会执行 DEFLATE/LZMA；本 skill 只覆盖"读 metadata"和"改 metadata 后重组"

## 与其它 skill 的区别

- 编码/压缩算法本身：不在本 skill 范围
- 安装包（DEB/RPM）：用对应 skill
- 在网络流里传输的归档：先解网络层（network-protocol skill），再走本 skill
