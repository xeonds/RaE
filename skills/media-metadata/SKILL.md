---
name: media-metadata
description: Use this skill whenever the user wants to read, modify, or extract metadata from media container formats using RaE — including JPEG (JFIF/EXIF), PNG, MP4/MOV (ISO BMFF), and basic RIFF/WAV. Triggers on "读 EXIF", "改 MP4 metadata", "提取 JPEG 大小", "PNG chunk", "修改 ID3", "看 MP4 时长", "container box", "moov atom". Do NOT use for raw pixel/audio data decoding (RGB, PCM, YUV), codec-level bitstream parsing (H.264 NALU, AAC frames), or non-container formats like BMP/TIFF raw.
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

JPEG/PNG/MP4 块都用 `[size][type][payload]` 模式。在 RaE 中：

```rae
struct Chunk {
    size: u32 @ 0;
    type: bytes(4) @ 4;
    payload: bytes @ 8 [count = .size - 8];
}
chunks: array<Chunk> @ 0 [count = ...];
```

注意 `array<Chunk>` 需要 `[count = expr]` 给出定长，而媒体文件多数是长度可变的：**对容器顶层适合直接用 `bytes` 抓整个 payload，然后用 `variant` 在内部按 type 路由**。

## JPEG / JFIF

最小事实：

- 文件以 `0xFFD8` (SOI) 开始，以 `0xFFD9` (EOI) 结束
- segment 形如 `FF En size_hi size_lo payload`
- `En != 0` 时后面跟 2 字节长度（不含 FF En，但含长度自身）
- `En == 0`（例如 `0xFFC0` SOF0）也是长度+payload
- EXIF 在 `0xFFE1` (APP1) 里，前缀是 `"Exif\0\0"`，再后面才是 TIFF header

最小 schema 思路：

```rae
file JPEG {
    struct Segment {
        marker: u16 @ 0;
        length: u16 @ 2;          // 对 marker != 0xFFD8/0xFFD9
        payload: bytes @ 4 [count = .length - 2];
    }
    soi: bytes(2) @ 0 == "\xFF\xD8";
    segs: array<Segment> @ 2 [count = ...];
}
```

变体按 marker 路由更清爽：

```rae
struct Seg {
    marker: u16 @ 0;
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

最小 schema 思路（顶层用 array<Chunk>，但 PNG 长度可变，所以**先取第一块 IHDR 拿尺寸**，再决定后续解析）：

```rae
file PNG {
    struct Chunk {
        length: u32 @ 0 [endian = be];
        type: bytes(4) @ 4;
        data: bytes @ 8 [count = .length];
        crc: u32 @ after(data) [endian = be];
    }
    magic: bytes(8) @ 0 == "\x89PNG\r\n\x1a\n";
    chunks: array<Chunk> @ 8 [count = ...];
}
```

变长 chunk 数量问题：和 JPEG 同样，**用 variant + 顶层 iter**。或者在脚本层写：

```rae
@block {
    @each(c in .chunks) { @echo(c.type) }
}
```

`@each` 仍需要定长 count 表达式。**实用做法**：先用 `bytes` 抓一个固定大块（如文件前 1KB）做 demo；生产场景下用 `@each` 之前先确定 count。

## MP4 / ISO BMFF

最小事实：

- 文件由 box 组成：`[size u32 BE][type 4B][payload size-8 bytes]`
- `size == 1` 表示 64 位扩展 size（紧跟 8 字节大 size）
- `size == 0` 表示 box 延伸至文件末尾
- 容器/完整 box 包含子 box（如 `moov` → `trak` → `mdia` → `minf` → `stbl`）
- `ftyp` 在最前面，给 brand 和 minor_version
- 时长信息在 `moov/trak/mdia/mdhd`（version 0/1 各异），或 `moov/mvex/mehd`

schema 模板：

```rae
file MP4 {
    struct Box {
        size: u32 @ 0 [endian = be];
        type: bytes(4) @ 4;
        payload: bytes @ 8 [count = .size - 8];
    }
    struct Ftyp {
        major: bytes(4) @ 0;
        minor: u32 @ 4 [endian = be];
        brands: bytes @ 8 [count = .size - 8 - 8];
    }
    ftyp: Ftyp @ 0;
    boxes: array<Box> @ after(ftyp) [count = ...];
}
```

变体按 type 路由更稳：

```rae
struct BoxHdr {
    size: u32 @ 0 [endian = be];
    type: bytes(4) @ 4;
    variant(type) {
        "ftyp" => { /* Ftyp 子字段 @ 8 */ }
        "moov" => { /* 嵌套 boxes，从 8 开始 */ }
        "mdat" => { /* 媒体数据，通常 raw bytes */ }
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

### 任务 2：改 PNG tEXt chunk 的 keyword

`@write` 不重编码 VObj；必须 `new`：

```rae
let new_chunk = new Chunk { length = 11, type = "tEXt", data = "Title\x00New Title", crc = 0 };
@write(new_chunk)
```

CRC 必须自己算。RaE 内置只有 `@checksum`（16 位 byte sum），不够。**生产场景下用外部脚本补 CRC**。

### 任务 3：列出 MP4 顶层 box

```rae
@block { @each(b in .boxes) { @echo(b.type) } }
```

注意 `.boxes` 数组里每项是 `VObj`，`b.type` 字段是 `bytes(4)` 解析为 `VString`（ASCII）。

## 常见坑

1. **JPEG marker 跳过 payload 偏移**：`En D8/D9` 后面没 length；其他都跟 2 字节大端长度
2. **PNG/ISO BMFF 是大端**：`@0 [endian = be]` 别忘
3. **MP4 box 长度字段本身是大端 u32**：`size`/`type` 都要 `[endian = be]`
4. **容器层和 codec 层要分开**：RaE 不解 H.264/AAC，只看 box 树
5. **CRC/校验和**：PNG chunk、MP4 stco 等位置可能需要外部工具补

## 与其它 skill 的区别

- 容器层级走本 skill；裸 PCM/YUV/RGB 走 binary-raw
- 网络抓包的 MP4（在 RTP/HTTP 里）走 network-protocol
- 固件里的 media asset 看其外层格式决定
