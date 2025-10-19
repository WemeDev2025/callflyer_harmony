// force-reload-test.js - 强制重新加载测试
console.log('🔄 强制重新加载响应适配器...');

// 重新加载模块
delete require.cache[require.resolve('./utils/dataAdapter')];
const { ResponseAdapter } = require('./utils/dataAdapter');

// 测试用户信息模拟数据格式
const mockUserInfoResponse = {
  "id": "mock_user_123",
  "openid": "mock_openid_123",
  "nickname": "微信用户",
  "avatar": "",
  "phone": "",
  "user_type": "user"
};

console.log('📥 测试用户信息模拟数据:', mockUserInfoResponse);

const result = ResponseAdapter.handleResponse(mockUserInfoResponse);

console.log('🔄 响应适配器处理结果:', result);

if (result.success) {
  console.log('✅ 用户信息模拟数据格式处理成功!');
  console.log('👤 用户数据:', result.data);
} else {
  console.log('❌ 用户信息模拟数据格式处理失败:', result.message);
}

// 测试其他格式
console.log('\n🧪 测试其他响应格式...');

// 测试标准格式
const standardResponse = {
  "code": 0,
  "success": true,
  "data": {
    "id": "68f3271fb45f2bab41c392b5",
    "nickname": "微信用户"
  }
};

const standardResult = ResponseAdapter.handleResponse(standardResponse);
console.log('📊 标准格式处理结果:', standardResult);

module.exports = {
  result,
  standardResult,
  message: '强制重新加载测试完成'
};
