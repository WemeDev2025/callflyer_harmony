// pages/preview/preview.js
const dataManager = require('../../utils/dataManager');

Page({
  data: {
    workCardData: null,
    createTimeText: '',
    cardType: 'work', // work 或 hire
    publishing: false
  },

  onLoad(options) {
    // 获取卡片类型
    const type = options.type || 'work';
    this.setData({
      cardType: type
    });
    
    // 动态设置导航栏标题
    wx.setNavigationBarTitle({
      title: type === 'hire' ? '预览需求' : '预览工作卡'
    });
    
    if (type === 'hire') {
      this.loadHireData();
    } else {
      this.loadWorkCardData();
    }
  },

  onShow() {
    // 页面显示时刷新数据，确保编辑后的数据能正确显示
    if (this.data.cardType === 'hire') {
      this.loadHireData();
    } else {
      this.loadWorkCardData();
    }
  },

  // 加载工作卡数据
  async loadWorkCardData() {
    try {
      const result = await dataManager.workCard.getMy();
      
      if (result.success && result.data) {
        console.log('📋 预览页面获取工作卡数据:', result.data);
        console.log('📊 数据类型:', typeof result.data);
        console.log('📊 是否为数组:', Array.isArray(result.data));
        
        // 处理不同的数据结构
        let workCardData;
        if (Array.isArray(result.data) && result.data.length > 0) {
          // 如果是数组，取第一个
          workCardData = result.data[0];
          console.log('✅ 使用数组第一个元素:', workCardData);
        } else if (result.data && typeof result.data === 'object') {
          // 如果是对象，直接使用
          workCardData = result.data;
          console.log('✅ 直接使用对象数据:', workCardData);
        } else {
          workCardData = null;
          console.log('❌ 数据格式不正确，设置为null');
        }
        
        if (workCardData) {
          console.log('✅ 设置工作卡数据到页面:', workCardData);
          console.log('📝 其他要求字段值:', workCardData.otherRequirements);
          console.log('📝 其他要求字段类型:', typeof workCardData.otherRequirements);
          console.log('📝 其他要求字段是否为空:', !workCardData.otherRequirements);
          console.log('📝 其他要求字段长度:', workCardData.otherRequirements ? workCardData.otherRequirements.length : 0);
          console.log('📝 完整工作卡数据结构:', JSON.stringify(workCardData, null, 2));
          this.setData({
            workCardData: workCardData,
            createTimeText: workCardData.createTime ? this.formatTime(workCardData.createTime) : '刚刚'
          });
        } else {
          // 没有数据，显示提示并返回
          wx.showToast({
            title: '未找到工作卡数据',
            icon: 'none'
          });
          setTimeout(() => {
            wx.navigateBack();
          }, 2000);
        }
      } else {
        // API失败时尝试从本地存储获取
        const localData = wx.getStorageSync('workCardData');
        if (localData) {
          this.setData({
            workCardData: localData,
            createTimeText: this.formatTime(localData.createTime)
          });
        } else {
          wx.showToast({
            title: result.message || '未找到工作卡数据',
            icon: 'none'
          });
          setTimeout(() => {
            wx.navigateBack();
          }, 2000);
        }
      }
    } catch (error) {
      console.error('加载工作卡数据失败:', error);
      // 网络失败时尝试从本地存储获取
      const localData = wx.getStorageSync('workCardData');
      if (localData) {
        this.setData({
          workCardData: localData,
          createTimeText: this.formatTime(localData.createTime)
        });
      } else {
        wx.showToast({
          title: '加载失败',
          icon: 'none'
        });
        setTimeout(() => {
          wx.navigateBack();
        }, 2000);
      }
    }
  },

  // 加载养老请人数据
  async loadHireData() {
    try {
      const result = await dataManager.hireRequirement.getMy();
      
      if (result.success && result.data) {
        const hireData = result.data;
        // 将养老请人数据转换为工作卡格式，复用样式
        const workCardData = {
          name: hireData.contactName,
          phone: hireData.contactPhone,
          avatarUrl: '',
          skills: hireData.services,
          certs: hireData.certs,
          otherRequirements: hireData.otherRequirements,
          createTime: hireData.createTime,
          type: 'hire' // 标记为养老请人类型
        };
        
        this.setData({
          workCardData: workCardData,
          createTimeText: hireData.createTime
        });
      } else {
        // API失败时尝试从本地存储获取
        const localData = wx.getStorageSync('hireData');
        if (localData) {
          const workCardData = {
            name: localData.contactName,
            phone: localData.contactPhone,
            avatarUrl: '',
            skills: localData.services,
            certs: localData.certs,
            otherRequirements: localData.otherRequirements,
            createTime: localData.createTime,
            type: 'hire'
          };
          
          this.setData({
            workCardData: workCardData,
            createTimeText: localData.createTime
          });
        } else {
          wx.showToast({
            title: result.message || '未找到需求数据',
            icon: 'none'
          });
          setTimeout(() => {
            wx.navigateBack();
          }, 2000);
        }
      }
    } catch (error) {
      console.error('加载养老需求数据失败:', error);
      // 网络失败时尝试从本地存储获取
      const localData = wx.getStorageSync('hireData');
      if (localData) {
        const workCardData = {
          name: localData.contactName,
          phone: localData.contactPhone,
          avatarUrl: '',
          skills: localData.services,
          certs: localData.certs,
          otherRequirements: localData.otherRequirements,
          createTime: localData.createTime,
          type: 'hire'
        };
        
        this.setData({
          workCardData: workCardData,
          createTimeText: localData.createTime
        });
      } else {
        wx.showToast({
          title: '加载失败',
          icon: 'none'
        });
        setTimeout(() => {
          wx.navigateBack();
        }, 2000);
      }
    }
  },

  // 格式化时间
  formatTime(timeString) {
    const date = new Date(timeString);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  },

  // 编辑工作卡/需求
  editCard() {
    // 检查页面栈，判断是从哪个路径进入的预览页面
    const pages = getCurrentPages();
    const prevPage = pages[pages.length - 2];
    
    if (this.data.cardType === 'hire') {
      // 养老请人逻辑
      if (prevPage && prevPage.route === 'pages/hire/hire') {
        // 如果上一页是养老请人编辑页面，说明是新建流程，直接返回
        wx.navigateBack();
      } else {
        // 如果上一页不是养老请人编辑页面，说明是已有需求，打开编辑页面
        wx.navigateTo({
          url: '/pages/hire/hire?edit=true'
        });
      }
    } else {
      // 工作卡逻辑
      if (prevPage && prevPage.route === 'pages/work-card/work-card') {
        // 如果上一页是工作卡编辑页面，说明是新建流程，直接返回
        wx.navigateBack();
      } else {
        // 如果上一页不是工作卡编辑页面，说明是已有工作卡，打开编辑页面
        wx.navigateTo({
          url: '/pages/work-card/work-card?edit=true'
        });
      }
    }
  },

  // 发布工作卡/需求
  async publishCard() {
    // 防止重复发布
    if (this.data.publishing) {
      return;
    }

    const title = this.data.cardType === 'hire' ? '发布需求' : '发布工作卡';
    const content = this.data.cardType === 'hire' ? 
      '确定要发布您的养老需求吗？发布后护理员可以看到您的需求。' : 
      '确定要发布您的工作卡吗？发布后其他用户可以看到您的信息。';
    
    wx.showModal({
      title: title,
      content: content,
      showCancel: true,
      cancelText: '取消',
      confirmText: '发布',
      success: async (res) => {
        if (res.confirm) {
          await this.doPublish();
        }
      }
    });
  },

  // 执行发布
  async doPublish() {
    this.setData({ publishing: true });

    try {
      wx.showLoading({ title: '发布中...' });

      let result;
      if (this.data.cardType === 'hire') {
        // 发布养老需求
        result = await dataManager.hireRequirement.publish(this.data.workCardData.id);
      } else {
        // 发布工作卡
        result = await dataManager.workCard.publish(this.data.workCardData.id);
      }

      if (result.success) {
        wx.hideLoading();
        wx.showToast({
          title: this.data.cardType === 'hire' ? '需求发布成功' : '发布成功',
          icon: 'success',
          duration: 2000,
          success: () => {
            setTimeout(() => {
              wx.redirectTo({
              url: '/pages/elderly/elderly'
            });
            }, 2000);
          }
        });
      } else {
        wx.hideLoading();
        wx.showToast({
          title: result.message || '发布失败',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('发布失败:', error);
      wx.hideLoading();
      wx.showToast({
        title: '发布失败，请重试',
        icon: 'none'
      });
    } finally {
      this.setData({ publishing: false });
    }
  },

  // 保存到相册
  saveToAlbum() {
    wx.showLoading({
      title: '生成图片中...'
    });

    // 这里应该使用canvas生成图片，简化处理
    setTimeout(() => {
      wx.hideLoading();
      wx.showToast({
        title: '保存成功',
        icon: 'success'
      });
    }, 2000);
  },

  // 分享给朋友
  shareToFriend() {
    wx.showToast({
      title: '请使用右上角分享功能',
      icon: 'none'
    });
  },

  // 复制链接
  copyLink() {
    wx.setClipboardData({
      data: '瞻养乐园工作卡链接',
      success: () => {
        wx.showToast({
          title: '链接已复制',
          icon: 'success'
        });
      }
    });
  },

  // 页面分享
  onShareAppMessage() {
    const title = this.data.cardType === 'hire' ? 
      `${this.data.workCardData.name}的养老需求` : 
      `${this.data.workCardData.name}的工作卡`;
    
    return {
      title: title,
      path: `/pages/preview/preview?type=${this.data.cardType}`,
      imageUrl: this.data.workCardData.avatarUrl || ''
    };
  }
})