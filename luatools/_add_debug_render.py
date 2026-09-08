p = r'E:\LuaRes\web\app.js'
s = open(p, encoding='utf-8').read()

old = '''        <div style="margin-bottom:10px"><div style="font-size:11px;color:#8b949e;margin-bottom:4px">指令列表</div>${renderInstructions(p)}</div>
        <div><div style="font-size:11px;color:#8b949e;margin-bottom:4px">子Proto</div>${renderSubProtos(p, depth)}</div>'''

new = '''        <div style="margin-bottom:10px"><div style="font-size:11px;color:#8b949e;margin-bottom:4px">指令列表</div>${renderInstructions(p)}</div>
        <div style="margin-bottom:10px"><div style="font-size:11px;color:#8b949e;margin-bottom:4px">调试信息</div>${renderDebugInfo(p)}</div>
        <div><div style="font-size:11px;color:#8b949e;margin-bottom:4px">子Proto</div>${renderSubProtos(p, depth)}</div>'''

if old in s:
    s = s.replace(old, new, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('replaced renderProtoSection')
else:
    print('old not found in renderProtoSection')

# Now add renderDebugInfo function before renderSubProtos
anchor = 'function renderSubProtos'
if anchor in s:
    debug_fn = '''function renderDebugInfo(p){
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

'''
    s = s.replace(anchor, debug_fn + anchor, 1)
    open(p, 'w', encoding='utf-8').write(s)
    print('added renderDebugInfo')
else:
    print('anchor not found')
