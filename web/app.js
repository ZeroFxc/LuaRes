/* Luac WASM Obfuscator - App Logic v2 */
(function(){
'use strict';

// ---- Built-in module definitions ----
const MODULE_GROUPS = [
  { name: '常量混淆', modules: [
    { id: 'bool_obfuscate_c', label: '布尔混淆', desc: 'true/false 替换为算术表达式' },
    { id: 'num_obfuscate_c', label: '数字混淆', desc: '整数常量拆分为 ADD/SUB/BXOR' },
    { id: 'str_split_c', label: '字符串分割', desc: '长字符串拆分为多段 CONCAT' },
    { id: 'const_hide_c', label: '常量隐藏', desc: '字符串编码为字节数组+运行时重建' },
    { id: 'str_encrypt_c', label: '字符串加密', desc: 'XOR 加密字符串+内联解密 opcode' },
    { id: 'const_shuffle_c', label: '常量池打乱', desc: '重排常量池顺序+修正所有引用' },
  ]},
  { name: '指令混淆', modules: [
    { id: 'instruction_mutate_c', label: '指令变异', desc: '等价指令替换 (MOVE/LOADK 等)' },
    { id: 'operator_substitute_c', label: '运算符等价替换', desc: 'ADD/SUB/MUL 替换为位运算/算术等价式' },
    { id: 'table_obfuscate_c', label: '表混淆', desc: 'NEWTABLE/SETTABLE 常量隐藏' },
    { id: 'opaque_predicate_c', label: '不透明谓词', desc: '插入恒真/恒假条件分支' },
    { id: 'const_poison_c', label: '常量投毒', desc: '插入无效常量干扰反编译' },
    { id: 'reg_shuffle_c', label: '寄存器洗牌', desc: '插入冗余 MOVE 链，高寄存器中转' },
    { id: 'proto_shuffle_c', label: 'Proto重排', desc: '打乱子函数Proto顺序+修正CLOSURE索引' },
    { id: 'live_range_split_c', label: '活跃范围分裂', desc: '寄存器值存高寄存器+ dummy覆盖+恢复' },
  ]},
  { name: '垃圾指令', modules: [
    { id: 'opaque_junk_c', label: '不透明垃圾', desc: 'TEST+JMP 跳过的垃圾指令' },
    { id: 'junk_c', label: '纯花指令', desc: '独立花指令注入(MOVE/LOADBOOL/NEWTABLE 等)' },
    { id: 'junk_jmp_c', label: '跳转垃圾', desc: '插入无意义 JMP 指令' },
    { id: 'junk_loadk_c', label: 'LOADK 垃圾', desc: '插入无效 LOADK 加载到废弃寄存器' },
    { id: 'junk_move_c', label: 'MOVE 垃圾', desc: '插入无效 MOVE 指令' },
    { id: 'op48_junk_c', label: 'OP48 垃圾', desc: '自定义 48 号 opcode 垃圾指令' },
  ]},
  { name: '字节码混淆', modules: [
    { id: 'luac_obfuscate_c', label: '字节码加密', desc: '整体字节码 XOR 加密+运行时解密' },
    { id: 'luac_flatten_c', label: '控制流平坦化', desc: '将顺序执行转为分发器循环' },
    { id: 'flatten_enhance_c', label: '分发增强', desc: '平坦化后状态值算术化+分发比较XOR混淆，需在平坦化后运行' },
  ]},
  { name: '控制流', modules: [
    { id: 'condition_split_c', label: '条件拆分', desc: '单个判断拆为多重不透明谓词(4种模式)，与扁平化联动增强分发复杂度' },
    { id: 'loop_restructure_c', label: '循环重构', desc: '插入执行一次的循环模板混入正常代码' },
    { id: 'for_loop_unroll_c', label: 'for循环展开', desc: 'FORPREP+FORLOOP无损展开为普通指令，破坏反编译器for循环特征识别' },
    { id: 'tforcall_to_call_c', label: 'TFORCALL转CALL', desc: '泛型for迭代器调用转普通CALL，断裂TFORCALL+TFORLOOP配对' },
    { id: 'tforloop_as_jump_c', label: 'TFORLOOP混淆跳转', desc: '回跳JMP改TFORLOOP+LOADBOOL，利用条件复制语义避免被一键还原' },
    { id: 'fake_forloop_c', label: '伪造FOR循环', desc: '插入循环次数为0的伪造FORPREP+FORLOOP对，反编译器输出无意义for但实际不执行' },
    { id: 'jmp_obfuscate_c', label: 'JMP偏移混淆', desc: '插入 no-op JMP 链混淆跳转偏移' },
    { id: 'indirect_call_c', label: '间接调用', desc: 'CALL 前经临时表存取值，函数调用间接化' },
    { id: 'call_rewrite_c', label: '参数/返回值混淆', desc: 'f(a,b)→f({a,b})内部解包，多返回值先打包再解包' },
    { id: 'upvalue_promote_c', label: 'upvalue升降', desc: 'IIFE包装把局部变量提升为upvalue，改变变量存储方式' },
    { id: 'block_clone_c', label: '基本块克隆', desc: '每个直线块克隆一份(寄存器重映射)，不透明谓词选择原版/克隆版，CFG节点翻倍' },
    { id: 'cfg_shuffle_c', label: 'CFG基本块重排', desc: '物理打乱基本块顺序，块间用JMP连接，反编译器按物理顺序解析看到混乱控制流' },
  ]},
  { name: '其他', modules: [
    { id: 'debug_strip_c', label: '调试信息剥离', desc: '移除 lineinfo/locvars/upvalue 名' },
    { id: 'antidec_c', label: '反编译对抗', desc: '插入干扰 unluac/luadec 的结构' },
    { id: 'debug_mutate_c', label: '调试信息变异', desc: '伪造 locvar/upval 名和 lineinfo，不剥离' },
  ]},
  { name: '虚拟机组装', modules: [
    { id: 'vm_dispatch_shuffle_c', label: 'VM分发重映射', desc: '随机重映射opcode编号，主循环分发三选一（switch乱序/查表/算术），每轮结果不同，最后执行' },
    { id: 'vm_reg_shuffle_c', label: 'VM寄存器槽打乱', desc: 'VM内部寄存器槽重命名：载荷寄存器编号与解释器寄存器表访问下标同步remap，跟分发重映射共用seed派生' },
    { id: 'vm_const_shuffle_c', label: 'VM常量池打乱', desc: '生成的VM常量池表顺序打乱+载荷常量索引同步remap，字符串/数字/表交错排列，跟opcode remap对称' },
    { id: 'vm_embed_c', label: '自包含VM打包', desc: '成品式：把字节码转为纯Lua自包含解释器，零外部依赖，最后执行' },
  ]},
];

const BUILTIN_IDS = new Set(MODULE_GROUPS.flatMap(g => g.modules.map(m => m.id)));

// Execution order (matches menu.lua FORWARD_ORDER)
const EXEC_ORDER = [
  'const_hide_c','const_shuffle_c','str_split_c','str_encrypt_c','instruction_mutate_c','operator_substitute_c','call_rewrite_c','upvalue_promote_c','block_clone_c','cfg_shuffle_c','for_loop_unroll_c','tforcall_to_call_c','tforloop_as_jump_c','fake_forloop_c',
  'num_obfuscate_c','bool_obfuscate_c','table_obfuscate_c',
  'opaque_predicate_c','const_poison_c','opaque_junk_c','junk_jmp_c',
  'junk_loadk_c','junk_move_c','luac_obfuscate_c','luac_flatten_c',
  'flatten_enhance_c','debug_strip_c','debug_mutate_c','antidec_c','proto_shuffle_c',
  'live_range_split_c','op48_junk_c','vm_dispatch_shuffle_c','vm_reg_shuffle_c','vm_const_shuffle_c','vm_embed_c'
];
const EXEC_ORDER_MAP = new Map(EXEC_ORDER.map((id,i) => [id, i]));
function sortModulesForExecution(mods){
  return [...mods].sort((a,b) => {
    const ia = EXEC_ORDER_MAP.has(a) ? EXEC_ORDER_MAP.get(a) : 999;
    const ib = EXEC_ORDER_MAP.has(b) ? EXEC_ORDER_MAP.get(b) : 999;
    return ia - ib;
  });
}
let _dsSeedInit = 0;
function dsFreshSeed(){
  if(!_dsSeedInit){ _dsSeedInit = Math.floor(Math.random() * 0x7FFFFFFF) + 1; }
  return _dsSeedInit;
}
const STORAGE_KEY = 'luac_obf_config_v2';
const CUSTOM_STORAGE_KEY = 'luac_obf_custom_modules_v2';
const JS_CUSTOM_STORAGE_KEY = 'luac_obf_js_modules_v2';

// ---- State ----
let Module = null;
let wasmReady = false;
let fileBytes = null;
let fileName = '';
let resultBytes = null;
let resultIsLua = false;
let customModules = []; // [{name, label, description, source}] (Lua)
let jsModules = [];     // [{name, label, description, source, moduleObj}] (JS)
let vmLuajitCompat = false; // LuaJIT compat mode for vm_embed

// ---- DOM ----
const $ = id => document.getElementById(id);
const uploadZone = $('uploadZone'), fileInput = $('fileInput');
const fileNameEl = $('fileName'), fileInfo = $('fileInfo');
const origSizeEl = $('origSize'), modCountEl = $('modCount'), customCountEl = $('customCount');
const moduleScroll = $('moduleScroll');
const btnProcess = $('btnProcess'), btnProcessRun = $('btnProcessRun'), btnDownload = $('btnDownload'), btnRun = $('btnRun');
const btnAll = $('btnAll'), btnNone = $('btnNone'), btnClearLog = $('btnClearLog'), btnDebugLocate = $('btnDebugLocate'), btnDebugLocateCum = $('btnDebugLocateCum');
const logArea = $('logArea'), statusDot = $('statusDot'), statusText = $('statusText');
const sizeCompare = $('sizeCompare'), sizeBefore = $('sizeBefore'), sizeAfter = $('sizeAfter'), sizeDelta = $('sizeDelta');
const wasmStatus = $('wasmStatus');
const customInput = $('customInput'), btnCustomUpload = $('btnCustomUpload'), customList = $('customList');
const jsInput = $('jsInput'), btnJsUpload = $('btnJsUpload');
const runOutput = $('runOutput'), runOutputText = $('runOutputText'), btnCloseRun = $('btnCloseRun');
const helpModal = $('helpModal'), btnHelp = $('btnHelp'), btnCloseHelp = $('btnCloseHelp');
const btnInspect = $('btnInspect'), btnCompare = $('btnCompare'), inspectModal = $('inspectModal'), inspectContent = $('inspectContent');
const inspectTitle = $('inspectTitle'), btnCloseInspect = $('btnCloseInspect');

// ---- Logging ----
function log(msg, type){
  const line = document.createElement('div');
  line.className = 'log-line' + (type ? ' ' + type : '');
  line.textContent = msg;
  logArea.appendChild(line);
  logArea.scrollTop = logArea.scrollHeight;
}
function setStatus(text, state){
  statusText.textContent = text;
  statusDot.className = 'status-dot' + (state ? ' ' + state : '');
}
function fmtBytes(n){
  if(n < 1024) return n + ' B';
  if(n < 1048576) return (n/1024).toFixed(1) + ' KB';
  return (n/1048576).toFixed(2) + ' MB';
}

// ---- Persistence ----
function saveConfig(){
  try {
    const selected = getSelectedModules();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(selected));
    const lc = document.getElementById('luajit_compat');
    if (lc) localStorage.setItem('luajit_compat', lc.checked ? '1' : '0');
  } catch(e){}
}
function loadConfig(){
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if(raw) return JSON.parse(raw);
  } catch(e){}
  return [];
}
function saveCustomModules(){
  try {
    const data = customModules.map(m => ({name:m.name, label:m.label, description:m.description, source:m.source}));
    localStorage.setItem(CUSTOM_STORAGE_KEY, JSON.stringify(data));
  } catch(e){ log('自定义模块保存失败(可能超出存储限制)', 'warn'); }
}
function loadCustomModules(){
  try {
    const raw = localStorage.getItem(CUSTOM_STORAGE_KEY);
    if(raw) return JSON.parse(raw);
  } catch(e){}
  return [];
}
function saveJsModules(){
  try {
    const data = jsModules.map(m => ({name:m.name, label:m.label, description:m.description, source:m.source}));
    localStorage.setItem(JS_CUSTOM_STORAGE_KEY, JSON.stringify(data));
  } catch(e){ log('JS模块保存失败(可能超出存储限制)', 'warn'); }
}
function loadJsModules(){
  try {
    const raw = localStorage.getItem(JS_CUSTOM_STORAGE_KEY);
    if(raw) return JSON.parse(raw);
  } catch(e){}
  return [];
}

