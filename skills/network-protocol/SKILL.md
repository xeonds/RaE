---
name: network-protocol
description: Use this skill whenever the user wants to inspect, dissect, or modify network protocol packets or captures using RaE — including PCAP, PCAPNG, DNS messages, IPv4/IPv6, TCP/UDP headers, and common L2/L3/L4 fields. Triggers on "解析 pcap", "读 DNS 应答", "改 IP 头", "看 TCP flags", "extract HTTP from pcap", "PCAPNG block", "DNS query parsing". Do NOT use for application-layer protocol bodies (HTTP, TLS, MQTT) — use a dedicated protocol skill for those. Also NOT for live packet capture (use tcpdump) or for analyzing encrypted payloads.
---

# Network Protocol Inspection with RaE

网络协议是定长头 + 变长 payload 的典型。RaE schema 适合拆帧结构、定长头、TLV 字段。本 skill 覆盖 L2/L3/L4 + 常见元格式（PCAP/PCAPNG）+ 一个简单应用层（DNS）作为示例。

## 何时使用

- 解析 PCAP 文件中的 record 序列、读 linktype、timestamp、captured length
- 解析 PCAPNG 的 block 序列（Section Header / Interface Description / Enhanced Packet / Simple Packet）
- 解析 IPv4 头（IHL、Total Length、TTL、Protocol、Checksum、src/dst IP）
- 解析 IPv6 头（Version、Traffic Class、Flow Label、Payload Length、Next Header、Hop Limit、src/dst）
- 解析 TCP 头（src/dst port、seq、ack、flags、window、checksum）
- 解析 UDP 头（src/dst port、length、checksum）
- 解析 DNS 报文（header + question/answer/authority/additional sections）

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
        magic: u32 @ 0 [endian = le] == 0xA1B2C3D4;
        major: u16 @ 4 [endian = le];
        minor: u16 @ 6 [endian = le];
        snaplen: u32 @ 16 [endian = le];
        linktype: u32 @ 20 [endian = le];
    }
    struct Rec {
        ts_sec: u32 @ 0 [endian = le];
        ts_usec: u32 @ 4 [endian = le];
        incl_len: u32 @ 8 [endian = le];
        packet: bytes @ 16 [count = .incl_len];
    }
    hdr: Hdr @ 0;
    recs: array<Rec> @ 24 [count = ...];
}
```

### 任务：列 PCAP 中所有包的 captured length

```rae
@block { @each(r in .recs) { @echo(r.incl_len) } }
```

### 任务：解析包内 Ethernet 头

```rae
struct Eth {
    dst: bytes(6) @ 0;
    src: bytes(6) @ 6;
    type: u16 @ 12 [endian = be];   // 网络字节序 = 大端
}
eth: Eth @ 0;
```

### 任务：链路层 type=0x0800 (IPv4) 后续

把 packet 字段定义为 `bytes`，再用 `variant(eth.type)` 路由到 `IPv4`/`IPv6`/`ARP` 等子结构。

## PCAPNG

最小事实：

- block: `[block_type u32][block_total_length u32][body][block_total_length u32]`
- magic block 0x0A0D0D0A（Section Header Block，SHB）
- Interface Description Block (IDB) = type 0x00000001
- Enhanced Packet Block (EPB) = type 0x00000006
- 各 block 内部是 TLV 风格（option code + length + value）

最小 schema：

```rae
file PCAPNG {
    struct Block {
        btype: u32 @ 0 [endian = le];
        blen: u32 @ 4 [endian = le];
        body: bytes @ 8 [count = .blen - 12];
    }
    blocks: array<Block> @ 0 [count = ...];
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

变体里 `body` 字段按各自 btype 内的偏移再切。

## IPv4 头

最小事实：

- byte 0: version (high 4 bits) + IHL (low 4 bits)
- byte 1: DSCP + ECN
- byte 2-3: Total Length (大端)
- byte 4-5: Identification
- byte 6-7: Flags (3 bits) + Fragment Offset (13 bits)
- byte 8: TTL
- byte 9: Protocol (1=ICMP, 6=TCP, 17=UDP)
- byte 10-11: Header Checksum
- byte 12-15: src IP
- byte 16-19: dst IP
- byte 20..IHL*4: options (variable, can be 0)

schema 写法：

```rae
struct IPv4 {
    vihl: u8 @ 0;
    dscpecn: u8 @ 1;
    total_len: u16 @ 2 [endian = be];
    ident: u16 @ 4 [endian = be];
    flags_frag: u16 @ 6 [endian = be];
    ttl: u8 @ 8;
    proto: u8 @ 9;
    checksum: u16 @ 10 [endian = be];
    src: u32 @ 12 [endian = be];
    dst: u32 @ 16 [endian = be];
    options: bytes @ 20 [count = (.vihl & 0x0F) * 4 - 20];
}
```

注意 RaE **没有**位域算子——`(.vihl & 0x0F) * 4 - 20` 在 schema 解析时被求值，要确认 parser 支持位运算。**实测限制**：当前 RaE expression 只有 `+ - * / == < >`，**没有位运算**。要先在外部把 `vihl` 拆成 version/IHL 两字节，或在 schema 里硬编码 IHL（IPv4 头通常 20 字节无 options，把 options 字段去掉）。

简化：

```rae
struct IPv4 {
    total_len: u16 @ 2 [endian = be];
    ttl: u8 @ 8;
    proto: u8 @ 9;
    src: u32 @ 12 [endian = be];
    dst: u32 @ 16 [endian = be];
}
```

丢字段比写错字段好。**生产场景**：先识别 packet 是 IPv4，再 `new` 重新构造完整头。

## TCP / UDP

TCP 头最小（20 字节定长部分）：

```rae
struct TCP {
    sport: u16 @ 0 [endian = be];
    dport: u16 @ 2 [endian = be];
    seq: u32 @ 4 [endian = be];
    ack: u32 @ 8 [endian = be];
    data_offset_flags: u16 @ 12 [endian = be];
    window: u16 @ 14 [endian = be];
    checksum: u16 @ 16 [endian = be];
    urgent: u16 @ 18 [endian = be];
}
```

UDP：

```rae
struct UDP {
    sport: u16 @ 0 [endian = be];
    dport: u16 @ 2 [endian = be];
    length: u16 @ 4 [endian = be];
    checksum: u16 @ 6 [endian = be];
}
```

flags 同样在 `data_offset_flags` 里，**当前 RaE 取不出单个 SYN/ACK 标志位**（无位运算）。要按位取值先用其它工具预处理。

## DNS

DNS 报文：12 字节头 + 4 段（question/answer/authority/additional），每段里是 name(type=压缩指针) + type(2B) + class(2B) + ...

最简（不解析压缩）：

```rae
struct DNS {
    qid: u16 @ 0 [endian = be];
    flags: u16 @ 2 [endian = be];
    qdcount: u16 @ 4 [endian = be];
    ancount: u16 @ 6 [endian = be];
    nscount: u16 @ 8 [endian = be];
    arcount: u16 @ 10 [endian = be];
}
```

提取 query name 用 sequence-of-labels，每 label 是 `[len u8][bytes len]`，以 `\x00` 结尾，且可能跨段指针（label 高两位为 `11`）。**RaE 没指针跟随能力**——DNS name 解析在表达式层做非常笨拙。

**实用做法**：

- DNS header 字段：schema 解
- 段计数：从 `qdcount`/`ancount` 读
- 实际 name 字节：当作 `bytes` 字段取出来，再用 Python/Shell 解析

## 典型任务

### 任务 1：列 PCAP 中 linktype

```rae
@echo(.hdr.linktype)
```

### 任务 2：列 PCAP 每个包的捕获长度

```rae
@block { @each(r in .recs) { @echo(r.incl_len) } }
```

### 任务 3：IPv4 src/dst IP（已知偏移）

```rae
@block {
    @echo(.ipv4.src);    // 整数形式
    @echo(.ipv4.dst)
}
```

IPv4 地址是网络字节序 u32；要转 dotted-quad：`(a>>24)&0xFF . (a>>16)&0xFF . (a>>8)&0xFF . a&0xFF`——**RaE 没位运算也没字符串拼接 `.`**。**生产场景**用外部脚本把 int 转字符串。

### 任务 4：DNS 响应 answer 数

```rae
@echo(.dns.ancount)
```

### 任务 5：写一个最小 IPv4 头并落盘（仅头 20 字节）

```rae
let hdr = new IPv4 { total_len = 20, ttl = 64, proto = 17, src = 0xC0A80101, dst = 0xC0A80102 };
@write("/tmp/ip.bin")
```

## 常见坑

1. **大端 vs 小端**：网络协议字段基本都是大端；PCAP 文件级是文件 magic 决定。**别混**。
2. **位域**：版本、flags、Fragment Offset 都在字节里，RaE 无位运算，要么拆字节要么写多字段。
3. **变长头**：IPv4 options、TCP options、DNS name 都变长；先在 schema 外算好 offset 再切。
4. **校验和**：TCP/UDP/IP 都需要重算，RaE 内置只有 16 位 byte sum，**不匹配**真实校验和算法。
5. **压缩指针**：DNS name 走 14 位指针跨段；本 skill 不覆盖。
6. **PCAP vs PCAPNG**：格式完全不一样，**别用 PCAP schema 读 PCAPNG**。

## 与其它 skill 的区别

- 应用层协议（HTTP/TLS/QUIC/MQTT）走独立 skill
- 在文件/固件里嵌的协议：用对应容器 skill 先解容器
- 实时抓包 / packet injection：用 tcpdump / scapy，不在本 skill 范围
