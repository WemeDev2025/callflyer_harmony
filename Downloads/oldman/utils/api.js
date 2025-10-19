// utils/api.js - API接口封装
const config = require('./config');
const API_BASE_URL = config.API.BASE_URL;

/**
 * 网络请求封装
 */
class ApiService {
  constructor() {
    this.baseURL = API_BASE_URL;
    this.timeout = 10000;
  }

  /**
   * 通用请求方法
   */
  request(options) {
    return new Promise((resolve, reject) => {
      // 检查是否使用模拟数据
      if (config.DEV.USE_MOCK_DATA && options.url.includes('/user/login')) {
        this.handleMockRequest(options, resolve, reject);
        return;
      }

      // 显示加载提示
      if (options.showLoading !== false) {
        wx.showLoading({
          title: options.loadingText || '加载中...',
          mask: true
        });
      }

      // 获取用户token
      const token = wx.getStorageSync('userToken');
      console.log('🔑 当前token状态:', token ? '已获取' : '未获取');
      console.log('🔑 token值:', token ? token.substring(0, 20) + '...' : 'null');
      
      // 构建请求头
      const header = {
        'Content-Type': 'application/json',
        ...options.header
      };
      
      if (token) {
        header['Authorization'] = `Bearer ${token}`;
        console.log('🔑 已添加Authorization头');
      } else {
        console.log('⚠️ 未找到token，请求可能失败');
      }

      // 构建请求参数
      const requestData = options.data !== undefined ? options.data : {};
      
      // 添加详细的请求日志
      console.log('🌐 API请求详情:', {
        url: `${this.baseURL}${options.url}`,
        method: options.method || 'GET',
        data: requestData,
        header: header,
        timeout: this.timeout
      });

      wx.request({
        url: `${this.baseURL}${options.url}`,
        method: options.method || 'GET',
        data: requestData,
        header: header,
        timeout: this.timeout,
        success: (res) => {
          wx.hideLoading();
          
          // 添加详细的成功响应日志
          console.log('✅ API请求成功:', {
            statusCode: res.statusCode,
            data: res.data,
            header: res.header
          });
          
          if (res.statusCode === 200) {
            // 后端已统一格式，直接处理标准响应
            if (res.data.success) {
              console.log('✅ API响应数据有效:', res.data);
              resolve(res.data);
            } else {
              console.log('❌ API响应数据无效:', res.data);
              this.handleError(res.data.message || '请求失败', reject);
            }
          } else {
            console.log('❌ HTTP状态码错误:', res.statusCode);
            console.log('❌ 错误响应数据:', res.data);
            
            // 对于422错误，显示详细的验证错误信息
            if (res.statusCode === 422 && res.data) {
              let errorMessage = '数据验证失败';
              if (res.data.detail) {
                errorMessage = res.data.detail;
              } else if (res.data.message) {
                errorMessage = res.data.message;
              } else if (typeof res.data === 'string') {
                errorMessage = res.data;
              }
              this.handleError(errorMessage, reject);
            } else {
              this.handleError(`请求失败 (${res.statusCode})`, reject);
            }
          }
        },
        fail: (err) => {
          wx.hideLoading();
          
          // 添加详细的失败日志
          console.log('❌ API请求失败详情:', {
            errMsg: err.errMsg,
            statusCode: err.statusCode,
            data: err.data,
            header: err.header
          });
          
          // 检查是否是SSL错误
          if (err.errMsg && err.errMsg.includes('SSL') || err.errMsg.includes('TLS') || err.errMsg.includes('cipher')) {
            console.log('🔒 检测到SSL/TLS错误，尝试降级处理...');
            this.handleSSLError(err, reject);
            return;
          }
          
          this.handleError('网络请求失败', reject, err);
        }
      });
    });
  }

  /**
   * 处理模拟请求
   */
  handleMockRequest(options, resolve, reject) {
    console.log('使用模拟API响应:', options.url);
    
    setTimeout(() => {
      if (options.url === '/user/login' && options.data.type === 'wechat') {
        // 模拟微信登录成功
        resolve({
          code: 0,
          success: true,
          data: {
            user: {
              id: 'mock_user_' + Date.now(),
              openid: 'mock_openid_' + options.data.code,
              nickname: '微信用户',
              avatar: '',
              phone: '',
              gender: 0,
              city: '',
              province: '',
              country: '中国',
              createdAt: new Date().toISOString()
            },
            token: 'mock_token_' + Date.now()
          },
          message: '登录成功'
        });
      } else {
        // 其他请求返回失败
        reject(new Error('模拟API不支持此请求'));
      }
    }, config.DEV.MOCK_API_DELAY);
  }

  /**
   * SSL错误处理
   */
  handleSSLError(err, reject) {
    console.log('🔒 SSL错误详情:', err);
    
    // 显示SSL错误提示
    wx.showModal({
      title: 'SSL证书问题',
      content: '检测到SSL证书问题，请联系后端开发人员检查HTTPS配置。\n\n错误详情: ' + err.errMsg,
      showCancel: false,
      confirmText: '确定'
    });
    
    reject(new Error('SSL证书配置问题: ' + err.errMsg));
  }

  /**
   * 错误处理
   */
  handleError(message, reject, error = null) {
    console.error('API请求错误:', message, error);
    
    wx.showToast({
      title: message,
      icon: 'none',
      duration: 2000
    });
    
    reject(error || new Error(message));
  }

