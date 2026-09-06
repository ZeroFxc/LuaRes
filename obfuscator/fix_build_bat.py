with open(r'E:\LuaRes\build.bat', 'r', encoding='utf-8') as f:
    content = f.read()

# 移除 ROOT_PATH 定义行
content = content.replace('echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk\n', '')
content = content.replace('echo ROOT_PATH := $(LOCAL_PATH) >> Android.mk\r\n', '')

# 把 $(ROOT_PATH) 替换为 E:/LuaRes
content = content.replace('$(ROOT_PATH)', 'E:/LuaRes')

with open(r'E:\LuaRes\build.bat', 'w', encoding='utf-8') as f:
    f.write(content)
print('OK')
