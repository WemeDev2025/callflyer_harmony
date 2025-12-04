// utils/storage.js

const TOKEN_KEY = 'wok_token'

/**
 * 保存 token
 */
export function setToken(token) {
  try {
    wx.setStorageSync(TOKEN_KEY, token)
  } catch (e) {
    console.error('保存 token 失败:', e)
  }
}

/**
 * 获取 token
 */
export function getToken() {
  try {
    return wx.getStorageSync(TOKEN_KEY) || ''
  } catch (e) {
    console.error('获取 token 失败:', e)
    return ''
  }
}

/**
 * 清除 token
 */
export function clearToken() {
  try {
    wx.removeStorageSync(TOKEN_KEY)
  } catch (e) {
    console.error('清除 token 失败:', e)
  }
}

