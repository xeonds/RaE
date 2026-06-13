---
name: media-metadata
description: Use this skill whenever the user wants to read, modify, or extract metadata from media container formats using RaE — including JPEG (JFIF/EXIF), PNG, MP4/MOV (ISO BMFF), and basic RIFF/WAV. Triggers on "读 EXIF", "改 MP4 metadata", "提取 JPEG 大小", "PNG chunk", "修改 ID3", "看 MP4 时长", "container box", "moov atom", "ISO BMFF box", "PNG tEXt", "JFIF APP0". Do NOT use for raw pixel/audio data decoding (RGB, PCM, YUV), codec-level bitstream parsing (H.264 NALU, AAC frames), or non-container formats like BMP/TIFF raw.
---

# Media Container Metadata with RaE

媒体容器由"容器头 + 块"组成，RaE 的 schema 特别适合拆解这种结构。本 skill 给出主流媒体格式的最小 schema 与改写流程。

## 何时使用

- 解析 JPEG 的 APP0/APP1/EXIF segment，提取/修改元数据
- 解析 PNG 的 IHDR/tEXt/iTXt/zTXt chunk
- 解析 MP4 的 box 树（ftyp / moov / trak / mdia / minf / stbl）
- 解析 RIFF（WAV/AVI）的 chunk 列表

**不适用**：H.264 NALU 解析、AAC frame 解码、原始 RGB/PCM 数据处理。

## 共同点：变长块

JPEG/PNG/MP4 块都用 `[size][type][payload]` 模式。

## 自动 offset + 模板的优势

新版本支持 `@` 省略（自动 `After ""`），容器层/段头可以顺序堆叠。`template<T>` 仍是单形参但**已支持在 schema 中** —— 用它给"统一 chunk 头"：

```rae
template<T> SizedChunk {
    size: u32 [endian = be];
    type: bytes(4);
    payload: T;
}
```

## JPEG / JFIF

最小事实：

- 文件以 `0xFFD8` (SOI) 开始，以 `0xFFD9` (EOI) 结束
- segment 形如 `FF En size_hi size_lo payload`
- `En != 0` 时后面跟 2 字节长度（不含 FF En，但含长度自身）
- EXIF 在 `0xFFE1` (APP1) 里，前缀是 `"Exif\0\0"`，再后面才是 TIFF header

最小 schema（自动 offset）：

```rae
file JPEG {
    struct Segment {
        marker: u16 [endian = be];
        length: u16 [endian = be];
        payload: bytes [count = .length - 2];
    }
    soi: bytes(2) == "\xFF\xD8";
    segs: array<Segment> [count = ...];
}
```

变体按 marker 路由更清爽：

```rae
struct Seg {
    marker: u16 [endian = be];
    variant(marker) {
        0xFFC0 => { /* SOF0: precision, height, width, components ... */ }
        0xFFE0 => { /* APP0/JFIF */ }
        0xFFE1 => { /* APP1/EXIF */ }
    }
}
```

注意：变体里的 payload 字段要**显式**给偏移 `@ 4`，并标 `[if = .marker == 0xFFE0]` 等条件，或者直接用 `variant(marker)` 让 schema 解析时分发。

提取 EXIF：如果只是关心图像宽高，SOF0 段里有 `precision (1B) height (2B) width (2B)`，直接读出即可。

## PNG

最小事实：

- magic: `89 50 4E 47 0D 0A 1A 0A`
- chunk: `[length u32 BE][type 4B][data length bytes][crc u32 BE]`
- 关键 chunk: `IHDR`, `IDAT`, `IEND`, `tEXt`, `iTXt`, `zTXt`, `pHYs`, `tIME`

最小 schema（自动 offset）：

```rae
file PNG {
    struct Chunk {
        length: u32 [endian = be];
        type: bytes(4);
        data: bytes [count = .length];
        crc: u32 [endian = be];
    }
    magic: bytes(8) == "\x89PNG\r\n\x1a\n";
    chunks: array<Chunk> [count = ...];
}
```

变长 chunk 数量问题：和 JPEG 同样，**用 variant + 顶层 iter**。或者在脚本层写：

```rae
@block {
    @each(c in .chunks) { @echo(c.type) }
}
```

## MP4 / ISO BMFF

最小事实：

