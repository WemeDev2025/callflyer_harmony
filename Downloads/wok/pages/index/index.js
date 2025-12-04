// pages/index/index.js
import { getTasks } from '../../utils/api.js'

Page({
  data: {
    userInfo: null,
    animationClass: 'cooking',  // 动画类名：'cooking' 表示炒菜动画
    activeParticipants: []  // 进行中任务的参与者头像
  },

  onLoad() {
    this.loadUserInfo()
    // 页面加载时启动动画
    this.startAnimation()
    // 加载进行中的任务参与者
    this.loadActiveParticipants()
  },

  onShow() {
    // 每次显示页面时刷新用户信息
    this.loadUserInfo()
    // 重新启动动画
    this.startAnimation()
    // 刷新进行中的任务参与者
    this.loadActiveParticipants()
  },

  onHide() {
    // 页面隐藏时停止动画（可选）
    // this.stopAnimation()
  },

  /**
   * 启动炒锅旋转动画
   */
  startAnimation() {
    // 确保动画类名已设置
    this.setData({
      animationClass: 'cooking'
    })
  },

  /**
   * 停止动画（如果需要）
   */
  stopAnimation() {
    this.setData({
      animationClass: ''
    })
  },

  /**
   * 加载用户信息
   */
  loadUserInfo() {
    const app = getApp()
    if (app.globalData && app.globalData.userInfo) {
      // 统一字段名处理
      const userInfo = app.globalData.userInfo
      if (userInfo.avatarUrl && !userInfo.avatar_url) {
        userInfo.avatar_url = userInfo.avatarUrl
      }
      console.log('[Index] 加载用户信息:', userInfo)
      this.setData({
        userInfo: userInfo
      })
    } else {
      console.log('[Index] 用户信息未就绪，等待登录完成...')
      // 如果用户信息还未就绪，延迟重试
      setTimeout(() => {
        this.loadUserInfo()
      }, 500)
    }
  },

  /**
   * 创建"吃什么"任务
   * 如果有进行中的任务，打开详情页；否则打开创建页
   */
  async createTask() {
    try {
      const app = getApp()
      const currentOpenid = app.globalData?.userInfo?.openid
      
      if (!currentOpenid) {
        // 如果用户未登录，直接跳转到创建页
        wx.navigateTo({
          url: '/pages/task/create/create'
        })
        return
      }

      // 查找用户参与或创建的进行中任务
      const result = await getTasks(0, 50)
      if (result && result.items) {
        const activeTask = result.items.find(task => {
          if (task.status !== 'active') return false
          // 检查是否是创建者或参与者
          if (task.creatorOpenid === currentOpenid) return true
          if (task.participants && task.participants.some(p => p.openid === currentOpenid)) return true
          return false
        })

        if (activeTask) {
          // 有进行中的任务，跳转到详情页
          wx.navigateTo({
            url: `/pages/task/detail/detail?taskId=${activeTask.taskId}&shareCode=${activeTask.shareCode || ''}`
          })
        } else {
          // 没有进行中的任务，跳转到创建页
          wx.navigateTo({
            url: '/pages/task/create/create'
          })
        }
      } else {
        // 获取任务列表失败，默认跳转到创建页
        wx.navigateTo({
          url: '/pages/task/create/create'
        })
      }
    } catch (error) {
      console.error('检查任务失败:', error)
      // 出错时默认跳转到创建页
      wx.navigateTo({
        url: '/pages/task/create/create'
      })
    }
  },

  /**
   * 跳转到任务列表页面
   */
  goToTasksList() {
    wx.navigateTo({
      url: '/pages/tasks/list/list'
    })
  },

  /**
   * 跳转到个人资料页面
   */
  goToProfile() {
    wx.navigateTo({
      url: '/pages/profile/profile'
    })
  },

  /**
   * 加载进行中任务的参与者头像
   */
  async loadActiveParticipants() {
    try {
      const result = await getTasks(0, 50) // 获取前50个任务
      if (result && result.items) {
        const app = getApp()
        const currentOpenid = app.globalData?.userInfo?.openid
        
        // 找出用户参与或创建的进行中任务
        const activeTasks = result.items.filter(task => {
          if (task.status !== 'active') return false
          // 检查是否是创建者或参与者
          if (task.creatorOpenid === currentOpenid) return true
          if (task.participants && task.participants.some(p => p.openid === currentOpenid)) return true
          return false
        })

        // 收集所有参与者头像（去重）
        const participantMap = new Map()
        activeTasks.forEach(task => {
          if (task.participants && Array.isArray(task.participants)) {
            task.participants.forEach(p => {
              if (p.openid && !participantMap.has(p.openid)) {
                participantMap.set(p.openid, {
                  avatar_url: p.avatar_url || p.avatarUrl || '',
                  openid: p.openid
                })
              }
            })
          }
        })

        // 转换为数组并添加随机位置和延迟
        const participants = Array.from(participantMap.values()).slice(0, 6) // 最多显示6个头像
        const activeParticipants = participants.map((p, index) => {
          let x, y
          
          if (participants.length === 1) {
            // 只有一个头像时，往左移动40rpx（相对于350rpx容器，约11.4%）
            // 容器中心是50%，往左移动就是减少x值
            x = 50 - (40 / 350) * 100 // 约38.6%，往左移动40rpx
            y = 50 // 垂直居中
          } else {
            // 多个头像时，从中心往外侧分布
            // 容器是350rpx，头像50rpx，有效半径约150rpx（350/2 - 50/2）
            const angle = (Math.PI * 2 * index) / participants.length + Math.random() * 0.2
            // 从中心往外分布：第一个在中心附近，最后一个在外侧
            const radiusRatio = (index + 1) / participants.length // 0.2 到 1.0
            const minRadius = 20 // 最小半径（中心附近）
            const maxRadius = 100 // 最大半径（外侧）
            const radius = minRadius + (maxRadius - minRadius) * radiusRatio
            x = 50 + (Math.cos(angle) * radius / 175) * 50 // 转换为百分比，175是容器半径
            y = 50 + (Math.sin(angle) * radius / 175) * 50 // 转换为百分比
          }
          
          return {
            avatar_url: p.avatar_url || p.avatarUrl || '',
            openid: p.openid,
            x: Math.max(20, Math.min(80, x)), // 限制在 20-80% 范围内
            y: Math.max(20, Math.min(80, y)), // 限制在 20-80% 范围内
            delay: Math.random() * 2 // 0-2秒的随机延迟
          }
        })

        this.setData({
          activeParticipants: activeParticipants
        })
      }
    } catch (error) {
      console.error('加载参与者失败:', error)
      // 静默失败，不影响页面显示
    }
  }
})