// ---- Render modules ----
function renderModules(){
  moduleScroll.innerHTML = '';
  const saved = loadConfig();
  const savedSet = new Set(saved);

  MODULE_GROUPS.forEach((grp, gi) => {
    const grpEl = document.createElement('div');
    grpEl.className = 'group';
    grpEl.innerHTML = `
      <div class="group-header" data-gi="${gi}">
        <input type="checkbox" class="group-check" data-gi="${gi}" title="全选/取消该分类">
        <span>${grp.name}</span>
        <span class="count">${grp.modules.length} 个</span>
      </div>
      <div class="group-items">
        ${grp.modules.map(m => `
          <div class="module-item">
            <input type="checkbox" id="mod_${m.id}" value="${m.id}" ${savedSet.has(m.id)?'checked':''}>
            <label for="mod_${m.id}" title="${m.desc}">${m.label}</label>
            ${m.id === 'vm_dispatch_shuffle_c' ? `
            <div class="ds-opts" style="margin-top:3px;font-size:11px;color:#8b949e;display:flex;gap:8px;align-items:center;flex-wrap:wrap">
              <span>分发 <select id="ds_mode" style="font-size:11px;background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:4px">
                <option value="0">switch 有序</option>
                <option value="1">switch 乱序</option>
                <option value="2">查表</option>
                <option value="3">算术槽</option>
              </select></span>
              <span>seed <input id="ds_seed" type="number" min="0" value="${dsFreshSeed()}" style="width:64px;font-size:11px;background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:4px" title="0=每轮随机；打开页面自动刷新"></span>
            </div>` : ''}
            ${m.id === 'vm_reg_shuffle_c' || m.id === 'vm_const_shuffle_c' ? `
            <div class="ds-opts" style="margin-top:3px;font-size:11px;color:#8b949e;display:flex;gap:8px;align-items:center;flex-wrap:wrap">
              <span>seed <input id="${m.id === 'vm_reg_shuffle_c' ? 'rs_seed' : 'cs_seed'}" type="number" min="0" value="${dsFreshSeed()}" style="width:64px;font-size:11px;background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:4px" title="0=每轮随机；打开页面自动刷新"></span>
            </div>` : ''}
            ${m.id === 'vm_embed_c' ? `
            <div class="ds-opts" style="margin-top:3px;font-size:11px;color:#8b949e;display:flex;gap:8px;align-items:center;flex-wrap:wrap">
              <label style="display:flex;align-items:center;gap:4px;cursor:pointer">
                <input type="checkbox" id="luajit_compat" class="vm-opt" checked title="用 bit32 库代替直接位运算，兼容 luajvm/Android 等不支持浮点位运算的环境">
                <span>luajvm兼容</span>
              </label>
            </div>` : ''}
          </div>
        `).join('')}
      </div>`;
    moduleScroll.appendChild(grpEl);
  });

  // luajit_compat checkbox event
  const lcEl = document.getElementById('luajit_compat');
  if (lcEl) {
    lcEl.addEventListener('change', () => { vmLuajitCompat = lcEl.checked; });
  }

  // Custom modules group (Lua + JS)
  const allCustom = [
    ...customModules.map(m => ({...m, type: 'lua'})),
    ...jsModules.map(m => ({...m, type: 'js'}))
  ];
  if(allCustom.length > 0){
    const grpEl = document.createElement('div');
    grpEl.className = 'group';
    grpEl.innerHTML = `
      <div class="group-header">
        <span style="color:#d2a8ff">自定义模块</span>
        <span class="count">${allCustom.length} 个</span>
      </div>
      <div class="group-items single">
        ${allCustom.map(m => `
          <div class="module-item custom">
            <input type="checkbox" id="mod_${m.name}" value="${m.name}" ${savedSet.has(m.name)?'checked':''}>
            <label for="mod_${m.name}" title="${m.description||m.name}">
              <span style="font-size:9px;color:${m.type==='js'?'#79c0ff':'#d2a8ff'};border:1px solid ${m.type==='js'?'#79c0ff':'#d2a8ff'};border-radius:3px;padding:0 3px;margin-right:4px">${m.type==='js'?'JS':'LUA'}</span>
              ${m.label||m.name}
            </label>
            <span class="remove-mod" data-name="${m.name}" data-type="${m.type}" title="移除模块">✕</span>
          </div>
        `).join('')}
      </div>`;
    moduleScroll.appendChild(grpEl);
  }

  // group toggle
  moduleScroll.querySelectorAll('.group-header').forEach(h => {
    h.addEventListener('click', e => {
      if(e.target.classList.contains('remove-mod') || e.target.classList.contains('group-check')) return;
      const items = h.nextElementSibling;
      items.style.display = items.style.display === 'none' ? '' : 'none';
    });
  });

  // group checkbox: check/uncheck all modules in group
  moduleScroll.querySelectorAll('.group-check').forEach(gcb => {
    gcb.addEventListener('change', e => {
      e.stopPropagation();
      const gi = parseInt(gcb.dataset.gi);
      const grp = MODULE_GROUPS[gi];
      const checked = gcb.checked;
      grp.modules.forEach(m => {
        const cb = document.getElementById('mod_' + m.id);
        if(cb) cb.checked = checked;
      });
      saveConfig();
    });
  });

  // update group checkbox state when individual module changes
  function updateGroupCheckboxes(){
    MODULE_GROUPS.forEach((grp, gi) => {
      const gcb = document.querySelector('.group-check[data-gi="' + gi + '"]');
      if(!gcb) return;
      const mods = grp.modules.map(m => document.getElementById('mod_' + m.id));
      const checked = mods.filter(cb => cb && cb.checked).length;
      const total = mods.length;
      gcb.checked = (checked === total);
      gcb.indeterminate = (checked > 0 && checked < total);
    });
  }
  // override saveConfig to also update group checkboxes
  const origSaveConfig = saveConfig;
  saveConfig = function(){
    origSaveConfig();
    updateGroupCheckboxes();

  // load luajit_compat persisted state
  try {
    const lcSaved = localStorage.getItem('luajit_compat');
    const lcEl = document.getElementById('luajit_compat');
    if (lcEl && lcSaved !== null) {
      lcEl.checked = (lcSaved === '1');
      vmLuajitCompat = lcEl.checked;
    }
  } catch(e){}
  };
  updateGroupCheckboxes();

  // remove custom module
  moduleScroll.querySelectorAll('.remove-mod').forEach(el => {
    el.addEventListener('click', e => {
      e.stopPropagation();
      const name = el.dataset.name;
      const type = el.dataset.type;
      if(type === 'js') removeJsModule(name);
      else removeCustomModule(name);
    });
  });

  // save on change + antidec/vm mutual exclusion
  const VM_MODS = ['vm_dispatch_shuffle_c','vm_reg_shuffle_c','vm_const_shuffle_c','vm_embed_c'];
  moduleScroll.querySelectorAll('input[type=checkbox]').forEach(cb => {
    cb.addEventListener('change', () => {
      if(cb.value === 'antidec_c' && cb.checked){
        VM_MODS.forEach(id => { const c = document.getElementById('mod_'+id); if(c) c.checked = false; });
      } else if(VM_MODS.includes(cb.value) && cb.checked){
        const ad = document.getElementById('mod_antidec_c'); if(ad) ad.checked = false;
      }
      saveConfig();
    });
  });

  modCountEl.textContent = MODULE_GROUPS.flatMap(g=>g.modules).length;
  customCountEl.textContent = customModules.length + jsModules.length;
}

function getSelectedModules(){
  return Array.from(moduleScroll.querySelectorAll('input[type=checkbox]:checked:not(.group-check):not(.vm-opt)')).map(cb => cb.value);
}

// ---- Custom modules ----
function registerCustomModule(source, filename){
  if(!wasmReady){ log('WASM 未就绪，无法注册模块', 'err'); return; }
  const srcPtr = Module._malloc(source.length);
  Module.HEAPU8.set(source, srcPtr);
  const ret = Module.ccall('wasm_register_module', 'number', ['number','number'], [srcPtr, source.length]);
  Module._free(srcPtr);
  if(ret !== 0){
    const err = Module.ccall('wasm_last_error', 'string', [], []);
    log('模块注册失败: ' + (err||'unknown'), 'err');
    return false;
  }
  // Parse module info from source (extract name/label/description)
  const srcStr = new TextDecoder().decode(source);
  const nameMatch = srcStr.match(/name\s*=\s*["']([^"']+)["']/);
  const labelMatch = srcStr.match(/label\s*=\s*["']([^"']+)["']/);
  const descMatch = srcStr.match(/description\s*=\s*["']([^"']+)["']/);
  const mod = {
    name: nameMatch ? nameMatch[1] : filename.replace(/\.lua$/,''),
    label: labelMatch ? labelMatch[1] : (nameMatch ? nameMatch[1] : filename),
    description: descMatch ? descMatch[1] : '',
    source: srcStr
  };
  // avoid duplicates
  customModules = customModules.filter(m => m.name !== mod.name);
  customModules.push(mod);
  saveCustomModules();
  renderModules();
  log('自定义模块已注册: ' + mod.name + ' (' + filename + ')', 'ok');
  return true;
}

