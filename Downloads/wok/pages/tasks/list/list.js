// pages/tasks/list/list.js
import { getTasks } from '../../../utils/api.js'

Page({
  data: {
    tasks: [],
    loading: false,
    loadingMore: false,
    hasMore: true,
    page: 0,
    pageSize: 20
  },

  onLoad() {
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
      
      if (result && result.items) {
        // 统一字段名处理
        const tasks = result.items.map(task => {
          if (task.creator_profile) {
            if (task.creator_profile.avatarUrl && !task.creator_profile.avatar_url) {
              task.creator_profile.avatar_url = task.creator_profile.avatarUrl
            }
          }
          // 处理参与者头像（过滤掉创建者）
          if (task.participants && Array.isArray(task.participants)) {
            // 过滤掉创建者，只保留其他参与者
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
        })

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

