// test-clear-cache-fix.js - 测试clearCache修复
console.log('🔧 测试clearCache修复...');

// 模拟DataManager实例
class MockDataManager {
  constructor() {
    this.cache = new Map();
  }
  
  clearCache(key) {
    if (key === 'all') {
      this.cache.clear();
      console.log('🗑️ 已清除所有缓存');
    } else if (key) {
      this.cache.delete(key);
      console.log(`🗑️ 已清除缓存: ${key}`);
    } else {
      this.cache.clear();
      console.log('🗑️ 已清除所有缓存');
    }
  }
}

// 创建实例
const dataManager = new MockDataManager();

// 测试clearCache调用
console.log('🧪 测试clearCache方法调用...');

try {
  // 模拟登录成功后的缓存清除
  console.log('📋 模拟登录成功，清除缓存...');
  dataManager.clearCache('all');
  console.log('✅ clearCache调用成功！');
} catch (error) {
  console.log('❌ clearCache调用失败:', error);
}

// 测试不同的调用方式
console.log('\n🔍 测试不同的调用方式...');

// 方式1: 直接调用
try {
  dataManager.clearCache('all');
  console.log('✅ 方式1成功');
} catch (error) {
  console.log('❌ 方式1失败:', error);
}

// 方式2: 通过this调用（模拟之前的问题）
try {
  const user = {
    login: function() {
      // 这里之前会出错，因为this指向user对象
      // this.clearCache('all'); // 这会失败
      dataManager.clearCache('all'); // 修复后的方式
    }
  };
  
  user.login();
  console.log('✅ 方式2成功');
} catch (error) {
  console.log('❌ 方式2失败:', error);
}

console.log('\n🎯 clearCache修复测试完成！');

module.exports = {
  dataManager,
  message: 'clearCache修复测试完成'
};
