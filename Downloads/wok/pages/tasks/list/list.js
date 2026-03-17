// pages/tasks/list/list.js
import { getTasks, getTaskDetail } from '../../../utils/api.js'

Page({
  data: {
    tasks: [],
    loading: false,
    loadingMore: false,
    hasMore: true,
    page: 0,
    pageSize: 20,
    navBarHeight: 88  // 默认导航栏高度，onLoad 时用 API 算准确值
  },

  onLoad() {
    // 全屏模式：计算状态栏 + 胶囊高度，给列表留出顶部空间
    try {
      const sysInfo = wx.getSystemInfoSync()
      const menuButton = wx.getMenuButtonBoundingClientRect()
      // 导航栏高度 = 胶囊底部 + 8rpx 间距
      const navBarHeight = menuButton.bottom + 8
      this.setData({ navBarHeight })
    } catch (e) {
      console.warn('[List] 获取系统信息失败:', e)
    }
    this.loadTasks()
  },

  /**
   * 页面显示时静默刷新（从其他页面返回时）
   */
  onShow() {
    // 如果已有任务列表，静默刷新第一页数据以更新状态
    if (this.data.tasks.length > 0) {
      this.loadTasks(true)
    }
  },

  /**
   * 页面下拉刷新
   */
  async onPullDownRefresh() {
    this.setData({
      page: 0,
      hasMore: true
    })
    await this.loadTasks(true)
    wx.stopPullDownRefresh()
  },

  /**
   * 加载任务列表
   */
  async loadTasks(refresh = false) {
    if (this.data.loading) {
      return
    }

    this.setData({
      loading: true
    })

    try {
      const skip = refresh ? 0 : this.data.page * this.data.pageSize
      const result = await getTasks(skip, this.data.pageSize)
      
      // 调试：打印原始数据
      if (result && result.items) {
        console.log('[List] 原始任务数据:', JSON.stringify(result.items, null, 2))
      }
      
      if (result && result.items) {
        // 统一字段名处理
        const tasks = await Promise.all(result.items.map(async (task) => {
          // 处理创建者信息：统一转换为 creator_profile（下划线格式）以便模板使用
          // 后端可能返回 creatorProfile（驼峰）或 creator_profile（下划线）
          const creatorProfile = task.creatorProfile || task.creator_profile
          if (creatorProfile) {
            // 统一使用 creator_profile 字段名
            task.creator_profile = {
              openid: creatorProfile.openid,
              nickname: creatorProfile.nickname,
              avatarUrl: creatorProfile.avatarUrl || creatorProfile.avatar_url,
              avatar_url: creatorProfile.avatar_url || creatorProfile.avatarUrl
            }
            console.log('[List] 处理创建者信息:', task.taskId, {
              nickname: task.creator_profile.nickname,
              avatarUrl: task.creator_profile.avatarUrl,
              avatar_url: task.creator_profile.avatar_url
            })
          } else {
            console.warn('[List] 任务缺少创建者信息:', task.taskId)
          }
          // 收集所有菜品（包括创建者和参与者）
          // 如果列表接口没有返回 dishes，需要调用详情接口获取
          let allDishes = []
          let hasDishesInList = false
          
          if (task.participants && Array.isArray(task.participants)) {
            // 检查是否有任何参与者有 dishes 字段
            hasDishesInList = task.participants.some(p => p.dishes && Array.isArray(p.dishes) && p.dishes.length > 0)
            
            if (hasDishesInList) {
              // 列表接口有 dishes 数据，直接收集
              task.participants.forEach(p => {
                if (p.dishes && Array.isArray(p.dishes) && p.dishes.length > 0) {
                  p.dishes.forEach(dish => {
                    const dishStr = dish && typeof dish === 'string' ? dish.trim() : String(dish).trim()
                    if (dishStr && !allDishes.includes(dishStr)) {
                      allDishes.push(dishStr)
                    }
                  })
                }
              })
            } else {
              // 列表接口没有 dishes 数据，调用详情接口获取
              try {
                const detailResult = await getTaskDetail(task.taskId)
                if (detailResult && detailResult.participants && Array.isArray(detailResult.participants)) {
                  detailResult.participants.forEach(p => {
                    if (p.dishes && Array.isArray(p.dishes) && p.dishes.length > 0) {
                      p.dishes.forEach(dish => {
                        const dishStr = dish && typeof dish === 'string' ? dish.trim() : String(dish).trim()
                        if (dishStr && !allDishes.includes(dishStr)) {
                          allDishes.push(dishStr)
                        }
                      })
                    }
                  })
                }
              } catch (error) {
                console.error('[List] 获取任务详情失败:', task.taskId, error)
              }
            }
          }
          
          task.allDishes = allDishes
          
          // 处理 selectedDish：确保字符串格式一致（trim处理）
          if (task.selectedDish) {
            task.selectedDish = typeof task.selectedDish === 'string' ? task.selectedDish.trim() : String(task.selectedDish).trim()
          }
          
          // 处理参与者头像（过滤掉创建者，用于头像显示）
          if (task.participants && Array.isArray(task.participants)) {
            // 过滤掉创建者，只保留其他参与者（用于头像显示）
            task.participants = task.participants
              .filter(p => p.openid !== task.creatorOpenid)
              .map(p => {
                if (p.avatarUrl && !p.avatar_url) {
                  p.avatar_url = p.avatarUrl
                }
                return p
              })
          }
          // 格式化时间
          if (task.createdAt) {
            task.createdAt = this.formatTime(task.createdAt)
          }
          // 格式化耗时（只处理已结束的任务）
          if (task.status === 'finished' && task.durationSeconds !== null && task.durationSeconds !== undefined && task.durationSeconds > 0) {
            task.durationText = this.formatDuration(task.durationSeconds)
          } else {
            task.durationText = null
          }
          
          return task
        }))

        if (refresh) {
          this.setData({
            tasks: tasks,
            page: 1,
            hasMore: tasks.length >= this.data.pageSize
          })
        } else {
          const allTasks = this.data.tasks.concat(tasks)
          this.setData({
            tasks: allTasks,
            page: this.data.page + 1,
            hasMore: tasks.length >= this.data.pageSize
          })
        }
      } else {
        this.setData({
          hasMore: false
        })
      }
    } catch (error) {
      console.error('加载任务列表失败:', error)
      wx.showToast({
        title: error.message || '加载失败',
        icon: 'none'
      })
    } finally {
      this.setData({
        loading: false
      })
    }
  },

  /**
   * 格式化时间（只显示创建时间：月-日 时:分）
   */
  formatTime(timeStr) {
    if (!timeStr) return ''
    const date = new Date(timeStr)
    const month = date.getMonth() + 1
    const day = date.getDate()
    const hours = date.getHours()
    const mins = date.getMinutes()
    return `${month}月${day}日 ${hours.toString().padStart(2, '0')}:${mins.toString().padStart(2, '0')}`
  },

  /**
   * 格式化耗时（秒数转换为友好格式）
   */
  formatDuration(seconds) {
    if (!seconds || seconds < 0) return ''
    
    if (seconds < 60) {
      return `${seconds}秒`
    } else if (seconds < 3600) {
      const minutes = Math.floor(seconds / 60)
      const secs = seconds % 60
      if (secs === 0) {
        return `${minutes}分钟`
      } else {
        return `${minutes}分${secs}秒`
      }
    } else {
      const hours = Math.floor(seconds / 3600)
      const minutes = Math.floor((seconds % 3600) / 60)
      if (minutes === 0) {
        return `${hours}小时`
      } else {
        return `${hours}小时${minutes}分钟`
      }
    }
  },

  /**
   * 跳转到任务详情
   */
  goToTaskDetail(e) {
    const taskId = e.currentTarget.dataset.taskid
    const shareCode = e.currentTarget.dataset.sharecode
    
    if (shareCode) {
      wx.navigateTo({
        url: `/pages/task/detail/detail?shareCode=${shareCode}`
      })
    } else if (taskId) {
      wx.navigateTo({
        url: `/pages/task/detail/detail?taskId=${taskId}`
      })
    }
  }
})

