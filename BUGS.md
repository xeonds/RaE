# Bug Report — RaE 实际测试发现的问题

测试环境：OCaml + Dune 构建，两个 g++ 编译的真实 ELF 文件（hello.elf 16KB、types.elf 60KB）。

## 当前状态（2025-XX-XX 验证）

**`dune build` 失败** — `lib/engine.ml` 与 `lib/ast.ml` / `lib/parser.mly` / `bin/main.ml` 不同步。

具体：ast.ml 已重构为新 `expr` 类型（`BinaryOp`/`FieldAccess`/`Pipe`/...），parser.mly 生成对应语法，main.ml 调用 `Engine.parse_binary` / `Engine.eval_actions` 等新 API；但 `lib/engine.ml` 仍是旧版（引用不存在的 `Equal`/`Plus`/`Times`/`Access`/`I8Data`）。

错误：
```
File "lib/engine.ml", line 71, characters 8-13:
71 |       | Equal (e1, e2) ->
                 ^^^^^
Error: This variant pattern is expected to have type "expr"
       There is no constructor "Equal" within type "expr"
```

git reflog 显示 `reset: moving to @{upstream}` 把 `a5758bf fix: script parser` 等修复 commit 撤掉了，但 working tree 又有未提交的 ast/parser/main 修改 — 处于半完成状态。

**结论：本轮"修复"未生效，RAE 当前不可构建。**

---

## 修复前实测发现的问题（仍待处理）

### B1. 多顶层表达式时 current 被污染，导致后续字段访问全部失败
**文件**：`lib/engine.ml`（旧版 `eval_actions`，已不存在于 working tree）
**现象**：多个顶层 expr（`.field1` / `.field2` …）时，第一个之后的 expr 把 `current` 改成上一个 expr 的 `VInt`/`VObj` 等结果。
**实测**：
```rae
file ELF { type: u16 @ 16; machine: u16 @ 18; }
.type
.machine   (* 期望 62，实际空 *)
```
**注**：源码中 `separated_list(SEMICOLON, expr)` 强制要求 `;` 分隔顶层 expr；缺 `;` 时被解析为 pipe 链（`.type | .machine`），行为更混乱。

---

### B2. `@echo` 不处理 `VBytes`/`VString`/数组
**文件**：`lib/engine.ml` 旧版 `eval_builtin "echo"`
**现象**：`bytes(n)` 字段永远输出 `<value>`。

---

### B3. `parse_binary` 不处理 `file_def.definitions` 里的 struct
**文件**：`lib/engine.ml` 旧版 `parse_binary` / `lookup_struct`
**现象**：`file X { H: H @ 0; }` 报 `Engine error: Struct 'H' not found`。

---

### B4. 7 个未解决的 shift/reduce conflict
**文件**：`lib/parser.mly`
**来源**：`menhir --explain`
- `@block` 末尾 `option(SEMICOLON)` 与 `separated_nonempty_list` 冲突
- `MINUS` 一元 vs 二元
- `DOT` 后跟 `LBRACK`

---

### B5. 字符串/变长字段未实现
**文件**：`TODO.md` 标记未完成
**现象**：`string` / `bytes` 强制要求 `(n)` 形式；无大小写法 syntax error。

---

### B6. `@write` 只能写原始 bytes
**文件**：`lib/engine.ml` 旧版 `eval_builtin "write"`
**现象**：`@write("out.bin")` 永远写原始文件，未应用任何修改（mutation 路径未实现）。

---

### B7. `@checksum` 对结构体/嵌套值静默返回 0
**文件**：`lib/engine.ml` 旧版 `value_to_bytes`
**现象**：`@checksum(.header)` 实际算空 sum，返回 0，无错误提示。

---

### B8. `field_decl` 分号接受行为不一致
**文件**：`lib/parser.mly` `field_decl` 强制 `SEMICOLON`
**现象**：单字段/多字段/换行场景下接受行为不统一。

---

### B9. `eval_binary_op` 不支持 `VInt32`/`VInt64`
**文件**：`lib/engine.ml` 旧版 `eval_binary_op`

---

### B10. `eval_actions` 副作用与返回值耦合
**文件**：`lib/engine.ml` 旧版 `eval_builtin`

---

## 历史工作流（修复前曾验证）

按 README 写法 + `@block` 包裹，曾能正确解析真实 ELF：

```rae
file ELF {
    struct Header { magic: bytes(4) @ 0; class: u8 @ 4; ... shstrndx: u16 @ 62; }
    header: Header @ 0;
}
@block { @echo(.header.magic); @echo(.header.class); @echo(.header.shnum) }
```

跑 `hello.elf`/`types.elf`，17 个 ELF 头字段值与 `readelf -h` 一致。

**唯一不可用部分**：`magic`（VBytes）输出 `<value>`；`.sections` 等变长数组未完成。
