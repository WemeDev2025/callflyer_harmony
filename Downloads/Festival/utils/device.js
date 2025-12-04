/**
 * 设备信息工具
 * 用于获取和上报设备信息
 */

const API_BASE_URL = 'https://wemedev.com/api/festival';
const { getToken, getOpenId } = require('./auth');

/**
 * 获取设备信息
 * @returns {Object} 设备信息对象
 */
function getDeviceInfo() {
  try {
    const systemInfo = wx.getSystemInfoSync();
    
    return {
      // 设备基础信息
      brand: systemInfo.brand || '', // 设备品牌
      model: systemInfo.model || '', // 设备型号
      platform: systemInfo.platform || '', // 平台类型：ios/android/devtools
      system: systemInfo.system || '', // 操作系统版本
      
      // 屏幕信息
      screenWidth: systemInfo.screenWidth || 0,
      screenHeight: systemInfo.screenHeight || 0,
      windowWidth: systemInfo.windowWidth || 0,
      windowHeight: systemInfo.windowHeight || 0,
      pixelRatio: systemInfo.pixelRatio || 1,
      
      // 状态栏信息
      statusBarHeight: systemInfo.statusBarHeight || 0,
      safeArea: systemInfo.safeArea || null,
      
      // 微信版本信息
      version: systemInfo.version || '', // 微信版本号
      SDKVersion: systemInfo.SDKVersion || '', // 基础库版本
      
      // 其他信息
      language: systemInfo.language || '', // 语言
      fontSizeSetting: systemInfo.fontSizeSetting || 0, // 字体大小设置
      enableDebug: systemInfo.enableDebug || false, // 是否开启调试
      
      // 时间戳
      timestamp: Date.now()
    };
  } catch (err) {
    console.error('[设备信息] 获取设备信息失败', err);
    return {
      error: err.message || '获取设备信息失败',
      timestamp: Date.now()
    };
  }
}

/**
 * 上报设备信息到服务器
 * @param {Object} deviceInfo 设备信息对象（可选，如果不传则自动获取）
 * @returns {Promise} 返回上报结果
 */
function reportDeviceInfo(deviceInfo = null) {
  return new Promise((resolve, reject) => {
    // 如果没有传入设备信息，自动获取
    const info = deviceInfo || getDeviceInfo();
    
    // 获取用户信息
    const token = getToken();
    const openid = getOpenId();
    
    // 如果没有登录，延迟上报（等待登录完成）
    if (!token || !openid) {
      console.log('[设备信息] 用户未登录，延迟上报设备信息');
      // 延迟3秒后重试
      setTimeout(() => {
        reportDeviceInfo(info).then(resolve).catch(reject);
      }, 3000);
      return;
    }
    
    console.log('[设备信息] 开始上报设备信息:', {
      brand: info.brand,
      model: info.model,
      platform: info.platform,
      system: info.system
    });
    
    wx.request({
      url: `${API_BASE_URL}/device/report`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      data: {
        openid: openid,
        device_info: info
      },
      success: (res) => {
        if (res.statusCode === 200 || res.statusCode === 201) {
          console.log('[设备信息] 上报成功:', res.data);
          resolve(res.data);
        } else {
          console.warn('[设备信息] 上报失败:', {
            statusCode: res.statusCode,
            data: res.data
          });
          // 上报失败不影响使用，静默处理
          resolve(null);
        }
      },
      fail: (err) => {
        console.error('[设备信息] 上报请求失败:', err);
        // 上报失败不影响使用，静默处理
        resolve(null);
      }
    });
  });
}

/**
 * 判断设备类型
 * @returns {string} 设备类型：ios/android/devtools/unknown
 */
function getDeviceType() {
  try {
    const systemInfo = wx.getSystemInfoSync();
    const platform = systemInfo.platform || '';
    
    if (platform.includes('ios')) {
      return 'ios';
    } else if (platform.includes('android')) {
      return 'android';
    } else if (platform.includes('devtools')) {
      return 'devtools';
    } else {
      return 'unknown';
    }
  } catch (err) {
    console.error('[设备信息] 判断设备类型失败', err);
    return 'unknown';
  }
}

/**
 * 判断是否为真机
 * @returns {boolean} 是否为真机
 */
function isRealDevice() {
  const deviceType = getDeviceType();
  return deviceType === 'ios' || deviceType === 'android';
}

/**
 * 判断是否为开发者工具
 * @returns {boolean} 是否为开发者工具
 */
function isDevTools() {
  return getDeviceType() === 'devtools';
}

module.exports = {
  getDeviceInfo,
  reportDeviceInfo,
  getDeviceType,
  isRealDevice,
  isDevTools
};

