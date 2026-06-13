# RaE — Quality & Bugs

构建：`dune build` 通过，2 个 menhir shift/reduce conflict（预期内）。

## Quality (全关)

17 项，11 修 6 免修。

## Bug Report

| ID | 问题 | 状态 |
|----|------|------|
| B7 | `@checksum` VInt32/VInt64 字符串化 | ✅ |
| B9 | 位运算 keyword 形式 (`land`/`lor`/`lsl`) | ✅ |
| B15 | `template<T>` + 基本类型参数 | ✅ |
| B16 | u64 越界 | OCaml Int64 限制 |
| M1 | `array<struct>` 字段 mutation 崩 | ✅ |
| M2 | VBytes 字面量长度不匹配 blit 崩 | ✅ |

**本轮修复**：B7 value_to_bytes 对 VInt32/VInt64 用 write_uint；B9 lexer 加 land/lor/lxor/lsl/lsr keywords + parser BOR token；B15 resolve_type 将 StructType "u8" → U8 等基本类型映射。

## 设计注释

- B3 (`parse_binary` definitions) 不是 bug：struct 必须实例化为 field 才能解析
- N1 (`after(field)` 语义) 不是 bug：`after(X)` 明确是字段结束位置

---

## 实测发现的限制（M1/M2）

### M1. `array<struct>` 字段 mutation + construct 崩 — ❌
**位置**：`lib/engine.ml:178` `write_value` 走 `_ -> raise (Engine_error "Cannot serialize type")`，不处理 `StructType`。
**实测**：
```rae
file X {
    struct E { v: u32 @ 0; }
    arr: array<E> @ 0 [count = 2];
}
@block { .arr[0].v = 0xAAAAAAAA; new X { arr = .arr } }
```
→ `Engine error: Cannot serialize type`
- `array<u8>` work（`write_value` 走 I8|U8 返 bytes）
- `array<struct>` fail（`write_value StructType E` 走 `_` 抛错）
**workaround**：用 `.a`, `.b` 等基本类型字段做 mutation，不用 struct 数组字段。
**修复**：`write_value` 收到 `StructType sn` 递归调 `construct_binary sn` 拿 bytes。

### M2. VBytes 字面量长度不匹配 blit 崩 — ❌
**位置**：`lib/engine.ml:178` 同样原因。
**实测**：
```rae
file X { magic: bytes(4) @ 0; }
@block { new X { magic = "AB" } }    # 2字节 vs 4字段 → Bytes.blit 崩
```
**修复**：`write_value` 对 `StringType`/`BytesType` 截断到字段 size。

---

## ELF 编辑工作流

**已验证的 mutation 路径**（`/tmp/opencode/rae-test/s5.rae`）：
```rae
file ELF {
    struct H { magic: bytes(4) @ 0; pad1: bytes(8) @ 8; type: u16 @ 16; machine: u16 @ 18;
               version: u32 @ 20; entry: u64 @ 24; phoff: u64 @ 32; shoff: u64 @ 40;
               flags: u32 @ 48; ehsize: u16 @ 52; phentsize: u16 @ 54; phnum: u16 @ 56;
               shentsize: u16 @ 58; shnum: u16 @ 60; shstrndx: u16 @ 62; }
    h: H @ 0;
}
@block {
    .h.shstrndx = 30;     # 改 shstrndx 29→30
    new H { magic = .h.magic, pad1 = .h.pad1, type = .h.type, machine = .h.machine,
            version = .h.version, entry = .h.entry, phoff = .h.phoff, shoff = .h.shoff,
            flags = .h.flags, ehsize = .h.ehsize, phentsize = .h.phentsize, phnum = .h.phnum,
            shentsize = .h.shentsize, shnum = .h.shnum, shstrndx = .h.shstrndx }
}
$ rae script.rae in.elf -o out.elf
# out.elf 头部跟 in.elf 几乎一致，仅 shstrndx 字节改
$ rae read.rae out.elf   # 验证 shstrndx=30 ✓
```

**修改 entry point**（`/tmp/opencode/rae-test/s4.rae`）：
```rae
@block { .h.entry = 0x100000; new H { ... } }
# 写入 0x100000 = bytes `00 00 10 00 00 00 00 00` (LE) ✓
```

**完整 phdr 解析**（`/tmp/opencode/rae-test/s1.rae`）：
- 读 phdr[0].p_type=6 (PHDR) / phdr[1].p_type=3 (INTERP) / phdr[6].p_type=2 (DYNAMIC) ✓
- 读 phdr[0].p_offset=64 / phdr[1].p_offset=884 / phdr[6].p_offset=11688 ✓
