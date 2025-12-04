// pages/task/detail/detail.js
import { getTaskDetail, participateTask, randomSelectDish, getTaskByShareCode } from '../../../utils/api.js'
import { getToken } from '../../../utils/storage.js'

Page({
  data: {
    taskId: '',
    shareCode: '',
    taskInfo: {},
    currentDish: '',
    myDishes: [],
    isCreator: false,
    randoming: false
  },

  onLoad(options) {
    const { taskId, shareCode } = options
    if (shareCode) {
      // 通过分享码进入
      this.loadTaskByShareCode(shareCode)
    } else if (taskId) {
      // 直接通过任务ID进入
      this.setData({ taskId })
      this.loadTaskDetail()
    } else {
      wx.showToast({
        title: '参数错误',
        icon: 'none'
      })
      setTimeout(() => {
        wx.navigateBack()
      }, 1500)
    }

    // 启用分享功能
    wx.showShareMenu({
      withShareTicket: true,
      menus: ['shareAppMessage', 'shareTimeline']
    })
  },

  /**
   * 通过分享码加载任务
   */
  async loadTaskByShareCode(shareCode) {
    try {
      const result = await getTaskByShareCode(shareCode)
      if (result && result.taskId) {
        this.setData({
          taskId: result.taskId,
          shareCode: shareCode
        })
        this.loadTaskDetail()
      }
    } catch (error) {
      console.error('加载任务失败:', error)
      wx.showToast({
        title: error.message || '任务不存在',
        icon: 'none'
      })
      setTimeout(() => {
        wx.navigateBack()
      }, 1500)
    }
  },

  /**
   * 加载任务详情
   */
  async loadTaskDetail() {
    try {
      const result = await getTaskDetail(this.data.taskId)
      if (result) {
        // 检查是否是创建者
        const app = getApp()
        const currentOpenid = app.globalData?.userInfo?.openid
        const isCreator = result.creatorOpenid === currentOpenid

        // 获取当前用户的菜品
        const myParticipant = result.participants?.find(p => p.openid === currentOpenid)
        const myDishes = myParticipant?.dishes || []

        // 确保创建者也在参与者列表中显示
        if (result.participants && Array.isArray(result.participants)) {
          // 检查创建者是否已经在参与者列表中
          const creatorInParticipants = result.participants.some(p => p.openid === result.creatorOpenid)
          
          // 如果创建者不在参与者列表中，且存在 creator_profile，则添加创建者
          if (!creatorInParticipants && result.creator_profile) {
            const creatorParticipant = {
              openid: result.creatorOpenid,
              nickname: result.creator_profile.nickname || '未设置昵称',
              avatar_url: result.creator_profile.avatar_url || result.creator_profile.avatarUrl || '',
              dishes: [] // 创建者可能没有在 participants 中，需要从其他地方获取
            }
            // 查找创建者的菜品（可能在 participants 中，但 openid 匹配）
            const creatorDishes = result.participants.find(p => p.openid === result.creatorOpenid)?.dishes || []
            if (creatorDishes.length > 0) {
              creatorParticipant.dishes = creatorDishes
            }
            result.participants.unshift(creatorParticipant) // 添加到列表开头
          }
          
          // 统一字段名处理
          result.participants = result.participants.map(p => {
            if (p.avatarUrl && !p.avatar_url) {
              p.avatar_url = p.avatarUrl
            }
            return p
          })
          
          // 创建过滤后的参与者列表（用于底部头像显示，不包含创建者）
          result.otherParticipants = result.participants.filter(p => p.openid !== result.creatorOpenid)
          
          // 创建只包含创建者的列表（用于 participants-list 显示）
          result.creatorOnly = result.participants.filter(p => p.openid === result.creatorOpenid)
          // 如果创建者不在 participants 中，从 creator_profile 创建
          if (result.creatorOnly.length === 0 && result.creator_profile) {
            result.creatorOnly = [{
              openid: result.creatorOpenid,
              nickname: result.creator_profile.nickname || '未设置昵称',
              avatar_url: result.creator_profile.avatar_url || result.creator_profile.avatarUrl || '',
              dishes: []
            }]
          }
        }

        this.setData({
          taskInfo: result,
          isCreator: isCreator,
          myDishes: myDishes,
          shareCode: result.shareCode || this.data.shareCode
        })
      }
    } catch (error) {
      console.error('加载任务详情失败:', error)
      wx.showToast({
        title: error.message || '加载失败',
        icon: 'none'
      })
    }
  },

  /**
   * 菜品输入
   */
  onDishInput(e) {
    this.setData({
      currentDish: e.detail.value
    })
  },

  /**
   * 添加菜品
   */
  async addDish() {
    // 检查任务状态
    if (this.data.taskInfo.status === 'finished') {
      wx.showToast({
        title: '任务已结束，不能再添加菜品',
        icon: 'none'
      })
      return
    }

    const dish = this.data.currentDish.trim()
    if (!dish) {
      wx.showToast({
        title: '请输入菜品名称',
        icon: 'none'
      })
      return
    }

    if (this.data.myDishes.includes(dish)) {
      wx.showToast({
        title: '该菜品已添加',
        icon: 'none'
      })
      return
    }

    const newDishes = this.data.myDishes.concat([dish])
    
    try {
      await participateTask(this.data.taskId, newDishes)
      this.setData({
        myDishes: newDishes,
        currentDish: ''
      })
      wx.showToast({
        title: '添加成功',
        icon: 'success'
      })
      // 刷新任务详情
      this.loadTaskDetail()
    } catch (error) {
      console.error('添加菜品失败:', error)
      wx.showToast({
        title: error.message || '添加失败',
        icon: 'none'
      })
    }
  },

  /**
   * 移除菜品
   */
  async removeDish(e) {
    // 检查任务状态
    if (this.data.taskInfo.status === 'finished') {
      wx.showToast({
        title: '任务已结束，不能再修改菜品',
        icon: 'none'
      })
      return
    }

    const dish = e.currentTarget.dataset.dish
    const newDishes = this.data.myDishes.filter(d => d !== dish)
    
    try {
      await participateTask(this.data.taskId, newDishes)
      this.setData({
        myDishes: newDishes
      })
      wx.showToast({
        title: '移除成功',
        icon: 'success'
      })
      // 刷新任务详情
      this.loadTaskDetail()
    } catch (error) {
      console.error('移除菜品失败:', error)
      wx.showToast({
        title: error.message || '移除失败',
        icon: 'none'
      })
    }
  },

  /**
   * 分享给微信好友（页面分享）
   * 当用户点击分享按钮或使用 open-type="share" 的按钮时会触发
   */
  onShareAppMessage() {
    const shareCode = this.data.shareCode || this.data.taskInfo?.shareCode
    if (!shareCode) {
      return {
        title: '今天吃什么？一起来选择吧！',
        path: '/pages/index/index'
      }
    }
    return {
      title: '今天吃什么？一起来选择吧！',
      path: `/pages/task/detail/detail?shareCode=${shareCode}`,
      imageUrl: '' // 可以设置分享图片
    }
  },

  /**
   * 分享到朋友圈（如果支持）
   */
  onShareTimeline() {
    const shareCode = this.data.shareCode || this.data.taskInfo?.shareCode
    if (!shareCode) {
      return {
        title: '今天吃什么？一起来选择吧！',
        query: ''
      }
    }
    return {
      title: '今天吃什么？一起来选择吧！',
      query: `shareCode=${shareCode}`,
      imageUrl: '' // 可以设置分享图片
    }
  },

  /**
   * 随机选择菜品
   */
  async randomSelect() {
    if (!this.data.isCreator) {
      wx.showToast({
        title: '只有创建者可以随机选择',
        icon: 'none'
      })
      return
    }

    this.setData({
      randoming: true
    })

    try {
      const result = await randomSelectDish(this.data.taskId)
      if (result) {
        const selectedDish = result.selectedDish
        wx.showToast({
          title: selectedDish ? `已选择：${selectedDish}` : '选择成功',
          icon: 'success',
          duration: 2000
        })
        // 刷新任务详情
        setTimeout(() => {
          this.loadTaskDetail()
        }, 500)
      }
    } catch (error) {
      console.error('随机选择失败:', error)
      wx.showToast({
        title: error.message || '选择失败',
        icon: 'none',
        duration: 2000
      })
    } finally {
      this.setData({
        randoming: false
      })
    }
  }
})

