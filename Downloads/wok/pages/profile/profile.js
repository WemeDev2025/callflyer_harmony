// pages/profile/profile.js
import { getProfile, updateProfile, uploadAvatar } from '../../utils/api.js'

Page({
  data: {
    userInfo: {
      nickname: '',
      avatar_url: ''
    },
    saving: false
  },

  onLoad() {
    this.loadProfile()
  },

  /**
   * 加载用户资料
   */
  async loadProfile() {
    try {
      const profile = await getProfile()
      // getProfile 在用户资料不存在时会返回 null，不会抛出错误
      // 统一处理字段名：支持 avatarUrl（驼峰）和 avatar_url（下划线）
      const avatarUrl = (profile && profile.avatar_url) || (profile && profile.avatarUrl) || ''
      this.setData({
        userInfo: profile ? {
          nickname: profile.nickname || '',
          avatar_url: avatarUrl
        } : {
          nickname: '',
          avatar_url: ''
        }
      })
    } catch (error) {
      // 只有非 404 的错误才会进入这里（如 401 token 过期等）
      console.error('加载用户资料失败:', error)
      // 设置默认值，允许用户继续操作
      this.setData({
        userInfo: {
          nickname: '',
          avatar_url: ''
        }
      })
      // 只在非 404 错误时显示提示
      if (!error.message || !error.message.includes('不存在')) {
        wx.showToast({
          title: error.message || '加载失败',
          icon: 'none',
          duration: 2000
        })
      }
    }
  },

  /**
   * 选择头像
   */
  chooseAvatar() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['album', 'camera'],
      success: async (res) => {
        const tempFilePath = res.tempFiles[0].tempFilePath
        
        wx.showLoading({
          title: '上传中...',
          mask: true
        })

        try {
          const result = await uploadAvatar(tempFilePath)
          // 支持 url 和 avatar_url 两种字段名
          const avatarUrl = (result && result.avatar_url) || (result && result.url) || ''
          if (result && avatarUrl) {
            console.log('[Profile] 上传成功，设置头像URL:', avatarUrl)
            this.setData({
              'userInfo.avatar_url': avatarUrl
            })
            wx.showToast({
              title: '上传成功',
              icon: 'success'
            })
            
            // 更新全局数据
            const app = getApp()
            if (app.globalData && app.globalData.userInfo) {
              app.globalData.userInfo.avatar_url = avatarUrl
              app.globalData.userInfo.avatarUrl = avatarUrl
            }
          } else {
            wx.showToast({
              title: '上传失败：未获取到图片地址',
              icon: 'none'
            })
          }
        } catch (error) {
          console.error('[Profile] 上传头像失败:', error)
          
          // 处理 token 过期的情况
          if (error.message && (error.message.includes('过期') || error.message.includes('401'))) {
            wx.showModal({
              title: '提示',
              content: '登录已过期，请重新登录',
              showCancel: false,
              success: () => {
                // 重新登录
                const app = getApp()
                if (app && app.silentLogin) {
                  app.silentLogin()
                }
              }
            })
          } else {
            wx.showToast({
              title: error.message || '上传失败',
              icon: 'none',
              duration: 2000
            })
          }
        } finally {
          wx.hideLoading()
        }
      },
      fail: (err) => {
        console.error('选择图片失败:', err)
      }
    })
  },

  /**
   * 昵称输入
   */
  onNicknameInput(e) {
    this.setData({
      'userInfo.nickname': e.detail.value
    })
  },

  /**
   * 头像加载失败处理
   */
  onAvatarError(e) {
    const errorMsg = (e.detail && e.detail.errMsg) || '图片加载失败'
    console.error('[Profile] 头像加载失败:', errorMsg)
    // 头像加载失败时，静默处理，不显示错误提示
  },

  /**
   * 保存资料
   */
  async saveProfile() {
    const { nickname, avatar_url } = this.data.userInfo
    
    if (!nickname || nickname.trim() === '') {
      wx.showToast({
        title: '请输入昵称',
        icon: 'none'
      })
      return
    }

    this.setData({
      saving: true
    })

    try {
      // 构建更新数据，使用驼峰命名（avatarUrl）与后端接口一致
      const updateData = {
        nickname: nickname.trim()
      }
      
      // 如果用户上传了头像，也一起更新
      if (avatar_url && avatar_url.trim()) {
        updateData.avatarUrl = avatar_url.trim()
      }
      
      console.log('[Profile] 更新资料数据:', updateData)
      
      await updateProfile(updateData)
      
      wx.showToast({
        title: '保存成功',
        icon: 'success'
      })

      // 更新全局数据
      const app = getApp()
      if (app.globalData && app.globalData.userInfo) {
        app.globalData.userInfo.nickname = nickname.trim()
        if (avatar_url) {
          app.globalData.userInfo.avatar_url = avatar_url
          app.globalData.userInfo.avatarUrl = avatar_url
        }
      }
    } catch (error) {
      console.error('[Profile] 保存资料失败:', error)
      
      // 处理 token 过期的情况
      if (error.message && (error.message.includes('过期') || error.message.includes('401'))) {
        wx.showModal({
          title: '提示',
          content: '登录已过期，请重新登录',
          showCancel: false,
          success: () => {
            // 重新登录
            const app = getApp()
            if (app && app.silentLogin) {
              app.silentLogin().then(() => {
                // 登录成功后重试保存
                this.saveProfile()
              })
            }
          }
        })
      } else {
        wx.showToast({
          title: error.message || '保存失败',
          icon: 'none',
          duration: 2000
        })
      }
    } finally {
      this.setData({
        saving: false
      })
    }
  }
})