function removeCustomModule(name){
  customModules = customModules.filter(m => m.name !== name);
  saveCustomModules();
  renderModules();
  log('已移除自定义模块: ' + name, 'info');
}

// ---- JS custom modules ----
function registerJsModule(sourceStr, filename){
  try {
    // Execute in a sandboxed function with module.exports
    const moduleObj = { exports: {} };
    const factory = new Function('module', 'exports', sourceStr);
    factory(moduleObj, moduleObj.exports);
    const mod = moduleObj.exports;
    if(!mod || typeof mod !== 'object'){
      log('JS模块必须导出一个对象 (module.exports = {...})', 'err');
      return false;
    }
    if(!mod.name || typeof mod.name !== 'string'){
      log('JS模块缺少 name 字段', 'err');
      return false;
    }
    if(!mod.apply || typeof mod.apply !== 'function'){
      log('JS模块缺少 apply 函数', 'err');
      return false;
    }
    // avoid duplicates
    jsModules = jsModules.filter(m => m.name !== mod.name);
    jsModules.push({
      name: mod.name,
      label: mod.label || mod.name,
      description: mod.description || '',
      source: sourceStr,
      moduleObj: mod
    });
    saveJsModules();
    renderModules();
    log('JS模块已注册: ' + mod.name + ' (' + filename + ')', 'ok');
    return true;
  } catch(e){
    log('JS模块加载失败: ' + e.message, 'err');
    return false;
  }
}

function removeJsModule(name){
  jsModules = jsModules.filter(m => m.name !== name);
  saveJsModules();
  renderModules();
  log('已移除JS模块: ' + name, 'info');
}

btnCustomUpload.addEventListener('click', () => customInput.click());
customInput.addEventListener('change', e => {
  Array.from(e.target.files).forEach(file => {
    const reader = new FileReader();
    reader.onload = () => registerCustomModule(new Uint8Array(reader.result), file.name);
    reader.readAsArrayBuffer(file);
  });
  customInput.value = '';
});

btnJsUpload.addEventListener('click', () => jsInput.click());
jsInput.addEventListener('change', e => {
  Array.from(e.target.files).forEach(file => {
    const reader = new FileReader();
    reader.onload = () => registerJsModule(reader.result, file.name);
    reader.readAsText(file);
  });
  jsInput.value = '';
});

// ---- File upload ----
uploadZone.addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', e => { if(e.target.files[0]) handleFile(e.target.files[0]); });
uploadZone.addEventListener('dragover', e => { e.preventDefault(); uploadZone.classList.add('dragover'); });
uploadZone.addEventListener('dragleave', () => uploadZone.classList.remove('dragover'));
uploadZone.addEventListener('drop', e => {
  e.preventDefault(); uploadZone.classList.remove('dragover');
  if(e.dataTransfer.files[0]) handleFile(e.dataTransfer.files[0]);
});

function handleFile(file){
  fileName = file.name;
  fileNameEl.textContent = file.name;
  const reader = new FileReader();
  reader.onload = () => {
    fileBytes = new Uint8Array(reader.result);
    origSizeEl.textContent = fmtBytes(fileBytes.length);
    fileInfo.style.display = 'flex';
    btnProcess.disabled = !wasmReady;
    btnProcessRun.disabled = !wasmReady;
    btnInspect.disabled = !wasmReady;
    btnCompare.disabled = !wasmReady;
    btnEditor.disabled = !wasmReady;
    let fmt = '未知';
    const first = fileBytes[0];
    if(first === 0x1B) fmt = '标准字节码 (0x1B)';
    else if(first === 0x1A) fmt = 'andlua 字节码 (0x1A)';
    else if(first === 0x1C) fmt = 'andlua 加密字节码 (0x1C)';
    else if(first === 0x3D) fmt = 'andlua base64 壳 (=)';
    else if(first >= 0x20 && first < 0x7F) fmt = 'Lua 明文源码';
    log('已加载文件: ' + file.name + ' (' + fmtBytes(fileBytes.length) + ', ' + fmt + ')', 'info');
    setStatus('文件已加载 (' + fmt + ')，选择模块后开始处理', 'ready');
  };
  reader.readAsArrayBuffer(file);
}

// ---- Process ----
async function runObfuscation(){
  if(!fileBytes || !wasmReady) return false;
  const mods = sortModulesForExecution(getSelectedModules());
  if(mods.length === 0){ log('请至少选择一个模块', 'warn'); return false; }

  btnProcess.disabled = true;
  btnProcessRun.disabled = true;
  btnDownload.disabled = true;
  btnRun.disabled = true;
  runOutput.style.display = 'none';
  setStatus('正在处理...', 'working');
  log('=== 开始混淆 (' + mods.length + ' 个模块) ===', 'info');

  try {
    Module.ccall('wasm_init', 'number', [], []);

    // re-register custom modules (fresh state)
    for(const cm of customModules){
      const src = new TextEncoder().encode(cm.source);
      const srcPtr = Module._malloc(src.length);
      Module.HEAPU8.set(src, srcPtr);
      Module.ccall('wasm_register_module', 'number', ['number','number'], [srcPtr, src.length]);
      Module._free(srcPtr);
    }

    const dataPtr = Module._malloc(fileBytes.length);
    Module.HEAPU8.set(fileBytes, dataPtr);
    const handle = Module.ccall('wasm_load', 'number', ['number','number'], [dataPtr, fileBytes.length]);
    Module._free(dataPtr);
    if(handle < 0){
      const err = Module.ccall('wasm_last_error', 'string', [], []);
      throw new Error('加载失败: ' + (err || 'unknown'));
    }
    log('字节码加载成功 (handle=' + handle + ')', 'ok');
    const loadDbg = Module.ccall('wasm_last_error', 'string', [], []);
    if(loadDbg) log('LOAD_DEBUG: ' + loadDbg, 'info');

    // 统一设置/重置 VM shuffle 全局状态（避免模块遍历重复设置或上次残留）
    {
      const rsOn = mods.includes('vm_reg_shuffle_c');
      const csOn = mods.includes('vm_const_shuffle_c');
      const rsEl = document.getElementById('rs_seed');
      const csEl = document.getElementById('cs_seed');
      const rs = rsOn ? (rsEl ? (parseInt(rsEl.value, 10) || 0) : 0) : -1;
      const cs = csOn ? (csEl ? (parseInt(csEl.value, 10) || 0) : 0) : -1;
      Module.ccall('wasm_vm_shuffle_opts', null, ['number','number'], [rs, cs]);
      log('  VM shuffle状态: reg=' + (rsOn ? ('seed=' + (rs > 0 ? rs : '随机')) : '关') + ' const=' + (csOn ? ('seed=' + (cs > 0 ? cs : '随机')) : '关'), 'info');
    }

    for(let i = 0; i < mods.length; i++){
      const mod = mods[i];
      if(mod === 'vm_embed_c') continue;
      const isJs = jsModules.some(m => m.name === mod);
      const isLuaCustom = !isJs && !BUILTIN_IDS.has(mod);
      const label = isJs
        ? (jsModules.find(m=>m.name===mod)?.label || mod)
        : (isLuaCustom
          ? (customModules.find(m=>m.name===mod)?.label || mod)
          : (MODULE_GROUPS.flatMap(g=>g.modules).find(m=>m.id===mod)?.label || mod));
      setStatus('应用模块 ' + (i+1) + '/' + mods.length + ': ' + label, 'working');

      if(mod === 'vm_dispatch_shuffle_c'){
        const modeEl = document.getElementById('ds_mode');
        const seedEl = document.getElementById('ds_seed');
        const m = modeEl ? (parseInt(modeEl.value, 10) || 0) : 0;
        const s = seedEl ? (parseInt(seedEl.value, 10) || 0) : 0;
        Module.ccall('wasm_dispatch_opts', null, ['number','number'], [m, s]);
        log('  VM分发参数: mode=' + m + ' seed=' + (s > 0 ? s : '随机'), 'info');
      }
      if(mod === 'vm_reg_shuffle_c' || mod === 'vm_const_shuffle_c'){
        // 全局 seed 已在遍历前统一设置/重置，此处不再重复调用
      }

      if(isJs){
        const jsMod = jsModules.find(m => m.name === mod);
        const api = {
          handle: handle,
          Module: Module,
          call: (name, ret, argTypes, args) => Module.ccall(name, ret, argTypes, args),
          log: (msg) => log('    [JS] ' + msg, 'info'),
          fmtBytes: fmtBytes
        };
        try {
          const ok = jsMod.moduleObj.apply(api);
          if(ok === false){
            throw new Error('JS模块返回 false');
          }
        } catch(e){
          throw new Error('JS模块 ' + label + ' 失败: ' + e.message);
        }
        log('  [' + (i+1) + '/' + mods.length + '] ' + label + ' (JS) OK', 'ok');
      } else {
        const fn = isLuaCustom ? 'wasm_apply_custom' : 'wasm_apply';
        const ret = Module.ccall(fn, 'number', ['number','string'], [handle, mod]);
        if(ret !== 0){
          const err = Module.ccall('wasm_last_error', 'string', [], []);
          throw new Error('模块 ' + label + ' 失败: ' + (err || 'unknown'));
        }
        log('  [' + (i+1) + '/' + mods.length + '] ' + label + (isLuaCustom?' (自定义)':'') + ' OK', 'ok');
      }
      await new Promise(r => setTimeout(r, 0));
    }

    const useVmEmbed = mods.includes('vm_embed_c');
    if(useVmEmbed){
      setStatus('组装自包含VM...', 'working');
      const outLenPtr = Module._malloc(4);
      const outPtr = Module.ccall('wasm_vm_embed', 'number', ['number','number','number'], [handle, vmLuajitCompat?1:0, outLenPtr]);
      const outLen = Module.getValue(outLenPtr, 'i32');
      Module._free(outLenPtr);
      if(!outPtr || outLen === 0){
        const err = Module.ccall('wasm_last_error', 'string', [], []);
        Module.ccall('wasm_free', null, ['number'], [handle]);
        throw new Error('VM组装失败: ' + (err || 'unknown'));
      }
      resultBytes = new Uint8Array(outLen);
      resultBytes.set(Module.HEAPU8.subarray(outPtr, outPtr + outLen));
      Module.ccall('wasm_free_output', null, ['number'], [outPtr]);
      Module.ccall('wasm_free', null, ['number'], [handle]);
      resultIsLua = true;
      log('自包含VM组装完成 (' + fmtBytes(outLen) + ' Lua源码)', 'ok');
    } else {
      setStatus('导出字节码...', 'working');
      const outLenPtr = Module._malloc(4);
      const outPtr = Module.ccall('wasm_dump', 'number', ['number','number'], [handle, outLenPtr]);
      const outLen = Module.getValue(outLenPtr, 'i32');
      Module._free(outLenPtr);

      if(!outPtr || outLen === 0){
        const err = Module.ccall('wasm_last_error', 'string', [], []);
        Module.ccall('wasm_free', null, ['number'], [handle]);
        throw new Error('导出失败: ' + (err || 'unknown'));
      }

      resultBytes = new Uint8Array(outLen);
      resultBytes.set(Module.HEAPU8.subarray(outPtr, outPtr + outLen));
      Module.ccall('wasm_free_dump', null, ['number'], [outPtr]);
      Module.ccall('wasm_free', null, ['number'], [handle]);
      resultIsLua = false;
    }

    sizeBefore.textContent = fmtBytes(fileBytes.length);
    sizeAfter.textContent = fmtBytes(resultBytes.length);
    const delta = ((resultBytes.length - fileBytes.length) / fileBytes.length * 100).toFixed(1);
    sizeDelta.textContent = (delta > 0 ? '+' : '') + delta + '%';
    sizeDelta.style.color = delta > 0 ? '#d29922' : '#3fb950';
    sizeCompare.style.display = 'flex';

    log('=== 完成! 输出 ' + fmtBytes(resultBytes.length) + ' (' + (delta>0?'+':'') + delta + '%) ===', 'ok');
    window._lastResult = resultBytes;
    window._lastResultIsLua = resultIsLua;
    window._wasmGetDebug = function() { return Module.ccall('wasm_get_debug', 'string', [], []); };
    window._wasmClearDebug = function() { Module.ccall('wasm_clear_debug', null, [], []); };
    setStatus('处理完成，可运行或下载结果', 'ready');
    btnDownload.disabled = false;
    btnRun.disabled = false;
    inspectSource = 'result';
    document.querySelectorAll('.inspect-src').forEach(b => {
      b.classList.toggle('active', b.dataset.src === 'result');
    });
  } catch(e){
    log('错误: ' + e.message, 'err');
    setStatus('处理失败: ' + e.message, 'error');
  } finally {
    btnProcess.disabled = !wasmReady || !fileBytes;
    btnProcessRun.disabled = !wasmReady || !fileBytes;
    btnInspect.disabled = !wasmReady || (!fileBytes && !resultBytes);
    btnCompare.disabled = !wasmReady || (!fileBytes || !resultBytes);
    btnEditor.disabled = !wasmReady || (!fileBytes && !resultBytes);
  }
  return true;
}

