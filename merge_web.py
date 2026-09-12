#!/usr/bin/env python3
"""
merge_web.py - Merge WASM + JS + HTML into a single self-contained HTML file.

Usage:
    python merge_web.py [--output luac_obf.html]

Inputs (relative to project root E:\\LuaRes):
    web/index.html        - HTML template with placeholders
    web/app.js            - Application JavaScript
    luasafe/luac_wasm.js  - Emscripten-generated JS loader (Luac core)
    luasafe/luac_wasm.wasm- Emscripten-generated WASM binary (Luac core)
    web/pay_wasm.js       - Emscripten-generated JS loader (PAY core)
    web/pay_wasm.wasm     - Emscripten-generated WASM binary (PAY core)
    web/pay.js            - PAY client JS (fetch 网络层 + 赞赏 UI)

Placeholders in index.html:
    // __WASM_JS_INJECT__   -> replaced with emscripten JS content (Luac)
    // __APP_JS__           -> replaced with base64 wasm global + app JS content
    // __PAY_WASM_JS_INJECT__ -> replaced with emscripten JS content (PAY)
    // __PAY_APP_JS__       -> replaced with base64 pay wasm global + pay JS content
"""
import base64
import os
import sys
import argparse

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))



def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()


def read_binary(path):
    with open(path, 'rb') as f:
        return f.read()


def main():
    parser = argparse.ArgumentParser(description='Merge WASM tool into single HTML')
    parser.add_argument('--output', '-o', default=os.path.join(PROJECT_ROOT, 'luac_obf.html'),
                        help='Output HTML file path')
    args = parser.parse_args()

    html_path = os.path.join(PROJECT_ROOT, 'web', 'index.html')
    app_js_path = os.path.join(PROJECT_ROOT, 'web', 'app.js')
    wasm_js_path = os.path.join(PROJECT_ROOT, 'luasafe', 'luac_wasm.js')
    wasm_bin_path = os.path.join(PROJECT_ROOT, 'luasafe', 'luac_wasm.wasm')
    pay_wasm_js_path = os.path.join(PROJECT_ROOT, 'web', 'pay_wasm.js')
    pay_wasm_bin_path = os.path.join(PROJECT_ROOT, 'web', 'pay_wasm.wasm')
    pay_app_js_path = os.path.join(PROJECT_ROOT, 'web', 'pay.js')

    # Check inputs
    for p in [html_path, app_js_path, wasm_js_path, wasm_bin_path,
              pay_wasm_js_path, pay_wasm_bin_path, pay_app_js_path]:
        if not os.path.exists(p):
            print(f'ERROR: missing input file: {p}', file=sys.stderr)
            sys.exit(1)

    print(f'Reading HTML template: {html_path}')
    html = read_file(html_path)

    print(f'Reading app JS: {app_js_path} ({os.path.getsize(app_js_path)} bytes)')
    app_js = read_file(app_js_path)

    print(f'Reading emscripten JS: {wasm_js_path} ({os.path.getsize(wasm_js_path)} bytes)')
    wasm_js = read_file(wasm_js_path)

    print(f'Reading WASM binary: {wasm_bin_path} ({os.path.getsize(wasm_bin_path)} bytes)')
    wasm_bytes = read_binary(wasm_bin_path)
    wasm_b64 = base64.b64encode(wasm_bytes).decode('ascii')
    print(f'  base64 encoded: {len(wasm_b64)} bytes')

    print(f'Reading PAY emscripten JS: {pay_wasm_js_path} ({os.path.getsize(pay_wasm_js_path)} bytes)')
    pay_wasm_js = read_file(pay_wasm_js_path)

    print(f'Reading PAY WASM binary: {pay_wasm_bin_path} ({os.path.getsize(pay_wasm_bin_path)} bytes)')
    pay_wasm_b64 = base64.b64encode(read_binary(pay_wasm_bin_path)).decode('ascii')
    print(f'  base64 encoded: {len(pay_wasm_b64)} bytes')

    print(f'Reading PAY app JS: {pay_app_js_path} ({os.path.getsize(pay_app_js_path)} bytes)')
    pay_app_js = read_file(pay_app_js_path)

    # Inject emscripten JS
    if '// __WASM_JS_INJECT__' not in html:
        print('ERROR: placeholder // __WASM_JS_INJECT__ not found in HTML', file=sys.stderr)
        sys.exit(1)
    html = html.replace('// __WASM_JS_INJECT__', wasm_js)

    # Inject base64 wasm global + app JS
    wasm_global = f'window.__LUAC_WASM_BASE64__ = "{wasm_b64}";\n\n'
    app_injected = wasm_global + app_js
    if '// __APP_JS__' not in html:
        print('ERROR: placeholder // __APP_JS__ not found in HTML', file=sys.stderr)
        sys.exit(1)
    html = html.replace('// __APP_JS__', app_injected)

    # Inject PAY emscripten JS
    if '// __PAY_WASM_JS_INJECT__' not in html:
        print('ERROR: placeholder // __PAY_WASM_JS_INJECT__ not found in HTML', file=sys.stderr)
        sys.exit(1)
    html = html.replace('// __PAY_WASM_JS_INJECT__', pay_wasm_js)

    # Inject PAY base64 wasm global + pay app JS
    pay_wasm_global = f'window.__PAY_WASM_BASE64__ = "{pay_wasm_b64}";\n\n'
    pay_app_injected = pay_wasm_global + pay_app_js
    if '// __PAY_APP_JS__' not in html:
        print('ERROR: placeholder // __PAY_APP_JS__ not found in HTML', file=sys.stderr)
        sys.exit(1)
    html = html.replace('// __PAY_APP_JS__', pay_app_injected)

    # Write output
    out_dir = os.path.dirname(args.output)
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(html)

    out_size = os.path.getsize(args.output)
    print(f'\n=== Merge complete ===')
    print(f'Output: {args.output}')
    print(f'Size:   {out_size:,} bytes ({out_size/1024:.1f} KB)')
    print(f'  - Luac WASM (base64): {len(wasm_b64):,} bytes')
    print(f'  - Luac Emscripten JS: {len(wasm_js):,} bytes')
    print(f'  - App JS:        {len(app_js):,} bytes')
    print(f'  - PAY WASM (base64): {len(pay_wasm_b64):,} bytes')
    print(f'  - PAY Emscripten JS: {len(pay_wasm_js):,} bytes')
    print(f'  - PAY App JS:    {len(pay_app_js):,} bytes')
    print(f'  - HTML/CSS:      {len(html) - len(wasm_b64) - len(wasm_js) - len(app_js) - len(pay_wasm_b64) - len(pay_wasm_js) - len(pay_app_js):,} bytes')


if __name__ == '__main__':
    main()