  /**
   * GET请求
   */
  get(url, data = {}, options = {}) {
    return this.request({
      url,
      method: 'GET',
      data,
      ...options
    });
  }

  /**
   * POST请求
   */
  post(url, data = {}, options = {}) {
    return this.request({
      url,
      method: 'POST',
      data: data === null ? undefined : data,
      ...options
    });
  }

  /**
   * PUT请求
   */
  put(url, data = {}, options = {}) {
    return this.request({
      url,
      method: 'PUT',
      data,
      ...options
    });
  }

  /**
   * DELETE请求
   */
  delete(url, data = {}, options = {}) {
    return this.request({
      url,
      method: 'DELETE',
      data,
      ...options
    });
  }
}

// 创建API服务实例
const apiService = new ApiService();

/**
 * 工作卡相关API
 */
const workCardAPI = {
  // 创建/更新工作卡
  saveWorkCard(data) {
    return apiService.post('/work-card', data, {
      showLoading: false
    });
  },

  // 获取工作卡详情
  getWorkCard(id) {
    return apiService.get(`/work-card/${id}`);
  },

  // 获取我的工作卡
  getMyWorkCard() {
    return apiService.get('/work-card/my');
  },

  // 发布工作卡
  publishWorkCard(id) {
    return apiService.post(`/work-card/${id}/publish`, null, {
      showLoading: false
    });
  },

  // 获取已发布的工作卡列表
  getPublishedWorkCards(params = {}) {
    return apiService.get('/work-card/published', params);
  },

  // 删除工作卡
  deleteWorkCard(id) {
    return apiService.delete(`/work-card/${id}`, {}, {
      showLoading: false
    });
  }
};

/**
 * 养老需求相关API
 */
const hireAPI = {
  // 创建/更新养老需求
  saveHireRequirement(data) {
    return apiService.post('/hire-requirement', data, {
      showLoading: false
    });
  },

  // 获取需求详情
  getHireRequirement(id) {
    return apiService.get(`/hire-requirement/${id}`);
  },

  // 获取我的需求
  getMyHireRequirement() {
    return apiService.get('/hire-requirement/my');
  },

  // 发布需求
  publishHireRequirement(id) {
    return apiService.post(`/hire-requirement/${id}/publish`, {}, {
      showLoading: false
    });
  },

  // 获取已发布的需求列表
  getPublishedHireRequirements(params = {}) {
    return apiService.get('/api/employers', params);
  },

  // 删除需求
  deleteHireRequirement(id) {
    return apiService.delete(`/hire-requirement/${id}`, {}, {
      showLoading: false
    });
  }
};

/**
 * 用户相关API
 */
const userAPI = {
  // 用户登录（支持微信静默登录）
  login(data) {
    return apiService.post('/user/login', data, {
      showLoading: false // 静默登录不显示加载提示
    });
  },

  // 微信静默登录（使用GET请求，code作为查询参数）
  wechatLogin(code) {
    return apiService.get(`/api/auth/wechat-login?code=${code}`, {}, {
      showLoading: false // 静默登录不显示加载提示
    });
  },

  // 用户注册
  register(data) {
    return apiService.post('/user/register', data, {
      showLoading: false
    });
  },

  // 获取用户信息
  getUserInfo() {
    return apiService.get('/user/info');
  },

  // 更新用户信息
  updateUserInfo(data) {
    return apiService.put('/user/info', data, {
      showLoading: false
    });
  },

  // 上传头像
  uploadAvatar(filePath) {
    return new Promise((resolve, reject) => {
      wx.uploadFile({
        url: `${API_BASE_URL}/user/avatar`,
        filePath: filePath,
        name: 'avatar',
        header: {
          'Authorization': `Bearer ${wx.getStorageSync('userToken')}`
        },
        success: (res) => {
          const data = JSON.parse(res.data);
          if (data.code === 0) {
            resolve(data);
          } else {
            reject(new Error(data.message));
          }
        },
        fail: reject
      });
    });
  }
};

/**
 * 文件上传API
 */
const uploadAPI = {
  // 上传图片
  uploadImage(filePath, type = 'general') {
    return new Promise((resolve, reject) => {
      wx.uploadFile({
        url: `${API_BASE_URL}/api/upload/image`,
        filePath: filePath,
        name: 'file',
        formData: {
          type: type
        },
        header: {
          'Authorization': `Bearer ${wx.getStorageSync('userToken')}`
        },
        success: (res) => {
          console.log('📤 上传响应:', res);
          const data = JSON.parse(res.data);
          console.log('📤 解析后的数据:', data);
          
          // 检查上传成功标志（有filename和url表示成功）
          if (data.filename && data.url) {
            console.log('✅ 上传成功:', data);
            resolve(data);
          } else {
            console.log('❌ 上传失败:', data);
            reject(new Error(data.message || '上传失败'));
          }
        },
        fail: (error) => {
          console.log('❌ 上传请求失败:', error);
          reject(error);
        }
      });
    });
  }
};

// 匹配数据API
const matchAPI = {
  // 获取匹配数据
  getMatches() {
    return apiService.get('/api/matches');
  }
};

module.exports = {
  apiService,
  workCardAPI,
  hireAPI,
  userAPI,
  uploadAPI,
  matchAPI
};
