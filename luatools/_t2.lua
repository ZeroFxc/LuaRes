local luac=require('luac') local code=io.open('_full21_2.luac','rb'):read('*a') local r,e=load(code) if not r then print('seed=2 FAIL: '..tostring(e)) else r() print('seed=2 OK') end
