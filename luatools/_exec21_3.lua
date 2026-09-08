local f=io.open('_full21_3.luac','rb') local d=f:read('*a') f:close() local r,e=load(d) if not r then print('seed=3 LOAD FAIL: '..tostring(e)) else r() print('seed=3 PASS') end
