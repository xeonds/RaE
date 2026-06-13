---
name: elf-analysis
description: Use this skill whenever the user wants to inspect, extract information from, or modify an ELF binary (Linux executable, .so, object file) using RaE. Triggers on requests like "查看 ELF 头", "修改 ELF section", "改 dynamic section", "重写 ELF", "extracting symbols from ELF", "read ELF program headers". Also triggers when the user is working with executables, shared libraries, or relocatable objects and wants a schema-driven way to read/write them. Do NOT use for PE/COFF (Windows), Mach-O (macOS), or non-ELF binary formats.
---

# ELF Analysis & Modification with RaE

RaE 是 awk/jq for binary files；本 skill 帮你用 RaE 的声明式 schema 处理 ELF 文件（Executable and Linkable Format）。

## 何时使用

- 解析 ELF 头、program header table、section header table
- 提取 dynamic section、symbol table、relocation table 的字段
- 修改 ELF 中某字段并通过 `new` 重新构造落盘
- 校验 ELF magic、machine type、e_ident 各项

**不适用**：PE/COFF、Mach-O、Firmware 镜像里的 ELF 容器请改用对应 skill。

## ELF 最小事实（写 schema 前先确认）

- 文件以 `0x7F 'E' 'L' 'F'` 四个字节开头（magic）
- 32 位 ELF 头占 52 字节，64 位占 64 字节
- 大小端由 `e_ident[EI_DATA]` 决定（1=LE, 2=BE）
- 字段 `e_phoff` 指向 program header table，每个 program header 在 32 位下 32 字节、64 位下 56 字节
- section header table 同理，32/64 位各 40/64 字节
- 关键常量：`ET_EXEC=2`, `ET_DYN=3`, `EM_X86_64=0x3E`, `EM_AARCH64=0xB7`, `EM_RISCV=0xF3`

## 最小可运行 schema

```rae
file ELF {
    struct Ident {
        magic: u32 @ 0 [endian = be] == 0x7F454C46;
        class: u8 @ 4;     // 1=32bit, 2=64bit
        data: u8 @ 5;      // 1=LE, 2=BE
        version: u8 @ 6;
        osabi: u8 @ 7;
        pad: bytes(8) @ 8;
    }
    ident: Ident @ 0;

    struct H32 {
        type: u16 @ 16;
        machine: u16 @ 18;
        version: u32 @ 20;
        entry: u32 @ 24;
        phoff: u32 @ 28;
        shoff: u32 @ 32;
        flags: u32 @ 36;
        ehsize: u16 @ 40;
        phentsize: u16 @ 42;
        phnum: u16 @ 44;
        shentsize: u16 @ 46;
        shnum: u16 @ 48;
        shstrndx: u16 @ 50;
    }
    struct H64 {
        type: u16 @ 16;
        machine: u16 @ 18;
        version: u32 @ 20;
        entry: u64 @ 24;
        phoff: u64 @ 32;
        shoff: u64 @ 40;
        flags: u32 @ 48;
        ehsize: u16 @ 52;
        phentsize: u16 @ 54;
        phnum: u16 @ 56;
        shentsize: u16 @ 58;
        shnum: u16 @ 60;
        shstrndx: u16 @ 62;
    }
    h32: H32 @ 16 [if = .ident.class == 1];
    h64: H64 @ 16 [if = .ident.class == 2];
}
```

变体用 `variant(ident.class)` 也可以，但 `if` 条件更直接。

## 典型任务模板

### 任务 1：读出 ELF 头关键字段

```rae
file ELF { ... 上面那个最小 schema ... }
.ident.data
```

如果是要看 32/64 位头，把 `h32`/`h64` 都加进 schema，再写：

```rae
.ident.data
```

注意：`[if = ...]` 字段不满足条件时不会出现在 env 里。

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

`@echo` 对 `VInt` 直接打印十进制。要看 magic 的 hex，自己再写到 0x7F454C46 比较。

### 任务 3：program header 列表

64 位 program header 56 字节：

```rae
struct Phdr64 {
    type: u32 @ 0;
    flags: u32 @ 4;
    offset: u64 @ 8;
    vaddr: u64 @ 16;
    paddr: u64 @ 24;
    filesz: u64 @ 32;
    memsz: u64 @ 40;
    align: u64 @ 48;
}
phdrs: array<Phdr64> @ .h64.phoff [count = .h64.phnum];
```

然后 `.phdrs | @each(p in .) { @echo(p.type) }` 可以遍历（但 `phdrs` 是顶层字段，访问用 `.phdrs[]` + `@each`）。

### 任务 4：解析 section header string table

`.shstrndx` 是 `shstrndx` 的下标；要拿名字字符串需要把对应 section 的 `offset` + `size` 切片出来。schema 里：

```rae
shstr: bytes @ after(.shdrs) [count = .shdrs[.h64.shstrndx].size];
```

注意 `bytes` 字段必须用 `[count = expr]` 给定长度才能定界。

### 任务 5：修改 ELF 并落盘

RaE 的 `new` 是用 schema 重新构造二进制，最稳的回写路径：

```rae
file ELF { ... }
let bytes = new H32 { type = 2, machine = 0x3E, version = 1, entry = 0,
                     phoff = 52, shoff = 0, flags = 0, ehsize = 52,
                     phentsize = 0, phnum = 0, shentsize = 0, shnum = 0, shstrndx = 0 }
       | new Ident { magic = 0x7F454C46, class = 1, data = 1, version = 1, osabi = 0, pad = "" };
@write("/tmp/out.elf")
```

`@write` 接收 `VBytes`，所以构造链尾必须收尾于 `new` 表达式。简单的字段修补用 `new`，对复杂修改先在 schema 里把目标字段编进 `new` 里。

## 常见坑

1. **endian 一定要标**。ELF 头字段都是小端；缺省按 le 处理但显式写 `[endian = le]` 更稳。
2. **`bytes(n)` 的 n 必须是字面量**。`[count = expr]` 配合 `bytes` 字段用，且 `expr` 必须是字面量才在 `@write` 序列化时拿到长度。
3. **`array<T>` 元素大小**：对定长结构体 OK；对 `string`/`bytes` 元素不可用，因为无固定 stride。
4. **不要假设 64 位**：把 32/64 都做出来并用 `[if = ...]` 切换更通用。
5. **`@write` 不会按 schema 编码 `VObj`**。要"修改 ELF 字段并落盘"，必须用 `new` 重新构造。

## 调试步骤

1. 先单独跑最简 schema（只 Ident + 一两个 H32/H64 字段），确认 magic 通过
2. 逐步加 program header / section header
3. 校验失败时把 `== 0x7F454C46` 改成 `@echo(.ident.magic)` 手动比较
4. 对 32/64 不确定的输入，先打印 `.ident.class`

## 与其它 skill 的区别

- PE/COFF 用单独的 windows-pe skill
- 固件/裸二进制无 magic 也不走 ELF，请改用通用 binary-raw
- 网络抓包里封装 ELF 的，PCAP 容器层另解
