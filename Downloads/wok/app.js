// app.js
import { wxLogin, getProfile, getVipStatus } from './utils/api.js'
import { setToken, getToken } from './utils/storage.js'
import { requestSubscribeMessage, isAuthorized } from './utils/subscribeMessage.js'

function normalizeBgList(items) {
  if (!Array.isArray(items)) return []
  const seen = new Set()
  const out = []
  for (const item of items) {
    if (!item) continue
    const filename = item.filename || ''
    const url = item.url || ''
    if (!url) continue
    // 过滤掉默认/分享图
    if (filename === 'pic_default.png' || filename === 'pic_share.png') continue
    // 去重 + 为渲染生成强唯一 key（避免 wx:key 冲突导致列表“渲染两份/复用错位”）
    const baseKey = url || filename
    if (!baseKey) continue
    if (seen.has(baseKey)) continue
    seen.add(baseKey)
    out.push({ ...item, __key: baseKey })
  }
  return out
}

const BG_CACHE_KEY_V2 = 'bg_list_cache_v2'
const BG_CACHE_KEY_LEGACY = 'bg_list_cache'
const BG_CACHE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000 // 7 天

function readBgCache() {
  try {
    const v2 = wx.getStorageSync(BG_CACHE_KEY_V2)
    if (v2 && typeof v2 === 'object' && Array.isArray(v2.items)) {
      return { ts: Number(v2.ts) || 0, items: v2.items }
    }
  } catch (e) {}

  try {
    const legacy = wx.getStorageSync(BG_CACHE_KEY_LEGACY)
    if (Array.isArray(legacy) && legacy.length > 0) {
      return { ts: 0, items: legacy }
    }
  } catch (e) {}

  return null
}

function writeBgCache(items) {
  try {
    wx.setStorageSync(BG_CACHE_KEY_V2, { ts: Date.now(), items })
  } catch (e) {}
  // 兼容旧结构：仍写入纯数组，防止其它页面/旧版本代码读不到
  try {
    wx.setStorageSync(BG_CACHE_KEY_LEGACY, items)
  } catch (e) {}
}

