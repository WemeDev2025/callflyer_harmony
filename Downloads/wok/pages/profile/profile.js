// pages/profile/profile.js
import { getProfile, updateProfile, uploadAvatar, getVipStatus, createPayOrder, generatePaySign, queryPayOrder } from '../../utils/api.js'

Page({
  data: {
    userInfo: {
      nickname: '',
      avatar_url: ''
    },
    isVip: false,
    saving: false,
    purchasing: false,
    statusBarHeight: 20,
    navBarHeight: 88,
    menuButtonTop: 44,
    menuButtonHeight: 32
  },

  onLoad() {
    try {
      const sysInfo = wx.getSystemInfoSync()
      const menuButton = wx.getMenuButtonBoundingClientRect()
      const navBarHeight = menuButton.bottom + 8
      this.setData({
        statusBarHeight: sysInfo.statusBarHeight,
        navBarHeight,
        menuButtonTop: menuButton.top,
        menuButtonHeight: menuButton.height
      })
    } catch (e) {
      this.setData({ navBarHeight: 88, menuButtonTop: 44, menuButtonHeight: 32 })
    }
    this.loadProfile()
  },

  goBack() {
    wx.navigateBack()
  },

  onShow() {
    // 从 globalData 同步，如果还是 false 才去后端查
    const app = getApp()
    if (app.globalData.isVip) {
      this.setData({ isVip: true })
    } else {
      this.loadVipStatus()
    }
  },

  /**
   * app.js refreshVipStatus 完成后的回调
   */
  onVipUpdate(isVip) {
    this.setData({ isVip: !!isVip })
  },

  /**
   * 加载 VIP 状态（直接从 profile 接口读，与后端保持一致）
   */
  async loadVipStatus() {
    try {
      const app = getApp()
      if (app.globalData.isVip) {
        this.setData({ isVip: true })
        return
      }
      const profile = await getProfile()
      const isVip = !!(profile && profile.isVip)
      app.globalData.isVip = isVip
      this.setData({ isVip })
    } catch (e) {
      console.warn('[Profile] 获取 VIP 状态失败:', e.message || e)
    }
  },

  /**
   * 加载用户资料
   */
  async loadProfile() {
    try {
      const profile = await getProfile()
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
      console.error('加载用户资料失败:', error)
      this.setData({ userInfo: { nickname: '', avatar_url: '' } })
      if (!error.message || !error.message.includes('不存在')) {
        wx.showToast({ title: error.message || '加载失败', icon: 'none', duration: 2000 })
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
        wx.showLoading({ title: '上传中...', mask: true })
        try {
          const result = await uploadAvatar(tempFilePath)
          const avatarUrl = (result && result.avatar_url) || (result && result.url) || ''
          if (result && avatarUrl) {
            this.setData({ 'userInfo.avatar_url': avatarUrl })
            wx.showToast({ title: '上传成功', icon: 'success' })
            const app = getApp()
            if (app.globalData && app.globalData.userInfo) {
              app.globalData.userInfo.avatar_url = avatarUrl
              app.globalData.userInfo.avatarUrl = avatarUrl
            }
          } else {
            wx.showToast({ title: '上传失败：未获取到图片地址', icon: 'none' })
          }
        } catch (error) {
          console.error('[Profile] 上传头像失败:', error)
          if (error.message && (error.message.includes('过期') || error.message.includes('401'))) {
            wx.showModal({
              title: '提示', content: '登录已过期，请重新登录', showCancel: false,
              success: () => { const app = getApp(); app && app.silentLogin && app.silentLogin() }
            })
          } else {
            wx.showToast({ title: error.message || '上传失败', icon: 'none', duration: 2000 })
          }
        } finally {
          wx.hideLoading()
        }
      },
      fail: (err) => { console.error('选择图片失败:', err) }
    })
  },

  onNicknameInput(e) {
    this.setData({ 'userInfo.nickname': e.detail.value })
  },

  onAvatarError(e) {
    console.error('[Profile] 头像加载失败:', (e.detail && e.detail.errMsg) || '图片加载失败')
  },

  /**
   * 保存资料
   */
  async saveProfile() {
    const { nickname, avatar_url } = this.data.userInfo
    if (!nickname || nickname.trim() === '') {
      wx.showToast({ title: '请输入昵称', icon: 'none' })
      return
    }
    this.setData({ saving: true })
    try {
      const updateData = { nickname: nickname.trim() }
      if (avatar_url && avatar_url.trim()) {
        updateData.avatarUrl = avatar_url.trim()
      }
      await updateProfile(updateData)
      wx.showToast({ title: '保存成功', icon: 'success' })
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
      if (error.message && (error.message.includes('过期') || error.message.includes('401'))) {
        wx.showModal({
          title: '提示', content: '登录已过期，请重新登录', showCancel: false,
          success: () => {
            const app = getApp()
            app && app.silentLogin && app.silentLogin().then(() => this.saveProfile())
          }
        })
      } else {
        wx.showToast({ title: error.message || '保存失败', icon: 'none', duration: 2000 })
      }
    } finally {
      this.setData({ saving: false })
    }
  },

  // ─── VIP 购买流程 ─────────────────────────────────────────────

  /**
   * 点击购买 VIP 按钮
   */
  onBuyVip() {
    if (this.data.isVip) {
      wx.showToast({ title: '您已是 VIP', icon: 'success' })
      return
    }
    this.startVipPurchase()
  },

  /**
   * 发起支付流程
   */
  async startVipPurchase() {
    if (this.data.purchasing) return
    this.setData({ purchasing: true })
    wx.showLoading({ title: '准备支付...', mask: true })

    try {
      const app = getApp()
      const openid = app.globalData && app.globalData.userInfo && app.globalData.userInfo.openid
      if (!openid) throw new Error('获取用户信息失败，请重试')

      // 第1步：创建订单
      const orderRes = await createPayOrder(openid)
      const { order_id, prepay_id } = orderRes
      if (!prepay_id) throw new Error('创建订单失败')

      // 第2步：生成支付签名
      const signRes = await generatePaySign(prepay_id)

      wx.hideLoading()

      // 第3步：唤起微信支付
      await new Promise((resolve, reject) => {
        wx.requestPayment({
          timeStamp: signRes.timeStamp,
          nonceStr: signRes.nonceStr,
          package: signRes.package,
          signType: signRes.signType || 'RSA',
          paySign: signRes.paySign,
          success: resolve,
          fail: reject
        })
      })

      // 第4步：支付成功，轮询确认状态
      wx.showLoading({ title: '确认支付...', mask: true })
      await this.pollOrderStatus(order_id)

    } catch (err) {
      wx.hideLoading()
      const msg = err.errMsg || err.message || ''
      if (msg.includes('cancel') || msg.includes('用户取消')) {
        wx.showToast({ title: '已取消支付', icon: 'none' })
      } else {
        console.error('[VIP] 支付失败:', err)
        wx.showToast({ title: msg || '支付失败，请重试', icon: 'none', duration: 2500 })
      }
    } finally {
      this.setData({ purchasing: false })
      wx.hideLoading()
    }
  },

  /**
   * 轮询订单状态，最多 10 次，每次间隔 1.5s
   */
  async pollOrderStatus(orderId) {
    for (let i = 0; i < 10; i++) {
      await new Promise(r => setTimeout(r, 1500))
      try {
        const res = await queryPayOrder(orderId)
        if (res && res.is_paid) {
          // 支付成功，刷新 VIP 状态并通知所有页面
          const app = getApp()
          app.globalData.isVip = true
          app.notifyVipUpdate && app.notifyVipUpdate(true)
          this.setData({ isVip: true })
          wx.hideLoading()
          wx.showToast({ title: 'VIP 解锁成功 🎉', icon: 'success', duration: 2500 })
          return
        }
      } catch (e) {
        console.warn('[VIP] 查询订单状态失败:', e.message)
      }
    }
    // 超时仍未确认，提示用户稍后刷新
    wx.hideLoading()
    wx.showModal({
      title: '支付处理中',
      content: '支付结果确认中，请稍后返回此页面查看 VIP 状态',
      showCancel: false,
      confirmText: '知道了'
    })
  }
})
