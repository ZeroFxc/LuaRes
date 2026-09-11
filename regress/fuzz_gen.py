#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fuzz_gen.py - 生成输出确定、结构多样的 Lua 用例, 用于组合崩溃定位"""
import random, argparse, os

HEADER = "local out = {}\nlocal function P(...) local t={...} local s='' for i=1,select('#',...) do if i>1 then s=s..'|' end s=s..tostring(t[i]) end out[#out+1]=s end\n"

# 每个片段是 (代码, 它对 state 的影响用注释), 全部用局部变量/全局P, 输出确定
SNIPPETS = [
 'P("n", {N})',
 'P("s", "{S}")',
 'P("bool", {B})',
 'local t{t} = {{}}\nfor k=1,{N} do t{t}[k] = k*{N} end\nP("tbl", t{t}[1], t{t}[{N}], #t{t})',
 'local ac{t}=0\nfor k=1,{N} do ac{t}=ac{t}+k end\nP("for", ac{t})',
 'local wc{t}=0\nlocal k{t}=1\nwhile k{t}<={N} do wc{t}=wc{t}+k{t}; k{t}=k{t}+1 end\nP("while", wc{t})',
 'local rc{t}=0\nlocal q{t}=0\nrepeat q{t}=q{t}+1; rc{t}=rc{t}+2 until q{t}>={N}\nP("rep", rc{t})',
 'local function ff{t}(a) local r=0 for z=1,a do r=r+z end return r end\nP("fn", ff{t}({N}))',
 'if {N} > 2 then P("if", 1) else P("if", 0) end',
 'local sc{t}=""\nfor k=1,{N} do sc{t}=sc{t}.."a" end\nP("cat", sc{t})',
 'local ic{t}=0\nfor k=1,{N} do if k%2==0 then ic{t}=ic{t}+1 else ic{t}=ic{t}-1 end end\nP("ibr", ic{t})',
 'local nc{t}=0\nfor k=1,{N} do for m=1,2 do nc{t}=nc{t}+m end end\nP("nest", nc{t})',
 'local lt{t}={1,2,{N},4,5}\nP("larr", lt{t}[1], lt{t}[3], #lt{t})',
 'local lm{t}={a=1,b={N},c="{S}"}\nP("lrec", lm{t}.a, lm{t}.b, lm{t}.c)',
 'local ls{t}=0\nfor k=1,{N} do local row={k,k*2,"{S}"}; ls{t}=ls{t}+row[1]+row[2] end\nP("lrow", ls{t})',
 'local la{t}={{"{S}",1},{"{S}",2}}\nP("lmat", la{t}[1][1], la{t}[2][2])',
 'local function fp{t}(x) local h={p=x,q=x+1} return h.p+h.q end\nP("fpt", fp{t}({N}))',
]
FOOT = "print(table.concat(out, \"#\"))\n"

def gen(seed, n):
    rnd=random.Random(seed)
    parts=[HEADER]
    for i in range(n):
        s=rnd.choice(SNIPPETS)
        s=s.replace("{t}", str(i)).replace("{N}", str(rnd.randint(1,6))).replace("{S}", rnd.choice(["ab","cd","ef","xyz"])).replace("{B}", rnd.choice(["true","false"]))
        parts.append(s)
    parts.append(FOOT)
    return "\n".join(parts)

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--seed",type=int,required=True)
    ap.add_argument("--n",type=int,default=12)
    ap.add_argument("--out",required=True)
    a=ap.parse_args()
    with open(a.out,"w",encoding="utf-8",newline="\n") as f: f.write(gen(a.seed,a.n))
