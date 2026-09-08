const fs = require('fs');
let lines = [];
for (let i = 0; i < 100; i++) {
    lines.push(`print("这是第${i}个中文测试字符串用于验证体积优化效果")`);
}
fs.writeFileSync('_test_100cn.lua', lines.join('\n'));
console.log('created _test_100cn.lua with', lines.length, 'lines');
