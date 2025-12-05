// pages/task/detail/detail.js
import { getTaskDetail, participateTask, randomSelectDish, getTaskByShareCode, createTask } from '../../../utils/api.js'
import { getToken } from '../../../utils/storage.js'

Page({
  data: {
    // 模式：'create' 创建模式，'detail' 详情模式
    mode: 'detail',
    taskId: '',
    shareCode: '',
    taskInfo: {},
    currentDish: '',
    myDishes: [],
    isCreator: false,
    currentUserInfo: null,  // 当前用户信息（用于创建模式显示头像）
    showTipsAnimation: false,  // 控制 tips 动画
    showActionsAnimation: false,  // 控制 actions 动画
    randoming: false,
    tapPressed: false,  // 随机选择图标按下状态
    sharePressed: false,  // 分享图标按下状态
    showResultMask: false,  // 显示结果遮罩
    selectedDishResult: '',  // 选中的菜品结果
    // 创建模式的数据
    title: '今天吃什么？',
    dishes: [],  // 创建模式下的菜品列表
    creating: false,
    // Placeholder 文案数组
    placeholders: ['今天吃什么？', '团建去哪里玩？', '有啥拿不定主意的？'],
    placeholderIndex: 0,  // 当前 placeholder 索引
    placeholderTimer: null,  // Placeholder 切换定时器
    // 菜品输入框 Placeholder 文案数组
    dishPlaceholders: ['你的建议是？', '尊重每个意见～', '相信第一选择！'],
    dishPlaceholderIndex: 0,  // 当前菜品 placeholder 索引
    dishPlaceholderTimer: null,  // 菜品 Placeholder 切换定时器
    allDishes: [],  // 所有参与者的菜品列表
    refreshTimer: null  // 数据刷新定时器
  },

  onLoad(options) {
    const { taskId, shareCode } = options
    if (shareCode) {
      // 通过分享码进入详情模式
      this.setData({ mode: 'detail' })
      this.loadTaskByShareCode(shareCode)
    } else if (taskId) {
      // 直接通过任务ID进入详情模式
      this.setData({ 
        mode: 'detail',
        taskId 
      })
      this.loadTaskDetail()
    } else {
      // 没有参数，进入创建模式
      this.setData({ mode: 'create' })
      // 加载当前用户信息（用于显示创建者头像）
      this.loadCurrentUserInfo()
      // 启动 placeholder 自动切换
      this.startPlaceholderCarousel()
      // 触发动画
      setTimeout(() => {
        this.triggerAnimations()
      }, 100)
    }

    // 启用分享功能（仅在详情模式）
    if (taskId || shareCode) {
      wx.showShareMenu({
        withShareTicket: true,
        menus: ['shareAppMessage', 'shareTimeline']
      })
    }
  },

  /**
   * 页面显示时启动刷新定时器
   */
  onShow() {
    if (this.data.mode === 'detail' && this.data.taskId) {
      this.startRefreshTimer()
    }
  },

  /**
   * 页面隐藏时停止刷新定时器
   */
  onHide() {
    this.stopRefreshTimer()
  },

  /**
   * 启动数据刷新定时器（每3秒刷新一次）
   */
  startRefreshTimer() {
    this.stopRefreshTimer() // 先清除旧的定时器
    if (this.data.mode === 'detail' && this.data.taskId) {
      this.data.refreshTimer = setInterval(() => {
        // 只在任务进行中时刷新
        if (this.data.taskInfo.status !== 'finished' && !this.data.taskInfo.selectedDish) {
          console.log('[refreshTimer] 定时刷新任务数据')
          this.loadTaskDetail()
        } else {
          // 任务已完成，停止刷新
          this.stopRefreshTimer()
        }
      }, 3000) // 每3秒刷新一次
    }
  },

  /**
   * 停止数据刷新定时器
   */
  stopRefreshTimer() {
    if (this.data.refreshTimer) {
      clearInterval(this.data.refreshTimer)
      this.data.refreshTimer = null
    }
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
   * 加载当前用户信息（用于创建模式显示头像）
   */
  loadCurrentUserInfo() {
    const app = getApp()
    if (app.globalData && app.globalData.userInfo) {
      const userInfo = app.globalData.userInfo
      // 统一字段名处理
      if (userInfo.avatarUrl && !userInfo.avatar_url) {
        userInfo.avatar_url = userInfo.avatarUrl
      }
      this.setData({
        currentUserInfo: {
          nickname: userInfo.nickname || '未设置昵称',
          avatar_url: userInfo.avatar_url || '',
          openid: userInfo.openid || ''
        }
      })
    } else {
      // 如果用户信息还未就绪，延迟重试
      setTimeout(() => {
        this.loadCurrentUserInfo()
      }, 500)
    }
  },

  /**
   * 处理任务数据（用于 createTask 和 loadTaskDetail）
   */
  processTaskData(result) {
    if (!result) return null

    // 检查是否是创建者
    const app = getApp()
    const currentOpenid = (app.globalData && app.globalData.userInfo && app.globalData.userInfo.openid) || null
    const isCreator = result.creatorOpenid === currentOpenid

    // 获取当前用户的菜品
    const myParticipant = (result.participants && Array.isArray(result.participants)) 
      ? result.participants.find(p => p.openid === currentOpenid) 
      : null
    const myDishes = (myParticipant && myParticipant.dishes) || []

    // 确保创建者也在参与者列表中显示
    if (result.participants && Array.isArray(result.participants)) {
      // 检查创建者是否已经在参与者列表中
      const creatorInParticipants = result.participants.some(p => p.openid === result.creatorOpenid)
      
      // 如果创建者不在参与者列表中，且存在 creator_profile，则添加创建者
      if (!creatorInParticipants && result.creator_profile) {
        // 查找创建者的菜品（可能在 participants 中，但 openid 匹配）
        const existingCreator = result.participants.find(p => p.openid === result.creatorOpenid)
        const creatorDishes = (existingCreator && existingCreator.dishes) || []
        
        const creatorParticipant = {
          openid: result.creatorOpenid,
          nickname: result.creator_profile.nickname || '未设置昵称',
          avatar_url: result.creator_profile.avatar_url || result.creator_profile.avatarUrl || '',
          dishes: creatorDishes
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
      // 如果创建者在 participants 中，但数据不完整，用 creator_profile 补充
      if (result.creatorOnly.length > 0 && result.creator_profile) {
        const creator = result.creatorOnly[0]
        // 如果缺少头像或昵称，从 creator_profile 补充
        if (!creator.avatar_url && !creator.avatarUrl) {
          creator.avatar_url = result.creator_profile.avatar_url || result.creator_profile.avatarUrl || ''
        }
        if (!creator.nickname || creator.nickname === '未设置昵称') {
          creator.nickname = result.creator_profile.nickname || '未设置昵称'
        }
        // 确保 avatar_url 字段存在
        if (creator.avatarUrl && !creator.avatar_url) {
          creator.avatar_url = creator.avatarUrl
        }
      }
      // 确保 creatorOnly 只包含一个元素（取第一个，避免重复）
      if (result.creatorOnly.length > 1) {
        result.creatorOnly = [result.creatorOnly[0]]
      }
      
      // 收集所有参与者的菜品（去重）
      const allDishesSet = new Set()
      result.participants.forEach(p => {
        if (p.dishes && Array.isArray(p.dishes)) {
          p.dishes.forEach(dish => {
            if (dish && dish.trim()) {
              allDishesSet.add(dish.trim())
            }
          })
        }
      })
      result.allDishes = Array.from(allDishesSet)
      console.log('[processTaskData] 收集到的所有菜品:', result.allDishes)
      console.log('[processTaskData] 参与者数量:', result.participants.length)
      result.participants.forEach((p, index) => {
        console.log(`[processTaskData] 参与者 ${index}:`, p.nickname, '菜品:', p.dishes)
      })
    } else {
      result.allDishes = []
    }

    const returnData = {
      taskInfo: result,
      isCreator: isCreator,
      myDishes: myDishes,
      selectedDishResult: result.selectedDish || '',
      allDishes: result.allDishes || []
    }
    console.log('[processTaskData] 返回数据中的 allDishes:', returnData.allDishes)
    return returnData
  },

  /**
   * 加载任务详情
   */
  async loadTaskDetail() {
    try {
      console.log('[loadTaskDetail] 开始加载任务详情')
      console.log('[loadTaskDetail] 当前 taskInfo:', this.data.taskInfo)
      console.log('[loadTaskDetail] 当前 taskInfo.selectedDish:', this.data.taskInfo.selectedDish)
      console.log('[loadTaskDetail] 当前 taskInfo.status:', this.data.taskInfo.status)
      
      const result = await getTaskDetail(this.data.taskId)
      console.log('[loadTaskDetail] API 返回结果:', result)
      console.log('[loadTaskDetail] result.selectedDish:', result.selectedDish)
      console.log('[loadTaskDetail] result.status:', result.status)
      
      if (result) {
        // 处理任务数据
        const processed = this.processTaskData(result)
        if (!processed) {
          throw new Error('处理任务数据失败')
        }
        
        console.log('[loadTaskDetail] 处理后的数据:', processed)
        console.log('[loadTaskDetail] processed.taskInfo.selectedDish:', processed.taskInfo.selectedDish)
        console.log('[loadTaskDetail] processed.taskInfo.status:', processed.taskInfo.status)
        
        // 合并 taskInfo，而不是完全替换，避免 content 卡片重新渲染
        const existingTaskInfo = this.data.taskInfo || {}
        const mergedTaskInfo = Object.assign({}, existingTaskInfo, processed.taskInfo)
        
        console.log('[loadTaskDetail] 合并后的 taskInfo:', mergedTaskInfo)
        console.log('[loadTaskDetail] 合并后的 taskInfo.selectedDish:', mergedTaskInfo.selectedDish)
        console.log('[loadTaskDetail] 合并后的 taskInfo.status:', mergedTaskInfo.status)
        console.log('[loadTaskDetail] add-dish-section 应该显示:', this.data.mode === 'create' || (this.data.mode === 'detail' && mergedTaskInfo.status !== 'finished' && !mergedTaskInfo.selectedDish))
        
        console.log('[loadTaskDetail] processed.allDishes:', processed.allDishes)
        console.log('[loadTaskDetail] mergedTaskInfo.allDishes:', mergedTaskInfo.allDishes)
        
        this.setData({
          taskInfo: mergedTaskInfo,
          isCreator: processed.isCreator,
          myDishes: processed.myDishes,
          shareCode: result.shareCode || this.data.shareCode,
          selectedDishResult: processed.selectedDishResult,
          allDishes: processed.allDishes || []
        })
        
        console.log('[loadTaskDetail] setData 完成')
        console.log('[loadTaskDetail] 当前 data.allDishes:', this.data.allDishes)
        console.log('[loadTaskDetail] all-dishes-section 应该显示:', this.data.mode === 'detail' && this.data.allDishes && this.data.allDishes.length > 0 && mergedTaskInfo.status !== 'finished')
        
        // 启动数据刷新定时器（仅在任务进行中）
        if (mergedTaskInfo.status !== 'finished' && !mergedTaskInfo.selectedDish) {
          this.startRefreshTimer()
        } else {
          this.stopRefreshTimer()
        }
        
        // 延迟触发动画，让 content 卡片先稳定
        setTimeout(() => {
          this.triggerAnimations()
        }, 100)
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
   * 标题输入（创建模式）
   */
  onTitleInput(e) {
    this.setData({
      title: e.detail.value
    })
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
    const dish = this.data.currentDish.trim()
    if (!dish) {
      wx.showToast({
        title: '请输入菜品名称',
        icon: 'none'
      })
      return
    }

    // 创建模式
    if (this.data.mode === 'create') {
      if (this.data.dishes.includes(dish)) {
        wx.showToast({
          title: '该菜品已添加',
          icon: 'none'
        })
        return
      }

      const newDishes = this.data.dishes.concat([dish])
      this.setData({
        dishes: newDishes,
        currentDish: ''
      })
      return
    }

    // 详情模式
    // 检查任务状态
    if (this.data.taskInfo.status === 'finished') {
      wx.showToast({
        title: '任务已结束，不能再添加菜品',
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
    // 创建模式
    if (this.data.mode === 'create') {
      const index = e.currentTarget.dataset.index
      const dishes = this.data.dishes
      dishes.splice(index, 1)
      this.setData({
        dishes: dishes
      })
      return
    }

    // 详情模式
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
   * 处理任务数据（用于 createTask 和 loadTaskDetail）
   */
  processTaskData(result) {
    if (!result) return null

    // 检查是否是创建者
    const app = getApp()
    const currentOpenid = (app.globalData && app.globalData.userInfo && app.globalData.userInfo.openid) || null
    const isCreator = result.creatorOpenid === currentOpenid

    // 获取当前用户的菜品
    const myParticipant = (result.participants && Array.isArray(result.participants)) 
      ? result.participants.find(p => p.openid === currentOpenid) 
      : null
    const myDishes = (myParticipant && myParticipant.dishes) || []

    // 确保创建者也在参与者列表中显示
    if (result.participants && Array.isArray(result.participants)) {
      // 检查创建者是否已经在参与者列表中
      const creatorInParticipants = result.participants.some(p => p.openid === result.creatorOpenid)
      
      // 如果创建者不在参与者列表中，且存在 creator_profile，则添加创建者
      if (!creatorInParticipants && result.creator_profile) {
        // 查找创建者的菜品（可能在 participants 中，但 openid 匹配）
        const existingCreator = result.participants.find(p => p.openid === result.creatorOpenid)
        const creatorDishes = (existingCreator && existingCreator.dishes) || []
        
        const creatorParticipant = {
          openid: result.creatorOpenid,
          nickname: result.creator_profile.nickname || '未设置昵称',
          avatar_url: result.creator_profile.avatar_url || result.creator_profile.avatarUrl || '',
          dishes: creatorDishes
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
      // 如果创建者在 participants 中，但数据不完整，用 creator_profile 补充
      if (result.creatorOnly.length > 0 && result.creator_profile) {
        const creator = result.creatorOnly[0]
        // 如果缺少头像或昵称，从 creator_profile 补充
        if (!creator.avatar_url && !creator.avatarUrl) {
          creator.avatar_url = result.creator_profile.avatar_url || result.creator_profile.avatarUrl || ''
        }
        if (!creator.nickname || creator.nickname === '未设置昵称') {
          creator.nickname = result.creator_profile.nickname || '未设置昵称'
        }
        // 确保 avatar_url 字段存在
        if (creator.avatarUrl && !creator.avatar_url) {
          creator.avatar_url = creator.avatarUrl
        }
      }
      // 确保 creatorOnly 只包含一个元素（取第一个，避免重复）
      if (result.creatorOnly.length > 1) {
        result.creatorOnly = [result.creatorOnly[0]]
      }
      
      // 收集所有参与者的菜品（去重）
      const allDishesSet = new Set()
      result.participants.forEach(p => {
        if (p.dishes && Array.isArray(p.dishes)) {
          p.dishes.forEach(dish => {
            if (dish && dish.trim()) {
              allDishesSet.add(dish.trim())
            }
          })
        }
      })
      result.allDishes = Array.from(allDishesSet)
      console.log('[processTaskData] 收集到的所有菜品:', result.allDishes)
      console.log('[processTaskData] 参与者数量:', result.participants.length)
      result.participants.forEach((p, index) => {
        console.log(`[processTaskData] 参与者 ${index}:`, p.nickname, '菜品:', p.dishes)
      })
    } else {
      result.allDishes = []
    }

    const returnData = {
      taskInfo: result,
      isCreator: isCreator,
      myDishes: myDishes,
      selectedDishResult: result.selectedDish || '',
      allDishes: result.allDishes || []
    }
    console.log('[processTaskData] 返回数据中的 allDishes:', returnData.allDishes)
    return returnData
  },

  /**
   * 创建任务（创建模式）
   */
  async createTask() {
    if (this.data.dishes.length === 0) {
      wx.showToast({
        title: '请至少添加一个菜品',
        icon: 'none'
      })
      return
    }

    this.setData({
      creating: true
    })

    try {
      const result = await createTask({
        title: this.data.title || '今天吃什么？',
        description: `已添加 ${this.data.dishes.length} 个选项`
      })

      if (result && result.taskId) {
        // 创建成功后，参与任务（提交菜品），使用返回的数据
        let taskData = result
        try {
          taskData = await participateTask(result.taskId, this.data.dishes)
          // participateTask 返回完整的任务数据，直接使用
        } catch (e) {
          console.log('参与任务失败，但任务已创建:', e)
          // 如果参与失败，使用 createTask 返回的数据
        }

        // 如果 taskData 没有 creator_profile，从当前用户信息中获取
        if (!taskData.creator_profile) {
          const app = getApp()
          const userInfo = app.globalData && app.globalData.userInfo
          if (userInfo && taskData.creatorOpenid === userInfo.openid) {
            taskData.creator_profile = {
              openid: userInfo.openid,
              nickname: userInfo.nickname || '未设置昵称',
              avatar_url: userInfo.avatar_url || userInfo.avatarUrl || '',
              avatarUrl: userInfo.avatarUrl || userInfo.avatar_url || ''
            }
          }
        }

        // 处理任务数据
        const processed = this.processTaskData(taskData)
        if (!processed) {
          throw new Error('处理任务数据失败')
        }

        // 切换到详情模式，使用处理后的数据，避免重新获取
        // 先重置动画标志，避免闪烁
        this.setData({
          showTipsAnimation: false,
          showActionsAnimation: false
        })

        // 合并 taskInfo，保持对象引用稳定
        const existingTaskInfo = this.data.taskInfo || {}
        const mergedTaskInfo = Object.assign({}, existingTaskInfo, processed.taskInfo)
        
        // 一次性更新所有数据，避免多次渲染
        this.setData({
          mode: 'detail',
          taskId: taskData.taskId,
          shareCode: taskData.shareCode || '',
          taskInfo: mergedTaskInfo,
          isCreator: processed.isCreator,
          myDishes: processed.myDishes,
          selectedDishResult: processed.selectedDishResult,
          dishes: [],  // 清空创建模式的菜品列表
          currentDish: ''
        })

        // 延迟触发动画，让 content 卡片先稳定
        setTimeout(() => {
          this.triggerAnimations()
        }, 150)

        // 启用分享功能
        wx.showShareMenu({
          withShareTicket: true,
          menus: ['shareAppMessage', 'shareTimeline']
        })

        wx.showToast({
          title: '创建成功',
          icon: 'success'
        })
      } else {
        throw new Error('创建任务失败')
      }
    } catch (error) {
      console.error('创建任务失败:', error)
      wx.showToast({
        title: error.message || '创建失败',
        icon: 'none'
      })
    } finally {
      this.setData({
        creating: false
      })
    }
  },

  /**
   * 分享给微信好友（页面分享）
   * 当用户点击分享按钮或使用 open-type="share" 的按钮时会触发
   */
  onShareAppMessage() {
    const shareCode = this.data.shareCode || (this.data.taskInfo && this.data.taskInfo.shareCode) || ''
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
    const shareCode = this.data.shareCode || (this.data.taskInfo && this.data.taskInfo.shareCode) || ''
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
   * 分享图标按下
   */
  onShareTouchStart() {
    // 震动反馈
    wx.vibrateShort({
      type: 'light'
    })
    this.setData({
      sharePressed: true
    })
  },

  /**
   * 分享图标释放
   */
  onShareTouchEnd() {
    setTimeout(() => {
      this.setData({
        sharePressed: false
      })
    }, 150)
  },

  /**
   * 随机选择图标按下
   */
  onRandomTouchStart() {
    this.setData({
      tapPressed: true
    })
  },

  /**
   * 随机选择图标释放
   */
  onRandomTouchEnd() {
    this.setData({
      tapPressed: false
    })
  },

  /**
   * 随机选择菜品（仅创建者可操作）
   */
  async randomSelect() {
    // 严格检查：必须是创建者
    if (!this.data.isCreator || this.data.isCreator !== true) {
      wx.showToast({
        title: '只有创建者可以随机选择',
        icon: 'none'
      })
      return
    }

    // 检查任务状态
    if (this.data.taskInfo.status === 'finished' || this.data.taskInfo.selectedDish) {
      wx.showToast({
        title: '任务已结束',
        icon: 'none'
      })
      return
    }

    // 检查任务ID
    if (!this.data.taskId) {
      wx.showToast({
        title: '任务不存在',
        icon: 'none'
      })
      return
    }

    // 震动反馈
    wx.vibrateShort({
      type: 'medium'
    })

    // 按下动画
    this.setData({
      tapPressed: true,
      randoming: true
    })

    // 延迟释放按下状态，让动画可见
    setTimeout(() => {
      this.setData({
        tapPressed: false
      })
    }, 150)

    try {
      console.log('[randomSelect] 开始随机选择，当前 taskInfo:', this.data.taskInfo)
      console.log('[randomSelect] 当前 taskInfo.selectedDish:', this.data.taskInfo.selectedDish)
      console.log('[randomSelect] 当前 taskInfo.status:', this.data.taskInfo.status)
      
      const result = await randomSelectDish(this.data.taskId)
      console.log('[randomSelect] API 返回结果:', result)
      
      if (result) {
        const selectedDish = result.selectedDish
        console.log('[randomSelect] 选中的菜品:', selectedDish)
        
        // 立即更新 taskInfo.selectedDish，使 add-dish-section 立即隐藏
        const updatedTaskInfo = Object.assign({}, this.data.taskInfo, {
          selectedDish: selectedDish || '',
          status: 'finished'
        })
        console.log('[randomSelect] 更新后的 taskInfo:', updatedTaskInfo)
        console.log('[randomSelect] 更新后的 taskInfo.selectedDish:', updatedTaskInfo.selectedDish)
        console.log('[randomSelect] 更新后的 taskInfo.status:', updatedTaskInfo.status)
        
        // 显示动画遮罩和结果卡片
        // 使用路径更新方式，确保视图立即响应
        // 同时更新 selectedDishResult 作为备用判断条件
        const dishValue = selectedDish || ''
        this.setData({
          'taskInfo.selectedDish': dishValue,
          'taskInfo.status': 'finished',
          selectedDishResult: dishValue,
          showResultMask: true
        }, () => {
          // setData 回调，确保数据已更新到视图层
          console.log('[randomSelect] setData 回调执行，检查显示条件:')
          console.log('[randomSelect] 当前 taskInfo.selectedDish:', this.data.taskInfo.selectedDish)
          console.log('[randomSelect] 当前 taskInfo.status:', this.data.taskInfo.status)
          console.log('[randomSelect] 当前 selectedDishResult:', this.data.selectedDishResult)
          console.log('[randomSelect] mode === "create":', this.data.mode === 'create')
          console.log('[randomSelect] mode === "detail" && taskInfo.status !== "finished":', this.data.mode === 'detail' && this.data.taskInfo.status !== 'finished')
          console.log('[randomSelect] !taskInfo.selectedDish:', !this.data.taskInfo.selectedDish)
          console.log('[randomSelect] !selectedDishResult:', !this.data.selectedDishResult)
          const shouldShow = this.data.mode === 'create' || (this.data.mode === 'detail' && this.data.taskInfo.status !== 'finished' && !this.data.taskInfo.selectedDish && !this.data.selectedDishResult)
          console.log('[randomSelect] add-dish-section 应该显示:', shouldShow)
          
          // 强制触发一次视图更新，确保 wx:if 重新计算
          this.setData({
            'taskInfo.selectedDish': this.data.taskInfo.selectedDish,
            'taskInfo.status': this.data.taskInfo.status,
            selectedDishResult: this.data.selectedDishResult
          })
        })
        
        console.log('[randomSelect] setData 调用完成，检查显示条件:')
        console.log('[randomSelect] mode === "create":', this.data.mode === 'create')
        console.log('[randomSelect] mode === "detail" && taskInfo.status !== "finished":', this.data.mode === 'detail' && updatedTaskInfo.status !== 'finished')
        console.log('[randomSelect] !taskInfo.selectedDish:', !updatedTaskInfo.selectedDish)
        console.log('[randomSelect] add-dish-section 应该显示:', this.data.mode === 'create' || (this.data.mode === 'detail' && updatedTaskInfo.status !== 'finished' && !updatedTaskInfo.selectedDish))
        
        // 刷新任务详情
        setTimeout(() => {
          console.log('[randomSelect] 延迟后调用 loadTaskDetail')
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
      this.setData({
        randoming: false
      })
    }
  },

  /**
   * 显示结果（用于查看已有结果）
   */
  showResult() {
    if (this.data.taskInfo && this.data.taskInfo.selectedDish) {
      this.setData({
        selectedDishResult: this.data.taskInfo.selectedDish,
        showResultMask: true
      })
    }
  },

  /**
   * 关闭结果遮罩
   */
  closeResultMask() {
    this.setData({
      showResultMask: false,
      randoming: false
    })
  },

  /**
   * 启动 placeholder 轮播
   */
  startPlaceholderCarousel() {
    // 清除已有定时器
    if (this.data.placeholderTimer) {
      clearInterval(this.data.placeholderTimer)
    }
    if (this.data.dishPlaceholderTimer) {
      clearInterval(this.data.dishPlaceholderTimer)
    }
    
    // 每 3 秒切换一次标题 placeholder
    const titleTimer = setInterval(() => {
      const nextIndex = (this.data.placeholderIndex + 1) % this.data.placeholders.length
      this.setData({
        placeholderIndex: nextIndex
      })
    }, 3000)
    
    // 每 3 秒切换一次菜品 placeholder（延迟 1.5 秒，错开切换）
    const dishTimer = setInterval(() => {
      const nextIndex = (this.data.dishPlaceholderIndex + 1) % this.data.dishPlaceholders.length
      this.setData({
        dishPlaceholderIndex: nextIndex
      })
    }, 3000)
    
    // 立即执行一次菜品 placeholder 切换（延迟 1.5 秒后）
    setTimeout(() => {
      const nextIndex = (this.data.dishPlaceholderIndex + 1) % this.data.dishPlaceholders.length
      this.setData({
        dishPlaceholderIndex: nextIndex
      })
    }, 1500)
    
    this.setData({
      placeholderTimer: titleTimer,
      dishPlaceholderTimer: dishTimer
    })
  },

  /**
   * 停止 placeholder 轮播
   */
  stopPlaceholderCarousel() {
    if (this.data.placeholderTimer) {
      clearInterval(this.data.placeholderTimer)
      this.setData({
        placeholderTimer: null
      })
    }
    if (this.data.dishPlaceholderTimer) {
      clearInterval(this.data.dishPlaceholderTimer)
      this.setData({
        dishPlaceholderTimer: null
      })
    }
  },

  /**
   * 触发动画（在合适的时机调用）
   */
  triggerAnimations() {
    // 检查是否需要显示 tips 动画
    const shouldShowTips = this.data.mode === 'detail' && 
                          this.data.isCreator === true && 
                          this.data.taskInfo && 
                          this.data.taskInfo.status !== 'finished' && 
                          !this.data.taskInfo.selectedDish
    
    // actions 动画：创建模式和详情模式都需要
    const shouldShowActions = true
    
    this.setData({
      showTipsAnimation: shouldShowTips,
      showActionsAnimation: shouldShowActions
    })
  },

  /**
   * 页面卸载
   */
  onUnload() {
    // 清理定时器
    this.stopPlaceholderCarousel()
    this.stopRefreshTimer()
  }
})

