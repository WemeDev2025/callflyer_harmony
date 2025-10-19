// utils/dataManager.js - 数据管理服务
const { workCardAPI, hireAPI, userAPI, uploadAPI } = require('./api');
const { WorkCardAdapter, HireRequirementAdapter, UserAdapter, ResponseAdapter } = require('./dataAdapter');

/**
 * 数据管理服务
 */
class DataManager {
  constructor() {
    this.cache = new Map(); // 内存缓存
    this.cacheTimeout = 5 * 60 * 1000; // 5分钟缓存过期
  }

  /**
   * 设置缓存
   */
  setCache(key, data) {
    this.cache.set(key, {
      data: data,
      timestamp: Date.now()
    });
  }

  /**
   * 获取缓存
   */
  getCache(key) {
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.data;
    }
    this.cache.delete(key);
    return null;
  }

  /**
   * 清除缓存
   */
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

  /**
   * 工作卡数据管理
   */
  workCard = {
    // 保存工作卡
    async save(data) {
      try {
        const apiData = WorkCardAdapter.toAPI(data);
        const response = await workCardAPI.saveWorkCard(apiData);
        const result = ResponseAdapter.handleResponse(response);
        
        if (result.success) {
          // 清除相关缓存
          dataManager.clearCache('myWorkCard');
          dataManager.clearCache('publishedWorkCards');
          
          // 同时保存到本地存储作为备份
          const localData = WorkCardAdapter.toLocal(result.data);
          wx.setStorageSync('workCardData', localData);
        }
        
        return result;
      } catch (error) {
        console.error('保存工作卡失败:', error);
        return {
          success: false,
          data: null,
          message: '保存失败，请检查网络连接'
        };
      }
    },

    // 获取我的工作卡
    async getMy() {
      try {
        // 先检查缓存
        const cached = dataManager.getCache('myWorkCard');
        if (cached) {
          return { success: true, data: cached };
        }

        const response = await workCardAPI.getMyWorkCard();
        console.log('🔍 dataManager获取工作卡原始响应:', response);
        
        // 直接使用API返回的数据，不进行适配器转换
        if (response.success) {
          console.log('✅ 工作卡数据直接返回:', response.data);
          dataManager.setCache('myWorkCard', response.data);
          return { success: true, data: response.data };
        }
        
        return result;
      } catch (error) {
        console.error('获取工作卡失败:', error);
        // 网络失败时尝试从本地存储获取
        const localData = wx.getStorageSync('workCardData');
        if (localData) {
          return { success: true, data: localData, fromCache: true };
        }
        return {
          success: false,
          data: null,
          message: '获取失败，请检查网络连接'
        };
      }
    },

    // 发布工作卡
    async publish(id) {
      try {
        const response = await workCardAPI.publishWorkCard(id);
        const result = ResponseAdapter.handleResponse(response);
        
        if (result.success) {
          // 清除缓存
          dataManager.clearCache('myWorkCard');
          dataManager.clearCache('publishedWorkCards');
          
          // 更新本地存储
          const localData = wx.getStorageSync('workCardData');
          if (localData) {
            localData.status = 'published';
            wx.setStorageSync('workCardData', localData);
          }
        }
        
        return result;
      } catch (error) {
        console.error('发布工作卡失败:', error);
        return {
          success: false,
          data: null,
          message: '发布失败，请检查网络连接'
        };
      }
    },

    // 获取已发布的工作卡列表
    async getPublished(params = {}) {
      try {
        const cacheKey = `publishedWorkCards_${JSON.stringify(params)}`;
        const cached = dataManager.getCache(cacheKey);
        if (cached) {
          return { success: true, data: cached };
        }

        const response = await workCardAPI.getPublishedWorkCards(params);
        const result = ResponseAdapter.handlePageResponse(response);
        
        if (result.success) {
          dataManager.setCache(cacheKey, result.data);
        }
        
        return result;
      } catch (error) {
        console.error('获取已发布工作卡失败:', error);
        return {
          success: false,
          data: [],
          message: '获取失败，请检查网络连接'
        };
      }
    }
  };

  /**
   * 养老需求数据管理
   */
  hireRequirement = {
    // 保存养老需求
    async save(data) {
      try {
        const apiData = HireRequirementAdapter.toAPI(data);
        const response = await hireAPI.saveHireRequirement(apiData);
        const result = ResponseAdapter.handleResponse(response);
        
        if (result.success) {
          // 清除相关缓存
          dataManager.clearCache('myHireRequirement');
          dataManager.clearCache('publishedHireRequirements');
          
          // 同时保存到本地存储作为备份
          const localData = HireRequirementAdapter.toLocal(result.data);
          wx.setStorageSync('hireData', localData);
        }
        
        return result;
      } catch (error) {
        console.error('保存养老需求失败:', error);
        return {
          success: false,
          data: null,
          message: '保存失败，请检查网络连接'
        };
      }
    },

    // 获取我的养老需求
    async getMy() {
      try {
        // 先检查缓存
        const cached = dataManager.getCache('myHireRequirement');
        if (cached) {
          return { success: true, data: cached };
        }

        const response = await hireAPI.getMyHireRequirement();
        const result = ResponseAdapter.handleResponse(response);
        
        if (result.success) {
          const localData = HireRequirementAdapter.toLocal(result.data);
          dataManager.setCache('myHireRequirement', localData);
          return { success: true, data: localData };
        }
        
        return result;
      } catch (error) {
        console.error('获取养老需求失败:', error);
        // 网络失败时尝试从本地存储获取
        const localData = wx.getStorageSync('hireData');
        if (localData) {
          return { success: true, data: localData, fromCache: true };
        }
        return {
          success: false,
          data: null,
          message: '获取失败，请检查网络连接'
        };
      }
    },

    // 发布养老需求
    async publish(id) {
      try {
        const response = await hireAPI.publishHireRequirement(id);
        const result = ResponseAdapter.handleResponse(response);
        
        if (result.success) {
          // 清除缓存
          dataManager.clearCache('myHireRequirement');
          dataManager.clearCache('publishedHireRequirements');
          
          // 更新本地存储
          const localData = wx.getStorageSync('hireData');
          if (localData) {
            localData.status = 'published';
            wx.setStorageSync('hireData', localData);
          }
        }
        
        return result;
      } catch (error) {
        console.error('发布养老需求失败:', error);
        return {
          success: false,
          data: null,
          message: '发布失败，请检查网络连接'
        };
      }
    },

    // 获取已发布的养老需求列表
    async getPublished(params = {}) {
      try {
        const cacheKey = `publishedHireRequirements_${JSON.stringify(params)}`;
        const cached = dataManager.getCache(cacheKey);
        if (cached) {
          return { success: true, data: cached };
        }

        const response = await hireAPI.getPublishedHireRequirements(params);
        const result = ResponseAdapter.handlePageResponse(response);
        
        if (result.success) {
          dataManager.setCache(cacheKey, result.data);
        }
        
        return result;
      } catch (error) {
        console.error('获取已发布养老需求失败:', error);
        return {
          success: false,
          data: [],
          message: '获取失败，请检查网络连接'
        };
      }
    }
  };

  /**
   * 用户数据管理
   */
  user = {
    // 用户登录（支持微信静默登录）
    async login(data) {
      try {
        let response;
        
        // 根据登录类型使用不同的接口
        if (data.type === 'wechat' && data.code) {
          // 微信静默登录 - 使用GET请求，code作为查询参数
          response = await userAPI.wechatLogin(data.code);
        } else {
          // 普通登录
          response = await userAPI.login(data);
        }
        
        // 添加详细的响应日志
        console.log('📥 登录接口响应:', response);
        
        const result = ResponseAdapter.handleResponse(response);
        
        // 添加详细的结果日志
        console.log('🔄 登录处理结果:', {
          success: result.success,
          data: result.data,
          message: result.message
        });
        
        if (result.success) {
          // 保存用户信息和token
          const userData = UserAdapter.toLocal(result.data.user);
          const token = result.data.token;
          
          console.log('💾 保存用户数据:', {
            userData: userData,
            token: token ? '已获取' : '未获取'
          });
          
          wx.setStorageSync('userInfo', userData);
          wx.setStorageSync('userToken', token);
          
          // 清除所有缓存
          dataManager.clearCache('all');
        }
        
        return result;
      } catch (error) {
        console.error('用户登录失败:', error);
        return {
          success: false,
          data: null,
          message: '登录失败，请检查网络连接'
        };
      }
    },

    // 获取用户信息
    async getInfo() {
      try {
        const response = await userAPI.getUserInfo();
        const result = ResponseAdapter.handleResponse(response);
        
        if (result.success) {
          const userData = UserAdapter.toLocal(result.data);
          wx.setStorageSync('userInfo', userData);
          return { success: true, data: userData };
        }
        
        return result;
      } catch (error) {
        console.error('获取用户信息失败:', error);
        // 从本地存储获取
        const localData = wx.getStorageSync('userInfo');
        if (localData) {
          return { success: true, data: localData, fromCache: true };
        }
        return {
          success: false,
          data: null,
          message: '获取用户信息失败'
        };
      }
    }
  };

  /**
   * 文件上传管理
   */
  upload = {
    // 上传头像
    async avatar(filePath) {
      try {
        const response = await uploadAPI.uploadImage(filePath, 'avatar');
        console.log('📤 上传头像响应:', response);
        
        // 上传接口直接返回文件信息，不需要通过ResponseAdapter处理
        if (response.filename && response.url) {
          console.log('✅ 头像上传成功:', response);
          return {
            success: true,
            data: response,
            message: '上传成功'
          };
        } else {
          console.log('❌ 头像上传失败:', response);
          return {
            success: false,
            data: null,
            message: '上传失败，请重试'
          };
        }
      } catch (error) {
        console.error('上传头像失败:', error);
        return {
          success: false,
          data: null,
          message: '上传失败，请重试'
        };
      }
    },

    // 上传证件图片
    async certificate(filePath, type) {
      try {
        const response = await uploadAPI.uploadImage(filePath, `cert_${type}`);
        console.log('📤 上传证件图片响应:', response);
        
        // 上传接口直接返回文件信息，不需要通过ResponseAdapter处理
        if (response.filename && response.url) {
          console.log('✅ 证件图片上传成功:', response);
          return {
            success: true,
            data: response,
            message: '上传成功'
          };
        } else {
          console.log('❌ 证件图片上传失败:', response);
          return {
            success: false,
            data: null,
            message: '上传失败，请重试'
          };
        }
      } catch (error) {
        console.error('上传证件失败:', error);
        return {
          success: false,
          data: null,
          message: '上传失败，请重试'
        };
      }
    }
  };
}

// 创建数据管理实例
const dataManager = new DataManager();

module.exports = dataManager;
