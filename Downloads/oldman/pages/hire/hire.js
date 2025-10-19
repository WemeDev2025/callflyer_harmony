// pages/hire/hire.js
const dataManager = require('../../utils/dataManager');

Page({
  data: {
    avatarUrl: '',
    gender: 'any', // male, female, any
    certs: {
      idCard: false,
      healthCard: false,
      nursingCert: false,
      firstAidCert: false
    },
    services: [
      { name: '失智照护', selected: false },
      { name: '失能照护', selected: false },
      { name: '术后/康复照护', selected: false },
      { name: '慢性病照护', selected: false },
      { name: '安宁疗养', selected: false }
    ],
    otherRequirements: '',
    contactName: '',
    contactPhone: '',
    isEdit: false,
    hireId: null,
    saving: false
  },

  async onLoad(options) {
    // 检查是否是编辑模式
    const isEdit = options.edit === 'true';
    this.setData({ isEdit });
    
    // 首先检查登录状态
    await this.checkLoginStatus();
    
    if (isEdit) {
      // 编辑模式：从API加载现有数据
      await this.loadHireData();
    } else {
      // 新建模式：检查是否已有养老请人数据
      await this.checkExistingHireData();
    }
  },

  // 检查登录状态
  async checkLoginStatus() {
    try {
      const token = wx.getStorageSync('userToken');
      console.log('🔑 检查登录状态，当前token:', token ? '已获取' : '未获取');
      
      if (!token) {
        console.log('🔄 未找到token，开始静默登录...');
        await this.performSilentLogin();
      } else {
        console.log('✅ 用户已登录，token有效');
      }
    } catch (error) {
      console.error('检查登录状态失败:', error);
    }
  },

  // 执行静默登录
  async performSilentLogin() {
    try {
      console.log('🔄 开始静默登录...');
      
      // 获取微信登录凭证
      const loginRes = await new Promise((resolve, reject) => {
        wx.login({
          success: resolve,
          fail: reject
        });
      });

      if (!loginRes.code) {
        console.error('获取微信登录凭证失败');
        wx.showToast({
          title: '登录失败，请重试',
          icon: 'none'
        });
        return;
      }

      console.log('获取到微信code:', loginRes.code);

      // 调用后端登录接口
      const result = await dataManager.user.login({
        code: loginRes.code,
        type: 'wechat'
      });

      console.log('📊 登录接口返回结果:', result);

      if (result.success) {
        console.log('✅ 静默登录成功');
        // 保存用户信息到本地
        wx.setStorageSync('userInfo', result.data.user);
        wx.setStorageSync('userToken', result.data.token);
        console.log('💾 用户数据已保存到本地存储');
      } else {
        console.error('❌ 静默登录失败:', result.message);
        wx.showToast({
          title: '登录失败，请重试',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('静默登录异常:', error);
      wx.showToast({
        title: '登录失败，请重试',
        icon: 'none'
      });
    }
  },

  // 加载养老需求数据
  async loadHireData() {
    try {
      wx.showLoading({ title: '加载中...' });
      
      // 强制刷新数据，不使用缓存
      const result = await dataManager.hireRequirement.getMy(true);
      console.log('🔍 养老需求数据加载结果:', result);
      
      if (result.success && result.data) {
        // 处理数据格式：如果返回的是数组，取第一个元素
        const data = Array.isArray(result.data) ? result.data[0] : result.data;
        console.log('🔍 处理后的养老需求数据:', data);
        
        // 检查数据是否有效
        if (data && (Array.isArray(result.data) ? result.data.length > 0 : true)) {
          console.log('🔍 加载的原始certs数据:', data.certs);
          const updateData = {
            avatarUrl: data.avatarUrl || '',
            gender: data.gender || 'any',
            certs: data.certs || {
              idCard: false,
              healthCard: false,
              nursingCert: false,
              firstAidCert: false
            },
            services: this.initializeServices(data.services || []),
            otherRequirements: data.otherRequirements || '',
            contactName: data.contactName || '',
            contactPhone: data.contactPhone || ''
          };
          
          // 只有当data.id存在时才设置hireId
          if (data.id) {
            updateData.hireId = data.id;
          }
          
          this.setData(updateData);
          
          console.log('✅ 养老需求数据设置完成:', {
            hireId: data.id,
            gender: data.gender,
            contactName: data.contactName,
            servicesCount: data.services ? data.services.length : 0
          });
        } else {
          console.log('📝 没有养老需求数据，显示新建页面');
          // 如果数据为空，保持默认的空值状态
        }
      } else {
        console.log('❌ 养老需求数据获取失败:', result);
        wx.showToast({
          title: result.message || '加载失败',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('加载养老需求数据失败:', error);
      wx.showToast({
        title: '加载失败',
        icon: 'none'
      });
    } finally {
      wx.hideLoading();
    }
  },

  // 检查是否已有养老需求
  async checkExistingHireData() {
    try {
      const result = await dataManager.hireRequirement.getMy();
      console.log('🔍 检查养老需求数据:', result);
      
      // 检查是否有有效数据
      const hasHireData = result.success && result.data && (Array.isArray(result.data) ? result.data.length > 0 : true);
      
      if (hasHireData) {
        console.log('✅ 已有养老需求数据，跳转到预览页面');
        // 如果已有数据，直接跳转到预览页面
        wx.redirectTo({
          url: '/pages/preview/preview?type=hire'
        });
      } else {
        console.log('📝 没有养老需求数据，显示新建页面');
        // 如果没有数据，继续显示新建页面
      }
    } catch (error) {
      console.error('检查养老需求失败:', error);
    }
  },

  // 初始化服务数据
  initializeServices(selectedServices) {
    const allServices = [
      { name: '失智照护', selected: false },
      { name: '失能照护', selected: false },
      { name: '术后/康复照护', selected: false },
      { name: '慢性病照护', selected: false },
      { name: '安宁疗养', selected: false }
    ];
    
    // 根据已保存的服务数据设置选中状态
    allServices.forEach(service => {
      if (selectedServices.includes(service.name)) {
        service.selected = true;
      }
    });
    
    return allServices;
  },

  // 性别选择
  onGenderTap(e) {
    const gender = e.currentTarget.dataset.gender;
    this.setData({
      gender: gender
    });
  },

  // 证件选择
  onCertChange(e) {
    const type = e.currentTarget.dataset.type;
    const checked = e.detail.value;
    console.log('🔍 证件开关状态变化:', type, checked);
    this.setData({
      [`certs.${type}`]: checked
    });
    console.log('🔍 更新后的certs数据:', this.data.certs);
  },

  // 服务选择
  onServiceTap(e) {
    const index = e.currentTarget.dataset.index;
    const services = this.data.services;
    services[index].selected = !services[index].selected;
    this.setData({
      services: services
    });
  },

  // 其他要求输入
  onOtherInput(e) {
    this.setData({
      otherRequirements: e.detail.value
    });
  },

  // 联系人姓名输入
  onContactNameInput(e) {
    this.setData({
      contactName: e.detail.value
    });
  },

  // 联系人电话输入
  onContactPhoneInput(e) {
    this.setData({
      contactPhone: e.detail.value
    });
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

      // 上传头像到服务器
      const uploadResult = await dataManager.upload.avatar(res.tempFiles[0].tempFilePath);
      
      if (uploadResult.success) {
        // 拼接完整的图片URL
        const config = require('../../utils/config');
        const fullImageUrl = config.API.BASE_URL + uploadResult.data.url;
        
        this.setData({
          avatarUrl: fullImageUrl
        });
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
    }
  },

  // 发布需求
  async publishRequirement() {
    // 防止重复提交
    if (this.data.saving) {
      return;
    }

    // 验证必填信息
    if (!this.data.contactName) {
      wx.showToast({
        title: '请输入联系人姓名',
        icon: 'none'
      });
      return;
    }

    if (!this.data.contactPhone) {
      wx.showToast({
        title: '请输入联系电话',
        icon: 'none'
      });
      return;
    }

    // 检查是否选择了至少一个服务
    const selectedServices = this.data.services.filter(service => service.selected);
    if (selectedServices.length === 0) {
      wx.showToast({
        title: '请选择至少一个所需服务',
        icon: 'none'
      });
      return;
    }

    this.setData({ saving: true });

    try {
      // 移除保存中loading提示

      // 准备数据
      const hireData = {
        avatarUrl: this.data.avatarUrl,
        gender: this.data.gender,
        certs: this.data.certs,
        services: selectedServices.map(service => service.name),
        otherRequirements: this.data.otherRequirements,
        contactName: this.data.contactName,
        contactPhone: this.data.contactPhone,
        status: 'draft' // 先保存为草稿状态
      };
      
      console.log('🔍 准备保存的养老需求数据:', hireData);
      console.log('🔍 当前certs状态:', this.data.certs);
      console.log('🔍 certs.idCard:', this.data.certs.idCard);
      console.log('🔍 certs.healthCard:', this.data.certs.healthCard);
      console.log('🔍 certs.nursingCert:', this.data.certs.nursingCert);
      console.log('🔍 certs.firstAidCert:', this.data.certs.firstAidCert);

      // 保存到API
      const result = await dataManager.hireRequirement.save(hireData);
      console.log('🔍 保存养老需求结果:', result);
      
      if (result.success) {
        // 保存成功后，自动发布需求
        const hireId = result.data.id;
        console.log('🔄 开始发布养老需求:', hireId);
        
        const publishResult = await dataManager.hireRequirement.publish(hireId);
        console.log('🔍 发布养老需求结果:', publishResult);
        
        if (publishResult.success) {
          console.log('✅ 养老需求发布成功');
          
          // 立即验证保存的数据是否正确
          console.log('🔍 验证保存后的数据...');
          const verifyResult = await dataManager.hireRequirement.getMy(true);
          if (verifyResult.success && verifyResult.data) {
            const verifyData = Array.isArray(verifyResult.data) ? verifyResult.data[0] : verifyResult.data;
            console.log('🔍 验证结果 - 原始API数据:', verifyData);
            console.log('🔍 验证结果 - certificates:', verifyData.certificates);
            console.log('🔍 验证结果 - 证件要求是否一致:', {
              保存时: {idCard: true, healthCard: true, nursingCert: true, firstAidCert: true},
              获取时: verifyData.certificates
            });
          }
        } else {
          console.log('⚠️ 养老需求保存成功但发布失败:', publishResult.message);
        }

        // 检查是否是从预览页面进入的编辑模式
        const pages = getCurrentPages();
        const prevPage = pages[pages.length - 2];
        
        if (prevPage && prevPage.route === 'pages/preview/preview') {
          // 如果是从预览页面进入的，返回上一页并刷新数据
          wx.navigateBack({
            success: () => {
              // 通知预览页面刷新数据
              const currentPage = getCurrentPages()[getCurrentPages().length - 1];
              if (currentPage && currentPage.loadHireData) {
                currentPage.loadHireData();
              }
            }
          });
        } else {
          // 如果是新建模式，跳转到预览页面
          wx.navigateTo({
            url: '/pages/preview/preview?type=hire'
          });
        }
      } else {
        wx.hideLoading();
        wx.showToast({
          title: result.message || '保存失败',
          icon: 'none'
        });
      }
    } catch (error) {
      console.error('保存养老需求失败:', error);
      wx.hideLoading();
      wx.showToast({
        title: '保存失败，请重试',
        icon: 'none'
      });
    } finally {
      this.setData({ saving: false });
    }
  },

  // 预览需求卡
  async previewRequirement() {
    try {
      // 首先保存当前数据
      await this.publishRequirement();
      
      // 保存成功后跳转到预览页面
      wx.navigateTo({
        url: '/pages/preview/preview?type=hire'
      });
    } catch (error) {
      console.error('预览需求卡失败:', error);
      wx.showToast({
        title: '预览失败，请重试',
        icon: 'none'
      });
    }
  }
})