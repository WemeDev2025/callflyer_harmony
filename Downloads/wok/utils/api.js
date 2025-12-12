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
    
    wx.request({
      url: fullUrl,
      method: method,
      data: data,
      header: {
        'Content-Type': 'application/json',
        'Authorization': token ? `Bearer ${token}` : ''
      },
      success: (res) => {
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
          // 422 错误可能返回数组格式的 errors
          let errorMsg = '参数验证失败'
          if (Array.isArray(res.data?.detail)) {
            // FastAPI 422 错误通常返回 [{loc: [...], msg: "...", type: "..."}]
            const errors = res.data.detail.map(e => e.msg || e.message).filter(Boolean)
            errorMsg = errors.length > 0 ? errors.join('; ') : errorMsg
          } else if (res.data?.detail) {
            errorMsg = typeof res.data.detail === 'string' ? res.data.detail : (res.data.detail.message || errorMsg)
          } else if (res.data?.message) {
            errorMsg = res.data.message
          }
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
          // 统一字段名：后端可能返回 avatarUrl（驼峰）或 avatar_url（下划线）
          const data = res.data
          if (data && data.avatarUrl && !data.avatar_url) {
            data.avatar_url = data.avatarUrl
          }
          resolve(data)
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
          // 422 错误可能返回数组格式的 errors
          let errorMsg = '参数验证失败'
          if (Array.isArray(res.data?.detail)) {
            // FastAPI 422 错误通常返回 [{loc: [...], msg: "...", type: "..."}]
            const errors = res.data.detail.map(e => e.msg || e.message).filter(Boolean)
            errorMsg = errors.length > 0 ? errors.join('; ') : errorMsg
          } else if (res.data?.detail) {
            errorMsg = typeof res.data.detail === 'string' ? res.data.detail : (res.data.detail.message || errorMsg)
          } else if (res.data?.message) {
            errorMsg = res.data.message
          }
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
 * 创建任务
 */
export function createTask(data) {
  return request('/tasks', 'POST', data)
}

/**
 * 获取任务列表
 */
export function getTasks(skip = 0, limit = 20) {
  return request(`/tasks?skip=${skip}&limit=${limit}`, 'GET')
}

/**
 * 获取任务详情
 */
export function getTaskDetail(taskId) {
  return request(`/tasks/${taskId}`, 'GET')
}

/**
 * 通过分享码获取任务
 */
export function getTaskByShareCode(shareCode) {
  return request(`/tasks/share/${shareCode}`, 'GET')
}

/**
 * 参与任务（提交菜品）
 */
export function participateTask(taskId, dishes) {
  return request(`/tasks/${taskId}/participate`, 'POST', { dishes })
}

/**
 * 随机选择菜品（仅创建者可操作）
 */
export function randomSelectDish(taskId) {
  return request(`/tasks/${taskId}/random`, 'POST')
}

/**
 * 查询任务结果（轻量级，用于轮询）
 */
export function getTaskResult(taskId) {
  return request(`/tasks/${taskId}/result`, 'GET')
}

/**
 * 获取广告图列表（公开接口，无需登录）
 */
export function getBanners() {
  return new Promise((resolve, reject) => {
    const fullUrl = `${BASE_URL}/banners`
    
    console.log(`[API] GET ${fullUrl} (公开接口)`)
    
    wx.request({
      url: fullUrl,
      method: 'GET',
      header: {
        'Content-Type': 'application/json'
      },
      success: (res) => {
        if (res.statusCode === 200) {
          // 返回 items 数组，只包含 enabled: true 的广告图
          const items = res.data.items || []
          resolve(items)
        } else {
          resolve([]) // 失败时返回空数组，不阻塞应用
        }
      },
      fail: (err) => {
        console.error('[API] 获取广告图请求失败，返回空数组', err)
        resolve([]) // 失败时返回空数组，不阻塞应用
      }
    })
  })
}

/**
 * 订阅任务通知
 */
export function subscribeTask(taskId, templateId) {
  return request(`/tasks/${taskId}/subscribe`, 'POST', { templateId })
}

/**
 * 取消订阅任务通知
 */
export function unsubscribeTask(taskId) {
  return request(`/tasks/${taskId}/subscribe`, 'DELETE')
}

/**
 * 查询任务订阅状态
 */
export function getTaskSubscribeStatus(taskId) {
  return request(`/tasks/${taskId}/subscribe`, 'GET')
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
          console.log('[API] 解析后的数据:', data)
          if (res.statusCode === 200) {
            // 后端返回的是 url 字段，统一转换为 avatar_url
            const avatarUrl = data.avatar_url || data.url
            console.log('[API] 上传头像成功，avatarUrl:', avatarUrl, 'data:', data)
            if (!avatarUrl) {
              console.error('[API] 错误：未找到头像URL，返回数据:', data)
              reject(new Error('上传成功但未获取到图片地址'))
              return
            }
            // 统一返回格式，确保有 avatar_url 字段
            const result = {
              avatar_url: avatarUrl,
              url: avatarUrl,
              ...data
            }
            console.log('[API] 返回结果:', result)
            resolve(result)
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
            // 422 错误可能返回数组格式的 errors
            let errorMsg = '参数验证失败'
            if (Array.isArray(data?.detail)) {
              // FastAPI 422 错误通常返回 [{loc: [...], msg: "...", type: "..."}]
              const errors = data.detail.map(e => e.msg || e.message).filter(Boolean)
              errorMsg = errors.length > 0 ? errors.join('; ') : errorMsg
            } else if (data?.detail) {
              errorMsg = typeof data.detail === 'string' ? data.detail : (data.detail.message || errorMsg)
            } else if (data?.message) {
              errorMsg = data.message
            }
            // 如果错误信息包含 file 字段，提供更友好的提示
            if (errorMsg.includes('file') || errorMsg.includes('File')) {
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

