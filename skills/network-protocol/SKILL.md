---
name: network-protocol
description: Use this skill whenever the user wants to inspect, dissect, or modify network protocol packets or captures using RaE — including PCAP, PCAPNG, DNS messages, IPv4/IPv6, TCP/UDP headers, and common L2/L3/L4 fields. Triggers on "解析 pcap", "读 DNS 应答", "改 IP 头", "看 TCP flags", "extract HTTP from pcap", "PCAPNG block", "DNS query parsing", "TCP checksum", "IPv4 version". Do NOT use for application-layer protocol bodies (HTTP, TLS, MQTT) — use a dedicated protocol skill for those. Also NOT for live packet capture (use tcpdump) or for analyzing encrypted payloads.
---

# Network Protocol Inspection with RaE

网络协议是定长头 + 变长 payload 的典型。RaE schema 适合拆帧结构、定长头、TLV 字段。本 skill 覆盖 L2/L3/L4 + 常见元格式（PCAP/PCAPNG）+ 一个简单应用层（DNS）作为示例。

## 何时使用

- 解析 PCAP 文件中的 record 序列、读 linktype、timestamp、captured length
- 解析 PCAPNG 的 block 序列
- 解析 IPv4 头（IHL、Total Length、TTL、Protocol、Checksum、src/dst IP）
- 解析 IPv6 头
- 解析 TCP 头（flags、seq/ack、window）
- 解析 UDP 头
- 解析 DNS 报文

**不适用**：HTTP/TLS/QUIC/MQTT 完整解析（应用层）；实时抓包（用 tcpdump）；加密 payload 还原。

## PCAP 文件

最小事实：

- magic: `D4 C3 B2 A1`（LE）或 `A1 B2 C3 D4`（BE），决定整文件字节序
- LE 时，magic 之后是 major(2) + minor(2) + thiszone(4) + sigfigs(4) + snaplen(4) + linktype(4) = 24 字节
- record: `ts_sec(4) ts_usec(4) incl_len(4) orig_len(4) packet[incl_len]`
- 大小端由 magic 决定，**所有**后续字段跟着翻转

最小 schema（LE）：

```rae
file PCAP {
    struct Hdr {
        magic: u32 [endian = le] == 0xA1B2C3D4;
        major: u16 [endian = le];
        minor: u16 [endian = le];
        snaplen: u32 [endian = le];
        linktype: u32 [endian = le];
    }
    struct Rec {
        ts_sec: u32 [endian = le];
        ts_usec: u32 [endian = le];
        incl_len: u32 [endian = le];
        packet: bytes [count = .incl_len];
    }
    hdr: Hdr;
    recs: array<Rec> [count = ...];
}
```

### 任务：列 PCAP 中所有包的 captured length

```rae
@block { @each(r in .recs) { @echo(r.incl_len) } }
```

### 任务：解析包内 Ethernet 头

```rae
struct Eth {
    dst: bytes(6);
    src: bytes(6);
    type: u16 [endian = be];   // 网络字节序 = 大端
}
eth: Eth;
```

### 任务：链路层 type=0x0800 (IPv4) 后续

把 packet 字段定义为 `bytes`，再用 `variant(eth.type)` 路由到 `IPv4`/`IPv6`/`ARP` 等子结构。

## PCAPNG

最小事实：

- block: `[block_type u32][block_total_length u32][body][block_total_length u32]`
- magic block 0x0A0D0D0A（Section Header Block，SHB）
- Interface Description Block (IDB) = type 0x00000001
- Enhanced Packet Block (EPB) = type 0x00000006

最小 schema：

```rae
file PCAPNG {
    struct Block {
        btype: u32 [endian = le];
        blen: u32 [endian = le];
        body: bytes [count = .blen - 12];
    }
    blocks: array<Block> [count = ...];
}
```

变体按 btype 路由：

```rae
variant(btype) {
    0x0A0D0D0A => { /* Section Header: byte_order_magic + options */ }
    0x00000001 => { /* IDB: linktype + snaplen + options */ }
    0x00000006 => { /* EPB: interface_id + ts_high + ts_low + cap_len + orig_len + packet + options */ }
}
```

