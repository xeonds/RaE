---
name: archive-inspect
description: Use this skill whenever the user wants to inspect, list, extract, or modify entries inside archive/container formats using RaE — primarily ZIP, TAR, GZIP, and 7z (basic). Triggers on "看 zip 里有什么", "提取 tar 某文件", "改 zip comment", "列出 7z entries", "read archive metadata", "extract single file from zip", "read tar header". Do NOT use for compression algorithm internals (DEFLATE bits, LZMA match finder), full archive extraction to filesystem (use unzip/tar CLI), or installer packages like DEB/RPM/NSIS.
---

# Archive Inspection & Modification with RaE

归档格式的核心是"局部头 + payload"的重复结构，RaE 的 schema 能让你在不解压整个文件的情况下定位条目。本 skill 给出 ZIP / TAR / GZIP / 7z 的最小 schema。

## 何时使用

- 列出 ZIP 内所有条目（文件名、压缩大小、未压缩大小、CRC、时间）
- 解析 TAR 各条目头（name、size、mode、uid/gid、mtime）
- 读 GZIP 头（magic、method、mtime、原始文件名）
- 读 7z 文件头（signature、major/minor、CRC、crc 定义、pack info 等）

**不适用**：解 DEFLATE/LZMA 算法本身、把整个归档解到磁盘（用 unzip/tar CLI 更合适）、DEB/RPM/NSIS 等安装包。

## 共同模式

归档 = `[global header][entries...] [central directory][end record]`。ZIP 是经典例子：尾部有 central directory，从那里反查所有条目。

## ZIP

最小事实：

- magic 不是文件头，是 central directory 结尾的 `End of central directory (EOCD)` 记录
- EOCD 在文件尾部，签名 `50 4B 05 06`
- EOCD 后至少有 22 字节，从中能读到 `cd_offset`（central directory 起点）
- central directory 每条 = 46 字节固定头 + filename + extra + comment
- local file header 签名 `50 4B 03 04`，固定 30 字节头 + filename + extra + (data)

### 思路：先定位 EOCD

```rae
file ZIP {
    struct EOCD {
        sig: u32 @ 0 == 0x06054B50;       // "PK\x05\x06" little-endian
        disk: u16 @ 4;
        cd_disk: u16 @ 6;
        cd_count: u16 @ 8;                // 本磁盘条目数
        cd_total: u16 @ 10;               // 总条目数
        cd_size: u32 @ 12;                // central directory 字节数
        cd_offset: u32 @ 16;              // central directory 起始偏移
        comment_len: u16 @ 20;
    }
    eocd: EOCD @ 0;       // 不一定对：见下
}
```

`eocd @ 0` 不能直接这么写，因为 EOCD 不在文件开头。**实际操作**：

- 在脚本里用 `@align` 不行（这是绝对偏移）
- **实用做法**：对**已知小文件**直接给出 `@ offset`（比如 `@ 0x100` 之类），或者在文件**末尾**用 `bytes` 抓 EOCD 区域

更稳的写法：用 `bytes` 抓文件末尾 22+65535 字节（comment 最多 65535 字节），在脚本里手算 EOCD 起点。**RaE 没有反向 seek**，这是当前限制。

**对常见 ZIP 文件**（无 comment，EOCD 紧跟 cd 之后）的最小可演示 schema：

```rae
file ZIP {
    struct EOCD {
        sig: u32 @ 0 == 0x06054B50;
        cd_offset: u32 @ 16;
        cd_count: u16 @ 8;
    }
    eocd: EOCD @ 0;          // ⚠ 仅当文件以 EOCD 开始时（不要这样做）
}
```

正确的最小 schema **应当**结合已知偏移或外部脚本提供 `@` 起点。一个 work-around：

```rae
file ZIP {
    struct EOCD { sig: u32 @ 0 == 0x06054B50; cd_offset: u32 @ 16; cd_count: u16 @ 8; }
    struct CDir {
        sig: u32 @ 0 == 0x02014B50;
        // ... other fields
        name_len: u16 @ 28;
        extra_len: u16 @ 30;
        comment_len: u16 @ 32;
        name: bytes @ 46 [count = .name_len];
    }
    cd: array<CDir> @ <cd_offset_expr> [count = .eocd.cd_count];
}
```

