// pages/task/create/create.js
import { createTask, participateTask } from '../../../utils/api.js'

Page({
  data: {
    title: '',
    currentDish: '',
    dishes: [],
    creating: false
  },

  onLoad() {
    // 页面加载，设置默认标题
    this.setData({
      title: '今天吃什么？'
    })
  },

  /**
   * 标题输入
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
  addDish() {
    const dish = this.data.currentDish.trim()
    if (!dish) {
      wx.showToast({
        title: '请输入菜品名称',
        icon: 'none'
      })
      return
    }

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
  },

  /**
   * 移除菜品
   */
  removeDish(e) {
    const index = e.currentTarget.dataset.index
    const dishes = this.data.dishes
    dishes.splice(index, 1)
    this.setData({
      dishes: dishes
    })
  },

  /**
   * 创建任务
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
        // 创建成功后，先参与任务（提交菜品）
        try {
          await participateTask(result.taskId, this.data.dishes)
        } catch (e) {
          console.log('参与任务失败，但任务已创建:', e)
        }

        // 跳转到任务详情页
        wx.redirectTo({
          url: `/pages/task/detail/detail?taskId=${result.taskId}&shareCode=${result.shareCode}`
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
  }
})

