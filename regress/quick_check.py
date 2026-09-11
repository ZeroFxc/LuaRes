#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""quick_check.py - 对 cases 目录所有用例跑指定组合集 x seed, 汇总 PASS/FAIL"""
import argparse, glob, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from run_matrix import run_one, baseline, classify, sort_mods, CASEDIR, EXEC_ORDER, VM4

DEFAULT_COMBOS = [
 [],
 ["for_loop_unroll_c"],
 ["cfg_shuffle_c"],
 ["for_loop_unroll_c","cfg_shuffle_c"],
 ["for_loop_unroll_c","cfg_shuffle_c","const_shuffle_c"],
 ["const_shuffle_c","cfg_shuffle_c"],
]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--seeds",type=int,default=8)
    ap.add_argument("--combos",default="",help="分号分隔的逗号模块列表, 覆盖默认")
    ap.add_argument("--cases",default="")
    ap.add_argument("--timeout",type=int,default=8)
    ap.add_argument("--no-vm",action="store_true")
    a=ap.parse_args()
    if a.combos:
        combos=[[m for m in c.split(",") if m] for c in a.combos.split(";") if c.strip()]
    else:
        combos=DEFAULT_COMBOS
    cases = sorted(glob.glob(os.path.join(CASEDIR,"*.lua")))
    if a.cases:
        want=set(a.cases.split(",")); cases=[c for c in cases if os.path.basename(c) in want or os.path.basename(c).split(".")[0] in want]
    total=0; fails=0
    for case in cases:
        exp=baseline(case)
        for combo in combos:
            worst=("PASS",""); npass=0
            for sd in range(a.seeds):
                r=run_one(case,combo,seed=sd,hard_timeout=a.timeout)
                v=classify(r,exp); total+=1
                if v=="PASS": npass+=1
                elif worst[0]=="PASS":
                    worst=(v,f"seed{sd}:{(r.get('run_err') or r.get('gen_err') or r.get('err') or '')[:90]}")
            tag="OK " if worst[0]=="PASS" else "XX "
            if worst[0]!="PASS": fails+=1
            name=os.path.basename(case)
            print(f"{tag}{name:20} {'+'.join(sort_mods(combo)) or 'BASELINE':48} {npass}/{a.seeds} {worst[1]}")
    print(f"\n==> combo-cells total={total} fails={fails}")
    sys.exit(1 if fails else 0)

if __name__=="__main__": main()