**`<cd_offset_expr>`** 是动态表达式；在 RaE 中是 `(expr)` 形式，但 `cd_offset` 字段得先解析出来——**这正是 RaE 的弱项**：当前 `@ (expr)` 表达式里能引用常量字面量，但**不能直接引用其他字段**。`parse_binary` 在 `compute_offset` 里跑 `eval_expr e env (ref VNull)`，env 传入的是字段外的全局 env，不包含前序字段。

**当前实操建议**：

1. **静态 ZIP 文件**：用十六进制编辑器或 `unzip -l` 拿到 cd_offset，硬编码 `@ 0xABCD`
2. **批量处理**：用 shell 脚本包装：先 `unzip -p file.zip` 抽 eocd 字节，再喂给 RaE
3. **修字段落盘**：`new` 重建 EOCD 段，配合其他工具拼回 ZIP

### 任务：列出 ZIP 条目名

假设 cd_offset = 0x100：

```rae
file ZIP {
    struct CDir {
        sig: u32 @ 0 == 0x02014B50;
        name_len: u16 @ 28;
        name: bytes @ 46 [count = .name_len];
    }
    cd: array<CDir> @ 0x100 [count = 5];
}
@block { @each(c in .cd) { @echo(c.name) } }
```

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

最小 schema（先把 name 和 size 抓出来，size 是 12 字节 octal ascii）：

```rae
file TAR {
    struct Hdr {
        name: bytes(100) @ 0;
        mode: bytes(8) @ 100;
        uid: bytes(8) @ 108;
        gid: bytes(8) @ 116;
        size_str: bytes(12) @ 124;
        mtime_str: bytes(12) @ 136;
        chksum: bytes(8) @ 148;
        typeflag: u8 @ 156;
        magic: bytes(6) @ 257;
    }
    hdr: Hdr @ 0;
    payload: bytes @ 512 [count = ...];
}
```

`size_str` 拿到后是 `VString`，octal 转换需要脚本里解析。**简化版**：在脚本里

```rae
@block {
    @echo(.hdr.name);
    @echo(.hdr.size_str);
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

最小 schema：

```rae
file GZIP {
    struct Hdr {
        magic: u16 @ 0 [endian = le] == 0x8B1F;
        method: u8 @ 2;
        flags: u8 @ 3;
        mtime: u32 @ 4 [endian = le];
        xfl: u8 @ 8;
        os: u8 @ 9;
    }
    hdr: Hdr @ 0;
    name: bytes @ 10 [count = ...];   // 若 flags & 0x08
}
```

GZIP 的 DEFLATE 流在 `new` 时 RaE 不能压缩，只能**读取 + 修改头**。要重打包请用 `gzip` CLI。

## 7z

7z 头复杂（signature、version、crc、crc定义、packInfo、unpackInfo、subStreamsInfo...），完整解析超出本 skill 范围。**最小**：仅校验 7z signature (`37 7A BC AF 27 1C`)，并打印前 32 字节：

```rae
file SEVENZ {
    struct Sig {
        sig: bytes(6) @ 0 == "7z\xBC\xAF\x27\x1C";
        major: u8 @ 6;
        minor: u8 @ 7;
        start_hdr_crc: u32 @ 8 [endian = le];
    }
    sig: Sig @ 0;
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

⚠️ **注意**：这会写出**仅 10 字节的头**，没有 DEFLATE 流。要重打包 GZIP 请用外部 CLI。

## 常见坑

1. **归档长度可变的字段必须显式 count**：`array<...>` 要求 `[count = expr]`，否则长度推断不出来
2. **octal 字符串**：`size_str`/`mtime_str` 是 ASCII octal，要解析为整数需在脚本里手写
3. **`@ (expr)` 动态偏移**目前不能引用同 struct 内其他字段；跨字段引用要 schema 外手动算
4. **CRC**：ZIP local header 也有 CRC，但条目 zip 时计算；RaE 没内置 CRC32，只有 16 位 byte sum
5. **解压**：`@write` 不会执行 DEFLATE/LZMA；本 skill 只覆盖"读 metadata"和"改 metadata 后重组"

## 与其它 skill 的区别

- 编码/压缩算法本身：不在本 skill 范围
- 安装包（DEB/RPM）：用对应 skill
- 在网络流里传输的归档：先解网络层（network-protocol skill），再走本 skill
