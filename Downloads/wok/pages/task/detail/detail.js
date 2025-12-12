// pages/task/detail/detail.js
import { getTaskDetail, participateTask, randomSelectDish, getTaskByShareCode, createTask, subscribeTask, unsubscribeTask, getTaskSubscribeStatus } from '../../../utils/api.js'
import { getToken } from '../../../utils/storage.js'
import { requestSubscribeMessage, isAuthorized, getTemplateId } from '../../../utils/subscribeMessage.js'

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
    tipsSharePressed: false,  // Tips 分享按钮按下状态
    showResultMask: false,  // 显示结果遮罩
    selectedDishResult: '',  // 选中的菜品结果
    tipsImagePath: 'https://wemedev.com/wok/data/images/pic_tips.png',  // Tips 图片路径（默认使用网络URL）
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
    refreshTimer: null,  // 数据刷新定时器
    fromShare: false,  // 是否通过分享码进入
    hasParticipated: false,  // 用户是否已参与任务
    subscribeMessageEnabled: false  // 订阅消息开关状态
  },

  onLoad(options) {
    const { taskId, shareCode } = options
    if (shareCode) {
      // 通过分享码进入详情模式（从分享页进入）
      this.setData({ 
        mode: 'detail',
        fromShare: true,
        shareCode
      })
      this.loadTaskByShareCode(shareCode)
    } else if (taskId) {
      // 直接通过任务ID进入详情模式（从列表页进入）
      this.setData({ 
        mode: 'detail',
        taskId,
        fromShare: false  // 从列表页进入，不是分享
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

    // 初始化音频
    this.initAudio()
    
    // 如果是分享页，初始化订阅消息开关状态
    if (shareCode) {
      this.initSubscribeMessageStatus()
    }
    
    // 加载 tips 图片路径（延迟一点，确保主页预加载有时间完成）
    setTimeout(() => {
      this.loadTipsImage()
    }, 100)
  },

  /**
   * 页面显示时启动刷新定时器
   */
  onShow() {
    if (this.data.mode === 'detail' && this.data.taskId) {
      this.startRefreshTimer()
    }
    // 每次显示页面时重新加载 tips 图片路径（以防预加载完成）
    this.loadTipsImage()
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
    return returnData
  },

  /**
   * 加载任务详情
   */
  async loadTaskDetail() {
    try {
      const result = await getTaskDetail(this.data.taskId)
      
      if (result) {
        // 处理任务数据
        const processed = this.processTaskData(result)
        if (!processed) {
          throw new Error('处理任务数据失败')
        }
        
        // 合并 taskInfo，而不是完全替换，避免 content 卡片重新渲染
        const existingTaskInfo = this.data.taskInfo || {}
        const mergedTaskInfo = Object.assign({}, existingTaskInfo, processed.taskInfo)
        
        // 检查是否是第一次收到结果（从进行中变为已完成）
        const previousSelectedDish = this.data.taskInfo.selectedDish
        const previousStatus = this.data.taskInfo.status
        const newSelectedDish = mergedTaskInfo.selectedDish
        const newStatus = mergedTaskInfo.status
        
        // 如果之前没有结果，现在有结果了，说明是第一次收到结果
        const isFirstTimeResult = !previousSelectedDish && newSelectedDish && 
                                  (previousStatus !== 'finished' || !previousStatus) && 
                                  newStatus === 'finished'
        
        this.setData({
          taskInfo: mergedTaskInfo,
          isCreator: processed.isCreator,
          myDishes: processed.myDishes,
          shareCode: result.shareCode || this.data.shareCode,
          selectedDishResult: processed.selectedDishResult,
          allDishes: processed.allDishes || [],
          hasParticipated: processed.hasParticipated || false
        }, () => {
          // 如果是第一次收到结果，播放音频并显示结果遮罩
          if (isFirstTimeResult) {
            // 将结果保存到全局数据，供主页显示
            const app = getApp()
            if (app.globalData && newSelectedDish) {
              app.globalData.selectedResultText = newSelectedDish
            }
            // 显示结果遮罩
            this.setData({
              showResultMask: true
            }, () => {
              // 播放音频
              this.playResultAudio()
            })
          }
        })
        
        // 启动数据刷新定时器（仅在任务进行中）
        if (mergedTaskInfo.status !== 'finished' && !mergedTaskInfo.selectedDish) {
          this.startRefreshTimer()
        } else {
          this.stopRefreshTimer()
        }
        
        // 如果是分享页，初始化订阅消息状态
        if (this.data.fromShare) {
          this.initSubscribeMessageStatus()
        }
        
        // 延迟触发动画，让 content 卡片先稳定，同时确保 tipsImagePath 已设置
        setTimeout(() => {
          // 确保 tipsImagePath 已加载（如果还没有）
          const app = getApp()
          if (app.globalData && app.globalData.tipsImagePath && !this.data.tipsImagePath) {
            this.setData({
              tipsImagePath: app.globalData.tipsImagePath
            }, () => {
              this.triggerAnimations()
            })
          } else {
            this.triggerAnimations()
          }
        }, 150)
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
    let value = e.detail.value
    
    // 限制最大长度为50个字符
    if (value.length > 50) {
      value = value.substring(0, 50)
      wx.showToast({
        title: '最多输入50个字符',
        icon: 'none',
        duration: 1500
      })
    }
    
    // 检测特殊字符模式：连续的相同字符超过10个
    const consecutivePattern = /(.)\1{9,}/g
    if (consecutivePattern.test(value)) {
      // 移除连续的相同字符（保留前10个）
      value = value.replace(/(.)\1{9,}/g, (match, char) => {
        return char.repeat(10)
      })
      wx.showToast({
        title: '不能输入过多相同字符',
        icon: 'none',
        duration: 1500
      })
    }
    
    // 检测超长数字字符串：连续数字超过20个
    const longNumberPattern = /\d{21,}/g
    if (longNumberPattern.test(value)) {
      // 截断超长数字字符串
      value = value.replace(/\d{21,}/g, (match) => {
        return match.substring(0, 20)
      })
      wx.showToast({
        title: '数字不能超过20位',
        icon: 'none',
        duration: 1500
      })
    }
    
    this.setData({
      currentDish: value
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
        currentDish: '',
        hasParticipated: true  // 添加菜品后，用户已参与任务
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
          allDishes: processed.allDishes || [],  // 设置所有参与者的菜品列表
          hasParticipated: processed.hasParticipated || true,  // 创建者自动参与
          fromShare: false,  // 创建任务不是从分享进入
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
    console.log('[分享] onShareAppMessage 被调用')
    const shareCode = this.data.shareCode || (this.data.taskInfo && this.data.taskInfo.shareCode) || ''
    console.log('[分享] shareCode:', shareCode)
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
  onShareTouchStart(e) {
    console.log('[分享] onShareTouchStart 被调用', e)
    console.log('[分享] 当前 shareCode:', this.data.shareCode, 'taskInfo.shareCode:', this.data.taskInfo?.shareCode)
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
   * Tips 分享按钮按下
   */
  onTipsShareTouchStart(e) {
    console.log('[Tips分享] onTipsShareTouchStart 被调用', e)
    // 震动反馈
    wx.vibrateShort({
      type: 'light'
    })
    this.setData({
      tipsSharePressed: true
    })
  },

  /**
   * Tips 分享按钮释放
   */
  onTipsShareTouchEnd() {
    setTimeout(() => {
      this.setData({
        tipsSharePressed: false
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
        
        // 将结果保存到全局数据，供主页显示
        const app = getApp()
        if (app.globalData) {
          app.globalData.selectedResultText = dishValue
        }
        
        this.setData({
          'taskInfo.selectedDish': dishValue,
          'taskInfo.status': 'finished',
          selectedDishResult: dishValue,
          showResultMask: true
        }, () => {
          // 播放音频
          this.playResultAudio()
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
   * 阻止事件冒泡（用于结果卡片）
   */
  stopPropagation() {
    // 空方法，仅用于阻止事件冒泡
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
   * 加载 tips 图片路径
   */
  loadTipsImage() {
    const app = getApp()
    const tipsImageUrl = 'https://wemedev.com/wok/data/images/pic_tips.png'
    
    // 优先使用全局数据中缓存的图片路径
    if (app.globalData && app.globalData.tipsImagePath) {
      this.setData({
        tipsImagePath: app.globalData.tipsImagePath
      }, () => {
        // 重新触发动画检查
        this.triggerAnimations()
      })
    } else {
      // 如果没有缓存，使用网络URL（确保图片路径不为空）
      this.setData({
        tipsImagePath: tipsImageUrl
      }, () => {
        // 重新触发动画检查
        this.triggerAnimations()
      })
    }
    
    // 如果 tipsImagePath 仍然为空，强制设置为网络URL
    setTimeout(() => {
      if (!this.data.tipsImagePath) {
        this.setData({
          tipsImagePath: tipsImageUrl
        }, () => {
          this.triggerAnimations()
        })
      }
    }, 50)
  },

  /**
   * Tips 图片加载成功
   */
  onTipsImageLoad(e) {
    const detail = e.detail || {}
    console.log('[Tips图片] 图片加载成功', {
      path: this.data.tipsImagePath,
      width: detail.width,
      height: detail.height
    })
    // 确保动画状态正确
    if (!this.data.showTipsAnimation) {
      this.triggerAnimations()
    }
  },

  /**
   * Tips 图片加载失败
   */
  onTipsImageError(e) {
    // 如果本地路径加载失败，使用网络URL作为备用
    const tipsImageUrl = 'https://wemedev.com/wok/data/images/pic_tips.png'
    this.setData({
      tipsImagePath: tipsImageUrl
    })
  },

  /**
   * 初始化音频
   */
  initAudio() {
    try {
      const audioContext = wx.createInnerAudioContext()
      audioContext.src = 'https://wemedev.com/wok/data/images/audio_done.MP3' // 尝试使用网络路径
      audioContext.volume = 1.0
      this.audioReady = false // 初始化为未准备好
      
      audioContext.onPlay(() => {
        console.log('[Audio] 开始播放')
      })
      
      audioContext.onCanplay(() => {
        console.log('[Audio] 音频可以播放')
        this.audioReady = true // 音频准备好
      })
      
      audioContext.onWaiting(() => {
        console.log('[Audio] 音频加载中...')
      })
      
      audioContext.onEnded(() => {
        console.log('[Audio] 播放结束')
      })
      
      audioContext.onError((res) => {
        console.error('[Audio] 播放失败:', res)
        console.error('[Audio] 错误详情:', JSON.stringify(res))
        // 如果网络路径失败，尝试回退到本地路径
        if (audioContext.src === 'https://wemedev.com/wok/data/images/audio_done.MP3') {
          console.warn('[Audio] 网络音频加载失败，尝试使用本地路径')
          audioContext.src = '/images/audio_done.MP3'
          audioContext.play() // 尝试播放本地音频
        }
      })
      
      this.audioContext = audioContext
      console.log('[Audio] 音频上下文初始化成功，src:', audioContext.src)
    } catch (error) {
      console.error('[Audio] 初始化失败:', error)
    }
  },

  /**
   * 播放结果音频
   */
  playResultAudio() {
    console.log('[Audio] 尝试播放音频')
    if (this.audioContext) {
      console.log('[Audio] 音频状态 - src:', this.audioContext.src)
      console.log('[Audio] 音频状态 - volume:', this.audioContext.volume)
      
      if (this.audioReady) {
        try {
          this.audioContext.stop() // 播放前先停止，确保从头开始
          this.audioContext.seek(0)
          this.audioContext.play()
          console.log('[Audio] 播放命令已发送')
        } catch (error) {
          console.error('[Audio] 播放异常:', error)
        }
      } else {
        console.warn('[Audio] 音频未准备好，等待 onCanplay 后播放')
        // 设置一个超时，如果5秒内没有 onCanplay，则强制播放
        const timeout = setTimeout(() => {
          if (!this.audioReady) {
            console.warn('[Audio] 音频加载超时，强制播放')
            try {
              this.audioContext.stop()
              this.audioContext.seek(0)
              this.audioContext.play()
            } catch (error) {
              console.error('[Audio] 强制播放异常:', error)
            }
          }
        }, 5000)
        
        this.audioContext.onCanplay(() => {
          clearTimeout(timeout) // 清除超时
          if (!this.audioContext.paused) { // 避免重复播放
            this.audioContext.stop()
          }
          this.audioContext.seek(0)
          this.audioContext.play()
          console.log('[Audio] onCanplay 触发，开始播放')
        })
      }
    } else {
      console.warn('[Audio] 音频上下文不存在，尝试重新初始化')
      this.initAudio()
      setTimeout(() => {
        this.playResultAudio() // 延迟播放，等待初始化完成
      }, 500)
    }
  },

  /**
   * 初始化订阅消息开关状态
   */
  async initSubscribeMessageStatus() {
    if (!this.data.taskId) {
      console.log('[订阅消息] 任务ID不存在，跳过初始化')
      // 默认关闭
      this.setData({
        subscribeMessageEnabled: false
      })
      return
    }
    
    try {
      // 查询后端订阅状态
      const status = await getTaskSubscribeStatus(this.data.taskId)
      console.log('[订阅消息] 后端订阅状态:', status)
      
      // 后端返回格式：{ subscribed: true/false }
      const subscribed = status.subscribed === true
      this.setData({
        subscribeMessageEnabled: subscribed
      })
      console.log('[订阅消息] 初始化开关状态:', subscribed)
    } catch (error) {
      console.error('[订阅消息] 查询订阅状态失败:', error)
      // 如果查询失败，默认关闭（不订阅）
      // 404表示没有订阅记录，这是正常的，应该关闭
      if (error.message && error.message.includes('资源不存在')) {
        console.log('[订阅消息] 没有订阅记录，默认关闭')
      }
      this.setData({
        subscribeMessageEnabled: false
      })
      console.log('[订阅消息] 默认关闭开关状态')
    }
  },

  /**
   * 订阅消息开关变化处理
   */
  onSubscribeSwitchChange(e) {
    const enabled = e.detail.value
    console.log('[订阅消息] 开关状态变化:', enabled)
    
    if (enabled) {
      // 开启订阅消息，请求授权
      // 注意：微信订阅消息授权是一次性的，每次都需要重新授权
      // 即使之前授权过，再次调用 wx.requestSubscribeMessage 也会弹出授权弹窗
      this.requestSubscribeAuth()
    } else {
      // 关闭订阅消息，调用后端接口取消订阅
      this.cancelSubscribe()
    }
  },

  /**
   * 请求订阅消息授权
   * 注意：微信订阅消息授权是一次性的，每次调用 wx.requestSubscribeMessage 都会弹出授权弹窗
   * 即使之前授权过，再次调用也会弹出授权弹窗，这是微信的机制
   */
  requestSubscribeAuth() {
    console.log('[订阅消息] 开始请求订阅消息授权')
    
    if (!this.data.taskId) {
      console.error('[订阅消息] 任务ID不存在，无法订阅')
      this.setData({
        subscribeMessageEnabled: false
      })
      return
    }
    
    // 检查基础库版本
    if (!wx.canIUse('requestSubscribeMessage')) {
      wx.showModal({
        title: '提示',
        content: '当前微信版本过低，不支持订阅消息功能，请升级微信版本',
        showCancel: false
      })
      // 恢复开关状态
      this.setData({
        subscribeMessageEnabled: false
      })
      return
    }
    
    // 获取模板ID
    const templateId = getTemplateId()
    
    // 先请求微信授权（每次调用都会弹出授权弹窗，这是微信的机制）
    // 注意：即使之前授权过，再次调用也会弹出授权弹窗
    // 如果用户之前选择了"总是保持以上选择"，不会再次弹出，但可以正常完整授权
    requestSubscribeMessage([templateId])
      .then(result => {
        console.log('[订阅消息] 微信授权请求成功，结果:', result)
        if (result.authorized) {
          console.log('[订阅消息] 用户已授权，开始调用后端接口保存订阅关系')
          // 用户同意授权，调用后端接口保存订阅关系
          return subscribeTask(this.data.taskId, templateId)
            .then(() => {
              // 后端保存成功
              console.log('[订阅消息] 后端保存订阅关系成功')
              this.setData({
                subscribeMessageEnabled: true
              })
              wx.showToast({
                title: '已授权',
                icon: 'success',
                duration: 1500
              })
            })
            .catch(err => {
              console.error('[订阅消息] 后端保存订阅关系失败:', err)
              // 恢复开关状态
              this.setData({
                subscribeMessageEnabled: false
              })
              wx.showToast({
                title: '授权失败',
                icon: 'none',
                duration: 1500
              })
              throw err
            })
        } else {
          console.log('[订阅消息] 用户未授权')
          // 恢复开关状态
          this.setData({
            subscribeMessageEnabled: false
          })
          
          const results = result.results || {}
          const templateIds = Object.keys(results)
          if (templateIds.length > 0) {
            const firstResult = results[templateIds[0]]
            if (firstResult === 'reject') {
              wx.showToast({
                title: '授权失败',
                icon: 'none',
                duration: 1500
              })
            } else {
              wx.showToast({
                title: '授权失败',
                icon: 'none',
                duration: 1500
              })
            }
          } else {
            wx.showToast({
              title: '授权失败',
              icon: 'none',
              duration: 1500
            })
          }
          throw new Error('用户未授权')
        }
      })
      .catch(err => {
        console.error('[订阅消息] 订阅失败:', err)
        
        // 如果已经显示过toast（用户未授权的情况），不再重复显示
        if (err.message === '用户未授权') {
          return
        }
        
        // 恢复开关状态
        this.setData({
          subscribeMessageEnabled: false
        })
        
        if (err.errMsg) {
          let errorMsg = '授权失败'
          if (err.errMsg.includes('template')) {
            errorMsg = '授权失败'
          } else if (err.errMsg.includes('can only be invoked by user TAP gesture')) {
            errorMsg = '授权失败'
          }
          wx.showToast({
            title: errorMsg,
            icon: 'none',
            duration: 1500
          })
        } else if (err.message && err.message !== '用户未授权') {
          wx.showToast({
            title: '授权失败',
            icon: 'none',
            duration: 1500
          })
        } else {
          wx.showToast({
            title: '授权失败',
            icon: 'none',
            duration: 1500
          })
        }
      })
  },

  /**
   * 取消订阅
   */
  async cancelSubscribe() {
    if (!this.data.taskId) {
      console.error('[订阅消息] 任务ID不存在，无法取消订阅')
      // 直接关闭开关
      this.setData({
        subscribeMessageEnabled: false
      })
      return
    }
    
    try {
      console.log('[订阅消息] 开始取消订阅')
      await unsubscribeTask(this.data.taskId)
      console.log('[订阅消息] 取消订阅成功')
      this.setData({
        subscribeMessageEnabled: false
      })
      wx.showToast({
        title: '已关闭消息通知',
        icon: 'success',
        duration: 1500
      })
    } catch (error) {
      console.error('[订阅消息] 取消订阅失败:', error)
      
      // 如果是404（资源不存在），说明本来就没有订阅记录，这是正常的
      if (error.message && error.message.includes('资源不存在')) {
        console.log('[订阅消息] 没有订阅记录，正常关闭')
        this.setData({
          subscribeMessageEnabled: false
        })
        wx.showToast({
          title: '已关闭消息通知',
          icon: 'success',
          duration: 1500
        })
        return
      }
      
      // 其他错误，也更新本地状态为关闭
      this.setData({
        subscribeMessageEnabled: false
      })
      wx.showToast({
        title: '已关闭消息通知',
        icon: 'success',
        duration: 1500
      })
    }
  },

  /**
   * 页面卸载
   */
  onUnload() {
    // 清理定时器
    this.stopPlaceholderCarousel()
    this.stopRefreshTimer()
    // 销毁音频上下文
    if (this.audioContext) {
      this.audioContext.destroy()
      this.audioContext = null
      console.log('[Audio] 音频上下文已销毁')
    }
  }
})

