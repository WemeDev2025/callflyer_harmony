// pages/work-card/work-card.js
const dataManager = require('../../utils/dataManager');

Page({
  data: {
    avatarUrl: '',
    name: '',
    phone: '',
    certs: {
      idCard: '',
      healthCard: '',
      nursingCert: '',
      firstAidCert: ''
    },
    skills: [
      { name: '失智照护', selected: false },
      { name: '失能照护', selected: false },
      { name: '术后/康复照护', selected: false },
      { name: '慢性病照护', selected: false },
      { name: '安宁疗养', selected: false }
    ],
    otherRequirements: '',
    isEdit: false,
    workCardId: null,
    saving: false,
    workCardStatus: 'draft' // 工作卡状态：draft, active, published
  },

  async onLoad(options) {
    // 检查是否是编辑模式
    const isEdit = options.edit === 'true';
    this.setData({ isEdit });
    
    // 动态设置导航栏标题
    if (isEdit) {
      wx.setNavigationBarTitle({
        title: '编辑工作卡'
      });
      // 编辑模式：从API加载现有数据
      await this.loadWorkCardData();
    } else {
      wx.setNavigationBarTitle({
        title: '创建工作卡'
      });
      // 新建模式：检查是否已有工作卡数据
      await this.checkExistingWorkCard();
    }
  },

  // 加载工作卡数据
  async loadWorkCardData() {
    try {
      // 移除加载中loading提示
      
      // 优先检查本地存储的编辑数据
      const editData = wx.getStorageSync('editWorkCardData');
      if (editData) {
        console.log('📝 使用本地存储的编辑数据:', editData);
        this.setData({
          workCardId: editData.id || '',
          avatarUrl: editData.avatarUrl || '',
          name: editData.name || '',
          phone: editData.phone || '',
          certs: editData.certs || {
            idCard: '',
            healthCard: '',
            nursingCert: '',
            firstAidCert: ''
          },
          skills: this.initializeSkills(editData.skills || []),
          otherRequirements: editData.otherRequirements || '',
          workCardStatus: editData.status || 'draft'
        });
        // 清除本地存储的编辑数据，避免重复使用
        wx.removeStorageSync('editWorkCardData');
        return;
      }
      
      // 如果没有本地编辑数据，从API加载
      const result = await dataManager.workCard.getMy();
      console.log('🔍 工作卡编辑页面获取数据:', result);
      
      if (result.success && result.data) {
        // 处理数据格式：如果返回的是数组，取第一个元素
        const data = Array.isArray(result.data) ? result.data[0] : result.data;
        console.log('🔍 处理后的工作卡数据:', data);
        
        // 检查数据是否有效（不是undefined且不是空数组）
        if (data && (Array.isArray(result.data) ? result.data.length > 0 : true)) {
          this.setData({
            workCardId: data.id || '',
            avatarUrl: data.avatarUrl || '',
            name: data.name || '',
            phone: data.phone || '',
            certs: data.certs || {
              idCard: '',
              healthCard: '',
              nursingCert: '',
              firstAidCert: ''
            },
            skills: this.initializeSkills(data.skills || []),
            otherRequirements: data.otherRequirements || '',
            workCardStatus: data.status || 'draft'
          });
          
          console.log('✅ 工作卡数据设置完成:', {
            workCardId: data.id,
            name: data.name,
            phone: data.phone,
            avatarUrl: data.avatarUrl,
            skillsCount: data.skills ? data.skills.length : 0
          });
        } else {
          console.log('📝 没有工作卡数据，显示新建页面');
          // 如果数据为空，保持默认的空值状态
        }
      } else {
        console.log('❌ 工作卡数据获取失败:', result);
        // 移除加载失败toast提示
      }
    } catch (error) {
      console.error('加载工作卡数据失败:', error);
      // 移除加载失败toast提示
    } finally {
      // 移除hideLoading调用
    }
  },

  // 检查是否已有工作卡
  async checkExistingWorkCard() {
    try {
      // 先检查我的工作卡（草稿状态）
      const myResult = await dataManager.workCard.getMy();
      console.log('🔍 检查我的工作卡数据:', myResult);
      
      // 再检查已发布的工作卡
      const publishedResult = await dataManager.workCard.getPublished();
      console.log('🔍 检查已发布工作卡数据:', publishedResult);
      
      // 如果有我的工作卡（草稿或已发布状态），显示编辑页面
      const hasWorkCard = myResult.success && myResult.data && (Array.isArray(myResult.data) ? myResult.data.length > 0 : true);
      
      if (hasWorkCard) {
        console.log('✅ 已有工作卡数据，显示编辑页面');
        this.setData({
          isEdit: true,
          workCardData: myResult.data
        });
        // 设置编辑模式标题
        wx.setNavigationBarTitle({
          title: '编辑工作卡'
        });
        this.loadWorkCardData();
      } else {
        // 如果都没有数据，显示新建页面
        console.log('📝 没有工作卡数据，显示新建页面');
        this.setData({
          isEdit: false
        });
        // 设置新建模式标题
        wx.setNavigationBarTitle({
          title: '创建工作卡'
        });
      }
    } catch (error) {
      console.error('检查工作卡失败:', error);
      // 出错时显示新建页面
      this.setData({
        isEdit: false
      });
    }
  },

  // 初始化技能数据
  initializeSkills(selectedSkills) {
    const allSkills = [
      { name: '失智照护', selected: false },
      { name: '失能照护', selected: false },
      { name: '术后/康复照护', selected: false },
      { name: '慢性病照护', selected: false },
      { name: '安宁疗养', selected: false }
    ];
    
    // 根据已保存的技能数据设置选中状态
    allSkills.forEach(skill => {
      if (selectedSkills.includes(skill.name)) {
        skill.selected = true;
      }
    });
    
    return allSkills;
  },

  // 选择头像
  async chooseAvatar() {
    try {
      const res = await new Promise((resolve, reject) => {
        wx.chooseMedia({
          count: 1,
          mediaType: ['image'],
          sourceType: ['album', 'camera'],
          success: resolve,
          fail: reject
        });
      });

      // 移除上传中loading提示
      
      // 上传头像到服务器
      const uploadResult = await dataManager.upload.avatar(res.tempFiles[0].tempFilePath);
      
      if (uploadResult.success) {
        // 拼接完整的图片URL
        const config = require('../../utils/config');
        const fullImageUrl = config.API.BASE_URL + uploadResult.data.url;
        
        this.setData({
          avatarUrl: fullImageUrl
        });
        // 移除成功toast提示
      } else {
        // 上传失败，使用本地路径
        this.setData({
          avatarUrl: res.tempFiles[0].tempFilePath
        });
        wx.showToast({
          title: uploadResult.message || '上传失败，使用本地图片',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('选择头像失败:', error);
      wx.showToast({
        title: '选择头像失败',
        icon: 'none'
      });
    } finally {
      // 移除hideLoading调用
    }
  },

  // 姓名输入
  onNameInput(e) {
    this.setData({
      name: e.detail.value
    });
  },

  // 电话输入
  onPhoneInput(e) {
    this.setData({
      phone: e.detail.value
    });
  },

  // 上传证件
  async uploadCert(e) {
    const type = e.currentTarget.dataset.type;
    
    try {
      const res = await new Promise((resolve, reject) => {
        wx.chooseMedia({
          count: 1,
          mediaType: ['image'],
          sourceType: ['album', 'camera'],
          success: resolve,
          fail: reject
        });
      });

      // 移除上传中loading提示
      
      // 上传证件图片到服务器
      const uploadResult = await dataManager.upload.certificate(res.tempFiles[0].tempFilePath, type);
      
      if (uploadResult.success) {
        // 拼接完整的图片URL
        const config = require('../../utils/config');
        const fullImageUrl = config.API.BASE_URL + uploadResult.data.url;
        
        this.setData({
          [`certs.${type}`]: fullImageUrl
        });
        // 移除成功toast提示
      } else {
        // 上传失败，使用本地路径
        this.setData({
          [`certs.${type}`]: res.tempFiles[0].tempFilePath
        });
        wx.showToast({
          title: uploadResult.message || '上传失败，使用本地图片',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('上传证件失败:', error);
      wx.showToast({
        title: '上传失败',
        icon: 'none'
      });
    } finally {
      // 移除hideLoading调用
    }
  },

  // 技能选择
  onSkillTap(e) {
    const index = e.currentTarget.dataset.index;
    const skills = this.data.skills;
    skills[index].selected = !skills[index].selected;
    this.setData({
      skills: skills
    });
  },

  // 其他要求输入
  onOtherInput(e) {
    this.setData({
      otherRequirements: e.detail.value
    });
  },

  // 预览工作卡
  async previewCard() {
    // 防止重复提交
    if (this.data.saving) {
      return;
    }

    // 验证必填信息
    if (!this.data.name) {
      wx.showToast({
        title: '请输入姓名',
        icon: 'none'
      });
      return;
    }

    if (!this.data.phone) {
      wx.showToast({
        title: '请输入联系电话',
        icon: 'none'
      });
      return;
    }

    // 检查是否选择了至少一个技能
    const selectedSkills = this.data.skills.filter(skill => skill.selected);
    if (selectedSkills.length === 0) {
      wx.showToast({
        title: '请选择至少一个擅长内容',
        icon: 'none'
      });
      return;
    }

    this.setData({ saving: true });

    try {
      // 移除保存中loading提示

      // 准备数据
      const workCardData = {
        avatarUrl: this.data.avatarUrl,
        name: this.data.name,
        phone: this.data.phone,
        certs: this.data.certs,
        skills: selectedSkills.map(skill => skill.name),
        otherRequirements: this.data.otherRequirements,
        createTime: new Date().toISOString()
      };

      // 保存到API
      const result = await dataManager.workCard.save(workCardData);
      
      if (result.success) {
        // 移除hideLoading调用
        // 移除成功toast提示
        
        // 清除所有相关缓存，确保数据更新
        dataManager.clearCache('myWorkCard');
        dataManager.clearCache('publishedWorkCards');
        dataManager.clearCache('all');

        // 检查是否是从预览页面进入的编辑模式
        const pages = getCurrentPages();
        const prevPage = pages[pages.length - 2];
        
        if (prevPage && prevPage.route === 'pages/preview/preview') {
          // 如果是从预览页面进入的，返回上一页并刷新数据
          wx.navigateBack({
            success: () => {
              // 通知预览页面刷新数据
              const currentPage = getCurrentPages()[getCurrentPages().length - 1];
              if (currentPage && currentPage.loadWorkCardData) {
                currentPage.loadWorkCardData();
              }
            }
          });
        } else {
          // 如果是新建模式，跳转到预览页面
          wx.navigateTo({
            url: '/pages/preview/preview'
          });
        }
      } else {
        // 移除hideLoading调用
        wx.showToast({
          title: result.message || '保存失败',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('保存工作卡失败:', error);
      // 移除hideLoading调用
      wx.showToast({
        title: '保存失败，请重试',
        icon: 'none'
      });
    } finally {
      this.setData({ saving: false });
    }
  }
})