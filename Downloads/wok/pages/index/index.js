// pages/index/index.js
import { getTasks, getTaskResult, randomSelectDish } from '../../utils/api.js'

Page({
  data: {
    userInfo: null,
    animationClass: 'cooking',  // 动画类名：'cooking' 表示炒菜动画
    activeParticipants: [],  // 进行中任务的参与者头像
    activeTaskIds: [],  // 进行中任务的ID列表（用于轮询）
    pollingTimer: null,  // 轮询定时器
    activeTask: null,  // 当前进行中的任务信息（用于显示 random-btn）
    randoming: false,  // 随机选择中状态
    tapPressed: false,  // 图标按下状态
    selectedResultText: null,  // 选中的结果文字
    resultTextChars: [],  // 结果文字拆分后的字符数组（用于动画显示）
    // 轮播文案
    slogans: [
      '这个不错 这锅不错～',
      '选好了 就要认哈～',
      '团建 聚会 年夜饭 咋选～',
      '每个人都有选择的机会～',
      '选择困难症的福音～',
      '铁锅出马 纷争不怕！',
      '选项堆成山，铁锅来把关！',
      '铁锅用的好，纷争自然少～',
      '这锅不错 下次还用～'
    ],
    sloganIndex: 0,  // 当前文案索引
    sloganText: '炒来炒去 铁锅定主意～',  // 当前显示的文案
    sloganVisible: true,  // 渐显动画状态
    sloganTimer: null  // 轮播定时器
  },

  onLoad() {
    this.loadUserInfo()
    // 页面加载时启动动画
    this.startAnimation()
    // 加载进行中的任务参与者
    this.loadActiveParticipants()
    // 开始轮询任务状态
    this.startPolling()
    // 检查是否有选中的结果文字
    this.loadSelectedResult()
  },

  onShow() {
    // 每次显示页面时刷新用户信息
    this.loadUserInfo()
    // 重新启动动画
    this.startAnimation()
    // 刷新进行中的任务参与者
    this.loadActiveParticipants()
    // 重新开始轮询
    this.startPolling()
    // 重新启动轮播文案
    this.startSloganCarousel()
    // 检查是否有选中的结果文字
    this.loadSelectedResult()
  },

  onHide() {
    // 页面隐藏时停止轮询
    this.stopPolling()
    // 停止轮播
    this.stopSloganCarousel()
  },

  onUnload() {
    // 页面卸载时停止轮询
    this.stopPolling()
    // 停止轮播
    this.stopSloganCarousel()
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
      const currentOpenid = (app.globalData && app.globalData.userInfo && app.globalData.userInfo.openid) || null
      
      if (!currentOpenid) {
        // 如果用户未登录，直接跳转到详情页（创建模式）
        wx.navigateTo({
          url: '/pages/task/detail/detail'
        })
        return
      }

      // 查找用户参与或创建的进行中任务（使用与 loadActiveParticipants 相同的逻辑）
      const result = await getTasks(0, 50)
      
      if (result && result.items) {
        // 找出用户参与或创建的进行中任务（与 loadActiveParticipants 逻辑一致）
        const activeTasks = result.items.filter(task => {
          if (task.status !== 'active') return false
          // 检查是否是创建者或参与者
          if (task.creatorOpenid === currentOpenid) return true
          if (task.participants && Array.isArray(task.participants)) {
            return task.participants.some(p => p.openid === currentOpenid)
          }
          return false
        })

        // 取第一个进行中的任务（如果有多个，优先显示最新的）
        const activeTask = activeTasks.length > 0 ? activeTasks[0] : null

        if (activeTask && activeTask.taskId) {
          // 有进行中的任务，跳转到详情页
          wx.navigateTo({
            url: `/pages/task/detail/detail?taskId=${activeTask.taskId}&shareCode=${activeTask.shareCode || ''}`
          })
        } else {
          // 没有进行中的任务，跳转到详情页（创建模式）
          wx.navigateTo({
            url: '/pages/task/detail/detail'
          })
        }
      } else {
        // 获取任务列表失败，默认跳转到详情页（创建模式）
        wx.navigateTo({
          url: '/pages/task/detail/detail'
        })
      }
    } catch (error) {
      console.error('检查任务失败:', error)
      // 出错时默认跳转到详情页（创建模式）
      wx.navigateTo({
        url: '/pages/task/detail/detail'
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
   * 跳转到任务详情页（用于随机选择按钮）
   */
  goToTaskDetail() {
    if (this.data.activeTask && this.data.activeTask.taskId) {
      wx.navigateTo({
        url: `/pages/task/detail/detail?taskId=${this.data.activeTask.taskId}&shareCode=${this.data.activeTask.shareCode || ''}`
      })
    }
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
   * 随机选择菜品（主页按钮）
   */
  async randomSelect() {
    if (!this.data.activeTask || !this.data.activeTask.taskId) {
      wx.showToast({
        title: '任务不存在',
        icon: 'none'
      })
      return
    }

    if (!this.data.activeTask.isCreator) {
      wx.showToast({
        title: '只有创建者可以随机选择',
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
      const result = await randomSelectDish(this.data.activeTask.taskId)
      if (result) {
        const selectedDish = result.selectedDish
        wx.showToast({
          title: selectedDish ? `已选择：${selectedDish}` : '选择成功',
          icon: 'success',
          duration: 2000
        })
        // 刷新任务状态和参与者列表
        setTimeout(() => {
          this.loadActiveParticipants()
        }, 500)
      }
    } catch (error) {
      console.error('[Index] 随机选择失败:', error)
      wx.showToast({
        title: error.message || '选择失败',
        icon: 'none'
      })
    } finally {
      this.setData({
        randoming: false
      })
    }
  },

  /**
   * 加载进行中任务的参与者头像
   */
  async loadActiveParticipants() {
    try {
      const result = await getTasks(0, 50) // 获取前50个任务
      if (result && result.items) {
        const app = getApp()
        const currentOpenid = (app.globalData && app.globalData.userInfo && app.globalData.userInfo.openid) || null
        
        // 找出用户参与或创建的进行中任务
        const activeTasks = result.items.filter(task => {
          if (task.status !== 'active') return false
          // 检查是否是创建者或参与者
          if (task.creatorOpenid === currentOpenid) return true
          if (task.participants && task.participants.some(p => p.openid === currentOpenid)) return true
          return false
        })

        // 保存进行中任务的ID列表，用于轮询
        const activeTaskIds = activeTasks.map(task => task.taskId)
        
        // 保存第一个进行中的任务信息（用于显示 random-btn）
        const activeTask = activeTasks.length > 0 ? activeTasks[0] : null
        const isCreator = activeTask && activeTask.creatorOpenid === currentOpenid
        
        this.setData({
          activeTaskIds: activeTaskIds,
          activeTask: activeTask ? {
            taskId: activeTask.taskId,
            shareCode: activeTask.shareCode,
            selectedDish: activeTask.selectedDish,
            isCreator: isCreator
          } : null
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
            // 多个头像时，随机分布（增加随机性）
            // 容器是350rpx，头像50rpx，有效半径约150rpx（350/2 - 50/2）
            // 完全随机角度和半径
            const angle = Math.random() * Math.PI * 2 // 0 到 2π 的随机角度
            const minRadius = 15 // 最小半径（中心附近）
            const maxRadius = 120 // 最大半径（外侧）
            const radius = minRadius + Math.random() * (maxRadius - minRadius) // 随机半径
            x = 50 + (Math.cos(angle) * radius / 175) * 50 // 转换为百分比，175是容器半径
            y = 50 + (Math.sin(angle) * radius / 175) * 50 // 转换为百分比
          }
          
          const finalX = Math.max(20, Math.min(80, x)) // 限制在 20-80% 范围内
          const finalY = Math.max(20, Math.min(80, y)) // 限制在 20-80% 范围内
          const finalDelay = Math.random() * 3 // 0-3秒的随机延迟（增加随机范围）
          const finalDuration = 4 + Math.random() * 2 // 4-6秒的随机动画时长（每个头像不同）
          
          return {
            avatar_url: p.avatar_url || p.avatarUrl || '',
            openid: p.openid,
            x: finalX,
            y: finalY,
            delay: finalDelay,
            duration: finalDuration,
            style: `animation-delay: ${finalDelay}s; animation-duration: ${finalDuration}s; left: ${finalX}%; top: ${finalY}%;`
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
  },

  /**
   * 开始轮询任务状态
   */
  startPolling() {
    // 清除之前的定时器
    this.stopPolling()
    
    // 如果没有进行中的任务，不需要轮询
    if (!this.data.activeTaskIds || this.data.activeTaskIds.length === 0) {
      return
    }

    // 每5秒轮询一次任务状态
    const timer = setInterval(() => {
      this.checkTaskStatus()
    }, 5000)

    this.setData({
      pollingTimer: timer
    })
  },

  /**
   * 停止轮询
   */
  stopPolling() {
    if (this.data.pollingTimer) {
      clearInterval(this.data.pollingTimer)
      this.setData({
        pollingTimer: null
      })
    }
  },

  /**
   * 检查任务状态（轮询）
   */
  async checkTaskStatus() {
    try {
      const activeTaskIds = this.data.activeTaskIds
      if (!activeTaskIds || activeTaskIds.length === 0) {
        return
      }

      // 检查所有进行中的任务状态
      const checkPromises = activeTaskIds.map(taskId => 
        getTaskResult(taskId).catch(err => {
          // 静默处理错误，不影响其他任务
          console.log(`[Index] 查询任务 ${taskId} 状态失败:`, err.message || err)
          return null
        })
      )

      const results = await Promise.all(checkPromises)
      
      // 检查是否有任务已完成
      let hasFinishedTask = false
      const stillActiveTaskIds = []
      
      results.forEach((result, index) => {
        if (result && result.status === 'finished') {
          hasFinishedTask = true
          console.log(`[Index] 任务 ${activeTaskIds[index]} 已完成，选择结果:`, result.selectedDish)
        } else if (result && result.status === 'active') {
          stillActiveTaskIds.push(activeTaskIds[index])
        }
      })

      // 如果有任务已完成，刷新参与者列表（会过滤掉已完成的任务）
      if (hasFinishedTask) {
        this.loadActiveParticipants()
      } else if (stillActiveTaskIds.length !== activeTaskIds.length) {
        // 更新进行中的任务ID列表
        this.setData({
          activeTaskIds: stillActiveTaskIds
        })
        // 如果所有任务都已完成，停止轮询
        if (stillActiveTaskIds.length === 0) {
          this.stopPolling()
        }
      }
    } catch (error) {
      console.error('[Index] 检查任务状态失败:', error)
      // 静默失败，不影响页面显示
    }
  },

  /**
   * 启动轮播文案
   */
  startSloganCarousel() {
    // 如果已有定时器，先清除
    if (this.data.sloganTimer) {
      clearInterval(this.data.sloganTimer)
    }
    // 每3秒切换一次文案
    const timer = setInterval(() => {
      this.switchSlogan()
    }, 3000)
    this.setData({
      sloganTimer: timer
    })
  },

  /**
   * 停止轮播文案
   */
  stopSloganCarousel() {
    if (this.data.sloganTimer) {
      clearInterval(this.data.sloganTimer)
      this.setData({
        sloganTimer: null
      })
    }
  },

  /**
   * 切换文案（带渐显动画）
   */
  switchSlogan() {
    // 先渐隐
    this.setData({
      sloganVisible: false
    })

    // 等待渐隐动画完成后切换文案并渐显
    setTimeout(() => {
      const nextIndex = (this.data.sloganIndex + 1) % this.data.slogans.length
      this.setData({
        sloganIndex: nextIndex,
        sloganText: this.data.slogans[nextIndex],
        sloganVisible: true
      })
    }, 300)  // 等待渐隐动画完成（动画时长的一半）
  },

  /**
   * 加载选中的结果文字
   */
  loadSelectedResult() {
    const app = getApp()
    if (app.globalData && app.globalData.selectedResultText) {
      const resultText = app.globalData.selectedResultText
      // 将结果文字拆分成字符数组，并计算每个字符的位置
      const chars = resultText.split('')
      const resultTextChars = chars.map((char, index) => {
        // 计算字符位置（类似"吃点啥"的布局，但根据字符数量动态调整）
        const totalChars = chars.length
        let left, top
        
        if (totalChars === 1) {
          // 单个字符居中
          left = 50
          top = 45
        } else if (totalChars === 2) {
          // 两个字符左右分布
          left = index === 0 ? 40 : 60
          top = 45
        } else if (totalChars === 3) {
          // 三个字符（类似"吃点啥"）
          const positions = [
            { left: 35, top: 34.3 },
            { left: 50, top: 39.3 },
            { left: 45, top: 49.3 }
          ]
          left = positions[index].left
          top = positions[index].top
        } else {
          // 多个字符：圆形分布
          const angle = (index / totalChars) * 2 * Math.PI - Math.PI / 2  // 从顶部开始
          const radius = 20  // 半径（百分比）
          left = 50 + radius * Math.cos(angle)
          top = 45 + radius * Math.sin(angle)
        }
        
        return {
          char: char,
          left: left,
          top: top,
          delay: index * 0.2  // 每个字符的动画延迟
        }
      })
      
      this.setData({
        selectedResultText: resultText,
        resultTextChars: resultTextChars
      })
    } else {
      // 没有结果文字，清空
      this.setData({
        selectedResultText: null,
        resultTextChars: []
      })
    }
  }
})

