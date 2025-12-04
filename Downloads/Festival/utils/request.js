/**
 * 网络请求工具函数
 * 自动携带 token 进行 API 请求
 */

const API_BASE_URL = 'https://wemedev.com/api/festival';
const { getToken, isTokenExpired, silentLogin } = require('./auth.js');

/**
 * 封装 wx.request，自动携带 token
 * @param {Object} options 请求配置
 * @param {string} options.url 请求地址（相对路径或完整路径）
 * @param {string} options.method 请求方法，默认为 GET
 * @param {Object} options.data 请求数据
 * @param {Object} options.header 请求头
 * @param {boolean} options.needAuth 是否需要认证，默认为 true
 * @returns {Promise}
 */
function request(options = {}) {
  return new Promise((resolve, reject) => {
    const {
      url,
      method = 'GET',
      data = {},
      header = {},
      needAuth = true
    } = options;

    // 构建完整 URL
    const fullUrl = url.startsWith('http') ? url : `${API_BASE_URL}${url.startsWith('/') ? url : '/' + url}`;

    // 如果需要认证，添加 token
    if (needAuth) {
      const token = getToken();
      if (token) {
        header['Authorization'] = `Bearer ${token}`;
      } else {
        console.warn('请求需要认证，但未找到 token');
      }
    }

    // 设置默认请求头
    header['Content-Type'] = header['Content-Type'] || 'application/json';

    wx.request({
      url: fullUrl,
      method: method,
      data: data,
      header: header,
      success: (res) => {
        // 如果 token 过期，尝试重新登录
        if (res.statusCode === 401 && needAuth) {
          console.log('Token 已过期，尝试重新登录...');
          silentLogin()
            .then(() => {
              // 重新发起请求
              const newToken = getToken();
              if (newToken) {
                header['Authorization'] = `Bearer ${newToken}`;
                wx.request({
                  url: fullUrl,
                  method: method,
                  data: data,
                  header: header,
                  success: resolve,
                  fail: reject
                });
              } else {
                reject(new Error('重新登录失败'));
              }
            })
            .catch((err) => {
              reject(err);
            });
        } else {
          resolve(res);
        }
      },
      fail: (err) => {
        reject(err);
      }
    });
  });
}

/**
 * GET 请求
 */
function get(url, data = {}, options = {}) {
  return request({
    url,
    method: 'GET',
    data,
    ...options
  });
}

/**
 * POST 请求
 */
function post(url, data = {}, options = {}) {
  return request({
    url,
    method: 'POST',
    data,
    ...options
  });
}

/**
 * PUT 请求
 */
function put(url, data = {}, options = {}) {
  return request({
    url,
    method: 'PUT',
    data,
    ...options
  });
}

/**
 * DELETE 请求
 */
function del(url, data = {}, options = {}) {
  return request({
    url,
    method: 'DELETE',
    data,
    ...options
  });
}

module.exports = {
  request,
  get,
  post,
  put,
  delete: del
};

