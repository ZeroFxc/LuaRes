local luac = require("luac")
local b64 = "=IAPYthkQWr2DFAH7uAABwAAA5BA10aAGv/rgnOiRAABVHdVHBaYIPTaEWXIo58ct8rAmR4b/HSwCMxh6y0N6Ijvz77qwwKTwPrr+F3yxeQYMqYqByxuTCOv3dEFwYGM9Zxd5HOaeqBWcmZS3W+NMRSGfNCcNG4eGTtLJpk7ZV2NrrMxg4M2tL6yClN7Ok/w7PwoCj0yiK986T62VGDlfoOfFFPQBjNC63jZhVU1nwV2GJAI8Vv8K/Ri2ibOO+h8NbKVtUS+qVhzuiC0pbM1w2kyzZEW3isfjFoByLaWPCsmhz8eZXIOKdnzqlQ4uHSIT3Xk+76eGSeKhMdJ4eKxGDwHMje1VjOv7khiLFleR+xu62Xpd7NigTWXuXiQ3Sz2QCazzTzGGie9d0kdE1qYzvt3jg8bR9Wt0GYzrfTKdxE4ZmQXfjX6VfautwIR6GNIxgsKIFuBITsY7nRm2rf9IIUMCk2A+mUza7b4FcAGMKRhv8JKQbgetObOzw3Sh52HPQMAAQoJAgkmeALcUz8YJpT+CShwUACg5EQAkLr3X23X1+iAgAXD/Ra2B+pbwqlvCT+YnoNylaCrOP0r3u2asRIaTjdYTgEAZK5r2zxNd5TYg9OSlbympofs3QoeAelqmpWzg6ISE3RT0qqljqNZEBgwqDHuCgAcqOARaI89YFhQc1R4Cm1TH0wg4B/fE+2XKrcF8/wyDVQ31jMu2YMrL7E1gKmoliYAFZdB0kPqzqgeAKZCyXpQUIC66jPZYEkpYAlp4ElJ4OD1m47gyffe4KmHIhzWvr2dLqIgmTmJeWmR4ndnMloKBgI8PSlP4zg4ga2ohpsBwEiklsFFNr4qLcvv2zzDyeT2anljDlAcVgFP3A2Qc8GxTM0DOatreXlbCYFbJeSO1XBahUz8qMbPiMvO3JqztKW0Dnxqo/P4GiqhEpGXCQS+ZvBZZVxz83Zypm5NoTTyDV9lA/SlVRm/Vc49txiUZ9yBJ7+q545rg8N3E6aSEEH3ui4PsApcTOFHAuhAibbToW3k0JUEupBCbyqoocSZEaAp2bOclLYERLBLAX/w6bHRFtxWjZQFegYxcg=="
local dec = string.dec(b64)
local proto = luac.undump(dec, false)
print("=== constants ===")
for i=1,#proto.k do
    print(string.format("  k[%d] = %s", i-1, tostring(proto.k[i])))
end
print("\n=== code (first 30) ===")
local opnames = {"MOVE","LOADK","LOADKX","LOADBOOL","LOADNIL","GETUPVAL","GETTABUP","GETTABLE","SETTABUP","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","MOD","POW","DIV","IDIV","BAND","BOR","BXOR","SHL","SHR","UNM","BNOT","NOT","LEN","CONCAT","JMP","EQ","LT","LE","TEST","TESTSET","CALL","TAILCALL","RETURN","FORLOOP","FORPREP","TFORCALL","TFORLOOP","SETLIST","CLOSURE","VARARG","EXTRAARG"}
for i=1,math.min(30,#proto.code) do
    local inst = proto.code[i]
    local op = luac.GET_OPCODE(inst)
    local a = luac.GETARG_A(inst)
    local b = luac.GETARG_B(inst)
    local c = luac.GETARG_C(inst)
    local bx = luac.GETARG_Bx(inst)
    print(string.format("  pc=%d %s A=%d B=%d C=%d Bx=%d", i-1, opnames[op+1] or tostring(op), a, b, c, bx))
end