- 文件由 box 组成：`[size u32 BE][type 4B][payload size-8 bytes]`
- `size == 1` 表示 64 位扩展 size（紧跟 8 字节大 size）
- `size == 0` 表示 box 延伸至文件末尾
- 容器/完整 box 包含子 box（如 `moov` → `trak` → `mdia` → `minf` → `stbl`）

schema 模板（自动 offset）：

```rae
file MP4 {
    struct Box {
        size: u32 [endian = be];
        type: bytes(4);
        payload: bytes [count = .size - 8];
    }
    ftyp: Box [if = true];   // 用 if 触发 ftyp
    boxes: array<Box> [count = ...];
}
```

变体按 type 路由更稳：

```rae
struct BoxHdr {
    size: u32 [endian = be];
    type: bytes(4);
    variant(type) {
        "ftyp" => { /* Ftyp 子字段 @ 8 */ }
        "moov" => { /* 嵌套 boxes，从 8 开始 */ }
        "mdat" => { /* 媒体数据 */ }
    }
}
```

**注意**：RaE 的 `bytes(4)` 字段如果要按字面量做 variant 模式，需要字段值是 `VString`，lexer 解析 `"ftyp"` 是字符串字面量，schema parser 接受。

## 典型任务

### 任务 1：读 JPEG 宽高（SOF0 段）

```rae
@block {
    let w = .segs[2].width;   // 假设 SOF0 是第 3 段
    let h = .segs[2].height;
    @echo(w); @echo(h)
}
```

### 任务 2：列 PNG 所有 chunk 类型

```rae
@block { @each(c in .chunks) { @echo(c.type) } }
```

### 任务 3：列出 MP4 顶层 box

```rae
@block { @each(b in .boxes) { @echo(b.type) } }
```

### 任务 4：改 PNG tEXt chunk 的 keyword

PNG chunk CRC 关键 —— 现在 **`@crc32(v)` 内置** + **`[checksum]` attr** 可用：

**路径 A**：脚本算 CRC，构造新 chunk

```rae
let new_chunk = new Chunk { length = 11, type = "tEXt", data = "Title\x00New Title", crc = 0 };
let real = @crc32(new_chunk);
@write("/tmp/out.png")
```

**问题**：chunk CRC 在 PNG 里是 `type+data` 的 CRC32，不是 `new` 之后的整段。`@crc32` 算整段，包括 length 字段。**实际生产**里要单独算 `type || data` 的 CRC32，然后写回 chunk —— 可以在脚本里把 `type+data` 拼起来：

```rae
let td = "tEXtTitle\x00New Title";   // 字符串字面量
let crc = @crc32(td);
```

`@crc32` 对 `VString` 走 `value_to_bytes` 路径，得到原始字节做 CRC32（`engine.ml:248-249`）。**结果是对的**。

**路径 B**：用 `[checksum]` attr（简化版）

`[checksum]` 当前实现：算出"截至当前 cur_off 的 buf"的 CRC32 并写到 expr 给出的偏移。对 PNG chunk 这种"局部 CRC"不直接适用。**完整文件 CRC**（如 gzip trailer）则可用。

### 任务 5：写一个最小 MP4 ftyp 头并落盘

```rae
let out = new Box { size = 20, type = "ftyp", payload = "isom\x00\x00\x00\x00isomavc1" };
@write("/tmp/out.mp4")
```

## 常见坑

1. **JPEG marker 跳过 payload 偏移**：`En D8/D9` 后面没 length；其他都跟 2 字节大端长度
2. **PNG/ISO BMFF 是大端**：`[endian = be]` 别忘
3. **MP4 box 长度字段本身是大端 u32**：`size`/`type` 都要 `[endian = be]`
4. **容器层和 codec 层要分开**：RaE 不解 H.264/AAC，只看 box 树
5. **CRC 算法**：PNG chunk CRC32 = `crc32(type || data)`，**不含 length 字段**。`@crc32` 算的是整段；调用时挑好输入
6. **改后落盘**：用 `new T {...}` 拿 `VBytes` 后 `@write` 或 `-o`

## 与其它 skill 的区别

- 容器层级走本 skill；裸 PCM/YUV/RGB 走 binary-raw
- 网络抓包的 MP4（在 RTP/HTTP 里）走 network-protocol
- 固件里的 media asset 看其外层格式决定
