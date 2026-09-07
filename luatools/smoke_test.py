import subprocess, sys, os, time

LUAC = r"E:\LuaRes\luasafe\lua_luac_c.exe"
TARGET = r"E:\LuaRes\luatools\smoke_target.lua"
TIMEOUT = 15

ALL_MODULES = [
    "str_encrypt_c", "const_hide_c", "const_shuffle_c",
    "debug_strip_c", "bool_obfuscate_c", "num_obfuscate_c",
    "junk_jmp_c", "opaque_predicate_c", "junk_loadk_c",
    "junk_move_c", "const_poison_c", "antidec_c",
    "table_obfuscate_c", "instruction_mutate_c", "str_split_c",
    "opaque_junk_c", "luac_flatten_c", "condition_split_c",
    "junk_c", "jmp_obfuscate_c", "indirect_call_c",
    "flatten_enhance_c", "reg_shuffle_c", "integrity_check_c",
]

# modules known to have issues or be environment-specific
SKIP_ALL = {"loop_restructure_c", "op48_junk_c", "luac_obfuscate_c"}

COMBOS = {
    "string+const": ["str_encrypt_c", "const_hide_c", "const_shuffle_c", "str_split_c", "num_obfuscate_c", "bool_obfuscate_c"],
    "control_flow": ["luac_flatten_c", "flatten_enhance_c", "condition_split_c", "jmp_obfuscate_c"],
    "junk_all": ["junk_jmp_c", "junk_loadk_c", "junk_move_c", "junk_c", "opaque_junk_c", "opaque_predicate_c"],
    "flatten_heavy": ["luac_flatten_c", "flatten_enhance_c", "condition_split_c", "opaque_predicate_c", "opaque_junk_c", "junk_c"],
    "register+call": ["reg_shuffle_c", "indirect_call_c", "instruction_mutate_c", "jmp_obfuscate_c"],
    "table+debug": ["table_obfuscate_c", "debug_strip_c", "const_poison_c", "antidec_c"],
    "heavy_mix": ["str_encrypt_c", "num_obfuscate_c", "luac_flatten_c", "flatten_enhance_c",
                  "opaque_predicate_c", "opaque_junk_c", "junk_c", "jmp_obfuscate_c",
                  "reg_shuffle_c", "indirect_call_c", "instruction_mutate_c",
                  "condition_split_c", "table_obfuscate_c", "str_split_c",
                  "bool_obfuscate_c", "const_shuffle_c", "debug_strip_c"],
}

def run_obf(modules, runs=3):
    """Run obfuscation with given modules, return (pass_count, fail_count, errors)."""
    mod_calls = "".join(f"luac.{m}(p);" for m in modules)
    target_fwd = TARGET.replace("\\", "/")
    script = f'''
local luac = require("luac")
local f = loadfile("{target_fwd}")
local bc = string.dec(string.dump(f, true))
local p = luac.undump(bc, false)
{mod_calls}
local d = luac.dump(p)
local r = load(d)
if r then r() else print("LOAD_FAIL") end
'''
    runner = os.path.join(os.path.dirname(TARGET), "_smoke_runner.lua")
    with open(runner, "w", encoding="utf-8") as f:
        f.write(script)

    passed = 0
    failed = 0
    errors = []
    for i in range(runs):
        try:
            proc = subprocess.run([LUAC, runner], capture_output=True, text=True, timeout=TIMEOUT)
            out = proc.stdout + proc.stderr
            if proc.returncode == 0 and "SMOKE_TEST_OK" in out:
                passed += 1
            else:
                failed += 1
                if len(errors) < 2:
                    err_line = [l for l in out.split("\n") if l.strip()][:2]
                    errors.append(" | ".join(err_line)[:200])
        except subprocess.TimeoutExpired:
            failed += 1
            errors.append("TIMEOUT (infinite loop)")
        except Exception as e:
            failed += 1
            errors.append(str(e)[:200])

    os.remove(runner) if os.path.exists(runner) else None
    return passed, failed, errors

def main():
    print("=" * 70)
    print("SMOKE TEST: individual modules")
    print("=" * 70)

    results = {}
    for mod in ALL_MODULES:
        p, f, errs = run_obf([mod], runs=3)
        status = "PASS" if f == 0 else ("PARTIAL" if p > 0 else "FAIL")
        results[mod] = (p, f, status)
        err_str = f"  ERR: {errs[0]}" if errs else ""
        print(f"  [{status:7s}] {mod:25s} {p}/3{err_str}")

    print()
    print("=" * 70)
    print("SMOKE TEST: module combinations")
    print("=" * 70)

    for name, mods in COMBOS.items():
        p, f, errs = run_obf(mods, runs=3)
        status = "PASS" if f == 0 else ("PARTIAL" if p > 0 else "FAIL")
        err_str = f"  ERR: {errs[0]}" if errs else ""
        print(f"  [{status:7s}] {name:20s} ({len(mods)} mods) {p}/3{err_str}")

    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    total = len(results)
    all_pass = sum(1 for v in results.values() if v[2] == "PASS")
    partial = sum(1 for v in results.values() if v[2] == "PARTIAL")
    fail = sum(1 for v in results.values() if v[2] == "FAIL")
    print(f"  Individual: {all_pass}/{total} PASS, {partial} PARTIAL, {fail} FAIL")
    if fail > 0:
        print("  Failed modules:")
        for mod, (p, f, s) in results.items():
            if s == "FAIL":
                print(f"    - {mod}")

if __name__ == "__main__":
    main()
