/**
 * 远程配置工具
 * 用于从服务器获取配置，控制广告的显示/隐藏
 */

const API_BASE_URL = 'https://wetofly.com/api';

/**
 * 获取远程配置
 * @returns {Promise<Object>} 配置对象
 */
function getRemoteConfig() {
  return new Promise((resolve, reject) => {
    wx.request({
      url: `${API_BASE_URL}/config`,
      method: 'GET',
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          resolve(res.data);
        } else {
          // 如果请求失败，返回默认配置
          console.warn('获取远程配置失败，使用默认配置', res);
          resolve(getDefaultConfig());
        }
      },
      fail: (err) => {
        console.error('请求远程配置失败，使用默认配置', err);
        // 请求失败时返回默认配置，不阻塞应用运行
        resolve(getDefaultConfig());
      }
    });
  });
}

/**
 * 获取默认配置
 * @returns {Object} 默认配置对象
 */
function getDefaultConfig() {
  return {
    showAdImage: false, // 默认不显示广告图
    adImageUrl: '', // 默认广告图URL为空
    adClickType: 'none', // 默认无跳转
    adClickPage: null, // 小程序页面路径
    adClickUrl: null, // 网页URL
    adClickMiniprogram: null // 其他小程序配置
  };
}

/**
 * 获取配置并缓存
 * @param {number} cacheTime 缓存时间（毫秒），默认5分钟
 * @returns {Promise<Object>}
 */
let cachedConfig = null;
let cacheTime = 0;
const CACHE_DURATION = 5 * 60 * 1000; // 5分钟缓存

function getConfig(cacheDuration = CACHE_DURATION) {
  const now = Date.now();
  
  // 如果缓存有效，直接返回缓存
  if (cachedConfig && (now - cacheTime) < cacheDuration) {
    return Promise.resolve(cachedConfig);
  }
  
  // 否则重新获取配置
  return getRemoteConfig().then(config => {
    cachedConfig = config;
    cacheTime = now;
    return config;
  });
}

/**
 * 清除配置缓存
 */
function clearConfigCache() {
  cachedConfig = null;
  cacheTime = 0;
}

module.exports = {
  getConfig,
  getRemoteConfig,
  getDefaultConfig,
  clearConfigCache
};






