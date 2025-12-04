// app.js
import { wxLogin, getProfile } from './utils/api.js'
import { setToken, getToken } from './utils/storage.js'

App({
  onLaunch() {
    // 应用启动时执行微信静默登录
    this.silentLogin()
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
            this.globalData.userInfo = profile
            this.globalData.isLoggedIn = true
            return
          } else {
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
            this.globalData.userInfo = profile
            console.log('登录成功，用户信息:', profile)
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

  globalData: {
    userInfo: null,
    isLoggedIn: false
  }
})

