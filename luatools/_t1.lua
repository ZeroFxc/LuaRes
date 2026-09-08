local luac=require('luac') local code=io.open('_full21_1.luac','rb'):read('*a') local r,e=load(code) if not r then print('seed=1 FAIL: '..tostring(e)) else r() print('seed=1 OK') end
