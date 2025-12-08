// pages/index/index.js
import { getTasks, getTaskResult, randomSelectDish, getBanners } from '../../utils/api.js'
const imageCache = require('../../utils/imageCache.js')

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
    sloganTimer: null,  // 轮播定时器
    // 广告图相关
    banners: [],  // 广告图列表
    currentBanner: null,  // 当前显示的广告图
    showAdImage: false,  // 是否显示广告图
    adImagePath: '',  // 广告图本地路径
    adImageAnimating: false,  // 广告图动画状态
    adImageWidth: null,  // 广告图宽度（rpx，自动适配）
    adImageHeight: null,  // 广告图高度（rpx，自动适配）
    adClickType: 'none',  // 广告点击类型：none, page, url, miniprogram
    adClickData: null  // 广告点击数据（包含 path, url, appId 等）
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
    // 加载广告配置
    this.loadAdConfig()
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
      // 将结果文字拆分成字符数组，使用 Array.from() 正确处理 Unicode 字符（包括 emoji）
      const chars = Array.from(resultText)
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
          left: left + '%',  // 直接包含 % 符号，避免 WXML 解析问题
          top: top + '%',    // 直接包含 % 符号，避免 WXML 解析问题
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
  },

  /**
   * 加载广告图列表
   */
  async loadAdConfig() {
    try {
      const banners = await getBanners()
      console.log('[广告图] 获取广告图列表成功', banners)
      
      // 只处理 enabled: true 的广告图，按 order 排序
      const enabledBanners = banners
        .filter(banner => banner.enabled === true)
        .sort((a, b) => {
          // 先按 order 升序，相同 order 按创建时间倒序
          if (a.order !== b.order) {
            return a.order - b.order
          }
          const aTime = new Date(a.createdAt || 0).getTime()
          const bTime = new Date(b.createdAt || 0).getTime()
          return bTime - aTime
        })
      
      this.setData({
        banners: enabledBanners
      })
      
      // 如果有广告图，加载第一个
      if (enabledBanners.length > 0) {
        const firstBanner = enabledBanners[0]
        this.processBanner(firstBanner)
      } else {
        console.log('[广告图] 没有启用的广告图')
      }
    } catch (error) {
      console.error('[广告图] 加载广告图列表失败', error)
      // 失败时不显示广告，不阻塞应用
    }
  },

  /**
   * 处理单个广告图
   */
  processBanner(banner) {
    console.log('[广告图] 处理广告图', banner)
    
    if (!banner || !banner.url) {
      console.warn('[广告图] 广告图数据无效', banner)
      return
    }
    
    // 更新广告点击配置
    this.setData({
      currentBanner: banner,
      adClickType: banner.clickType || 'none',
      adClickData: banner.clickData || null
    })
    
    // 加载广告图
    this.loadAdImage(banner.url)
  },

  /**
   * 加载广告图（参考 Festival 的逻辑：第一次下载，下次启动才显示）
   */
  loadAdImage(imageUrl) {
    if (!imageUrl) {
      console.warn('[广告图] URL为空')
      return
    }

    console.log('[广告图] 开始加载', imageUrl)

    // 先检查本地缓存
    imageCache.getCachedImagePath(imageUrl).then(cachedPath => {
      console.log('[广告图] 缓存检查结果:', cachedPath)
      if (cachedPath) {
        // 有缓存，直接显示
        console.log('[广告图] 使用缓存的广告图', cachedPath)
        this.showAdImage(cachedPath)
      } else {
        // 无缓存，后台静默下载，不显示（参考 Festival 的逻辑）
        console.log('[广告图] 无缓存，后台静默下载，不显示', imageUrl)
        
        // 后台下载并缓存（不显示）
        imageCache.downloadAndCacheImage(imageUrl).then(localPath => {
          console.log('[广告图] 下载并缓存成功，下次启动时会显示', localPath)
          // 不显示，只在后台下载
        }).catch(err => {
          console.error('[广告图] 下载失败', err)
        })
      }
    }).catch(err => {
      console.error('[广告图] 检查缓存失败', err)
      // 出错时不显示，尝试后台下载
      imageCache.downloadAndCacheImage(imageUrl).then(localPath => {
        console.log('[广告图] 下载并缓存成功（重试），下次启动时会显示', localPath)
        // 不显示，只在后台下载
      }).catch(downloadErr => {
        console.error('[广告图] 下载失败（重试）', downloadErr)
      })
    })
  },

  /**
   * 显示广告图
   */
  showAdImage(imagePath) {
    console.log('[广告图] 准备显示', imagePath)
    if (!imagePath) {
      console.warn('[广告图] 路径为空')
      return
    }
    
    // 验证本地文件路径是否存在（如果是本地路径）
    if (imagePath.startsWith('http://store/') || imagePath.startsWith('wxfile://') || !imagePath.startsWith('http')) {
      const fs = wx.getFileSystemManager()
      try {
        // 尝试访问文件，验证路径是否有效
        fs.accessSync(imagePath)
        console.log('[广告图] 本地文件路径有效', imagePath)
      } catch (e) {
        console.warn('[广告图] 本地文件路径无效，尝试使用网络URL', imagePath, e)
        // 如果本地路径无效，尝试从当前广告图数据中获取原始网络URL
        const { currentBanner } = this.data
        if (currentBanner && currentBanner.url) {
          console.log('[广告图] 使用网络URL作为备用', currentBanner.url)
          imagePath = currentBanner.url
        }
        this.doShowAdImage(imagePath)
        return
      }
    }
    
    this.doShowAdImage(imagePath)
  },

  /**
   * 执行显示广告图
   */
  doShowAdImage(imagePath) {
    console.log('[广告图] 执行显示，设置数据', {
      adImagePath: imagePath,
      showAdImage: true,
      adImageAnimating: false
    })
    
    // 先设置图片路径和显示状态，同时立即设置动画状态
    this.setData({
      adImagePath: imagePath,
      showAdImage: true,
      adImageAnimating: false // 先设置为false
    }, () => {
      console.log('[广告图] setData回调执行，当前状态:', {
        adImagePath: this.data.adImagePath,
        showAdImage: this.data.showAdImage,
        adImageAnimating: this.data.adImageAnimating
      })
      
      // DOM渲染完成后立即触发动画
      setTimeout(() => {
        this.setData({
          adImageAnimating: true
        })
        console.log('[广告图] 动画已触发，最终状态:', {
          adImagePath: this.data.adImagePath,
          showAdImage: this.data.showAdImage,
          adImageAnimating: this.data.adImageAnimating
        })
      }, 50) // 减少延迟，快速显示
    })
  },

  /**
   * 关闭广告图
   */
  closeAdImage() {
    this.setData({
      adImageAnimating: false
    })
    
    // 动画结束后隐藏
    setTimeout(() => {
      this.setData({
        showAdImage: false,
        adImagePath: '',
        adImageWidth: null, // 清除尺寸
        adImageHeight: null // 清除尺寸
      })
    }, 300)
  },

  /**
   * 广告图加载成功
   */
  onAdImageLoad(e) {
    const detail = e.detail || {}
    const imageWidth = detail.width || 0
    const imageHeight = detail.height || 0
    
    console.log('[广告图] 图片加载成功', {
      detail: detail,
      width: imageWidth,
      height: imageHeight
    })
    
    // 自动适配图片尺寸
    if (imageWidth > 0 && imageHeight > 0) {
      this.adaptImageSize(imageWidth, imageHeight)
    }
  },

  /**
   * 自动适配图片尺寸
   */
  adaptImageSize(imageWidth, imageHeight) {
    const systemInfo = wx.getSystemInfoSync()
    const screenWidth = systemInfo.windowWidth // px
    const screenHeight = systemInfo.windowHeight // px
    
    // 计算可用显示区域（留出边距）
    const maxDisplayWidth = screenWidth * 0.9 // 90% 屏幕宽度
    const maxDisplayHeight = screenHeight * 0.8 // 80% 屏幕高度
    
    // 计算缩放比例，保持宽高比
    const scaleX = maxDisplayWidth / imageWidth
    const scaleY = maxDisplayHeight / imageHeight
    const scale = Math.min(scaleX, scaleY, 1) // 不放大，只缩小
    
    // 计算适配后的尺寸（转换为 rpx：1px = 2rpx）
    const adaptedWidth = Math.round(imageWidth * scale * 2)
    const adaptedHeight = Math.round(imageHeight * scale * 2)
    
    console.log('[广告图] 自动适配尺寸', {
      原始尺寸: `${imageWidth}x${imageHeight}`,
      屏幕尺寸: `${screenWidth}x${screenHeight}`,
      最大显示区域: `${maxDisplayWidth}x${maxDisplayHeight}`,
      缩放比例: scale,
      适配后尺寸: `${adaptedWidth}rpx x ${adaptedHeight}rpx`
    })
    
    // 动态设置图片尺寸
    this.setData({
      adImageWidth: adaptedWidth,
      adImageHeight: adaptedHeight
    })
  },

  /**
   * 广告图加载失败
   */
  onAdImageError(e) {
    console.error('[广告图] 图片加载失败', {
      error: e,
      path: this.data.adImagePath
    })
    
    // 如果本地路径加载失败，尝试使用网络URL
    const currentPath = this.data.adImagePath
    if (currentPath && (currentPath.startsWith('http://store/') || currentPath.startsWith('wxfile://') || !currentPath.startsWith('http'))) {
      // 如果是本地路径但加载失败，使用网络URL作为备用
      console.log('[广告图] 本地图片加载失败，尝试使用网络URL')
      // 如果本地路径无效，尝试使用网络URL
      const { currentBanner } = this.data
      if (currentBanner && currentBanner.url) {
        console.log('[广告图] 图片加载失败，尝试使用网络URL', currentBanner.url)
        this.setData({
          adImagePath: currentBanner.url
        })
      } else {
        console.warn('[广告图] 图片加载失败且无备用URL')
      }
    }
  },

  /**
   * 广告图点击事件
   */
  onAdImageClick(e) {
    const { adClickType, adClickData, currentBanner } = this.data
    
    console.log('[广告图] 点击事件', {
      adClickType,
      adClickData,
      currentBanner
    })
    
    // 先关闭广告图
    this.closeAdImage()
    
    // 根据点击类型执行不同操作
    switch (adClickType) {
      case 'none':
        // 无跳转，只关闭广告图
        console.log('[广告图] 点击类型：无跳转')
        break
        
      case 'page':
        // 跳转到小程序页面
        if (adClickData && adClickData.path) {
          const pagePath = adClickData.path
          console.log('[广告图] 跳转到小程序页面:', pagePath)
          setTimeout(() => {
            wx.navigateTo({
              url: pagePath.startsWith('/') ? pagePath : `/${pagePath}`,
              fail: (err) => {
                console.error('[广告图] 页面跳转失败', err)
                // 尝试使用 reLaunch
                wx.reLaunch({
                  url: pagePath.startsWith('/') ? pagePath : `/${pagePath}`,
                  fail: (reLaunchErr) => {
                    console.error('[广告图] reLaunch 跳转失败', reLaunchErr)
                  }
                })
              }
            })
          }, 300) // 等待关闭动画完成
        } else {
          console.warn('[广告图] 页面路径为空')
        }
        break
        
      case 'url':
        // 跳转到网页
        if (adClickData && adClickData.url) {
          const targetUrl = adClickData.url
          console.log('[广告图] 跳转到网页:', targetUrl)
          setTimeout(() => {
            // 检查URL格式
            let finalUrl = targetUrl
            if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
              finalUrl = 'https://' + finalUrl
            }
            
            // 跳转到 webview 页面
            wx.navigateTo({
              url: `/pages/webview/webview?url=${encodeURIComponent(finalUrl)}`,
              fail: (err) => {
                console.error('[广告图] 跳转webview失败', err)
                // 如果webview页面不存在，尝试复制链接到剪贴板
                wx.setClipboardData({
                  data: finalUrl,
                  success: () => {
                    wx.showToast({
                      title: '链接已复制',
                      icon: 'success'
                    })
                  }
                })
              }
            })
          }, 300)
        } else {
          console.warn('[广告图] 网页URL为空')
        }
        break
        
      case 'miniprogram':
        // 跳转到其他小程序
        if (adClickData && adClickData.appId) {
          console.log('[广告图] 跳转到其他小程序:', adClickData)
          setTimeout(() => {
            wx.navigateToMiniProgram({
              appId: adClickData.appId,
              path: adClickData.path || '',
              extraData: adClickData.extraData || {},
              success: (res) => {
                console.log('[广告图] 跳转小程序成功', res)
              },
              fail: (err) => {
                console.error('[广告图] 跳转小程序失败', err)
                wx.showToast({
                  title: '跳转失败',
                  icon: 'none'
                })
              }
            })
          }, 300)
        } else {
          console.warn('[广告图] 小程序配置为空或缺少 appId')
        }
        break
        
      default:
        console.warn('[广告图] 未知的点击类型:', adClickType)
        break
    }
  },

  /**
   * 阻止事件冒泡
   */
  stopPropagation() {
    // 空函数，用于阻止事件冒泡
  }
})