btnProcess.addEventListener('click', () => { runObfuscation(); });

btnProcessRun.addEventListener('click', async () => {
  const ok = await runObfuscation();
  if(ok && resultBytes){
    // auto-run after obfuscation
    try {
      setStatus('正在运行结果...', 'working');
      log('--- 运行' + (resultIsLua ? 'Lua源码' : '字节码') + ' ---', 'run');
      let bcPtr, bcLen;
      if(resultIsLua){
        // pass lua source directly to wasm_run_bytecode (luaL_loadbuffer handles source, preserves raw bytes)
        bcPtr = Module._malloc(resultBytes.length);
        Module.HEAPU8.set(resultBytes, bcPtr);
        bcLen = resultBytes.length;
      } else {
        bcPtr = Module._malloc(resultBytes.length);
        Module.HEAPU8.set(resultBytes, bcPtr);
        bcLen = resultBytes.length;
      }
      const runLenPtr = Module._malloc(4);
      const runPtr = Module.ccall('wasm_run_bytecode', 'number', ['number','number','number'], [bcPtr, bcLen, runLenPtr]);
      const runLen = Module.getValue(runLenPtr, 'i32');
      Module._free(bcPtr);
      Module._free(runLenPtr);
      if(runPtr && runLen > 0){
        const output = new TextDecoder().decode(Module.HEAPU8.subarray(runPtr, runPtr + runLen));
        Module.ccall('wasm_free_output', null, ['number'], [runPtr]);
        runOutputText.textContent = output;
        log('运行完成 (' + runLen + ' 字节输出)', 'ok');
      } else {
        runOutputText.textContent = '(无输出)';
        log('运行完成 (无输出)', 'info');
      }
      runOutput.style.display = 'block';
      setStatus('运行完成', 'ready');
    } catch(e){
      log('运行错误: ' + e.message, 'err');
      runOutputText.textContent = '运行错误: ' + e.message;
      runOutput.style.display = 'block';
      setStatus('运行失败', 'error');
    }
  }
});

// ---- Run result in-page ----
btnRun.addEventListener('click', () => {
  if(!resultBytes || !wasmReady) return;
  setStatus('正在运行结果...', 'working');
  log('--- 运行' + (resultIsLua ? 'Lua源码' : '字节码') + ' ---', 'run');

  try {
    const bcPtr = Module._malloc(resultBytes.length);
    Module.HEAPU8.set(resultBytes, bcPtr);
    const outLenPtr = Module._malloc(4);
    const outPtr = Module.ccall('wasm_run_bytecode', 'number',
      ['number','number','number'], [bcPtr, resultBytes.length, outLenPtr]);
    const outLen = Module.getValue(outLenPtr, 'i32');
    Module._free(bcPtr);
    Module._free(outLenPtr);

    if(!outPtr || outLen === 0){
      const err = Module.ccall('wasm_last_error', 'string', [], []);
      runOutputText.textContent = '(无输出)\n' + (err || '');
      log('运行完成 (无输出)', 'info');
    } else {
      const outBytes = Module.HEAPU8.subarray(outPtr, outPtr + outLen);
      const output = new TextDecoder().decode(outBytes);
      runOutputText.textContent = output;
      Module.ccall('wasm_free_output', null, ['number'], [outPtr]);
      log('运行完成 (' + outLen + ' 字节输出)', 'ok');
    }
    runOutput.style.display = 'block';
    setStatus('运行完成', 'ready');
  } catch(e){
    log('运行错误: ' + e.message, 'err');
    runOutputText.textContent = '运行错误: ' + e.message;
    runOutput.style.display = 'block';
    setStatus('运行失败', 'error');
  }
});

btnCloseRun.addEventListener('click', () => { runOutput.style.display = 'none'; });

// ---- Bytecode Inspector ----
let inspectSource = 'result'; // 'result' or 'original'

