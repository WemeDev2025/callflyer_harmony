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
      this.setData({
        userInfo: profile || {
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
          if (result && result.avatar_url) {
            this.setData({
              'userInfo.avatar_url': result.avatar_url
            })
            wx.showToast({
              title: '上传成功',
              icon: 'success'
            })
          }
        } catch (error) {
          wx.showToast({
            title: error.message || '上传失败',
            icon: 'none'
          })
          console.error('上传头像失败:', error)
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
   * 保存资料
   */
  async saveProfile() {
    const { nickname } = this.data.userInfo
    
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
      await updateProfile({
        nickname: nickname.trim()
      })
      
      wx.showToast({
        title: '保存成功',
        icon: 'success'
      })

      // 更新全局数据
      const app = getApp()
      if (app.globalData) {
        app.globalData.userInfo = this.data.userInfo
      }
    } catch (error) {
      wx.showToast({
        title: error.message || '保存失败',
        icon: 'none'
      })
      console.error('保存资料失败:', error)
    } finally {
      this.setData({
        saving: false
      })
    }
  }
})

