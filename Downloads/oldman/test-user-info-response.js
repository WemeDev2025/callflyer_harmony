// test-user-info-response.js - 测试用户信息接口响应
console.log('👤 测试用户信息接口响应处理...');

const ResponseAdapter = require('./utils/dataAdapter').ResponseAdapter;

// 测试不同的用户信息响应格式
const testCases = [
  {
    name: '模拟数据格式（热更新问题）',
    response: {
      "id": "mock_user_123",
      "openid": "mock_openid_123",
      "nickname": "微信用户",
      "avatar": "",
      "phone": "",
      "user_type": "user"
    }
  },
  {
    name: '标准API格式',
    response: {
      "code": 0,
      "success": true,
      "data": {
        "id": "68f3271fb45f2bab41c392b5",
        "openid": "test_openid_123",
        "nickname": "微信用户",
        "avatar": "",
        "user_type": "user"
      },
      "message": "获取用户信息成功"
    }
  },
  {
    name: '嵌套格式',
    response: {
      "success": true,
      "data": {
        "id": "68f3271fb45f2bab41c392b5",
        "openid": "test_openid_123",
        "nickname": "微信用户",
        "avatar": "",
        "user_type": "user"
      },
      "message": "获取用户信息成功"
    }
  }
];

// 测试所有格式
testCases.forEach((testCase, index) => {
  console.log(`\n📋 测试用例 ${index + 1}: ${testCase.name}`);
  console.log('📥 输入响应:', testCase.response);
  
  const result = ResponseAdapter.handleResponse(testCase.response);
  
  console.log('🔄 处理结果:', result);
  
  if (result.success) {
    console.log('✅ 处理成功!');
    console.log('👤 用户信息:', result.data);
  } else {
    console.log('❌ 处理失败:', result.message);
  }
});

console.log('\n🎯 用户信息接口响应处理测试完成！');

module.exports = {
  testCases,
  message: '用户信息接口响应处理测试完成'
};
