# 养老小程序 API 对接指南

## 📋 项目概述

本项目已完成与后端API的完整对接，实现了微信静默登录、数据同步、文件上传等功能。

## 🔧 技术架构

### 核心文件结构
```
utils/
├── api.js              # API接口封装
├── dataAdapter.js      # 数据适配器
├── dataManager.js      # 数据管理服务
└── config.js          # 配置文件
```

### 主要功能模块
- **用户管理**: 微信静默登录、用户信息管理
- **工作卡管理**: 创建、编辑、发布工作卡
- **养老需求管理**: 发布、管理养老需求
- **文件上传**: 头像、证件图片上传
- **数据同步**: 本地存储与API数据同步

## 🚀 核心功能实现

### 1. 微信静默登录

**实现位置**: `app.js`
```javascript
// 应用启动时自动执行静默登录
async silentLogin() {
  const loginRes = await wx.login();
  const result = await dataManager.user.login({
    code: loginRes.code,
    type: 'wechat'
  });
  // 保存用户信息和token
}
```

**特点**:
- ✅ 无需用户操作，自动登录
- ✅ 应用启动时自动执行
- ✅ 失败不影响正常使用
- ✅ 支持token验证和刷新

### 2. API接口封装

**实现位置**: `utils/api.js`
```javascript
// 统一的网络请求封装
class ApiService {
  request(options) {
    // 自动添加token
    // 统一错误处理
    // 加载状态管理
  }
}
```

**特点**:
- ✅ 自动添加Authorization头
- ✅ 统一错误处理和提示
- ✅ 支持加载状态管理
- ✅ 请求超时控制

### 3. 数据管理服务

**实现位置**: `utils/dataManager.js`
```javascript
// 统一的数据管理
const dataManager = {
  workCard: {
    save: async (data) => { /* 保存工作卡 */ },
    getMy: async () => { /* 获取我的工作卡 */ },
    publish: async (id) => { /* 发布工作卡 */ }
  },
  hireRequirement: {
    save: async (data) => { /* 保存养老需求 */ },
    getMy: async () => { /* 获取我的需求 */ },
    publish: async (id) => { /* 发布需求 */ }
  }
};
```

**特点**:
- ✅ 统一的数据操作接口
- ✅ 自动数据格式转换
- ✅ 本地缓存机制
- ✅ 网络失败降级处理

### 4. 文件上传功能

**实现位置**: `utils/api.js` + `utils/dataManager.js`
```javascript
// 头像上传
const uploadResult = await dataManager.upload.avatar(filePath);
// 证件上传
const uploadResult = await dataManager.upload.certificate(filePath, type);
```

**特点**:
- ✅ 支持头像和证件上传
- ✅ 自动文件类型验证
- ✅ 上传进度提示
- ✅ 失败降级处理

## 📊 数据流设计

### 数据流向图
```
用户操作 → 页面组件 → dataManager → API接口 → 后端服务
    ↓           ↓           ↓          ↓
本地存储 ← 数据适配器 ← 响应处理 ← 网络请求
```

### 数据同步策略
1. **优先使用API**: 网络正常时使用API数据
2. **本地降级**: 网络失败时使用本地存储
3. **自动同步**: 数据变更时自动同步到服务器
4. **缓存机制**: 合理使用内存缓存提升性能

## 🔄 页面集成

### 工作卡页面 (`pages/work-card/work-card.js`)
- ✅ 集成API数据加载
- ✅ 支持编辑和新建模式
- ✅ 文件上传功能
- ✅ 数据验证和错误处理

### 养老需求页面 (`pages/hire/hire.js`)
- ✅ 集成API数据管理
- ✅ 支持需求发布
- ✅ 数据持久化

### 预览页面 (`pages/preview/preview.js`)
- ✅ 集成API数据展示
- ✅ 支持发布功能
- ✅ 数据刷新机制

## 🛠️ 配置说明

### API配置 (`utils/config.js`)
```javascript
module.exports = {
  API: {
    BASE_URL: 'https://wemedev.com/api',
    TIMEOUT: 10000
  },
  UPLOAD: {
    MAX_SIZE: 5 * 1024 * 1024, // 5MB
    ALLOWED_TYPES: ['image/jpeg', 'image/png', 'image/jpg']
  }
};
```

### 小程序配置
需要在微信小程序后台配置以下域名：
- **request合法域名**: `https://wemedev.com`
- **uploadFile合法域名**: `https://wemedev.com`

## 📱 用户体验优化

### 加载状态管理
- ✅ 统一的加载提示
- ✅ 防止重复提交
- ✅ 网络状态检测

### 错误处理
- ✅ 友好的错误提示
- ✅ 网络失败降级
- ✅ 数据验证提示

### 性能优化
- ✅ 内存缓存机制
- ✅ 按需数据加载
- ✅ 图片压缩上传

## 🔍 调试和测试

### 调试工具
- 控制台日志输出
- 网络请求监控
- 数据状态检查

### 测试场景
1. **网络正常**: 验证API调用和数据同步
2. **网络异常**: 验证降级处理和本地存储
3. **登录状态**: 验证静默登录和token管理
4. **文件上传**: 验证图片上传和错误处理

## 📈 后续扩展

### 可扩展功能
- 用户权限管理
- 数据统计分析
- 消息推送
- 离线数据同步

### 性能优化
- 图片懒加载
- 数据分页加载
- 缓存策略优化

## 🎯 总结

本次API对接实现了：
- ✅ 完整的微信静默登录
- ✅ 统一的数据管理架构
- ✅ 可靠的文件上传功能
- ✅ 优雅的错误处理机制
- ✅ 良好的用户体验

项目已具备完整的后端集成能力，可以支持生产环境使用。
