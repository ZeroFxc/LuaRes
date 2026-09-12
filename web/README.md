# PAY 支付对接（网络 JS + 核心 wasm + 赞赏）

本目录是 Luac 混淆工具的 web 端。在原有「Luac wasm 混淆器」基础上，对接了
`E:\LuaRes\pay-sdk-c`（PAY 支付中转系统 C SDK），并新增「赞赏」功能。

## 架构

```
浏览器页面 (index.html / luac_obf.html)
   │
   ├─ 赞赏 UI（pay.js 内，点击头部"赞赏"按钮）
   │
   ├─ 网络层：pay.js 用浏览器 fetch 收发请求（SDK 的 http.c 不参与 wasm）
   │
   └─ 核心处理：web/pay_wasm.wasm（由 pay-sdk-c 编译）
        ├─ payw_build_request  请求体组装 + 鉴权头（pk_ token）+ 可选 HMAC 签名
        └─ payw_parse_response 响应 AES-256-CBC 解密 + 验签 + JSON 结构化解析
```

- **网络在 JS**：`pay.js` 中的 `httpSend()` 用 `fetch` 完成，与 pay-sdk-c 的
  `http.c`（WinHTTP/libcurl）解耦。
- **核心在 wasm**：签名、解密、验签、解析全部复用 pay-sdk-c 原生 C 代码
  （`pay_wasm.c` 通过 `#include "pay.c"` 复用内部实现，原生构建不受影响）。

## 鉴权与自动配置（重要）

**鉴权走 token（`X-API-Key`，用 `pk_` 公钥）**，不手动硬编码签名头。

**密钥全部编译在 wasm 内**（`pay-sdk-c/src/pay_wasm.c` 顶部 `PAYW_CFG_*` 常量）：
adminToken / apiKey（pk_）/ secretKey（sk_）/ 签名密钥 / 响应安全密钥，
JS 与 HTML 中不出现任何明文密钥。JS 通过 `payw_get_admin_token()` 等接口读取。

页面初始化流程：

1. 加载 wasm（密钥内置），`payw_init` 传空串即用内置配置
2. `payw_get_admin_token()` 取管理员令牌 → 调 `GET /api/admin/users?token=...`
   定位商户用户（按 apiKey 匹配）
3. `GET /api/admin/generate-config?token=...&userId=...` 获取服务端配置
4. 自动决定签名：`payw_set_signing(0/1)`（当前 `pk_` + `requirePkSignature=false`
   → 不签名，token 鉴权足够，浏览器直连实测成功）

**签名是否携带由服务端配置自动决定**：
- `signatureConfig.enabled=false` → 不签名
- 使用 `pk_` 且 `requirePkSignature=false` → 不签名
- `sk_` 请求或后台强制要求签名 → 自动开启签名（`payw_set_signing(1)`），
  携带 `X-API-Sign` / `X-API-Timestamp`（HMAC-SHA256(body+timestamp, 内置签名密钥)）

> 为什么用 `pk_` 不用 `sk_`：服务端对 `sk_` 请求强制要求签名，而浏览器带
> 自定义签名头会触发 CORS 预检（服务端 `Access-Control-Allow-Headers` 未放行
> `X-API-Sign/X-API-Timestamp`）。`pk_` 请求在 `requirePkSignature=false`
> 时不需要签名，`X-API-Key` 本身在 CORS 白名单内，浏览器可直连。
> `sk_` 请仅在服务端/有签名的环境使用。

响应安全（`apiSecurity.enabled=true` 时）：
- 响应体为 `{"iv":"...","data":"..."}`（AES-256-CBC，密钥 = SHA256(secKey)）
- 响应头携带签名（`X-API-Sign` 等），wasm 自动解密 + 验签

## 赞赏弹窗

创建订单成功后：显示订单号 + 「跳转支付」按钮（点击新窗口打开付款页），
**不显示支付链接文本**；页面自动轮询订单状态，支付完成自动提示。

## 文件

| 文件 | 说明 |
|------|------|
| `web/index.html` | 页面模板（赞赏按钮 + 弹窗 + 注入占位符） |
| `web/pay.js` | PAY 客户端（自动配置 + fetch 网络层 + 赞赏 UI） |
| `web/pay_wasm.js` / `.wasm` | 支付核心 wasm（由 build_pay_wasm.bat 生成） |
| `web/test_pay_wasm_token.js` | token 自动配置 + 直连建单全链路测试（node） |
| `pay-sdk-c/src/pay_wasm.c` | wasm 桥接层源码（复用 pay.c） |
| `build_pay_wasm.bat` | 编译支付 wasm 的脚本 |
| `merge_web.py` | 把模板 + 两个 wasm + JS 合并成单文件 HTML |

## 构建 / 重新生成

```bat
rem 1. 编译支付核心 wasm（需要 Emscripten）
build_pay_wasm.bat

rem 2. 合并成单文件 HTML（同时产出 luac_obf.html 和 index.html）
python merge_web.py
python merge_web.py -o index.html
```

## 商户配置

编辑 `web/pay.js` 顶部 `PAY_CONFIG`：

```js
const PAY_CONFIG = {
  baseUrl:        'https://pay.xn--kiv483g.online',
  adminToken:     '...',  // 管理员令牌（自动获取商户配置用）
  merchantApiKey: 'pk_...', // 用于在用户列表中定位商户
};
```

其余（apiKey / secretKey / 签名密钥 / 响应安全密钥）均由
`/api/admin/generate-config` 自动获取填好，无需手动配置。

注意：纯前端接入会把商户及管理员信息暴露给访问者，仅适合个人赞赏/自用场景；
生产环境建议服务端代理接入。

## 测试

```bat
cd web
node test_pay_wasm_token.js   rem token 自动配置 + 直连建单 + 解密（25 项）
node test_pay_wasm.js         rem wasm 签名能力冒烟（27 项，签名路径）
```

## 公开 API（window.PayJS）

与 pay-sdk-c 的 C API 一一对应：

| PayJS | 对应 C API | 说明 |
|-------|-----------|------|
| `createOrder(amount, product)` | `pay_create_order` | 创建支付订单 |
| `queryOrder(orderId)` | `pay_query_order` | 查询订单状态 |
| `pollOrder(orderId, iv, max, cb)` | `pay_poll_order` | 轮询直到完成/过期/超时 |
| `registerUser(u, p)` | `pay_register_user` | 注册用户 |
| `loginUser(u, p)` | `pay_login_user` | 用户登录 |
| `getUserInfo(token)` | `pay_get_user_info` | 用户信息 |
| `shopRecharge(token, amount)` | `pay_shop_recharge` | 商城充值 |
