// utils/api.js
import { getToken } from './storage.js'

// API 基础地址
const BASE_URL = 'https://wemedev.com/wok/api'

/**
 * 通用请求方法
 */
function request(url, method = 'GET', data = {}) {
  return new Promise((resolve, reject) => {
    const token = getToken()
    const fullUrl = `${BASE_URL}${url}`
    
    console.log(`[API] ${method} ${fullUrl}`, token ? '有token' : '无token')
    
    wx.request({
      url: fullUrl,
      method: method,
      data: data,
      header: {
        'Content-Type': 'application/json',
        'Authorization': token ? `Bearer ${token}` : ''
      },
      success: (res) => {
        console.log(`[API] 响应 ${res.statusCode}:`, res.data)
        
        if (res.statusCode === 200) {
          resolve(res.data)
        } else if (res.statusCode === 401) {
          // token 过期，清除并跳转登录
          console.log('[API] Token 已过期')
          const { setToken } = require('./storage')
          setToken('')
          reject(new Error('登录已过期，请重新登录'))
        } else if (res.statusCode === 404) {
          // 资源不存在（如用户资料不存在）
          console.log('[API] 资源不存在 (404)')
          reject(new Error('资源不存在'))
        } else if (res.statusCode === 422) {
          // 参数验证失败（如缺少 Authorization header）
          console.log('[API] 参数验证失败 (422):', res.data)
          const errorMsg = res.data?.detail || res.data?.message || '参数验证失败'
          reject(new Error(errorMsg))
        } else {
          // 其他错误
          console.log('[API] 请求失败:', res.statusCode, res.data)
          const errorMsg = res.data?.message || res.data?.detail || `请求失败 (${res.statusCode})`
          reject(new Error(errorMsg))
        }
      },
      fail: (err) => {
        reject(err)
      }
    })
  })
}

/**
 * 微信登录
 */
export function wxLogin(code) {
  return new Promise((resolve, reject) => {
    const fullUrl = `${BASE_URL}/auth/wxlogin`
    console.log('[API] 微信登录请求:', fullUrl, 'code:', code ? '已提供' : '未提供')
    
    wx.request({
      url: fullUrl,
      method: 'POST',
      data: { code },
      header: {
        'Content-Type': 'application/json'
      },
      success: (res) => {
        console.log('[API] 登录响应:', res.statusCode, res.data)
        
        if (res.statusCode === 200) {
          if (res.data && res.data.token) {
            console.log('[API] 登录成功，获取到 token')
            resolve(res.data)
          } else {
            console.error('[API] 登录响应格式错误:', res.data)
            reject(new Error('登录响应格式错误'))
          }
        } else {
          const errorMsg = res.data?.message || res.data?.detail || `登录失败 (${res.statusCode})`
          console.error('[API] 登录失败:', errorMsg)
          reject(new Error(errorMsg))
        }
      },
      fail: (err) => {
        console.error('[API] 登录请求失败:', err)
        reject(err)
      }
    })
  })
}

/**
 * 获取用户资料
 * 如果用户资料不存在（404），返回 null 而不是抛出错误
 */
export function getProfile() {
  return new Promise((resolve, reject) => {
    const token = getToken()
    const fullUrl = `${BASE_URL}/profile`
    
    console.log(`[API] GET ${fullUrl}`, token ? '有token' : '无token')
    
    wx.request({
      url: fullUrl,
      method: 'GET',
      header: {
        'Content-Type': 'application/json',
        'Authorization': token ? `Bearer ${token}` : ''
      },
      success: (res) => {
        if (res.statusCode === 200) {
          console.log('[API] 获取用户资料成功')
          resolve(res.data)
        } else if (res.statusCode === 404) {
          // 用户资料不存在，这是正常的（新用户首次登录），返回 null
          console.log('[API] 用户资料不存在（新用户），返回默认值')
          resolve(null)
        } else if (res.statusCode === 401) {
          // token 过期，清除并跳转登录
          console.log('[API] Token 已过期')
          const { setToken } = require('./storage')
          setToken('')
          reject(new Error('登录已过期，请重新登录'))
        } else if (res.statusCode === 422) {
          // 参数验证失败（如缺少 Authorization header）
          console.log('[API] 参数验证失败 (422):', res.data)
          const errorMsg = res.data?.detail || res.data?.message || '参数验证失败'
          reject(new Error(errorMsg))
        } else {
          // 其他错误
          console.log('[API] 获取用户资料失败:', res.statusCode, res.data)
          const errorMsg = res.data?.message || res.data?.detail || `请求失败 (${res.statusCode})`
          reject(new Error(errorMsg))
        }
      },
      fail: (err) => {
        console.error('[API] 请求失败:', err)
        reject(err)
      }
    })
  })
}

/**
 * 更新用户资料
 */
export function updateProfile(data) {
  return request('/profile', 'PUT', data)
}

/**
 * 上传头像
 * 注意：文件字段名必须是 'file'，与后端接口定义一致
 */
export function uploadAvatar(filePath) {
  return new Promise((resolve, reject) => {
    const token = getToken()
    const fullUrl = `${BASE_URL}/profile/avatar`
    
    console.log('[API] 上传头像:', fullUrl, 'filePath:', filePath ? '已提供' : '未提供')
    
    if (!filePath) {
      reject(new Error('文件路径不能为空'))
      return
    }
    
    wx.uploadFile({
      url: fullUrl,
      filePath: filePath,
      name: 'file',  // 文件字段名必须是 'file'，与后端接口定义一致
      header: {
        'Authorization': token ? `Bearer ${token}` : ''
      },
      success: (res) => {
        console.log('[API] 上传头像响应:', res.statusCode, res.data)
        
        try {
          const data = JSON.parse(res.data)
          if (res.statusCode === 200) {
            console.log('[API] 上传头像成功:', data.avatar_url)
            resolve(data)
          } else if (res.statusCode === 401) {
            // token 过期
            console.log('[API] Token 已过期')
            const { setToken } = require('./storage')
            setToken('')
            reject(new Error('登录已过期，请重新登录'))
          } else if (res.statusCode === 404) {
            reject(new Error('资源不存在'))
          } else if (res.statusCode === 422) {
            // 参数验证失败（如缺少 file 字段）
            console.error('[API] 参数验证失败 (422):', data)
            const errorMsg = data?.detail || data?.message || '参数验证失败'
            // 如果错误信息包含 file 字段，提供更友好的提示
            if (errorMsg.includes('file')) {
              reject(new Error('上传失败：请选择图片文件'))
            } else {
              reject(new Error(errorMsg))
            }
          } else {
            console.error('[API] 上传失败:', res.statusCode, data)
            reject(new Error(data?.message || data?.detail || `上传失败 (${res.statusCode})`))
          }
        } catch (e) {
          console.error('[API] 解析响应失败:', e, res.data)
          reject(new Error('解析响应失败'))
        }
      },
      fail: (err) => {
        console.error('[API] 上传请求失败:', err)
        reject(err)
      }
    })
  })
}