function escHtml(s){
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

function renderStats(p){
  const fields = [
    ['sizecode','指令数'],['sizek','常量数'],['sizep','子Proto数'],
    ['numparams','参数数'],['is_vararg','可变参数'],['linedefined','起始行']
  ];
  return '<div class="insp-stats">' + fields.map(([k,label]) =>
    `<div class="insp-stat"><div class="label">${label}</div><div class="value">${escHtml(p[k] ?? '?')}</div></div>`
  ).join('') + '</div>';
}

function renderConstants(p){
  if(!p.constants || p.constants.length === 0) return '<div style="color:#8b949e;padding:8px">无常量</div>';
  const rows = p.constants.map(c => {
    let val = c.value;
    if(c.type === 'string') val = '"' + escHtml(val) + '"' + (c.truncated ? ' <span style="color:#d29922">...(+'+c.full_len+' chars)</span>' : '');
    else if(c.type === 'nil') val = '<span style="color:#8b949e">nil</span>';
    else if(c.type === 'boolean') val = '<span style="color:#3fb950">'+escHtml(val)+'</span>';
    else val = escHtml(val);
    return `<tr><td class="const-idx">${c.idx}</td><td class="const-type">${escHtml(c.type)}</td><td class="const-val">${val}</td></tr>`;
  }).join('');
  return `<div class="insp-scroll"><table class="insp-table"><thead><tr><th>#</th><th>类型</th><th>值</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

function renderInstructions(p){
  if(!p.instructions || p.instructions.length === 0) return '<div style="color:#8b949e;padding:8px">无指令</div>';
  const rows = p.instructions.map(inst => {
    let args = `A=${inst.a} B=${inst.b} C=${inst.c}`;
    if(inst.bx !== undefined) args += ` Bx=${inst.bx}`;
    if(inst.sbx !== undefined) args += ` sBx=${inst.sbx}`;
    return `<tr><td class="pc">${inst.pc}</td><td class="op">${escHtml(inst.op)}</td><td class="opcode">${inst.opcode}</td><td class="args">${args}</td></tr>`;
  }).join('');
  let note = '';
  if(p.instructions_truncated) note = `<div style="color:#d29922;padding:6px 8px;font-size:11px">仅显示前 ${p.instructions_show} 条，共 ${p.instructions_total} 条</div>`;
  return `<div class="insp-scroll" style="max-height:350px"><table class="insp-table"><thead><tr><th>PC</th><th>操作码</th><th>OP</th><th>操作数</th></tr></thead><tbody>${rows}</tbody></table></div>${note}`;
}

function renderDebugInfo(p){
  let html = '<div style="font-size:11px">';
  // locvars
  if(p.locvars && p.locvars.length > 0){
    html += '<div style="margin-bottom:6px"><span style="color:#d2a8ff">locvars (' + p.sizelocvars + '):</span> ';
    p.locvars.forEach((lv,i) => {
      if(i>0) html += ', ';
      html += '<span style="color:#79c0ff">' + escHtml(lv.varname||'null') + '</span>[' + lv.startpc + '-' + lv.endpc + ']';
    });
    html += '</div>';
  } else {
    html += '<div style="margin-bottom:6px;color:#6e7681">locvars: 无</div>';
  }
  // lineinfo
  if(p.lineinfo && p.lineinfo.length > 0){
    html += '<div style="margin-bottom:6px"><span style="color:#d2a8ff">lineinfo (' + p.sizelineinfo + (p.lineinfo_truncated ? ', 显示前' + p.lineinfo_show : '') + '):</span> ';
    html += p.lineinfo.slice(0,30).join(', ');
    if(p.lineinfo.length > 30) html += ' ...';
    html += '</div>';
  } else {
    html += '<div style="margin-bottom:6px;color:#6e7681">lineinfo: 无</div>';
  }
  // upvalues
  if(p.upvalues && p.upvalues.length > 0){
    html += '<div><span style="color:#d2a8ff">upvalues (' + p.sizeupvalues + '):</span> ';
    p.upvalues.forEach((uv,i) => {
      if(i>0) html += ', ';
      html += '<span style="color:#79c0ff">' + escHtml(uv.name||'null') + '</span>(instack=' + uv.instack + ',idx=' + uv.idx + ')';
    });
    html += '</div>';
  } else {
    html += '<div style="color:#6e7681">upvalues: 无</div>';
  }
  html += '</div>';
  return html;
}

function renderSubProtos(p, depth){
  if(!p.subprotos || p.subprotos.length === 0){
    if(p.subprotos_omitted) return `<div style="color:#8b949e;padding:8px">${p.subprotos_omitted} 个子Proto（深度限制未展开）</div>`;
    return '<div style="color:#8b949e;padding:8px">无子Proto</div>';
  }
  return p.subprotos.map((sp, i) => {
    return `<div class="insp-subproto">${renderProtoSection(sp, '子Proto [' + i + ']', depth+1)}</div>`;
  }).join('');
}

function renderProtoSection(p, title, depth){
  const sectionId = 'insp_' + Math.random().toString(36).substr(2,9);
  return `
    <div class="insp-section">
      <div class="insp-section-header" onclick="document.getElementById('${sectionId}').classList.toggle('collapsed')">
        <span>${escHtml(title)}</span>
        <span class="badge">${p.sizecode} 指令 / ${p.sizek} 常量 / ${p.sizep} 子Proto</span>
      </div>
      <div class="insp-section-body" id="${sectionId}">
        <div style="margin-bottom:10px">${renderStats(p)}</div>
        <div style="margin-bottom:10px"><div style="font-size:11px;color:#8b949e;margin-bottom:4px">常量池</div>${renderConstants(p)}</div>
        <div style="margin-bottom:10px"><div style="font-size:11px;color:#8b949e;margin-bottom:4px">指令列表</div>${renderInstructions(p)}</div>
        <div style="margin-bottom:10px"><div style="font-size:11px;color:#8b949e;margin-bottom:4px">调试信息</div>${renderDebugInfo(p)}</div>
        <div><div style="font-size:11px;color:#8b949e;margin-bottom:4px">子Proto</div>${renderSubProtos(p, depth)}</div>
      </div>
    </div>`;
}

async function runInspect(){
  // determine source: use result if available and selected, else original
  let src = inspectSource;
  if(src === 'result' && !resultBytes && fileBytes) src = 'original';
  const bytes = src === 'result' ? resultBytes : fileBytes;
  if(!bytes){ log('没有可查看的字节码', 'warn'); return; }
  inspectTitle.textContent = src === 'result' ? '(混淆结果)' : '(原始文件)';
  inspectContent.innerHTML = '<div style="color:#8b949e;padding:20px;text-align:center">正在分析...</div>';
  inspectModal.classList.add('show');

  try {
    Module.ccall('wasm_init', 'number', [], []);
    const dataPtr = Module._malloc(bytes.length);
    Module.HEAPU8.set(bytes, dataPtr);
    const handle = Module.ccall('wasm_load', 'number', ['number','number'], [dataPtr, bytes.length]);
    Module._free(dataPtr);
    if(handle < 0){
      const err = Module.ccall('wasm_last_error', 'string', [], []);
      inspectContent.innerHTML = '<div style="color:#f85149;padding:20px">加载失败: ' + escHtml(err||'unknown') + '</div>';
      return;
    }
    const outLenPtr = Module._malloc(4);
    const outPtr = Module.ccall('wasm_inspect', 'number', ['number','number'], [handle, outLenPtr]);
    const outLen = Module.getValue(outLenPtr, 'i32');
    Module._free(outLenPtr);
    Module.ccall('wasm_free', null, ['number'], [handle]);

    if(!outPtr || outLen === 0){
      inspectContent.innerHTML = '<div style="color:#f85149;padding:20px">分析失败</div>';
      return;
    }
    const jsonBytes = Module.HEAPU8.subarray(outPtr, outPtr + outLen);
    const jsonStr = new TextDecoder().decode(jsonBytes);
    Module.ccall('wasm_free_dump', null, ['number'], [outPtr]);

    const data = JSON.parse(jsonStr);
    inspectContent.innerHTML = renderProtoSection(data, '主 Proto', 0);
  } catch(e){
    inspectContent.innerHTML = '<div style="color:#f85149;padding:20px">分析错误: ' + escHtml(e.message) + '</div>';
  }
}

btnInspect.addEventListener('click', runInspect);

function getInspectJSON(bytes){
  Module.ccall('wasm_init', 'number', [], []);
  const dataPtr = Module._malloc(bytes.length);
  Module.HEAPU8.set(bytes, dataPtr);
  const handle = Module.ccall('wasm_load', 'number', ['number','number'], [dataPtr, bytes.length]);
  Module._free(dataPtr);
  if(handle < 0) return null;
  const outLenPtr = Module._malloc(4);
  const outPtr = Module.ccall('wasm_inspect', 'number', ['number','number'], [handle, outLenPtr]);
  const outLen = Module.getValue(outLenPtr, 'i32');
  Module._free(outLenPtr);
  Module.ccall('wasm_free', null, ['number'], [handle]);
  if(!outPtr || outLen === 0) return null;
  const jsonBytes = Module.HEAPU8.subarray(outPtr, outPtr + outLen);
  const jsonStr = new TextDecoder().decode(jsonBytes);
  Module._free(outPtr);
  return JSON.parse(jsonStr);
}

function countOps(p){
  const counts = {};
  if(p.instructions){
    p.instructions.forEach(ins => {
      counts[ins.op] = (counts[ins.op]||0) + 1;
    });
  }
  if(p.subprotos){
    p.subprotos.forEach(sp => {
      const sc = countOps(sp);
      for(const k in sc) counts[k] = (counts[k]||0) + sc[k];
    });
  }
  return counts;
}

function compareProto(b, a, path, changes){
  path = path || 'main';
  // basic fields
  ['sizecode','sizek','sizep','numparams','is_vararg','sizelocvars','sizelineinfo','sizeupvalues','maxstacksize'].forEach(f => {
    const bv = b[f], av = a[f];
    if(bv !== av){
      changes.push({path, field:f, before:bv, after:av, delta:(typeof av==='number'&&typeof bv==='number')?av-bv:null});
    }
  });
  // constants
  if(b.constants && a.constants){
    const maxK = Math.max(b.constants.length, a.constants.length);
    for(let i=0;i<maxK;i++){
      const bc = b.constants[i], ac = a.constants[i];
      if(!bc || !ac || bc.type !== ac.type || String(bc.value) !== String(ac.value)){
        changes.push({path, field:'k['+i+']', before: bc?bc.type+':'+String(bc.value).substr(0,30):'nil', after: ac?ac.type+':'+String(ac.value).substr(0,30):'nil'});
      }
    }
  }
  // locvars
  if(b.locvars && a.locvars){
    const maxL = Math.max(b.locvars.length, a.locvars.length);
    for(let i=0;i<maxL;i++){
      const bl = b.locvars[i], al = a.locvars[i];
      if(!bl || !al || bl.varname !== al.varname || bl.startpc !== al.startpc || bl.endpc !== al.endpc){
        changes.push({path, field:'locvar['+i+']', before: bl?bl.varname+'['+bl.startpc+'-'+bl.endpc+']':'nil', after: al?al.varname+'['+al.startpc+'-'+al.endpc+']':'nil'});
      }
    }
  }
  // upvalues
  if(b.upvalues && a.upvalues){
    const maxU = Math.max(b.upvalues.length, a.upvalues.length);
    for(let i=0;i<maxU;i++){
      const bu = b.upvalues[i], au = a.upvalues[i];
      if(!bu || !au || bu.name !== au.name || bu.instack !== au.instack || bu.idx !== au.idx){
        changes.push({path, field:'upval['+i+']', before: bu?bu.name+'(instack='+bu.instack+',idx='+bu.idx+')':'nil', after: au?au.name+'(instack='+au.instack+',idx='+au.idx+')':'nil'});
      }
    }
  }
  // subprotos
  if(b.subprotos && a.subprotos){
    const maxP = Math.max(b.subprotos.length, a.subprotos.length);
    for(let i=0;i<maxP;i++){
      if(b.subprotos[i] && a.subprotos[i]){
        compareProto(b.subprotos[i], a.subprotos[i], path+'.p'+i, changes);
      } else {
        changes.push({path, field:'subproto['+i+']', before: b.subprotos[i]?'exists':'nil', after: a.subprotos[i]?'exists':'nil'});
      }
    }
  }
}

async function runCompare(){
  if(!fileBytes || !resultBytes){ log('需要原始文件和混淆结果才能对比', 'warn'); return; }
  inspectTitle.textContent = '(对比变更)';
  inspectContent.innerHTML = '<div style="color:#8b949e;padding:20px;text-align:center">正在对比...</div>';
  inspectModal.classList.add('show');
  try {
    const before = getInspectJSON(fileBytes);
    const after = getInspectJSON(resultBytes);
    if(!before || !after){ inspectContent.innerHTML = '<div style="color:#f85149;padding:20px">分析失败</div>'; return; }
    const changes = [];
    compareProto(before, after, 'main', changes);
    // opcode distribution
    const opsBefore = countOps(before);
    const opsAfter = countOps(after);
    const opChanges = [];
    const allOps = new Set([...Object.keys(opsBefore), ...Object.keys(opsAfter)]);
    allOps.forEach(op => {
      const b = opsBefore[op]||0, a = opsAfter[op]||0;
      if(b !== a) opChanges.push({op, before:b, after:a, delta:a-b});
    });
    opChanges.sort((x,y) => Math.abs(y.delta) - Math.abs(x.delta));
    // render
    let html = '<div style="padding:15px">';
    html += '<div style="font-size:14px;font-weight:bold;color:#58a6ff;margin-bottom:10px">变更摘要</div>';
    html += '<div style="font-size:12px;margin-bottom:15px">';
    html += '原始: ' + before.sizecode + '指令/' + before.sizek + '常量/' + before.sizep + '子Proto';
    html += ' &rarr; 结果: ' + after.sizecode + '指令/' + after.sizek + '常量/' + after.sizep + '子Proto';
    html += '</div>';
    if(opChanges.length > 0){
      html += '<div style="font-size:12px;font-weight:bold;color:#d2a8ff;margin-bottom:5px">Opcode 分布变化:</div>';
      html += '<div style="font-size:11px;margin-bottom:15px">';
      opChanges.forEach(c => {
        const color = c.delta > 0 ? '#3fb950' : '#f85149';
        html += '<span style="margin-right:12px">' + c.op + ': ' + c.before + '&rarr;' + c.after + ' <span style="color:'+color+'">(' + (c.delta>0?'+':'') + c.delta + ')</span></span>';
      });
      html += '</div>';
    }
    if(changes.length > 0){
      html += '<div style="font-size:12px;font-weight:bold;color:#d2a8ff;margin-bottom:5px">详细变更 (' + changes.length + ' 项):</div>';
      html += '<div style="font-size:11px;max-height:400px;overflow-y:auto">';
      html += '<table style="width:100%;border-collapse:collapse">';
      html += '<tr style="color:#8b949e;border-bottom:1px solid #30363d"><th style="text-align:left;padding:4px">Proto</th><th style="text-align:left;padding:4px">字段</th><th style="text-align:left;padding:4px">混淆前</th><th style="text-align:left;padding:4px">混淆后</th></tr>';
      changes.slice(0, 200).forEach(c => {
        html += '<tr style="border-bottom:1px solid #21262d">';
        html += '<td style="padding:4px;color:#58a6ff">' + escHtml(c.path) + '</td>';
        html += '<td style="padding:4px;color:#d2a8ff">' + escHtml(c.field) + '</td>';
        html += '<td style="padding:4px;color:#8b949e">' + escHtml(String(c.before)) + '</td>';
        html += '<td style="padding:4px;color:#79c0ff">' + escHtml(String(c.after)) + '</td>';
        html += '</tr>';
      });
      html += '</table>';
      if(changes.length > 200) html += '<div style="color:#8b949e;padding:8px">... 共 ' + changes.length + ' 项，仅显示前 200 项</div>';
      html += '</div>';
    } else {
      html += '<div style="color:#f85149;padding:20px;text-align:center">*** 未检测到任何变更！模块可能未生效 ***</div>';
    }
    html += '</div>';
    inspectContent.innerHTML = html;
  } catch(e) {
    inspectContent.innerHTML = '<div style="color:#f85149;padding:20px">对比错误: ' + escHtml(e.message) + '</div>';
  }
}

btnCompare.addEventListener('click', runCompare);

btnCloseInspect.addEventListener('click', () => { inspectModal.classList.remove('show'); });
inspectModal.addEventListener('click', e => { if(e.target === inspectModal) inspectModal.classList.remove('show'); });

// Inspect source switching
document.querySelectorAll('.inspect-src').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.inspect-src').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    inspectSource = btn.dataset.src;
    if(inspectModal.classList.contains('show')) runInspect();
  });
});

// ---- Bytecode Editor ----
const OPCODE_NAMES = ["MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG","FULLOPSIZE"];

let editorHandle = -1;
let editorSource = 'result';
let editorInstructions = [];
let editorConstants = [];

const btnEditor = $('btnEditor'), editorModal = $('editorModal');
const editorTitle = $('editorTitle'), editorStats = $('editorStats');
const editorCodeBody = $('editorCodeBody'), editorConstBody = $('editorConstBody');
const editorCodePanel = $('editorCodePanel'), editorConstPanel = $('editorConstPanel');
const btnEditorRun = $('btnEditorRun'), btnEditorSave = $('btnEditorSave'), btnEditorClose = $('btnEditorClose');
const editorRunOutput = $('editorRunOutput'), editorRunText = $('editorRunText');

function edCall(name, ret, argTypes, args){
  return Module.ccall(name, ret, argTypes, args);
}

function edFetchAll(){
  editorInstructions = [];
  editorConstants = [];
  const codeSize = edCall('wasm_get_code_size', 'number', ['number'], [editorHandle]);
  for(let i = 0; i < codeSize; i++){
    const inst = edCall('wasm_get_instruction', 'number', ['number','number'], [editorHandle, i]);
    editorInstructions.push(inst >>> 0);
  }
  const kSize = edCall('wasm_get_k_size', 'number', ['number'], [editorHandle]);
  for(let i = 0; i < kSize; i++){
    const type = edCall('wasm_get_constant_type', 'number', ['number','number'], [editorHandle, i]);
    let val = null;
    if(type === 2) val = edCall('wasm_get_constant_number', 'number', ['number','number'], [editorHandle, i]);
    else if(type === 3) val = edCall('wasm_get_constant_string', 'string', ['number','number'], [editorHandle, i]);
    else if(type === 1) val = edCall('wasm_get_constant_bool', 'number', ['number','number'], [editorHandle, i]) ? true : false;
    editorConstants.push({type: type, value: val});
  }
  editorStats.textContent = codeSize + ' 指令 / ' + kSize + ' 常量';
}

function instOp(inst){ return inst & 0x3F; }
function instA(inst){ return (inst >>> 6) & 0xFF; }
function instB(inst){ return (inst >>> 23) & 0x1FF; }
function instC(inst){ return (inst >>> 14) & 0x1FF; }
function instBx(inst){ return (inst >>> 14) & 0x3FFFF; }
function instSbx(inst){ return instBx(inst) - 131071; }
function makeInst(op, a, b, c){
  return (op & 0x3F) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14) | ((b & 0x1FF) << 23);
}
function makeInstSbx(op, a, sbx){
  return (op & 0x3F) | ((a & 0xFF) << 6) | (((sbx + 131071) & 0x3FFFF) << 14);
}

function renderEditorCode(){
  let html = '';
  for(let i = 0; i < editorInstructions.length; i++){
    const inst = editorInstructions[i];
    const op = instOp(inst);
    const isJmp = (op === 30 || op === 39 || op === 40 || op === 42);
    const bxVal = isJmp ? instSbx(inst) : instBx(inst);
    const bxLabel = isJmp ? 'sBx' : 'Bx';
    const opOptions = OPCODE_NAMES.map((name, idx) =>
      `<option value="${idx}" ${idx===op?'selected':''}>${idx}:${name}</option>`
    ).join('');
    html += `<tr data-pc="${i}">
      <td class="pc">${i}</td>
      <td><select class="ed-op" style="width:100%;background:#0d1117;color:#3fb950;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px">${opOptions}</select></td>
      <td><input type="number" class="ed-a" value="${instA(inst)}" min="0" max="255" style="width:100%;background:#0d1117;color:#79c0ff;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px"></td>
      <td><input type="number" class="ed-b" value="${instB(inst)}" min="0" max="511" style="width:100%;background:#0d1117;color:#79c0ff;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px"></td>
      <td><input type="number" class="ed-c" value="${instC(inst)}" min="0" max="511" style="width:100%;background:#0d1117;color:#79c0ff;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px"></td>
      <td><input type="number" class="ed-bx" value="${bxVal}" style="width:100%;background:#0d1117;color:#d29922;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px" title="${bxLabel}"></td>
      <td>
        <button class="ed-insert" style="background:#21262d;color:#58a6ff;border:1px solid #30363d;border-radius:3px;padding:1px 6px;font-size:10px;cursor:pointer;margin-right:2px">+</button>
        <button class="ed-delete" style="background:#21262d;color:#f85149;border:1px solid #30363d;border-radius:3px;padding:1px 6px;font-size:10px;cursor:pointer">×</button>
      </td>
    </tr>`;
  }
  editorCodeBody.innerHTML = html;

  // Bind events
  editorCodeBody.querySelectorAll('tr').forEach(tr => {
    const pc = parseInt(tr.dataset.pc);
    const opSel = tr.querySelector('.ed-op');
    const aInp = tr.querySelector('.ed-a');
    const bInp = tr.querySelector('.ed-b');
    const cInp = tr.querySelector('.ed-c');
    const bxInp = tr.querySelector('.ed-bx');

    function commit(){
      const op = parseInt(opSel.value);
      const a = parseInt(aInp.value) || 0;
      const isJmp = (op === 30 || op === 39 || op === 40 || op === 42);
      let newInst;
      if(isJmp){
        const sbx = parseInt(bxInp.value) || 0;
        newInst = makeInstSbx(op, a, sbx);
      } else {
        const b = parseInt(bInp.value) || 0;
        const c = parseInt(cInp.value) || 0;
        newInst = makeInst(op, a, b, c);
      }
      editorInstructions[pc] = newInst >>> 0;
      edCall('wasm_set_instruction', 'number', ['number','number','number'], [editorHandle, pc, newInst]);
    }
    opSel.addEventListener('change', () => {
      const op = parseInt(opSel.value);
      const isJmp = (op === 30 || op === 39 || op === 40 || op === 42);
      bInp.style.display = isJmp ? 'none' : '';
      cInp.style.display = isJmp ? 'none' : '';
      commit();
    });
    aInp.addEventListener('change', commit);
    bInp.addEventListener('change', commit);
    cInp.addEventListener('change', commit);
    bxInp.addEventListener('change', commit);

    tr.querySelector('.ed-insert').addEventListener('click', () => {
      const newInst = makeInst(0, 0, 0, 0); // MOVE 0 0 0
      edCall('wasm_insert_instruction', 'number', ['number','number','number'], [editorHandle, pc, newInst]);
      edFetchAll();
      renderEditorCode();
    });
    tr.querySelector('.ed-delete').addEventListener('click', () => {
      edCall('wasm_delete_instruction', 'number', ['number','number'], [editorHandle, pc]);
      edFetchAll();
      renderEditorCode();
    });
  });
}

function renderEditorConst(){
  let html = '';
  for(let i = 0; i < editorConstants.length; i++){
    const c = editorConstants[i];
    const typeNames = ['nil','boolean','number','string','other'];
    const typeOptions = typeNames.map((name, idx) =>
      `<option value="${idx}" ${idx===c.type?'selected':''}>${name}</option>`
    ).join('');
    let valInput = '';
    if(c.type === 2){ // number
      valInput = `<input type="text" class="ed-cval" value="${c.value}" style="width:100%;background:#0d1117;color:#c9d1d9;border:1px solid #2d333b;border-radius:3px;padding:2px 4px;font-size:11px">`;
    } else if(c.type === 3){ // string
      valInput = `<input type="text" class="ed-cval" value="${escHtml(c.value)}" style="width:100%;background:#0d1117;color:#c9d1d9;border:1px solid #2d333b;border-radius:3px;padding:2px 4px;font-size:11px">`;
    } else if(c.type === 1){ // boolean
      valInput = `<select class="ed-cval" style="width:100%;background:#0d1117;color:#c9d1d9;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px"><option value="true" ${c.value?'selected':''}>true</option><option value="false" ${!c.value?'selected':''}>false</option></select>`;
    } else {
      valInput = `<span style="color:#8b949e">${c.type === 0 ? 'nil' : '(other)'}</span>`;
    }
    html += `<tr data-idx="${i}">
      <td class="const-idx">${i}</td>
      <td><select class="ed-ctype" style="width:100%;background:#0d1117;color:#d2a8ff;border:1px solid #2d333b;border-radius:3px;padding:2px;font-size:11px">${typeOptions}</select></td>
      <td class="const-val">${valInput}</td>
      <td><button class="ed-cdel" style="background:#21262d;color:#f85149;border:1px solid #30363d;border-radius:3px;padding:1px 8px;font-size:10px;cursor:pointer">删除</button></td>
    </tr>`;
  }
  editorConstBody.innerHTML = html;

  editorConstBody.querySelectorAll('tr').forEach(tr => {
    const idx = parseInt(tr.dataset.idx);
    const typeSel = tr.querySelector('.ed-ctype');
    const valInput = tr.querySelector('.ed-cval');

    function commitConst(){
      const type = parseInt(typeSel.value);
      if(type === 2){
        const v = parseFloat(valInput.value);
        edCall('wasm_set_constant_number', 'number', ['number','number','number'], [editorHandle, idx, v]);
      } else if(type === 3){
        const v = valInput.value;
        const ptr = Module._malloc(v.length);
        Module.HEAPU8.set(new TextEncoder().encode(v), ptr);
        edCall('wasm_set_constant_string', 'number', ['number','number','number','number'], [editorHandle, idx, ptr, v.length]);
        Module._free(ptr);
      } else if(type === 1){
        edCall('wasm_set_constant_bool', 'number', ['number','number','number'], [editorHandle, idx, valInput.value === 'true' ? 1 : 0]);
      } else if(type === 0){
        edCall('wasm_set_constant_nil', 'number', ['number','number'], [editorHandle, idx]);
      }
      editorConstants[idx].type = type;
    }
    if(typeSel) typeSel.addEventListener('change', () => {
      commitConst();
      edFetchAll();
      renderEditorConst();
    });
    if(valInput && valInput.tagName === 'INPUT') valInput.addEventListener('change', commitConst);
    if(valInput && valInput.tagName === 'SELECT') valInput.addEventListener('change', commitConst);

    const delBtn = tr.querySelector('.ed-cdel');
    if(delBtn) delBtn.addEventListener('click', () => {
      edCall('wasm_remove_constant', 'number', ['number','number'], [editorHandle, idx]);
      edFetchAll();
      renderEditorConst();
    });
  });
}

function openEditor(){
  let src = editorSource;
  if(src === 'result' && !resultBytes && fileBytes) src = 'original';
  const bytes = src === 'result' ? resultBytes : fileBytes;
  if(!bytes){ log('没有可编辑的字节码', 'warn'); return; }

  editorTitle.textContent = src === 'result' ? '(混淆结果)' : '(原始文件)';
  Module.ccall('wasm_init', 'number', [], []);
  const dataPtr = Module._malloc(bytes.length);
  Module.HEAPU8.set(bytes, dataPtr);
  editorHandle = Module.ccall('wasm_load', 'number', ['number','number'], [dataPtr, bytes.length]);
  Module._free(dataPtr);
  if(editorHandle < 0){
    const err = Module.ccall('wasm_last_error', 'string', [], []);
    log('编辑器加载失败: ' + (err||'unknown'), 'err');
    return;
  }
  edFetchAll();
  renderEditorCode();
  renderEditorConst();
  editorRunOutput.style.display = 'none';
  editorModal.classList.add('show');
}

function closeEditor(){
  if(editorHandle >= 0){
    Module.ccall('wasm_free', null, ['number'], [editorHandle]);
    editorHandle = -1;
  }
  editorModal.classList.remove('show');
}

btnEditor.addEventListener('click', openEditor);
btnEditorClose.addEventListener('click', closeEditor);
editorModal.addEventListener('click', e => { if(e.target === editorModal) closeEditor(); });

// Editor tab switching
document.querySelectorAll('.editor-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.editor-tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    const target = tab.dataset.tab;
    editorCodePanel.style.display = target === 'code' ? 'block' : 'none';
    editorConstPanel.style.display = target === 'const' ? 'block' : 'none';
  });
});

// Add constants
$('btnAddConstNum').addEventListener('click', () => {
  edCall('wasm_add_constant_number', 'number', ['number','number'], [editorHandle, 0]);
  edFetchAll(); renderEditorConst();
});
$('btnAddConstStr').addEventListener('click', () => {
  const s = "new_string";
  const ptr = Module._malloc(s.length);
  Module.HEAPU8.set(new TextEncoder().encode(s), ptr);
  edCall('wasm_add_constant_string', 'number', ['number','number','number'], [editorHandle, ptr, s.length]);
  Module._free(ptr);
  edFetchAll(); renderEditorConst();
});
$('btnAddConstBool').addEventListener('click', () => {
  edCall('wasm_add_constant_number', 'number', ['number','number'], [editorHandle, 0]);
  const idx = edCall('wasm_get_k_size', 'number', ['number'], [editorHandle]) - 1;
  edCall('wasm_set_constant_bool', 'number', ['number','number','number'], [editorHandle, idx, 1]);
  edFetchAll(); renderEditorConst();
});
$('btnAddConstNil').addEventListener('click', () => {
  edCall('wasm_add_constant_number', 'number', ['number','number'], [editorHandle, 0]);
  const idx = edCall('wasm_get_k_size', 'number', ['number'], [editorHandle]) - 1;
  edCall('wasm_set_constant_nil', 'number', ['number','number'], [editorHandle, idx]);
  edFetchAll(); renderEditorConst();
});

// Editor run
btnEditorRun.addEventListener('click', () => {
  const outLenPtr = Module._malloc(4);
  const outPtr = Module.ccall('wasm_dump', 'number', ['number','number'], [editorHandle, outLenPtr]);
  const outLen = Module.getValue(outLenPtr, 'i32');
  Module._free(outLenPtr);
  if(!outPtr || outLen === 0){ editorRunText.textContent = '导出失败'; editorRunOutput.style.display='block'; return; }
  const bc = new Uint8Array(outLen);
  bc.set(Module.HEAPU8.subarray(outPtr, outPtr + outLen));
  Module.ccall('wasm_free_dump', null, ['number'], [outPtr]);

  const bcPtr = Module._malloc(bc.length);
  Module.HEAPU8.set(bc, bcPtr);
  const runLenPtr = Module._malloc(4);
  const runPtr = Module.ccall('wasm_run_bytecode', 'number', ['number','number','number'], [bcPtr, bc.length, runLenPtr]);
  const runLen = Module.getValue(runLenPtr, 'i32');
  Module._free(bcPtr);
  Module._free(runLenPtr);
  if(runPtr && runLen > 0){
    const out = new TextDecoder().decode(Module.HEAPU8.subarray(runPtr, runPtr + runLen));
    editorRunText.textContent = out;
    Module.ccall('wasm_free_output', null, ['number'], [runPtr]);
  } else {
    const err = Module.ccall('wasm_last_error', 'string', [], []);
    editorRunText.textContent = err || '(无输出)';
  }
  editorRunOutput.style.display = 'block';
});

// Editor save & export
btnEditorSave.addEventListener('click', () => {
  const outLenPtr = Module._malloc(4);
  const outPtr = Module.ccall('wasm_dump', 'number', ['number','number'], [editorHandle, outLenPtr]);
  const outLen = Module.getValue(outLenPtr, 'i32');
  Module._free(outLenPtr);
  if(!outPtr || outLen === 0){ log('导出失败', 'err'); return; }
  const bc = new Uint8Array(outLen);
  bc.set(Module.HEAPU8.subarray(outPtr, outPtr + outLen));
  Module.ccall('wasm_free_dump', null, ['number'], [outPtr]);

  const blob = new Blob([bc], {type:'application/octet-stream'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'edited.luac';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  log('已导出编辑后的字节码: edited.luac (' + fmtBytes(bc.length) + ')', 'ok');
});

// Enable editor button when file loaded
// (handled in handleFile and process flow)

// ---- Download ----
btnDownload.addEventListener('click', () => {
  if(!resultBytes) return;
  const isLua = resultIsLua;
  const blob = new Blob([resultBytes], {type: isLua ? 'text/plain;charset=utf-8' : 'application/octet-stream'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  const baseName = fileName.replace(/\.[^.]+$/, '');
  a.href = url;
  a.download = baseName + (isLua ? '_vm.lua' : '_obf.luac');
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  log('已下载: ' + a.download, 'info');
});

// ---- Select all / none ----
btnAll.addEventListener('click', () => {
  moduleScroll.querySelectorAll('input[type=checkbox]').forEach(cb => cb.checked = true);
  saveConfig();
});
btnNone.addEventListener('click', () => {
  moduleScroll.querySelectorAll('input[type=checkbox]').forEach(cb => cb.checked = false);
  saveConfig();
});

// ---- Clear log ----
btnClearLog.addEventListener('click', () => { logArea.innerHTML = ''; });

// ---- Debug Locate: find which module causes error by disabling one by one ----
function isOutputOk(output) {
  if(!output || output.length === 0) return false;
  if(output.indexOf('test error') >= 0) return false;
  if(output.indexOf('测试失败') >= 0) return false;
  if(output.indexOf('attempt to') >= 0) return false;
  if(output.indexOf('execution timeout') >= 0) return false;
  if(output.indexOf('stack overflow') >= 0) return false;
  if(output.indexOf('not enough memory') >= 0) return false;
  /* must contain success marker */
  return output.indexOf('测试通过了') >= 0;
}

async function runObfuscationWithModules(modIds) {
  // Temporarily set checkboxes to match modIds, run, then restore
  const allCbs = moduleScroll.querySelectorAll('input[type=checkbox]');
  const prevStates = {};
  allCbs.forEach(cb => { prevStates[cb.value] = cb.checked; cb.checked = modIds.includes(cb.value); });
  try {
    const ok = await runObfuscation();
    if(!ok || !resultBytes) return { ok:false, output:'', error:'obfuscation failed' };
    // run result
    const bcPtr = Module._malloc(resultBytes.length);
    Module.HEAPU8.set(resultBytes, bcPtr);
    const outLenPtr = Module._malloc(4);
    const outPtr = Module.ccall('wasm_run_bytecode', 'number', ['number','number','number'], [bcPtr, resultBytes.length, outLenPtr]);
    const outLen = Module.getValue(outLenPtr, 'i32');
    Module._free(bcPtr);
    Module._free(outLenPtr);
    let output = '';
    if(outPtr && outLen > 0){
      output = new TextDecoder().decode(Module.HEAPU8.subarray(outPtr, outPtr + outLen));
      Module.ccall('wasm_free_output', null, ['number'], [outPtr]);
    }
    return { ok:true, output:output, error:'' };
  } catch(e) {
    return { ok:false, output:'', error:e.message };
  } finally {
    allCbs.forEach(cb => { cb.checked = prevStates[cb.value]; });
  }
}

function getModuleLabel(id) {
  const m = MODULE_GROUPS.flatMap(g => g.modules).find(m => m.id === id);
  return m ? m.label : id;
}

btnDebugLocate.addEventListener('click', async () => {
  if(!fileBytes || !wasmReady){ log('请先加载文件并确保 WASM 就绪', 'warn'); return; }
  const allMods = sortModulesForExecution(getSelectedModules());
  if(allMods.length === 0){ log('请至少选择一个模块', 'warn'); return; }

  btnDebugLocate.disabled = true;
  btnDebugLocate.textContent = '定位中...';
  log('=== 错误定位开始 (' + allMods.length + ' 个模块) ===', 'info');

  // Step 1: run with all modules as baseline
  log('[0/0] 基准测试 (全部模块)...', 'info');
  const baseline = await runObfuscationWithModules(allMods);
  const baselineOutput = baseline.output;
  const baselineOk = isOutputOk(baselineOutput);
  log('  基准输出: ' + (baselineOutput.substring(0, 100).replace(/\n/g, ' | ') || '(无输出)') + (baseline.error ? ' ERROR: ' + baseline.error : ''), baselineOk ? 'ok' : 'err');

  // Step 2: disable one module at a time (reverse order) and run
  const results = [];
  for(let i = allMods.length - 1; i >= 0; i--){
    const disabled = allMods[i];
    const remaining = allMods.filter((_, idx) => idx !== i);
    const stepNum = allMods.length - i;
    const progress = Math.round((stepNum / allMods.length) * 100);
    log('[' + stepNum + '/' + allMods.length + '] (' + progress + '%) 关闭: ' + getModuleLabel(disabled) + ' ...', 'info');
    btnDebugLocate.textContent = '定位中 ' + progress + '%';
    const r = await runObfuscationWithModules(remaining);
    const outputMatch = isOutputOk(r.output);
    results.push({
      disabled: disabled,
      disabledLabel: getModuleLabel(disabled),
      remaining: remaining,
      ok: r.ok,
      error: r.error,
      output: r.output,
      outputMatch: outputMatch
    });
    const rOk = isOutputOk(r.output);
    const status = rOk ? '正常' : (r.error ? '错误: ' + r.error : '异常输出');
    log('  结果: ' + status + (r.output && !rOk ? ' | 输出: ' + r.output.substring(0, 80).replace(/\n/g, ' | ') : ''), rOk ? 'ok' : 'warn');
  }

  // Step 3: show summary table
  log('\n=== 错误定位结果 ===', 'info');
  log('基准输出 (' + baselineOutput.length + ' 字节): ' + baselineOutput.substring(0, 120).replace(/\n/g, ' | '), 'info');
  log('\n按关闭顺序 (从后往前):', 'info');

  // Find culprit: module whose removal makes output match baseline (if baseline was broken)
  // Or module whose removal breaks output (if baseline was ok)
  const culpritCandidates = results.filter(r => isOutputOk(r.output) !== baselineOk);
  if(culpritCandidates.length > 0){
    log('\n*** 可疑模块 (关闭后状态反转) ***', 'err');
    culpritCandidates.forEach(r => {
      log('  - ' + r.disabledLabel + ' (' + r.disabled + '): 关闭后' + (r.outputMatch ? '输出恢复一致' : '输出变化/错误'), 'err');
    });
  } else {
    log('\n未找到单一可疑模块 (可能是多模块交互问题)', 'warn');
  }

  log('\n完整矩阵:', 'info');
  results.forEach(r => {
    const rOk = isOutputOk(r.output);
    const mark = rOk ? '[正常]' : (r.error ? '[错误]' : '[异常]');
    log('  ' + mark + ' 关闭 ' + r.disabledLabel + ' -> ' + (r.remaining.length + ' 模块') + (r.error ? ' ERR: ' + r.error : ''), rOk ? 'ok' : 'warn');
  });

  btnDebugLocate.disabled = false;
  btnDebugLocate.textContent = '错误定位';
  log('=== 错误定位完成 ===', 'ok');
});

// ---- Cumulative debug locate: disable modules one by one without restoring ----
btnDebugLocateCum.addEventListener('click', async () => {
  if(!fileBytes || !wasmReady){ log('请先加载文件并确保 WASM 就绪', 'warn'); return; }
  const allMods = sortModulesForExecution(getSelectedModules());
  if(allMods.length === 0){ log('请至少选择一个模块', 'warn'); return; }

  btnDebugLocateCum.disabled = true;
  btnDebugLocateCum.textContent = '定位中...';
  log('=== 累积定位开始 (' + allMods.length + ' 个模块) ===', 'info');
  log('方法: 从后往前累积关闭模块不恢复，定位最少需关闭哪些模块使状态反转', 'info');

  // Step 1: baseline with all modules
  log('[0/' + allMods.length + '] 基准测试 (全部模块)...', 'info');
  const baseline = await runObfuscationWithModules(allMods);
  const baselineOutput = baseline.output;
  const baselineOk = isOutputOk(baselineOutput);
  log('  基准输出: ' + (baselineOutput.substring(0, 100).replace(/\n/g, ' | ') || '(无输出)') + (baseline.error ? ' ERROR: ' + baseline.error : ''), baselineOk ? 'ok' : 'err');

  // Step 2: cumulatively disable modules (reverse order), do NOT restore
  const results = [];
  const disabledSoFar = [];
  for(let i = allMods.length - 1; i >= 0; i--){
    const disabled = allMods[i];
    disabledSoFar.push(disabled);
    const remaining = allMods.filter(m => !disabledSoFar.includes(m));
    const stepNum = allMods.length - i;
    const progress = Math.round((stepNum / allMods.length) * 100);
    log('[' + stepNum + '/' + allMods.length + '] (' + progress + '%) 累积关闭: ' + getModuleLabel(disabled) + ' (剩余 ' + remaining.length + ' 模块)...', 'info');
    btnDebugLocateCum.textContent = '定位中 ' + progress + '%';

    const r = await runObfuscationWithModules(remaining);
    const outputMatch = isOutputOk(r.output);
    results.push({
      disabled: disabled,
      disabledLabel: getModuleLabel(disabled),
      disabledCount: disabledSoFar.length,
      remainingLabels: remaining.map(m => getModuleLabel(m)),
      ok: r.ok,
      error: r.error,
      output: r.output,
      outputMatch: outputMatch
    });
    const rOk = isOutputOk(r.output);
    const status = rOk ? '正常' : (r.error ? '错误: ' + r.error : '异常输出');
    log('  结果: ' + status + (r.output && !rOk ? ' | 输出: ' + r.output.substring(0, 80).replace(/\n/g, ' | ') : ''), rOk ? 'ok' : 'warn');
  }

  // Step 3: summary
  log('\n=== 累积定位结果 ===', 'info');
  log('基准输出 (' + baselineOutput.length + ' 字节): ' + baselineOutput.substring(0, 120).replace(/\n/g, ' | '), 'info');

  // Find first point where output state changed relative to baseline
  const firstChange = results.find(r => isOutputOk(r.output) !== baselineOk);
  if(firstChange){
    log('\n*** 关键转折点 (关闭到此处状态首次反转) ***', 'err');
    log('  触发模块: ' + firstChange.disabledLabel + ' (' + firstChange.disabled + ')', 'err');
    log('  累计关闭 ' + firstChange.disabledCount + ' 个模块:', 'err');
    const cumLabels = disabledSoFar.slice(0, firstChange.disabledCount).map(m => getModuleLabel(m));
    log('    ' + cumLabels.join(', '), 'err');
  } else {
    log('\n未找到转折点 (关闭全部模块后状态仍与基准一致)', 'warn');
  }

  log('\n完整矩阵:', 'info');
  results.forEach(r => {
    const rOk = isOutputOk(r.output);
    const mark = rOk ? '[正常]' : (r.error ? '[错误]' : '[异常]');
    log('  ' + mark + ' 关闭 ' + r.disabledLabel + ' (累计' + r.disabledCount + '个) -> 剩余' + (allMods.length - r.disabledCount) + '模块' + (r.error ? ' ERR: ' + r.error : ''), rOk ? 'ok' : 'warn');
  });

  btnDebugLocateCum.disabled = false;
  btnDebugLocateCum.textContent = '累积定位';
  log('=== 累积定位完成 ===', 'ok');
});

// ---- Help modal ----
btnHelp.addEventListener('click', () => { helpModal.classList.add('show'); });
btnCloseHelp.addEventListener('click', () => { helpModal.classList.remove('show'); });
helpModal.addEventListener('click', e => { if(e.target === helpModal) helpModal.classList.remove('show'); });

// Help tab switching
document.querySelectorAll('.help-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.help-tab').forEach(t => t.classList.remove('active'));
    tab.classList.add('active');
    const target = tab.dataset.tab;
    $('helpLua').style.display = target === 'lua' ? 'block' : 'none';
    $('helpJs').style.display = target === 'js' ? 'block' : 'none';
  });
});

// ---- WASM init ----
async function initWasm(){
  try {
    setStatus('正在加载 WASM 模块...', 'working');
    log('正在初始化 WASM 运行时...', 'info');

    const wasmBase64 = window.__LUAC_WASM_BASE64__ || '';
    let wasmBinary = null;
    if(wasmBase64){
      const binaryStr = atob(wasmBase64);
      wasmBinary = new Uint8Array(binaryStr.length);
      for(let i = 0; i < binaryStr.length; i++) wasmBinary[i] = binaryStr.charCodeAt(i);
      log('WASM 二进制已嵌入 (' + fmtBytes(wasmBinary.length) + ')', 'info');
    }

    Module = await createLuacModule({
      wasmBinary: wasmBinary,
      printErr: function(text) { window._wasmStderr = (window._wasmStderr || '') + text + '\n'; }
    });
    window._Module = Module;
    wasmReady = true;
    wasmStatus.textContent = 'WASM 就绪';
    wasmStatus.style.color = '#3fb950';
    log('WASM 模块加载成功', 'ok');

    Module.ccall('wasm_init', 'number', [], []);

    // load & register persisted custom modules
    const savedCustom = loadCustomModules();
    for(const cm of savedCustom){
      const src = new TextEncoder().encode(cm.source);
      const srcPtr = Module._malloc(src.length);
      Module.HEAPU8.set(src, srcPtr);
      const ret = Module.ccall('wasm_register_module', 'number', ['number','number'], [srcPtr, src.length]);
      Module._free(srcPtr);
      if(ret === 0){
        customModules.push(cm);
        log('恢复Lua自定义模块: ' + cm.name, 'info');
      }
    }

    // load & register persisted JS modules
    const savedJs = loadJsModules();
    for(const jm of savedJs){
      try {
        const moduleObj = { exports: {} };
        const factory = new Function('module', 'exports', jm.source);
        factory(moduleObj, moduleObj.exports);
        if(moduleObj.exports && moduleObj.exports.name && moduleObj.exports.apply){
          jsModules.push({...jm, moduleObj: moduleObj.exports});
          log('恢复JS自定义模块: ' + jm.name, 'info');
        }
      } catch(e){ log('恢复JS模块失败: ' + jm.name, 'warn'); }
    }
    if(jsModules.length > 0) renderModules();

    const modList = Module.ccall('wasm_modules', 'string', [], []);
    if(modList){
      const count = modList.split(',').length;
      log('已注册 ' + count + ' 个内置模块 + ' + customModules.length + ' Lua + ' + jsModules.length + ' JS', 'ok');
    }
    setStatus('WASM 就绪，请上传文件', 'ready');
    btnProcess.disabled = !fileBytes;
    btnProcessRun.disabled = !fileBytes;
  } catch(e){
    log('WASM 加载失败: ' + e.message, 'err');
    setStatus('WASM 加载失败', 'error');
    wasmStatus.textContent = 'WASM 失败';
    wasmStatus.style.color = '#f85149';
  }
}

// ---- Boot ----
renderModules();
initWasm();

})();
