/**
 * 账号相关工具函数
 */

const API_BASE_URL = 'https://wemedev.com/api/festival';

/**
 * 静默登录
 * 通过 wx.login() 获取 code，然后调用后端登录接口
 */
function silentLogin() {
  return new Promise((resolve, reject) => {
    // 1. 调用 wx.login() 获取 code
    wx.login({
      success: (loginRes) => {
        if (!loginRes.code) {
          console.error('获取 code 失败', loginRes);
          reject(new Error('获取 code 失败'));
          return;
        }

        const code = loginRes.code;
        console.log('获取到 code，开始登录...');

        // 2. 将 code 发送到后端登录接口
        wx.request({
          url: `${API_BASE_URL}/wx/login`,
          method: 'POST',
          data: {
            code: code
          },
          success: (res) => {
            if (res.statusCode === 200 && res.data) {
              const { token, openid, unionid, expire_at, is_vip } = res.data;
              
              // 保存 token 和 openid 到本地存储
              wx.setStorageSync('token', token);
              wx.setStorageSync('openid', openid);
              if (unionid) {
                wx.setStorageSync('unionid', unionid);
              }
              if (expire_at) {
                wx.setStorageSync('token_expire_at', expire_at);
              }
              // 保存 VIP 状态
              if (is_vip !== undefined) {
                wx.setStorageSync('is_vip', is_vip);
              }

              console.log('静默登录成功', { openid, expire_at, is_vip });
              resolve({ token, openid, unionid, expire_at, is_vip });
            } else {
              console.error('登录失败', res);
              const errorMsg = (res.data && res.data.message) ? res.data.message : '登录失败';
              reject(new Error(errorMsg));
            }
          },
          fail: (err) => {
            console.error('登录请求失败', err);
            reject(err);
          }
        });
      },
      fail: (err) => {
        console.error('wx.login() 失败', err);
        reject(err);
      }
    });
  });
}

/**
 * 获取存储的 token
 */
function getToken() {
  return wx.getStorageSync('token') || '';
}

/**
 * 获取存储的 openid
 */
function getOpenId() {
  return wx.getStorageSync('openid') || '';
}

/**
 * 检查 token 是否过期
 */
function isTokenExpired() {
  const expireAt = wx.getStorageSync('token_expire_at');
  if (!expireAt) {
    return true; // 如果没有过期时间，认为已过期
  }
  
  const expireTime = new Date(expireAt).getTime();
  const now = Date.now();
  return now >= expireTime;
}

/**
 * 获取存储的 VIP 状态
 */
function getVipStatus() {
  return wx.getStorageSync('is_vip') || false;
}

/**
 * 激活解锁码
 * @param {string} code 解锁码
 * @returns {Promise} 返回激活结果
 */
function activateUnlockCode(code) {
  return new Promise((resolve, reject) => {
    const openid = getOpenId();
    if (!openid) {
      reject(new Error('未登录，无法激活'));
      return;
    }

    wx.request({
      url: `${API_BASE_URL}/unlock-codes/activate`,
      method: 'POST',
      header: {
        'Content-Type': 'application/json'
      },
      data: {
        code: code,
        client_id: openid,
        client_platform: 'miniapp'
      },
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          console.log('解锁码激活成功', res.data);
          resolve(res.data);
        } else {
          console.error('解锁码激活失败', res);
          // 解析错误信息
          let errorMsg = '激活失败';
          if (res.data && res.data.detail) {
            const detail = res.data.detail;
            if (typeof detail === 'string') {
              errorMsg = detail;
            } else if (detail.error_code) {
              // 根据错误码返回友好提示
              switch (detail.error_code) {
                case 'unlock_code_not_found':
                  errorMsg = '解锁码不存在';
                  break;
                case 'unlock_code_expired':
                  errorMsg = '解锁码已过期';
                  break;
                case 'unlock_code_already_activated_by_another_user':
                  errorMsg = '解锁码已被其他用户使用';
                  break;
                default:
                  errorMsg = detail.error_code || '激活失败';
              }
            } else {
              errorMsg = detail.message || detail.msg || '激活失败';
            }
          }
          reject(new Error(errorMsg));
        }
      },
      fail: (err) => {
        console.error('激活请求失败', err);
        reject(new Error('网络请求失败，请稍后重试'));
      }
    });
  });
}

/**
 * 查询用户VIP状态
 * @returns {Promise<boolean>} 返回是否为VIP
 */
function queryVipStatus() {
  return new Promise((resolve, reject) => {
    const openid = getOpenId();
    if (!openid) {
      reject(new Error('未登录，无法查询VIP状态'));
      return;
    }

    wx.request({
      url: `${API_BASE_URL}/users/${openid}/vip-status`,
      method: 'GET',
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          const isVip = res.data.is_vip || false;
          // 更新本地存储的VIP状态
          wx.setStorageSync('is_vip', isVip);
          console.log('VIP状态查询成功', isVip);
          resolve(isVip);
        } else {
          console.error('VIP状态查询失败', res);
          reject(new Error('查询VIP状态失败'));
        }
      },
      fail: (err) => {
        console.error('VIP状态查询请求失败', err);
        reject(new Error('网络请求失败，请稍后重试'));
      }
    });
  });
}

/**
 * 获取用户的解锁码
 * @returns {Promise<string>} 返回用户的解锁码
 */
function getUserUnlockCode() {
  return new Promise((resolve, reject) => {
    const openid = getOpenId();
    const token = getToken();
    if (!openid || !token) {
      reject(new Error('未登录，无法获取解锁码'));
      return;
    }

    wx.request({
      url: `${API_BASE_URL}/unlock-codes/my`,
      method: 'GET',
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          const unlockCode = res.data.code;
          if (unlockCode && unlockCode !== null) {
            console.log('获取用户解锁码成功', unlockCode);
            resolve(unlockCode);
          } else {
            // code 为 null 或空，表示用户没有有效解锁码
            reject(new Error('未找到有效解锁码'));
          }
        } else {
          console.error('获取解锁码失败', res);
          const errorMsg = (res.data && res.data.message) ? res.data.message : '获取解锁码失败';
          reject(new Error(errorMsg));
        }
      },
      fail: (err) => {
        console.error('获取解锁码请求失败', err);
        reject(new Error('网络请求失败，请稍后重试'));
      }
    });
  });
}

/**
 * 清除登录信息
 */
function clearAuth() {
  wx.removeStorageSync('token');
  wx.removeStorageSync('openid');
  wx.removeStorageSync('unionid');
  wx.removeStorageSync('token_expire_at');
  wx.removeStorageSync('is_vip');
}

module.exports = {
  silentLogin,
  getToken,
  getOpenId,
  isTokenExpired,
  getVipStatus,
  activateUnlockCode,
  queryVipStatus,
  getUserUnlockCode,
  clearAuth
};

