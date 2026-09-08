local f=io.open('_full21_1.luac','rb') local d=f:read('*a') f:close() local r,e=load(d) if not r then print('seed=1 LOAD FAIL: '..tostring(e)) else r() print('seed=1 PASS') end
