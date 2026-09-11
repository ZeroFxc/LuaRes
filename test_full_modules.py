import seed_browser_use as bu
import base64, time

# Read test file
with open(r'E:\LuaRes\testLuaClosure__.lua', 'r', encoding='utf-8') as f:
    content = f.read()
b64 = base64.b64encode(content.encode('utf-8')).decode('ascii')

bu.navigate("file:///E:/LuaRes/luac_obf.html?v=fix4_full3")
time.sleep(10)

# Upload file via DataTransfer
bu.js(f"""
(() => {{
    const b64 = "{b64}";
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    const file = new File([bytes], 'testLuaClosure__.lua', {{type: 'text/plain'}});
    const dt = new DataTransfer();
    dt.items.add(file);
    const input = document.getElementById('fileInput');
    input.files = dt.files;
    input.dispatchEvent(new Event('change', {{bubbles: true}}));
}})()
""")
time.sleep(3)

# Select all modules
bu.js("document.querySelectorAll('input[type=checkbox]').forEach(c => c.checked = true)")
time.sleep(1)

# Click process and run
bu.js("document.getElementById('btnProcessRun').click()")
time.sleep(45)

out = bu.js("return document.getElementById('runOutputText').textContent || ''")
print("=== Full test script with ALL modules ===")
print(out[:1000])
