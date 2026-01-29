// utils/subscribeMessage.js
// 订阅消息相关工具函数

/**
 * 请求订阅消息权限
 * @param {Array} tmplIds - 模板ID数组
 * @returns {Promise<Object>} 订阅结果
 */
export function requestSubscribeMessage(tmplIds) {
  return new Promise((resolve, reject) => {
    wx.requestSubscribeMessage({
      tmplIds: tmplIds,
      success(res) {
        console.log('订阅消息结果:', res)
        resolve(res)
      },
      fail(err) {
        console.error('订阅消息失败:', err)
        reject(err)
      }
    })
  })
}

/**
 * 检查是否已授权订阅消息
 * 注意：微信小程序没有直接的API检查订阅状态，这里返回true表示可以尝试订阅
 * @param {string} tmplId - 模板ID
 * @returns {boolean} 是否已授权
 */
export function isAuthorized(tmplId) {
  // 微信小程序没有直接检查订阅状态的API
  // 这里返回true，实际使用时会通过requestSubscribeMessage的结果判断
  return true
}