App({
  onLaunch() {
    // 应用启动时执行微信静默登录
    this.silentLogin()
    // 预加载背景图列表，确保进入 bg-gallery 页时缓存已就绪
    this._preloadBgList()
  },

  _preloadBgList() {
    this.getBgList()
      .then(list => console.log('[App] bgList ready, count:', (list && list.length) || 0))
      .catch(() => {})
  },

  normalizeBgList,

  getBgList(options = {}) {
    const forceRefresh = !!options.forceRefresh
    const maxAgeMs = typeof options.maxAgeMs === 'number' ? options.maxAgeMs : BG_CACHE_MAX_AGE_MS
    const backgroundRefresh = options.backgroundRefresh !== false

    if (!forceRefresh) {
      const mem = this.globalData.bgList
      if (mem && mem.length > 0) return Promise.resolve(mem)
      const cached = readBgCache()
      if (cached && cached.items && cached.items.length > 0) {
        const normalized = normalizeBgList(cached.items)
        this.globalData.bgList = normalized

        const isStale = cached.ts > 0 ? (Date.now() - cached.ts > maxAgeMs) : true
        if (isStale && backgroundRefresh) {
          // 不阻塞首屏：后台刷新一次（有 in-flight 锁）
          this._fetchBgListFromNetwork().catch(() => {})
        }
        return Promise.resolve(normalized)
      }
    }

    return this._fetchBgListFromNetwork()
  },

  _fetchBgListFromNetwork() {
    if (this._bgListPromise) return this._bgListPromise

    console.log('[App] bgList fetching from network...')
    this._bgListPromise = new Promise((resolve) => {
      wx.request({
        url: 'https://wemedev.com/wok/api/bg-images',
        success: (res) => {
          const items = res && res.data && res.data.items
          const normalized = normalizeBgList(items || [])
          if (normalized.length > 0) {
            this.globalData.bgList = normalized
            writeBgCache(normalized)
          }
          resolve(this.globalData.bgList || normalized || [])
        },
        fail: () => resolve(this.globalData.bgList || [])
      })
    }).finally(() => {
      this._bgListPromise = null
    })

    return this._bgListPromise
  },

  /**
   * 微信静默登录
   * 获取 openId 并保存 token
   */
  async silentLogin() {
    try {
      // 检查是否已有 token
      const token = getToken()
      if (token) {
        // 验证 token 是否有效，尝试获取用户信息
        try {
          const profile = await getProfile()
          if (profile) {
            console.log('已登录，用户信息:', profile)
            // 统一字段名：支持 avatarUrl（驼峰）和 avatar_url（下划线）
            if (profile.avatarUrl && !profile.avatar_url) {
              profile.avatar_url = profile.avatarUrl
            }
            this.globalData.userInfo = profile
            this.globalData.isLoggedIn = true
            // profile 接口直接返回 isVip，直接用，不需要单独请求
            this.globalData.isVip = !!profile.isVip
            console.log('[App] VIP 状态（来自 profile）:', this.globalData.isVip)
            // 通知所有页面用户信息已更新
            this.notifyUserInfoUpdate()
            this.notifyVipUpdate(this.globalData.isVip)
            return          } else {
            // profile 为 null 表示用户资料不存在（新用户），设置默认值
            console.log('用户资料不存在，使用默认值')
            this.globalData.userInfo = {
              nickname: '',
              avatar_url: ''
            }
            this.globalData.isLoggedIn = true
            return
          }
        } catch (e) {
          // 401 表示 token 无效，需要重新登录
          if (e.message && (e.message.includes('过期') || e.message.includes('401'))) {
            console.log('token 无效，重新登录')
            setToken('')
          } else {
            console.log('验证 token 失败:', e.message || e)
            setToken('')
          }
        }
      }

      // 调用微信登录接口
      const loginRes = await new Promise((resolve, reject) => {
        wx.login({
          success: resolve,
          fail: reject
        })
      })

      if (!loginRes.code) {
        console.error('获取 code 失败')
        return
      }

      // 调用后端接口获取 session token
      const result = await wxLogin(loginRes.code)
      
      if (result && result.token) {
        // 保存 token
        setToken(result.token)
        this.globalData.isLoggedIn = true
        
        // 获取用户资料（如果用户资料不存在，getProfile 会返回 null，不会抛出错误）
        try {
          const profile = await getProfile()
          if (profile) {
            // 统一字段名：支持 avatarUrl（驼峰）和 avatar_url（下划线）
            if (profile.avatarUrl && !profile.avatar_url) {
              profile.avatar_url = profile.avatarUrl
            }
            this.globalData.userInfo = profile
            console.log('登录成功，用户信息:', profile)
            // profile 接口直接返回 isVip，直接用
            this.globalData.isVip = !!profile.isVip
            console.log('[App] VIP 状态（来自 profile）:', this.globalData.isVip)
            // 通知所有页面用户信息已更新
            this.notifyUserInfoUpdate()
            this.notifyVipUpdate(this.globalData.isVip)
          } else {
            // profile 为 null 表示用户资料不存在（新用户首次登录），设置默认值
            console.log('新用户首次登录，用户资料待创建')
            this.globalData.userInfo = {
              nickname: '',
              avatar_url: ''
            }
          }
        } catch (e) {
          // 只有非 404 的错误才会进入这里（如 401 token 过期等）
          console.log('获取用户资料失败:', e.message || e)
          // 即使获取失败，也设置默认值，允许用户继续使用
          this.globalData.userInfo = {
            nickname: '',
            avatar_url: ''
          }
        }
        
        console.log('登录成功，openId:', result.openid)
      } else {
        console.error('登录失败:', result)
        wx.showToast({
          title: '登录失败',
          icon: 'none'
        })
      }
    } catch (error) {
      console.error('静默登录失败:', error)
    }
  },

  /**
   * 刷新 VIP 状态并存入 globalData，完成后通知所有页面
   */
  async refreshVipStatus() {
    try {
      const res = await getVipStatus()
      this.globalData.isVip = !!(res && res.is_vip)
      console.log('[App] VIP 状态:', this.globalData.isVip)
      // 通知所有在线页面同步 VIP 状态
      this.notifyVipUpdate()
    } catch (e) {
      console.warn('[App] 获取 VIP 状态失败:', e.message || e)
    }
  },

  /**
   * 通知所有页面 VIP 状态已更新
   */
  notifyVipUpdate() {
    const pages = getCurrentPages()
    pages.forEach(page => {
      if (page && typeof page.onVipUpdate === 'function') {
        page.onVipUpdate(this.globalData.isVip)
      }
    })
  },

  /**
   * 通知所有页面用户信息已更新
   */
  notifyUserInfoUpdate() {
    // 获取所有页面实例
    const pages = getCurrentPages()
    pages.forEach(page => {
      // 如果页面有 loadUserInfo 方法，调用它
      if (page && typeof page.loadUserInfo === 'function') {
        page.loadUserInfo()
      }
    })
  },

  /**
   * 请求订阅消息授权
   * 可以在应用启动时或特定场景下调用
   */
  requestSubscribeMessageAuth() {
    try {
      // 注意：微信订阅消息授权是一次性的，每次发送前都需要重新授权
      // 但为了避免频繁打扰用户，如果用户刚刚拒绝过，可以稍后再请求
      requestSubscribeMessage()
        .then(result => {
          if (result.authorized) {
            console.log('[订阅消息] 用户已授权，可以发送订阅消息')
          } else {
            console.log('[订阅消息] 用户未授权，稍后可以再次请求')
          }
        })
        .catch(err => {
          console.error('[订阅消息] 请求授权失败:', err)
          // 授权失败不影响小程序正常使用
        })
    } catch (e) {
      console.error('[订阅消息] 请求授权异常:', e)
    }
  },


  globalData: {
    userInfo: null,
    isLoggedIn: false,
    isVip: false,                    // VIP 状态
    bgList: null,                    // 背景图列表缓存（bg-gallery 与 course-schedule 共享）
    _navBar: null,                   // 导航栏尺寸缓存
    pendingBgUrl: null,              // bg-gallery "使用此图" 传递给课程表的待应用背景 URL
    selectedResultText: null         // 选中的结果文字（用于主页显示）
  }
})
