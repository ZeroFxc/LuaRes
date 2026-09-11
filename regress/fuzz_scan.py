#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fuzz_scan.py - 生成随机确定输出用例, 跑指定模块组合, 找首个失败并保留"""
import argparse, os, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_matrix import run_one, classify, sort_mods
import fuzz_gen

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("-m","--mods",required=True)
    ap.add_argument("--count",type=int,default=40)
    ap.add_argument("--n",type=int,default=12)
    ap.add_argument("--timeout",type=int,default=10)
    ap.add_argument("--save",default="")
    a=ap.parse_args()
    mods=[m for m in a.mods.split(",") if m]
    tmp=os.path.join(os.path.dirname(__file__),"tmp","fuzz.lua"); os.makedirs(os.path.dirname(tmp),exist_ok=True)
    hits=0
    for sd in range(a.count):
        src=fuzz_gen.gen(sd,a.n)
        with open(tmp,"w",encoding="utf-8",newline="\n") as f: f.write(src)
        exp=run_one(tmp,[],seed=1,hard_timeout=a.timeout)
        if not exp.get("run_ok"):
            print(f"seed{sd}: baseline broken"); continue
        expect=exp.get("output")
        r=run_one(tmp,mods,seed=sd,hard_timeout=a.timeout)
        v=classify(r,expect)
        if v!="PASS":
            hits+=1
            err=(r.get("run_err") or r.get("gen_err") or r.get("err") or "")[:140]
            print(f"HIT seed={sd} {v} {err}")
            if a.save:
                p=os.path.join(os.path.dirname(__file__),"cases",a.save)
                with open(p,"w",encoding="utf-8",newline="\n") as f: f.write(src)
                print("saved ->",p); return
        else:
            print(f"seed{sd} ok")
    print(f"==> hits={hits}/{a.count}")

if __name__=="__main__": main()
