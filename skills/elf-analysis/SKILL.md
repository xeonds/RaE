---
name: elf-analysis
description: Use this skill whenever the user wants to inspect, extract information from, or modify an ELF binary (Linux executable, .so, object file) using RaE. Triggers on requests like "查看 ELF 头", "修改 ELF section", "改 dynamic section", "重写 ELF", "extracting symbols from ELF", "read ELF program headers", "strip debug info", "patch ELF entry". Also triggers when the user is working with executables, shared libraries, or relocatable objects and wants a schema-driven way to read/write them. Do NOT use for PE/COFF (Windows), Mach-O (macOS), or non-ELF binary formats.
---

# ELF Analysis & Modification with RaE

RaE 是 awk/jq for binary files；本 skill 帮你用 RaE 的声明式 schema 处理 ELF 文件（Executable and Linkable Format）。

## 何时使用

- 解析 ELF 头、program header table、section header table
- 提取 dynamic section、symbol table、relocation table 的字段
- 修改 ELF 中某字段并落盘（用 `new` 或用 `@write` 触发 `construct_binary`）
- 校验 ELF magic、machine type、e_ident 各项
- patch entry point / flags

**不适用**：PE/COFF、Mach-O、固件裸二进制。

## ELF 最小事实（写 schema 前先确认）

- 文件以 `0x7F 'E' 'L' 'F'` 四个字节开头（magic）
- 32 位 ELF 头占 52 字节，64 位占 64 字节
- 大小端由 `e_ident[EI_DATA]` 决定（1=LE, 2=BE）
- 字段 `e_phoff` 指向 program header table，每个 program header 在 32 位下 32 字节、64 位下 56 字节
- section header table 同理，32/64 位各 40/64 字节
- 关键常量：`ET_EXEC=2`, `ET_DYN=3`, `ET_REL=1`, `EM_X86_64=0x3E`, `EM_AARCH64=0xB7`, `EM_RISCV=0xF3`

## 最小可运行 schema（自动 offset 版）

字段不写 `@` 会按出现顺序自动堆叠，省去手写偏移。`@ 0` 这种只在需要"显式占位"时再用。

```rae
file ELF {
    struct Ident {
        magic: u32 == 0x7F454C46 [endian = be];
        class: u8;
        data: u8;
        version: u8;
        osabi: u8;
        abi_version: u8;
        pad: bytes(7);
    }
    ident: Ident;

    struct H32 {
        type: u16;
        machine: u16;
        ver: u32;
        entry: u32;
        phoff: u32;
        shoff: u32;
        flags: u32;
        ehsize: u16;
        phentsize: u16;
        phnum: u16;
        shentsize: u16;
        shnum: u16;
        shstrndx: u16;
    }
    struct H64 {
        type: u16;
        machine: u16;
        ver: u32;
        entry: u64;
        phoff: u64;
        shoff: u64;
        flags: u32;
        ehsize: u16;
        phentsize: u16;
        phnum: u16;
        shentsize: u16;
        shnum: u16;
        shstrndx: u16;
    }
    h32: H32 [if = .ident.class == 1];
    h64: H64 [if = .ident.class == 2];
}
```

`@ 0` 都没写；schema 引擎按字段顺序自动接续。

## 用位运算拆 ELF e_ident[0]

`e_ident[0]` 是 1 字节，含 version(高 4 位) + padding(低 4 位) — 这个写法在 ELF 里实际是 `EI_VERSION`，但很多格式（IPv4 等）有更典型的位域需求，**ELF 的 e_ident[0] 反而是纯 version 字节**。ELF 中没有天然的多字段位字节；下面给个等价的 IPv4 风格示例，告诉你能力在就行：

```rae
let v = .ident.version;        // 直接读 u8
```

## 典型任务模板

### 任务 1：读出 ELF 头关键字段

```rae
file ELF { ... 上面那个 schema ... }
.ident.magic
```

`@echo` 对 `VInt` 直接打印十进制。magic 验证靠 `== 0x7F454C46` 在 schema 层做。

### 任务 2：检查 magic 与 machine

```rae
file ELF { ... }
@block {
    let m = .ident.magic;
    let cls = .ident.class;
    let be = .ident.data;
    @echo(m); @echo(cls); @echo(be)
}
```

### 任务 3：program header 列表

64 位 program header 56 字节；用 `count = .h64.phnum` 直接引用同 struct 字段 —— **现在支持了**（之前是限制项）：

