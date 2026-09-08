local luac=require('luac') local code=io.open('_full21_3.luac','rb'):read('*a') local r,e=load(code) if not r then print('seed=3 FAIL: '..tostring(e)) else r() print('seed=3 OK') end
