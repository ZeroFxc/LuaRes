p = r'C:\Users\ruilo\AppData\Local\DoubaoWork\User Data\Default\.doubaowork\agent_mode\workspace\.user_skills\lua-bytecode-obfuscation\SKILL.md'

new_section = '''

---

## 十三、实战经验与深度排障

### 13.1 upvalue_promote 模块完整 bug 修复历程（最有价值的参考）

upvalue_promote（upvalue 升降——IIFE 包装基本块，外部变量变闭包 upvalue）在开发过程中累计修复了 15 个串联 bug。这是字节码混淆模块开发中最典型的排障案例，每个 bug 都代表一类常见错误。

**Bug 1: obf_compile_subproto 的 src 格式错误**
- 症状：模块 0 变化，什么都没做
- 根因：传入的 src 是 `"function() return end"`（表达式不是语句），编译失败
- 修复：必须是 `"return function() return end"` 格式
- 教训：用 `obf_compile_subproto` 时，src 必须是一个完整的 Lua 语句块，返回一个函数

**Bug 2: 返回值检查写反**
- 症状：模块仍然 0 变化
- 根因：`if (ret != 0)` 把成功（返回 1）当失败
- 修复：`if (ret == 0)` 才是失败
- 教训：`obf_compile_subproto` 返回 1=成功，0=失败，不要搞反

**Bug 3: ins_reads_reg 对 CALL/TAILCALL 漏掉函数寄存器 A**
- 症状：完整特性脚本报 "attempt to call a string value"
- 根因：CALL 指令的函数寄存器 A 不被认为是"读取的寄存器"，导致 print 函数所在寄存器不被识别为外部变量，子 proto 中 CALL 时 R1 未定义残留字符串
- 修复：`ins_reads_reg` 对 CALL/TAILCALL 检查 A（函数寄存器）和 A+1 到 A+B-2（参数寄存器）
- 教训：分析指令的寄存器读写时，CALL 的函数寄存器也是读取的

**Bug 4: defined 数组不处理"先读后写"**
- 症状：仍然 "attempt to call a string value"
- 根因：只检查"块中是否被写入"，不处理"先读后写"（R1 先被 CALL 读取后被 GETTABLE 写入）
- 修复：改为前向数据流分析 `first_read >= 0 && (first_write < 0 || first_read < first_write)`
- 教训：判断一个变量是否是"外部变量"（块开始前已有值），要看第一次读取是否在第一次写入之前

**Bug 5: 递归处理子 proto 导致闭包返回值丢失**
- 症状：第 9 行 `print((function(x)return{x}end)(6))` 应输出 table 实际输出 6.6
- 根因：upvalue_promote 递归处理了子 proto（闭包函数体），子 proto 中 `return {x}` 的函数体被包装成 IIFE，但 IIFE 中创建的表在 R2 不会传回父栈帧
- 修复：禁用子 proto 处理，只处理主 proto
- 教训：IIFE 包装的副作用是不会把寄存器值传回调用者，处理子 proto 时要特别小心返回值

**Bug 6: upvalue instack=0 应为 1**
- 症状：位运算操作数为 nil
- 根因：子 proto 的 upvalue 设置中，外部变量的 `instack=0`，但外部变量是父 proto 的局部变量（寄存器），应为 `instack=1`
- 修复：`instack=1, idx=ext_regs[i]`
- 教训：Lua upvalue 的 instack=1 表示直接引用父栈帧的寄存器，instack=0 表示引用父 proto 的共享 upvalue。把局部变量作为 upvalue 时必须 instack=1

**Bug 7: ins_reads_reg CONCAT 只检查 B/C 漏掉中间寄存器**
- 症状：CONCAT 相关的外部变量识别错误
- 根因：CONCAT A B C 读取 R(B) 到 R(C) 所有寄存器，原代码只检查 B 和 C
- 修复：`return (reg >= B && reg <= C)`
- 教训：CONCAT 是范围读取，不是只读取两个端点

**Bug 8: ins_reads_reg SETLIST 只检查 A**
- 根因：SETLIST 读取 R(A+1) 到 R(A+B)，原代码只检查 A
- 修复：检查 [A+1, A+B] 范围

**Bug 9: ins_writes_reg SELF 漏掉 A+1**
- 根因：SELF 写入 R(A) 和 R(A+1)，原代码只检查 A
- 修复：检查 A 和 A+1

**Bug 10: ins_writes_reg VARARG 漏掉 A 到 A+B-2**
- 根因：VARARG 写入 R(A) 到 R(A+B-2)，原代码只检查 A
- 修复：检查 [A, A+B-2] 范围

**Bug 11: CONCAT 既读又写导致外部变量识别错误**
- 症状：`CONCAT R6,R6,R7` 中 R6 不被识别为外部变量
- 根因：`ins_writes_reg` 认为 CONCAT 写入了 R6（A=6），所以 R6 被认为是"块中定义的变量"，不是外部变量。但实际上 CONCAT R6,R6,R7 先读取 R6 再写入 R6，R6 的初始值来自块外部
- 修复：在 `ins_writes_reg` 中对 CONCAT 特殊处理：如果目标寄存器 A 也在源范围 [B,C] 内，则不认为写入了 A（返回 0）
- 教训：既读又写的指令（CONCAT、二元运算）在"是否写入了寄存器"的判断上需要特殊处理，用于外部变量分析时

**Bug 12: NEWTABLE 块跳过**
- 症状：包含表创建的块被 IIFE 包装后，表引用丢失
- 根因：NEWTABLE 创建的表在当前栈帧，IIFE 不会把表引用传回
- 修复：块中包含 NEWTABLE 时跳过该块
- 教训：IIFE 包装不适用于创建需要在块外部使用的对象的块（表、闭包等）

**Bug 13: 活跃变量分析（live-out）缺失**
- 症状：块中写入的寄存器在块之后被读取，导致值丢失
- 根因：没有检查块中写入的寄存器是否在块之后被使用
- 修复：添加活跃变量分析——块中修改的寄存器若在块之后被读取，则跳过该块
- 教训：IIFE 包装的基本块不能修改在块之后仍然活跃的变量，因为 IIFE 不会把值传回

**Bug 14: 二元运算既读又写**
- 症状：`BXOR R5,R5,R4` 中 R5 不被识别为外部变量
- 根因：与 Bug 11 同理，二元运算 A==B 或 A==C 时既读又写
- 修复：对 ADD/SUB/MUL/MOD/POW/DIV/IDIV/BAND/BOR/BXOR/SHL/SHR，如果 A==B 或 A==C，不认为写入了 A

**Bug 15: 活跃变量分析用 ins_writes_reg 导致 CONCAT 既读又写漏检**
- 症状：str_enc+str_split+upval 组合报 "attempt to concatenate a nil value"
- 根因：活跃变量分析用 `ins_writes_reg` 判断"块中是否写入了寄存器"，但 CONCAT R6,R6,R7 因 Bug 11 修复，`ins_writes_reg` 返回 0（不认为写入了 R6），导致活跃变量分析认为 R6 没被修改，不检查 R6 是否在块后被读取
- 修复：添加 `ins_modifies_reg` 函数（活跃变量分析专用，既读又写也算修改了寄存器值），并将活跃变量分析中的 `ins_writes_reg` 替换为 `ins_modifies_reg`
- 教训：同一个指令的"是否写入"在不同场景下有不同含义——外部变量分析用"是否定义了新值"（既读又写不算），活跃变量分析用"是否修改了值"（既读又写算）

### 13.2 各模块的触发条件（模块不生效时先检查这些）

| 模块 | 触发条件 | 不生效的常见原因 |
|------|----------|------------------|
| upvalue_promote | 基本块中有外部变量（块开始前已定义、块中读取、不在块后活跃） | 块太小、所有变量都是块内定义、NEWTABLE 块被跳过、活跃变量分析跳过 |
| call_rewrite (参数) | CLOSURE 后紧跟 CALL（IIFE 模式），参数>1 | 局部函数调用不是 CLOSURE+CALL 紧邻模式 |
| call_rewrite (返回值) | RETURN A B 且 B>2（返回 2+ 个值） | 函数只返回 1 个值 |
| debug_mutate | 字节码中有调试信息（locvars/lineinfo） | wasm_load 编译源码时 strip 了调试信息（已修复为不 strip） |
| operator_substitute | 有 ADD/SUB/MUL 等算术指令 | 测试代码太简单没有算术运算 |
| condition_split | 有 if/elseif 条件分支 | 测试代码没有条件分支 |
| loop_restructure | 有循环结构 | 测试代码没有循环 |
| indirect_call | 有直接 CALL 调用 | 测试代码太简单 |
| reg_shuffle | 有足够多的寄存器使用 | 测试代码太简单 |

**关键：模块不生效时，先用"对比变更"按钮确认字节码是否真的有变化。如果没有变化，检查触发条件是否满足。**

### 13.3 网页"对比变更"功能使用

网页中有"对比变更"按钮（在"查看字节码"旁边），点击后自动对比混淆前后的字节码，显示：

1. **变更摘要** — 指令/常量/子Proto 数量变化
2. **Opcode 分布变化** — 每个 opcode 的增减（如 LOADK +92, SETTABLE +36）
3. **详细变更表** — 递归对比所有 proto 的：
   - 基本字段（sizecode, sizek, numparams, maxstacksize 等）
   - 常量池（类型、值）
   - locvars（变量名、作用域）
   - upvalues（名称、instack、idx）
   - 子 proto（递归对比）

**使用场景：**
- 验证新模块是否真的修改了字节码（运行通过 ≠ 模块生效）
- 定位模块不生效的原因（看哪个字段没有变化）
- 对比不同模块组合的效果差异
- 调试时确认修改是否生效

### 13.4 debug_mutate 模块的调试信息依赖

debug_mutate 修改 locvar 名和 lineinfo，需要字节码中有调试信息。

**wasm_load 编译源码时：**
- 之前：`string.dump(func, true)` — strip 调试信息，debug_mutate 无法工作
- 现在：`string.dump(func, false)` — 保留调试信息，debug_mutate 可以工作
- 用户可通过"调试信息剥离"模块在最后手动 strip

**教训：** 编译源码时是否 strip 调试信息会影响依赖调试信息的模块。如果有模块修改调试信息，就不能 strip。

### 13.5 寄存器读写分析的完整参考

实现涉及寄存器分析的模块时，必须正确处理以下指令的读写：

**读取寄存器的指令（ins_reads_reg）：**
- MOVE: 读 B
- GETUPVAL: 无（读 upvalue 不是寄存器）
- GETTABUP: 读 C（RK）
- GETTABLE: 读 B, C（RK）
- SETTABUP: 读 B, C（RK）
- SETUPVAL: 读 A
- SETTABLE: 读 A, B, C（RK）
- NEWTABLE: 无
- SELF: 读 B, C（RK），写 A, A+1
- ADD/SUB/MUL/MOD/POW/DIV/IDIV: 读 B, C（RK）
- BAND/BOR/BXOR/SHL/SHR: 读 B, C（RK）
- UNM/BNOT/NOT/LEN: 读 B（RK）
- CONCAT: **读 [B, C] 范围**（不是只读 B 和 C）
- JMP: 无
- EQ/LT/LE: 读 B, C（RK）
- TEST: 读 A
- TESTSET: 读 B
- CALL/TAILCALL: **读 A（函数寄存器）+ [A+1, A+B-2]（参数寄存器）**
- RETURN: 读 [A, A+B-2]
- FORLOOP/FORPREP: 读 A（内部状态）
- TFORCALL: 读 A+1, A+2
- TFORLOOP: 读 A
- SETLIST: **读 [A+1, A+B]**（不是只读 A）
- CLOSURE: 无
- VARARG: 无（写入）

**写入寄存器的指令（ins_writes_reg）：**
- MOVE: 写 A
- LOADK/LOADKX/LOADBOOL/LOADNIL: 写 A
- GETUPVAL/GETTABUP/GETTABLE: 写 A
- SETTABUP/SETUPVAL/SETTABLE: 无（写表/upvalue）
- NEWTABLE: 写 A
- SELF: **写 A, A+1**
- 所有二元运算: 写 A（但 A==B 或 A==C 时既读又写，外部变量分析时不算写入）
- UNM/BNOT/NOT/LEN: 写 A
- CONCAT: 写 A（但 A 在 [B,C] 时既读又写，外部变量分析时不算写入）
- TESTSET: 写 A
- CALL: 写 [A, A+B-1]（返回值）
- TAILCALL: 无（尾调用不返回）
- RETURN: 无
- FORLOOP: 写 A（更新索引）
- TFORLOOP: 写 [A+3, A+2+C]
- SETLIST: 无
- CLOSURE: 写 A
- VARARG: **写 [A, A+B-2]**
- EXTRAARG: 无

**既读又写的特殊处理：**
- 外部变量分析（判断变量是否在块开始前已有值）：既读又写不算写入（`ins_writes_reg` 返回 0）
- 活跃变量分析（判断变量是否在块后被使用）：既读又写算修改（`ins_modifies_reg` 返回 1）

### 13.6 IIFE 包装模式的副作用与限制

upvalue_promote 使用 IIFE（立即调用函数表达式）包装基本块，把外部变量变成闭包 upvalue。这种模式有以下副作用和限制：

1. **返回值不传递** — IIFE 中创建的表、闭包等对象不会自动传回父栈帧。如果块中创建了需要在块外部使用的对象（NEWTABLE、CLOSURE），必须跳过该块。

2. **寄存器值不传递** — IIFE 中修改的寄存器值不会传回父栈帧。如果块中修改了在块之后仍然活跃的变量，必须跳过该块（活跃变量分析）。

3. **upvalue 引用方式** — 外部变量通过 upvalue 引用，instack=1 表示直接引用父栈帧寄存器。修改 upvalue 会直接修改父栈帧的寄存器（因为 instack=1）。

4. **性能开销** — 每个被包装的块都创建一个闭包并立即调用，有 CLOSURE+CALL 开销。不要包装太小的块（如单条指令）。

5. **不适用于子 proto** — 递归处理子 proto 会导致闭包返回值丢失（Bug 5），只处理主 proto。

### 13.7 排障时的日志策略

**C 层日志：**
```c
#define MYMODULE_DEBUG 1  // 调试时设 1，完成后设 0（不删除代码）

#if MYMODULE_DEBUG
    fprintf(stderr, "[mymodule] block=[%d,%d) ext_count=%d\n", start, end, ext_count);
    for (int i = start; i < end; i++) {
        fprintf(stderr, "  [%d] op=%d A=%d B=%d C=%d\n", i, p->code[i]&0x3F,
                (p->code[i]>>6)&0xFF, (p->code[i]>>23)&0x1FF, (p->code[i]>>14)&0x1FF);
    }
#endif
```

**WASM 中读取 stderr：**
- 网页中 `window._wasmStderr` 收集 fprintf(stderr, ...) 输出
- 或在 app.js 的 printErr 回调中收集

**日志级别建议：**
1. 入口日志：模块被调用、处理了多少个 proto
2. 选择日志：每个候选块的位置、外部变量数量、是否被跳过及原因
3. 详细日志：被处理块的指令序列、外部变量列表
4. 结果日志：修改了多少处、插入了多少指令

**关键：每次只改一个变量，改完立即编译测试。不要一次改多处导致无法定位哪个修改生效。**

### 13.8 已验证做不通的方案（不要重复尝试）

- **完整性校验模块** — 强制 mismatch 仍正常输出，运行时无法可靠校验字节码完整性（已移除）
- **MinGW -fsanitize=address** — 不支持
- **wasm_get_debug 通过 EMSCRIPTEN_KEEPALIVE 导出** — 在 WASM 中未导出，用 wasm_last_error 代替
- **calloc 从零创建 proto** — 会导致 CLOSURE+CALL 崩溃，必须用 obf_compile_subproto
- **upvalue_promote 递归处理子 proto** — 闭包返回值丢失，只处理主 proto
- **first_read <= first_write（外部变量判断）** — 导致某些块错误跳过，应为 first_read < first_write
- **块结尾截断** — 导致输出错误（第 10/12 输出 0）

---

## 十四、模块创意库（可扩展的新模块方向）

以下是经过分析可行的新模块方向，按实现难度排序：

### 14.1 低难度（已有参考实现模式）

1. **常量编码变换** — 把数字常量 x 变成 x XOR key，运行时再 XOR 回来；字符串常量变成 base64/rot13，运行时解码
2. **指令重排序（局部）** — 在无依赖的指令之间交换顺序（如两个独立的 LOADK）
3. **等价指令替换** — `MOVE A,B` ↔ `ADD A,B,0`（需要常量 0）；`LOADK A,k` ↔ `LOADKX A + EXTRAARG k`
4. **假调试信息注入** — 插入不存在的 locvar（作用域不覆盖任何指令）、假 lineinfo（行号跳跃）
5. **常量池去重/重复** — 相同值的常量合并或故意重复（改变 LOADK 索引）

### 14.2 中难度（需要数据流分析）

6. **寄存器生命周期分割** — 把一个寄存器的生命周期分成两段，中间用 MOVE 到高寄存器再 MOVE 回来（已有 live_range_split 模块的增强版）
7. **表达式拆分** — 把 `a + b * c` 拆成 `t1 = b * c; t2 = a + t1`（如果编译器已经做了就跳过）
8. **条件表达式转控制流** — 把 `x = a and b or c` 转成 if-else 控制流
9. **循环展开/折叠** — 把小循环展开成重复代码，或把重复代码折叠成循环
10. **函数内联/外提** — 把小函数调用内联，或把重复代码提取成函数

### 14.3 高难度（需要控制流分析）

11. **控制流图随机化** — 把基本块重新排序，用 JMP 连接（已有 flatten 模块的增强版）
12. **分支函数化** — 把 if-else 的每个分支变成独立函数，通过函数指针调用
13. **异常处理混淆** — 用 pcall/error 模拟正常控制流（把 if 变成 pcall+error）
14. **状态机分发增强** — 已有 flatten_enhance，可进一步多样化分发方式（表查找、算术计算、嵌套 switch）

### 14.4 研究方向（需要深入理解 Lua VM）

15. **自定义 opcode 编码** — 把标准 opcode 映射到自定义编码，运行时用自定义解释器执行（vm_embed 的变体）
16. **字节码加密 + 运行时解密** — 把字节码加密，运行时在自定义 loader 中解密（需要修改 lundump.c）
17. **元方法混淆** — 把普通操作变成元方法调用（如 `a + b` 变成 `getmetatable(a).__add(a,b)`）
18. **环境表混淆** — 把全局变量访问变成通过环境表间接访问（_ENV 操作）
'''

with open(p, 'a', encoding='utf-8') as f:
    f.write(new_section)

print(f'Appended {len(new_section)} bytes to SKILL.md')