## IPv4 头（位运算可用！）

最小事实：

- byte 0: version (高 4 bits) + IHL (低 4 bits)
- byte 1: DSCP + ECN
- byte 2-3: Total Length (大端)
- byte 4-5: Identification
- byte 6-7: Flags (3 bits) + Fragment Offset (13 bits)
- byte 8: TTL
- byte 9: Protocol (1=ICMP, 6=TCP, 17=UDP)
- byte 10-11: Header Checksum
- byte 12-15: src IP
- byte 16-19: dst IP
- byte 20..IHL*4: options

**位运算 `& << >>` 现在支持**，可以拆 version 和 IHL：

```rae
struct IPv4 {
    vihl: u8;
    dscpecn: u8;
    total_len: u16 [endian = be];
    ident: u16 [endian = be];
    flags_frag: u16 [endian = be];
    ttl: u8;
    proto: u8;
    checksum: u16 [endian = be];
    src: u32 [endian = be];
    dst: u32 [endian = be];
    options: bytes [count = (.vihl & 0x0F) * 4 - 20];
}
```

**限制提醒**：`@ (expr)` 动态偏移求值时 env 是空 `[]`（参见 `engine.ml:346`），但 expr 内的 `.vihl` 是从 `call_env` / 全局 env 找，**不能引用本 struct 兄弟字段**。`options` 字段用 `.vihl & 0x0F` 这种"引用前序同 struct 字段"——**当前不能跑**。简化：硬编码 IHL（IPv4 头通常 20 字节无 options）：

```rae
struct IPv4 {
    vihl: u8;
    dscpecn: u8;
    total_len: u16 [endian = be];
    ident: u16 [endian = be];
    flags_frag: u16 [endian = be];
    ttl: u8;
    proto: u8;
    checksum: u16 [endian = be];
    src: u32 [endian = be];
    dst: u32 [endian = be];
}
```

`version` 和 `ihl` 从 `vihl` 拆：

```rae
@block {
    let v = .ipv4.vihl >> 4;
    let ihl = .ipv4.vihl & 0x0F;
    @echo(v); @echo(ihl)
}
```

## TCP / UDP（flags 提取现在能做）

TCP 头最小（20 字节定长部分）：

```rae
struct TCP {
    sport: u16 [endian = be];
    dport: u16 [endian = be];
    seq: u32 [endian = be];
    ack: u32 [endian = be];
    data_offset_flags: u16 [endian = be];
    window: u16 [endian = be];
    checksum: u16 [endian = be];
    urgent: u16 [endian = be];
}
```

flags 在 `data_offset_flags` 的低 9 位；data offset 在高 4 位：

```rae
@block {
    let raw = .tcp.data_offset_flags;
    let data_off = raw >> 12;                       // 头长（4 字节单位）
    let flags = raw & 0x01FF;                       // 9 个 flag bit
    let fin = flags & 0x001;                        // bit 0
    let syn = (flags >> 1) & 0x001;                 // bit 1
    let rst = (flags >> 2) & 0x001;                 // bit 2
    let psh = (flags >> 3) & 0x001;                 // bit 3
    let ack = (flags >> 4) & 0x001;                 // bit 4
    let urg = (flags >> 5) & 0x001;                 // bit 5
    @echo(syn)
}
```

UDP：

```rae
struct UDP {
    sport: u16 [endian = be];
    dport: u16 [endian = be];
    length: u16 [endian = be];
    checksum: u16 [endian = be];
}
```

## TCP/IP Checksum 校验

**现在可以做**（CRC32 / 16 位 sum 都有了）。TCP/IP checksum 是反码求和，不是 CRC：

```rae
@block {
    let sum = @checksum(.tcp.sport);  // 占位：实际是 sum of all u16 words + carry fold
    @echo(sum)
}
```

`@checksum` 是 16 位 byte-sum，**不是** RFC 1071 的反码求和算法。要算正确的 IP/TCP checksum：

