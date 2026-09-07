# Plan: Lua 字节码虚拟机 (Lua 实现) + 自定义格式模块

## 目标
用纯 Lua 实现一个 Lua 5.3 寄存器式字节码虚拟机，支持加载自定义 table 格式字节码；新增混淆模块 `vm_pack`（执行顺序最后），将标准 proto 序列化为该 VM 可加载的格式。

## 自定义格式设计
用 Lua table 作为中间格式（VM 直接加载 table，无需二进制解析）：
```
chunk = {
  num_params = int,
  is_vararg = int,
  maxstacksize = int,
  code = { {op=, a=, b=, c=, bx=, sbx=}, ... },  -- 已解码指令
  k = { {type="nil"|"bool"|"int"|"flt"|"str", val=}, ... },
  p = { chunk, ... },  -- 子函数
  upvalues = { {instack=, idx=}, ... },
}
```
混淆模块将 luac_Proto 递归转成此 table，VM 从 table 加载执行。

## 步骤
1. VM 核心：栈帧/寄存器/指令分发循环 — `vm.lua`
2. 指令实现：47 条标准指令逐条实现
3. 加载器：从 table 格式构建可执行 proto
4. 混淆模块 `vm_pack`：C 版 + Lua 版，递归序列化 proto 为 table
5. 模块注册：加入模块列表末尾
6. 测试：复杂代码混淆后通过 VM 运行，对比输出

## 当前进度
- [ ] 步骤1: VM 核心框架
- [ ] 步骤2: 指令实现
- [ ] 步骤3: 加载器
- [ ] 步骤4: vm_pack 模块
- [ ] 步骤5: 注册集成
- [ ] 步骤6: 测试验证

## 发现与决策
- 用 Lua table 作为自定义格式，避免二进制解析复杂度
- VM 用闭包+upvalue 模拟函数对象，子 proto 预编译为 Lua 函数对象
- 指令用 table 预解码（op/a/b/c/bx/sbx），运行时不再做位运算
