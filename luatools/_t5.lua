local luac=require('luac') local code=io.open('_full21_5.luac','rb'):read('*a') local r,e=load(code) if not r then print('seed=5 FAIL: '..tostring(e)) else r() print('seed=5 OK') end
