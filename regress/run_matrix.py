#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_matrix.py - Lua 字节码混淆模块组合回归框架 (原生 obf_test.exe)

能力:
  combo   跑指定模块组合, 可扫 seed
  pair    两两组合矩阵
  all     全开
  nest    嵌套(混淆产物再次混淆)
  matrix  全用例 x (单模块 + 两两 + 全开) 输出 PASS/FAIL 矩阵 CSV

判定(与基线 NONE 输出对比):
  PASS        生成+运行成功, 输出与基线一致
  MISMATCH    运行成功但输出不同
  RUN_ERR     运行期 Lua 错误
  RUN_TIMEOUT 运行死循环(软超时)
  GEN_ERR     混淆阶段 Lua 报错
  GEN_CRASH   混淆阶段进程崩溃(segfault 等, 无结果文件)
  TIMEOUT     整个进程硬超时(GEN 阶段 C 死循环)
"""
import argparse, itertools, json, os, re, subprocess, sys, time, csv

ROOT = r"E:\LuaRes"
EXE = os.path.join(ROOT, "luasafe", "obf_test.exe")
HARNESS = os.path.join(ROOT, "regress", "harness.lua")
NEST_CHECK = os.path.join(ROOT, "nest_check.lua")
CASEDIR = os.path.join(ROOT, "regress", "cases")
TMPDIR = os.path.join(ROOT, "regress", "tmp")
os.makedirs(TMPDIR, exist_ok=True)

# 权威执行顺序始终从 web/app.js 的 EXEC_ORDER 动态解析。
# 之前这里硬编码了一份列表，新增模块(unary_chain/self_expand/jmp_split 等)后未同步，
# sort_mods 把缺失模块当成 idx=999 排到末尾，使测试按错误顺序应用模块，得出大量假失败。
def _load_exec_order():
    p = os.path.join(ROOT, "web", "app.js")
    txt = open(p, "r", encoding="utf-8").read()
    m = re.search(r"EXEC_ORDER\s*=\s*\[(.*?)\]", txt, re.S)
    if not m:
        raise RuntimeError("EXEC_ORDER not found in web/app.js")
    return re.findall(r"'([a-z0-9_]+_c)'", m.group(1))
EXEC_ORDER = _load_exec_order()
VM4 = {"vm_dispatch_shuffle_c","vm_reg_shuffle_c","vm_const_shuffle_c","vm_embed_c"}
ORDER_IDX = {m:i for i,m in enumerate(EXEC_ORDER)}

def sort_mods(mods):
    return sorted(mods, key=lambda m: ORDER_IDX.get(m, 999))

def write_case(path, text):
    with open(path,"wb") as f: f.write(text.encode("utf-8"))

_basel_cache = {}
def baseline(case_path):
    if case_path in _basel_cache: return _basel_cache[case_path]
    r = run_one(case_path, [], seed=1, hard_timeout=15)
    exp = r.get("output","") if r.get("run_ok") else None
    _basel_cache[case_path] = exp
    return exp

def run_one(case_path, mods, seed=None, hard_timeout=12, extra_opts=None,
            artifact_in=None, verbose=False):
    """起一个 obf_test 进程跑 harness, 返回结果 dict."""
    tag = f"r_{os.getpid()}_{int(time.time()*1000)%1000000}"
    resfile = os.path.join(TMPDIR, tag+".json")
    opts = {"run_hooks": 300}
    if seed is not None: opts["seed"] = seed
    if extra_opts: opts.update(extra_opts)
    opts_str = json.dumps(opts, separators=(",",":"))
    modarg = "NONE" if not mods else ",".join(sort_mods(mods))
    args = [EXE, HARNESS, case_path, modarg, opts_str, resfile]
    t0 = time.time()
    try:
        p = subprocess.run(args, cwd=ROOT, capture_output=True, timeout=hard_timeout)
    except subprocess.TimeoutExpired:
        return {"verdict":"TIMEOUT","ms":int((time.time()-t0)*1000),"mods":mods,"seed":seed}
    ms = int((time.time()-t0)*1000)
    if not os.path.exists(resfile):
        err = (p.stderr or b"").decode("utf-8","replace")[-400:]
        return {"verdict":"GEN_CRASH","ms":ms,"code":p.returncode,"err":err,"mods":mods,"seed":seed}
    try:
        # 混淆后输出可能含任意字节(字符串被破坏时), 必须容错: bytes 读入、
        # 非法 UTF-8 替换、允许字符串内控制字符, 否则会把 MISMATCH 误判成 GEN_CRASH
        raw = open(resfile, "rb").read().decode("utf-8", "replace")
        r = json.loads(raw, strict=False)
    except Exception as e:
        return {"verdict":"GEN_CRASH","ms":ms,"code":p.returncode,"err":"bad json: "+str(e),"mods":mods}
    finally:
        try: os.remove(resfile)
        except OSError: pass
    r["ms"]=ms; r["mods"]=mods; r["seed"]=seed
    # 判定
    if not r.get("gen_ok"):
        r["verdict"]="GEN_ERR"; return r
    if r.get("run_timeout"):
        r["verdict"]="RUN_TIMEOUT"; return r
    if not r.get("run_ok"):
        r["verdict"]="RUN_ERR"; return r
    r["verdict"]="OK"; return r

def classify(r, expected):
    v=r.get("verdict")
    if v!="OK": return v
    got = re.sub(r"table: (0x)?[0-9a-fA-F]+", "table: <addr>", r.get("output") or "")
    exp = re.sub(r"table: (0x)?[0-9a-fA-F]+", "table: <addr>", expected or "")
    return "PASS" if got==exp else "MISMATCH"

def run_combo(case, mods, seeds=range(1), hard=12, extra=None, verbose=False):
    exp = baseline(case)
    results=[]
    for sd in seeds:
        r=run_one(case, mods, seed=sd, hard_timeout=hard, extra_opts=extra)
        v=classify(r,exp)
        results.append((sd,v,r))
    return exp,results

def short(r):
    return (r.get("run_err") or r.get("gen_err") or r.get("err") or "")[:160].replace("\n"," ")

# ---------------- 命令 ----------------
def cmd_combo(a):
    case=_resolve_case(a.case); mods=[m for m in a.mods.split(",") if m]
    seeds=range(a.seeds) if a.seeds>0 else [None]
    exp,res=run_combo(case,mods,seeds,a.timeout)
    print(f"case={os.path.basename(case)} mods={sort_mods(mods)} expect={exp!r}")
    bad=0
    for sd,v,r in res:
        mark = "OK " if v=="PASS" else "XX "
        if v!="PASS": bad+=1
        print(f"  {mark}seed={sd} {v} {r['ms']}ms {short(r)}")
    print(f"==> {'ALL PASS' if bad==0 else str(bad)+' FAIL'}")

def cmd_pair(a):
    case=_resolve_case(a.case)
    pool=[m for m in (a.mods.split(",") if a.mods else EXEC_ORDER) if m]
    if a.skip_vm: pool=[m for m in pool if m not in VM4]
    exp=baseline(case); print(f"case={os.path.basename(case)} expect={exp!r}")
    seeds=list(range(a.seeds))
    rows=[]
    for x,y in itertools.combinations(pool,2):
        worst="PASS"; detail=""
        for sd in seeds:
            r=run_one(case,[x,y],seed=sd,hard_timeout=a.timeout)
            v=classify(r,exp)
            if v!="PASS": worst=v; detail=f"seed{sd}:{short(r)}"; break
        rows.append((x,y,worst,detail))
        flag="  " if worst=="PASS" else "XX"
        print(f"{flag} {x:24} + {y:24} {worst} {detail}")
    fails=[r for r in rows if r[2]!="PASS"]
    print(f"==> {len(rows)-len(fails)}/{len(rows)} pair PASS, {len(fails)} FAIL")

def cmd_all(a):
    case=_resolve_case(a.case)
    pool=[m for m in EXEC_ORDER if not (a.skip_vm and m in VM4)]
    exp=baseline(case)
    for sd in (range(a.seeds) if a.seeds else [1]):
        r=run_one(case,pool,seed=sd,hard_timeout=a.timeout)
        print(f"ALL({len(pool)}) seed={sd} {classify(r,exp)} {r['ms']}ms {short(r)}")

def cmd_nest(a):
    # 嵌套: 第一次混淆产物 dump 成文件, 再作为输入混淆第二次
    # harness 目前直接吃源码; 嵌套通过对同一源码连续两轮模块实现等价覆盖有限,
    # 这里改为: 第一轮产物落盘, 第二轮以字节码文件作为 case 输入
    raise SystemExit("use cmd_nest (implemented below)")

def run_nest(case, mods, seed=1, hard_timeout=20):
    """两轮嵌套: 源码->模块链->bc1->undump->再模块链->bc2->受控执行。"""
    modarg = "NONE" if not mods else ",".join(sort_mods(mods))
    args = [EXE, NEST_CHECK, case, modarg, str(seed)]
    t0=time.time()
    try:
        p=subprocess.run(args,cwd=ROOT,capture_output=True,timeout=hard_timeout)
    except subprocess.TimeoutExpired:
        return {"verdict":"TIMEOUT","ms":int((time.time()-t0)*1000)}
    ms=int((time.time()-t0)*1000)
    out=(p.stdout or b"").decode("utf-8","replace").strip()
    if out.startswith("NEST_GEN_ERR"): return {"verdict":"GEN_ERR","ms":ms,"err":out[:200]}
    if out.startswith("NEST_LOAD_ERR"):return {"verdict":"GEN_ERR","ms":ms,"err":out[:200]}
    if out.startswith("NEST_TIMEOUT"):  return {"verdict":"RUN_TIMEOUT","ms":ms}
    if out.startswith("NEST_RUN_ERR"):  return {"verdict":"RUN_ERR","ms":ms,"err":out[:200]}
    if p.returncode!=0:
        return {"verdict":"GEN_CRASH","ms":ms,"code":p.returncode,
                "err":(p.stderr or b"").decode("utf-8","replace")[-200:]}
    return {"verdict":"OK","ms":ms,"output":out}

def cmd_nest(a):
    cases=[_resolve_case(c) for c in (a.case.split(",") if a.case else [])] or \
          sorted(os.path.join(CASEDIR,f) for f in os.listdir(CASEDIR) if f.endswith(".lua"))
    pool=[m for m in EXEC_ORDER if not (a.skip_vm and m in VM4)]
    mods=[m for m in (a.mods.split(",") if a.mods else pool) if m]
    if a.skip_vm: mods=[m for m in mods if m not in VM4]  # 嵌套只对字节码, VM embed 无意义
    seeds=list(range(a.seeds))
    bad=0; total=0
    for case in cases:
        exp=baseline(case)
        for sd in seeds:
            total+=1
            r=run_nest(case,mods,sd,a.timeout)
            v=classify(r,exp) if r["verdict"]=="OK" else r["verdict"]
            if v!="PASS": bad+=1
            print(f"{'OK ' if v=='PASS' else 'XX'} {os.path.basename(case):16} seed={sd} {v} {r['ms']}ms {short(r)}")
    print(f"==> NEST {total-bad}/{total} PASS, {bad} FAIL")

def _norm_out(s):
    return re.sub(r"table: (0x)?[0-9a-fA-F]+","table: <addr>", s or "")

def cmd_matrix(a):
    """全模块 单模块/两两/全开/嵌套 -> CSV + HTML PASS-FAIL 矩阵。"""
    if a.case:
        cases=[_resolve_case(c) for c in a.case.split(",")]
    else:
        cases=sorted(os.path.join(CASEDIR,f) for f in os.listdir(CASEDIR) if f.endswith(".lua"))
    pool=[m for m in EXEC_ORDER if not (a.skip_vm and m in VM4)]
    seeds=list(range(max(1,a.seeds)))
    rows=[]   # case,seed,kind,mods,verdict,ms,detail
    def record(case,sd,kind,mods,r,exp):
        v=classify(r,exp) if r.get("verdict")=="OK" else r.get("verdict")
        rows.append((os.path.basename(case),sd,kind,"+".join(sort_mods(mods)) if mods else "NONE",
                     v,r.get("ms",0),short(r)))
        return v
    t_start=time.time()
    # single
    if not a.no_single:
        for case in cases:
            exp=baseline(case)
            for m in pool:
                for sd in seeds:
                    r=run_one(case,[m],seed=sd,hard_timeout=a.timeout)
                    record(case,sd,"single",[m],r,exp)
        print(f"[matrix] single done, {len(rows)} rows")
    # pair (跨 case 聚合, 每对取最差; 为控耗时只对每个 case 都跑但记录最差)
    pair_worst={}
    if not a.no_pair:
        pi=0
        for x,y in itertools.combinations(pool,2):
            pi+=1; worst="PASS"; detail=""
            for case in cases:
                exp=baseline(case)
                for sd in seeds:
                    r=run_one(case,[x,y],seed=sd,hard_timeout=a.timeout)
                    v=classify(r,exp) if r.get("verdict")=="OK" else r.get("verdict")
                    rows.append((os.path.basename(case),sd,"pair",f"{x}+{y}",v,r.get("ms",0),short(r)))
                    if v!="PASS" and worst=="PASS": worst=v; detail=f"{os.path.basename(case)} s{sd}:{short(r)}"
            pair_worst[(x,y)]=(worst,detail)
            if pi%25==0: print(f"[matrix] pair {pi}/{len(pool)*(len(pool)-1)//2}")
    # all + nest
    for case in cases:
        exp=baseline(case)
        for sd in seeds:
            record(case,sd,"all",pool,run_one(case,pool,seed=sd,hard_timeout=a.timeout),exp)
            record(case,sd,"nest",pool,run_nest(case,[m for m in pool if m not in VM4],sd,a.timeout),exp)
    stamp=time.strftime("%Y%m%d_%H%M%S")
    csv_path=os.path.join(TMPDIR,f"matrix_{stamp}.csv")
    with open(csv_path,"w",newline="",encoding="utf-8-sig") as f:
        w=csv.writer(f); w.writerow(["case","seed","kind","mods","verdict","ms","detail"]); w.writerows(rows)
    html_path=_write_matrix_html(pool,pair_worst,rows,stamp,a)
    fails=[r for r in rows if r[4]!="PASS"]
    print(f"==> MATRIX total={len(rows)} FAIL={len(fails)}  {int(time.time()-t_start)}s")
    print(f"    CSV : {csv_path}")
    print(f"    HTML: {html_path}")
    for r in fails[:30]: print("   XX",r[0],"s"+str(r[1]),r[2],r[3],r[4],r[6][:60])

def _write_matrix_html(pool,pair_worst,rows,stamp,a):
    VCOLOR={"PASS":"#1a3d24","MISMATCH":"#7d2b2b","RUN_ERR":"#7d2b2b","RUN_TIMEOUT":"#7a4b12",
            "GEN_ERR":"#7d2b2b","GEN_CRASH":"#5a1212","TIMEOUT":"#7a4b12"}
    def cell(v,detail):
        c=VCOLOR.get(v,"#333"); tip=(detail or v).replace('"','&quot;')
        return f'<td class="c" style="background:{c}" title="{tip}"></td>'
    # pair grid
    n=len(pool); grid=["<tr><th></th>"+"".join(f"<th>{i}</th>" for i in range(n))+"</tr>"]
    for i,x in enumerate(pool):
        tds=[f"<th class='rh'>{i}:{x.replace('_c','')}</th>"]
        for j,y in enumerate(pool):
            if j<=i: tds.append("<td class='z'></td>")
            else:
                v,d=pair_worst.get((x,y),("PASS","")); tds.append(cell(v,d))
        grid.append("<tr>"+"".join(tds)+"</tr>")
    # summary by kind/verdict
    kinds=sorted(set(r[2] for r in rows)); verdicts=sorted(set(r[4] for r in rows))
    summ=["<tr><th>kind</th>"+"".join(f"<th>{v}</th>" for v in verdicts)+"</tr>"]
    for k in kinds:
        cells=[sum(1 for r in rows if r[2]==k and r[4]==v) for v in verdicts]
        summ.append("<tr><th>"+k+"</th>"+"".join(f"<td>{c}</td>" for c in cells)+"</tr>")
    failrows="".join(
        f"<tr><td>{r[0]}</td><td>{r[1]}</td><td>{r[2]}</td><td>{r[3]}</td>"+
        f"<td style='color:#ff8a8a'>{r[4]}</td><td>{r[5]}</td><td>{r[6]}</td></tr>"
        for r in rows if r[4]!="PASS")
    html=f"""<!doctype html><html><head><meta charset="utf-8"><title>matrix {stamp}</title>
