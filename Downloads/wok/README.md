# WOK 微信小程序

微信小程序前端项目，实现微信静默登录、用户资料管理等功能。

## 功能特性

1. **微信静默登录**
   - 应用启动时自动执行微信登录
   - 获取 openId 并保存 session token
   - 自动验证 token 有效性

2. **个人资料管理**
   - 查看和编辑昵称
   - 上传和更换头像
   - 实时保存用户信息

## 项目结构

```
wok/
├── app.js                 # 应用入口，实现静默登录
├── app.json              # 应用配置
├── app.wxss              # 全局样式
├── project.config.json   # 项目配置
├── sitemap.json          # 站点地图配置
├── pages/
│   ├── index/            # 首页
│   │   ├── index.wxml
│   │   ├── index.js
│   │   └── index.wxss
│   └── profile/          # 个人资料页
│       ├── profile.wxml
│       ├── profile.js
│       └── profile.wxss
└── utils/
    ├── api.js            # API 请求封装
    └── storage.js        # 本地存储工具
```

## 配置说明

### 1. 修改 AppID

在 `project.config.json` 中修改 `appid` 为你的小程序 AppID：

```json
{
  "appid": "wx0a40fe4355dc9548"
}
```

**当前配置的 AppID：`wx0a40fe4355dc9548`**

### 2. 配置 API 地址

在 `utils/api.js` 中修改 `BASE_URL` 为你的后端 API 地址：

```javascript
const BASE_URL = 'https://wemedev.com/wok/api'
```

### 3. 后端配置 AppSecret

**重要**：AppSecret 是敏感信息，必须配置在后端，**不要**放在前端代码中。

后端需要在环境变量或配置文件中配置：
- **AppID**: `wx0a40fe4355dc9548`
- **AppSecret**: `94a2a4bcd96f3a0207822d1a6b2a6dc9`

后端使用 AppSecret 调用微信接口 `code2Session` 来获取 openid 和 session_key。

## API 接口

### 认证接口

- `POST /api/auth/wxlogin` - 微信登录，通过 code 获取 token

### 用户资料接口

- `GET /api/profile` - 获取用户资料
- `PUT /api/profile` - 更新用户资料（昵称）
- `POST /api/profile/avatar` - 上传头像

## 使用说明

### 1. 静默登录流程

应用启动时（`app.js` 的 `onLaunch`），会自动执行以下流程：

1. 检查本地是否有有效的 token
2. 如果有 token，验证其有效性（通过获取用户资料接口）
3. 如果 token 无效或不存在，调用 `wx.login()` 获取 code
4. 将 code 发送到后端获取 session token
5. 保存 token 并获取用户资料

### 2. 个人资料页面

- 点击头像可以更换头像（支持相册和拍照）
- 输入框可以编辑昵称
- 点击"保存"按钮保存资料

### 3. 首页

- 显示用户头像和昵称
- 提供入口跳转到个人资料页面

## 开发注意事项

1. **模块导入**：项目使用 ES6 模块语法（`import/export`），需要确保微信开发者工具的基础库版本 >= 2.2.1

2. **Token 管理**：Token 存储在本地存储中，应用启动时会自动验证有效性

3. **错误处理**：所有 API 请求都包含错误处理，401 状态码会自动清除 token

4. **头像上传**：使用 `wx.chooseMedia` 选择图片，然后通过 `wx.uploadFile` 上传

## 开发调试

1. 使用微信开发者工具打开项目
2. 配置 AppID（测试可以使用测试号）
3. 确保后端 API 已启动并可访问
4. 在开发者工具中预览和调试

## 依赖说明

本项目为纯微信小程序项目，无需安装 npm 包，直接使用微信小程序原生 API。

