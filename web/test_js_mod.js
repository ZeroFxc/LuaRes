// 测试 JS 模块：调用内置布尔混淆 + 数字混淆，然后记录日志
module.exports = {
    name: "test_js_pipeline",
    label: "测试-JS流水线",
    description: "JS模块测试：调用内置 bool+num 混淆",
    apply: function(api) {
        api.call('wasm_apply', 'number',
            ['number', 'string'], [api.handle, 'bool_obfuscate_c']);
        api.log('bool_obfuscate_c done');
        api.call('wasm_apply', 'number',
            ['number', 'string'], [api.handle, 'num_obfuscate_c']);
        api.log('num_obfuscate_c done');
        return true;
    }
};