```rae
struct Phdr64 {
    type: u32;
    flags: u32;
    offset: u64;
    vaddr: u64;
    paddr: u64;
    filesz: u64;
    memsz: u64;
    align: u64;
}
phdrs: array<Phdr64> [count = .h64.phnum];
```

注意 `phdrs` 字段在 `h64` 之后写，offset 会自动接到 H64 末尾（64+16=80）。但 `phdrs` 数组首元素应当出现在 `h64.phoff` 处 —— **这里需要用 `@ (h64.phoff)`** 来强制对齐：

```rae
phdrs: array<Phdr64> @ (.h64.phoff) [count = .h64.phnum];
```

### 任务 4：解析 section header string table

`.shstrndx` 是字符串表 section 的下标；要拿名字字符串需要把对应 section 的 `offset` + `size` 切片出来：

```rae
shstr: bytes [count = .shdrs[.h64.shstrndx].size];
```

### 任务 5：修改 ELF 并落盘

**两条路径**，二选一：

**路径 A**：`@write` 配合 `construct_binary`（最简）

```rae
file ELF { ... }
.h64.entry = 0x401000
@write("out.elf")
```

main.ml 会把 `.h64.entry` 改后的 `VObj` 喂给 `construct_binary` 重新打包（前提：env 里有 `__file__`，自动注入）。**适用**：仅改固定大小字段。

**路径 B**：`new` 显式构造

```rae
let bytes = new H32 { type = 2, machine = 0x3E, ver = 1, entry = 0,
                     phoff = 52, shoff = 0, flags = 0, ehsize = 52,
                     phentsize = 0, phnum = 0, shentsize = 0, shnum = 0, shstrndx = 0 };
@write(bytes)
```

`@write` 接收 `VBytes`，所以构造链尾必须收尾于 `new` 表达式。简单的字段修补用 `new`；复杂修改先在 schema 里把目标字段编进 `new` 里。

**路径 C**：用 `-o` CLI 参数

```bash
dune exec rae -- script.rae input.elf -o out.elf
```

顶层表达式返回 `VBytes` 时直接落盘（`main.ml:45-50`）。配合路径 A 的 `@write` + VBytes 都行。

### 任务 6：加 ELF checksum 字段（用 `[checksum]` attr）

`[checksum = expr]` 在 `construct_binary` 时按 expr 算出 CRC32 并写入该位置 —— **目前表达式求值 CRC32 数据用的是截至 `cur_off` 处的所有已编码字节**（`engine.ml:319`），不是整个文件：

```rae
struct TrailingCrc {
    data: bytes(64) [count = 64];
    crc: u32 [checksum = 64];   // 写到 @ 64 处，CRC32(buf[0..cur_off])
}
```

注意：当前实现 `[checksum]` 的 expr 含义是"目标写入偏移"（数字），不是"校验和算法"，且数据来源是已编码区段。**对完整文件 CRC**（如 gzip trailer）需要外部工具补。

## 常见坑

1. **endian 一定要标**。ELF 头字段都是小端；显式写 `[endian = le]` 更稳。
2. **`bytes(n)` 的 n 必须是字面量**。变长字节段要用 `bytes [count = expr]`。
3. **`array<T>` 元素大小**：定长结构体 OK；`string`/`bytes` 元素不可用。
4. **不要假设 64 位**：把 32/64 都做出来并用 `[if = ...]` 切换更通用。
5. **`@write` 对 `VObj` 现在会触发 `construct_binary` 重编码** —— 不再是以前的"key=value 文本拼接"。但仍要求 schema 完整、字段类型和大小匹配。
6. **`h64.phoff` 这种动态偏移要写 `@ (.h64.phoff)`** 才能引用到同 struct 外（h64 在前，phdrs 在后，但 schema 解析阶段是顺序处理）。

## 调试步骤

1. 先单独跑最简 schema（只 Ident + H32/H64），确认 magic 通过
2. 逐步加 program header / section header
3. 校验失败时把 `== 0x7F454C46` 改成 `@echo(.ident.magic)` 手动比较
4. 对 32/64 不确定的输入，先打印 `.ident.class`

## 与其它 skill 的区别

- PE/COFF 用单独的 windows-pe skill
- 固件/裸二进制无 magic 也不走 ELF，请改用通用 binary-raw
- 网络抓包里封装 ELF 的，PCAP 容器层另解