```rae
@block {
    let bytes = .ipv4;  // VObj
    let b = @checksum(bytes);
    // ⚠️ 实际 checksum 算法是：
    //   1. 把 header 按 u16 分组（最后不足补 0）
    //   2. 加起来，fold 进位（> 16 bit 回卷）
    //   3. 取反
    // @checksum 给的是 byte sum，不等价。
}
```

**生产场景**用外部脚本（Python `socket` 模块直接有 `ip_checksum`）算。

## DNS

DNS 报文：12 字节头 + 4 段（question/answer/authority/additional）。

最简（不解析压缩）：

```rae
struct DNS {
    qid: u16 [endian = be];
    flags: u16 [endian = be];
    qdcount: u16 [endian = be];
    ancount: u16 [endian = be];
    nscount: u16 [endian = be];
    arcount: u16 [endian = be];
}
```

提取 query name 用 sequence-of-labels，每 label 是 `[len u8][bytes len]`，以 `\x00` 结尾，且可能跨段指针（label 高两位为 `11`）。**RaE 没指针跟随能力**——DNS name 解析在表达式层做非常笨拙。

**实用做法**：

- DNS header 字段：schema 解
- 段计数：从 `qdcount`/`ancount` 读
- 实际 name 字节：当作 `bytes` 字段取出来，再用 Python/Shell 解析

## 字节序处理（`@bswap16` / `@bswap32`）

网络协议字段读取时按字段自身的字节序；若要转成相反字节序写出去：

```rae
@block {
    let native_val = .tcp.sport;        // 大端读出来的 VInt
    let le_val = @bswap16(native_val);  // 翻转字节序
    @echo(le_val)
}
```

`@bswap16` 返回 `VInt`；`@bswap32` 返回 `VInt32`。在 `new` 构造结构体时把字段赋成 `@bswap16(...)` 结果可实现字节序转换输出。

## 典型任务

### 任务 1：列 PCAP 中 linktype

```rae
@echo(.hdr.linktype)
```

### 任务 2：IPv4 src/dst IP（已知偏移）

```rae
@block {
    @echo(.ipv4.src);    // 整数形式
    @echo(.ipv4.dst)
}
```

IPv4 地址是网络字节序 u32；要转 dotted-quad：`(a>>24)&0xFF . (a>>16)&0xFF . (a>>8)&0xFF . a&0xFF`——**RaE 没字符串拼接运算符**。`@echo(@bswap32(.ipv4.src))` 翻转后仍是 int，转 dotted-quad 用 Python 后处理。

### 任务 3：DNS 响应 answer 数

```rae
@echo(.dns.ancount)
```

### 任务 4：写一个最小 IPv4 头并落盘

```rae
let hdr = new IPv4 { vihl = 0x45, dscpecn = 0, total_len = 20, ident = 0,
                     flags_frag = 0, ttl = 64, proto = 17, checksum = 0,
                     src = 0xC0A80101, dst = 0xC0A80102 };
@write("/tmp/ip.bin")
```

### 任务 5：从 PCAP 流读（stdin）

```bash
tcpdump -w - | rae pcap.rae -o /dev/null
```

stdin 模式现在支持（`main.ml:9-17`），PCAP header 解析路径不变。

## 常见坑

1. **大端 vs 小端**：网络协议字段基本都是大端；PCAP 文件级是文件 magic 决定。**别混**。
2. **`@ (expr)` 动态偏移**：env 还是空，不能引用同 struct 字段
3. **变长头**：IPv4 options、TCP options、DNS name 都变长；用 `After` 显式接续或硬编码
4. **校验和**：TCP/UDP/IP header checksum 走 RFC 1071 反码求和，**`@checksum` 不等价**；要算正确值用外部脚本
5. **压缩指针**：DNS name 走 14 位指针跨段；本 skill 不覆盖
6. **PCAP vs PCAPNG**：格式完全不一样，**别用 PCAP schema 读 PCAPNG**

## 与其它 skill 的区别

- 应用层协议（HTTP/TLS/QUIC/MQTT）走独立 skill
- 在文件/固件里嵌的协议：用对应容器 skill 先解容器
- 实时抓包 / packet injection：用 tcpdump / scapy，不在本 skill 范围