<style>
body{{background:#0d1117;color:#c9d1d9;font-family:Consolas,monospace;font-size:12px;margin:16px}}
h2{{color:#58a6ff}} table{{border-collapse:collapse;margin:10px 0}}
th,td{{border:1px solid #21262d;padding:2px 5px;font-size:11px}}
th{{background:#161b22;color:#8b949e}} td.c{{width:14px;height:14px;padding:0}} td.z{{background:#0a0d11}}
.rh{{text-align:left;white-space:nowrap}} .legend span{{display:inline-block;width:12px;height:12px;margin-right:4px}}
</style></head><body>
<h2>混淆模块组合回归矩阵 {stamp}</h2>
<div class="legend">模块索引见行/列号；绿=PASS，红=错误，橙=超时（悬停看详情）。</div>
<h3>两两组合（跨用例/seed 取最差）</h3>
<table>{''.join(grid)}</table>
<h3>分阶段统计</h3><table>{''.join(summ)}</table>
<h3>失败明细（{sum(1 for r in rows if r[4]!='PASS')}）</h3>
<table><tr><th>case</th><th>seed</th><th>kind</th><th>mods</th><th>verdict</th><th>ms</th><th>detail</th></tr>{failrows}</table>
<ol>{"".join(f"<li>{i}:{m}</li>" for i,m in enumerate(pool))}</ol>
</body></html>"""
    p=os.path.join(TMPDIR,f"matrix_{stamp}.html")
    with open(p,"w",encoding="utf-8") as f: f.write(html)
    return p

def _resolve_case(c):
    if not c: raise SystemExit("该子命令需要指定 case 文件路径或用例名")
    if os.path.exists(c): return os.path.abspath(c)
    p=os.path.join(CASEDIR,c)
    if os.path.exists(p): return p
    # 内联
    tmp=os.path.join(TMPDIR,"inline.lua"); write_case(tmp,c+"\n"); return tmp

def main():
    ap=argparse.ArgumentParser()
    sub=ap.add_subparsers(dest="cmd",required=True)
    def common(p):
        p.add_argument("case",nargs="?",default=None); p.add_argument("--seeds",type=int,default=1)
        p.add_argument("--timeout",type=int,default=12)
        p.add_argument("--skip-vm",action="store_true")
    p=sub.add_parser("combo"); common(p); p.add_argument("-m","--mods",required=True)
    p=sub.add_parser("pair"); common(p); p.add_argument("--mods",default="")
    p=sub.add_parser("all"); common(p)
    p=sub.add_parser("nest"); common(p); p.add_argument("--mods",default="")
    p=sub.add_parser("matrix"); common(p)
    for f in ("--no-pair","--no-single"): p.add_argument(f,action="store_true")
    a=ap.parse_args()
    {"combo":cmd_combo,"pair":cmd_pair,"all":cmd_all,"nest":cmd_nest,"matrix":cmd_matrix}[a.cmd](a)

if __name__=="__main__":
    main()
