p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

# 1. Add btnCompare declaration
old1 = "const btnInspect = $('btnInspect'), inspectModal = $('inspectModal'), inspectContent = $('inspectContent');"
new1 = "const btnInspect = $('btnInspect'), btnCompare = $('btnCompare'), inspectModal = $('inspectModal'), inspectContent = $('inspectContent');"
if old1 in s:
    s = s.replace(old1, new1, 1)
    print('added btnCompare declaration')
else:
    print('declaration not found')

# 2. Enable btnCompare alongside btnInspect (two places)
old2a = "    btnInspect.disabled = !wasmReady;"
new2a = "    btnInspect.disabled = !wasmReady;\n    btnCompare.disabled = !wasmReady;"
if old2a in s:
    s = s.replace(old2a, new2a, 1)
    print('enabled btnCompare (place 1)')

old2b = "    btnInspect.disabled = !wasmReady || (!fileBytes && !resultBytes);"
new2b = "    btnInspect.disabled = !wasmReady || (!fileBytes && !resultBytes);\n    btnCompare.disabled = !wasmReady || (!fileBytes || !resultBytes);"
if old2b in s:
    s = s.replace(old2b, new2b, 1)
    print('enabled btnCompare (place 2)')

# 3. Add comparison function before btnCloseInspect event listener
anchor = "btnCloseInspect.addEventListener('click', () => { inspectModal.classList.remove('show'); });"

compare_fn = '''
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

'''

if anchor in s:
    s = s.replace(anchor, compare_fn + anchor, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('added comparison function and button handler')
else:
    print('anchor not found')
