// pages/hire/hire.js
const dataManager = require('../../utils/dataManager');

Page({
  data: {
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
    
    if (isEdit) {
      // 编辑模式：从API加载现有数据
      await this.loadHireData();
    } else {
      // 新建模式：检查是否已有养老请人数据
      await this.checkExistingHireData();
    }
  },

  // 加载养老需求数据
  async loadHireData() {
    try {
      wx.showLoading({ title: '加载中...' });
      
      const result = await dataManager.hireRequirement.getMy();
      
      if (result.success && result.data) {
        const data = result.data;
        this.setData({
          hireId: data.id,
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
        });
      } else {
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
      
      if (result.success && result.data) {
        // 如果已有数据，直接跳转到预览页面
        wx.redirectTo({
          url: '/pages/preview/preview?type=hire'
        });
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
    this.setData({
      [`certs.${type}`]: checked
    });
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
        gender: this.data.gender,
        certs: this.data.certs,
        services: selectedServices.map(service => service.name),
        otherRequirements: this.data.otherRequirements,
        contactName: this.data.contactName,
        contactPhone: this.data.contactPhone,
        createTime: new Date().toLocaleString(),
        status: 'active'
      };

      // 保存到API
      const result = await dataManager.hireRequirement.save(hireData);
      
      if (result.success) {
        wx.hideLoading();
        // 移除成功toast提示

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
  }
})