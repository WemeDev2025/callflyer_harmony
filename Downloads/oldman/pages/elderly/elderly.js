// pages/elderly/elderly.js
const dataManager = require('../../utils/dataManager');

Page({
  data: {
    activeTab: 'nurses', // nurses、employers 或 orders
    searchInput: '',
    activeFilter: '全部',
    filterOptions: ['全部', '失智照护', '失能照护', '术后/康复照护', '慢性病照护', '安宁疗养'],
    
    // 护理员数据
    nurses: [],
    filteredNurses: [],
    
    // 雇主需求数据
    employers: [],
    filteredEmployers: [],
    
    // 订单数据
    orders: [],
    filteredOrders: [],
    
    // 数据加载状态
    dataLoaded: false
  },

  onLoad() {
    this.loadData();
  },

  onShow() {
    // 每次显示页面时都重新加载数据，确保数据最新
    // 清除所有相关缓存，强制从服务器获取最新数据
    dataManager.clearCache('all');
    
    // 重置数据加载状态，强制重新加载
    this.setData({
      dataLoaded: false,
      nurses: [],
      filteredNurses: [],
      employers: [],
      filteredEmployers: []
    });
    
    console.log('🔄 上门助老页面显示，强制刷新数据...');
    this.loadData();
  },

  // 加载数据
  loadData() {
    this.loadNurses();
    this.loadEmployers();
    this.loadOrders();
  },

  // 加载护理员数据
  async loadNurses() {
    try {
      console.log('🔄 开始加载护理员数据...');
      const result = await dataManager.workCard.getPublished();
      console.log('🔍 护理员数据加载结果:', result);
      
      if (result.success) {
        console.log('✅ 护理员数据成功:', result.data);
        console.log('📊 护理员数量:', result.data ? result.data.length : 0);
        
        // 处理数据字段映射，确保前端正确显示
        const processedData = (result.data || []).map(item => {
          console.log('🔍 处理护理员数据:', {
            id: item.id,
            name: item.name,
            avatarUrl: item.avatarUrl,
            phone: item.phone,
            skills: item.skills,
            certs: item.certs,
            createTime: item.createTime,
            status: item.status
          });
          return item;
        });
        
        this.setData({
          nurses: processedData,
          filteredNurses: processedData
        });
      } else {
        console.log('❌ 护理员数据失败:', result);
        this.setData({
          nurses: [],
          filteredNurses: []
        });
      }
    } catch (error) {
      console.error('加载护理员数据失败:', error);
      this.setData({
        nurses: [],
        filteredNurses: []
      });
    }
    
    this.filterNurses();
    this.checkDataLoaded();
  },

  // 加载雇主需求数据
  async loadEmployers() {
    try {
      const result = await dataManager.hireRequirement.getPublished();
      
      if (result.success) {
        this.setData({
          employers: result.data || [],
          filteredEmployers: result.data || []
        });
      } else {
        this.setData({
          employers: [],
          filteredEmployers: []
        });
      }
    } catch (error) {
      console.error('加载雇主需求数据失败:', error);
      this.setData({
        employers: [],
        filteredEmployers: []
      });
    }
    
    this.filterEmployers();
    this.checkDataLoaded();
  },

  // 加载订单数据
  loadOrders() {
    // 订单数据暂时从本地存储获取，后续可接入真实API
    const storedOrders = wx.getStorageSync('orders') || [];

    this.setData({
      orders: storedOrders,
      filteredOrders: storedOrders
    });

    this.filterOrders();
    this.checkDataLoaded();
  },

  // 检查数据是否已加载完成
  checkDataLoaded() {
    // 当护理员和雇主数据都加载完成后，设置dataLoaded为true
    if (this.data.nurses.length >= 0 && this.data.employers.length >= 0) {
      this.setData({
        dataLoaded: true
      });
    }
  },

  // 图片加载错误处理
  onImageError(e) {
    console.log('图片加载失败:', e);
    // 可以在这里设置默认头像或显示占位符
  },

  // Tab切换
  onTabChange(e) {
    const tab = e.currentTarget.dataset.tab;
    this.setData({
      activeTab: tab,
      searchInput: '',
      activeFilter: '全部'
    });
    
    // 重新筛选数据
    if (tab === 'nurses') {
      this.filterNurses();
    } else if (tab === 'employers') {
      this.filterEmployers();
    } else if (tab === 'orders') {
      this.filterOrders();
    }
  },

  // 搜索输入
  onSearchInput(e) {
    this.setData({
      searchInput: e.detail.value
    });
    
    if (this.data.activeTab === 'nurses') {
      this.filterNurses();
    } else if (this.data.activeTab === 'employers') {
      this.filterEmployers();
    } else if (this.data.activeTab === 'orders') {
      this.filterOrders();
    }
  },

  // 搜索按钮
  onSearch() {
    if (this.data.activeTab === 'nurses') {
      this.filterNurses();
    } else if (this.data.activeTab === 'employers') {
      this.filterEmployers();
    } else if (this.data.activeTab === 'orders') {
      this.filterOrders();
    }
  },

  // 筛选标签点击
  onFilterTag(e) {
    const filter = e.currentTarget.dataset.filter;
    this.setData({
      activeFilter: filter
    });
    
    if (this.data.activeTab === 'nurses') {
      this.filterNurses();
    } else if (this.data.activeTab === 'employers') {
      this.filterEmployers();
    } else if (this.data.activeTab === 'orders') {
      this.filterOrders();
    }
  },

  // 筛选护理员
  filterNurses() {
    const { nurses, searchInput, activeFilter } = this.data;
    console.log('🔍 筛选护理员数据:', {
      nurses: nurses.length,
      searchInput,
      activeFilter
    });
    
    let tempNurses = nurses;

    // 应用搜索筛选
    if (searchInput) {
      tempNurses = tempNurses.filter(nurse =>
        nurse.name.includes(searchInput) ||
        nurse.skills.some(skill => skill.includes(searchInput))
      );
      console.log('🔍 搜索筛选后:', tempNurses.length);
    }

    // 应用技能筛选
    if (activeFilter !== '全部') {
      tempNurses = tempNurses.filter(nurse =>
        nurse.skills.includes(activeFilter)
      );
      console.log('🔍 技能筛选后:', tempNurses.length);
    }

    console.log('🔍 最终筛选结果:', tempNurses.length, '个护理员');
    this.setData({
      filteredNurses: tempNurses
    });
  },

  // 筛选雇主需求
  filterEmployers() {
    const { employers, searchInput, activeFilter } = this.data;
    let tempEmployers = employers;

    // 应用搜索筛选
    if (searchInput) {
      tempEmployers = tempEmployers.filter(employer =>
        employer.contactName.includes(searchInput) ||
        employer.services.some(service => service.name.includes(searchInput)) ||
        (employer.otherRequirements && employer.otherRequirements.includes(searchInput))
      );
    }

    // 应用服务筛选
    if (activeFilter !== '全部') {
      tempEmployers = tempEmployers.filter(employer =>
        employer.services.some(service => service.name.includes(activeFilter))
      );
    }

    this.setData({
      filteredEmployers: tempEmployers
    });
  },

  // 筛选订单
  filterOrders() {
    const { orders, searchInput, activeFilter } = this.data;
    let tempOrders = orders;

    // 应用搜索筛选
    if (searchInput) {
      tempOrders = tempOrders.filter(order =>
        order.orderNumber.includes(searchInput) ||
        order.employer.name.includes(searchInput) ||
        order.nurse.name.includes(searchInput) ||
        order.careType.includes(searchInput)
      );
    }

    // 应用护理类型筛选
    if (activeFilter !== '全部') {
      tempOrders = tempOrders.filter(order =>
        order.careType.includes(activeFilter)
      );
    }

    this.setData({
      filteredOrders: tempOrders
    });
  },

  // 护理员卡片点击
  onNurseTap(e) {
    const nurse = e.currentTarget.dataset.nurse;
    wx.showActionSheet({
      itemList: ['拨打电话', '复制电话', '查看详情'],
      success(res) {
        if (res.tapIndex === 0) {
          wx.makePhoneCall({
            phoneNumber: nurse.phone
          });
        } else if (res.tapIndex === 1) {
          wx.setClipboardData({
            data: nurse.phone,
            success: () => {
              wx.showToast({
                title: '电话已复制',
                icon: 'success'
              });
            }
          });
        } else if (res.tapIndex === 2) {
          wx.showToast({
            title: `查看 ${nurse.name} 详情 (功能待开发)`,
            icon: 'none'
          });
        }
      }
    });
  },

  // 雇主需求卡片点击
  onEmployerTap(e) {
    const employer = e.currentTarget.dataset.employer;
    wx.showActionSheet({
      itemList: ['拨打电话', '复制电话', '查看详情'],
      success(res) {
        if (res.tapIndex === 0) {
          wx.makePhoneCall({
            phoneNumber: employer.contactPhone
          });
        } else if (res.tapIndex === 1) {
          wx.setClipboardData({
            data: employer.contactPhone,
            success: () => {
              wx.showToast({
                title: '电话已复制',
                icon: 'success'
              });
            }
          });
        } else if (res.tapIndex === 2) {
          wx.showToast({
            title: `查看 ${employer.contactName} 需求详情 (功能待开发)`,
            icon: 'none'
          });
        }
      }
    });
  },

  // 订单卡片点击
  onOrderTap(e) {
    const order = e.currentTarget.dataset.order;
    wx.showActionSheet({
      itemList: ['查看订单详情', '联系雇主', '联系护理员', '更新订单状态'],
      success(res) {
        if (res.tapIndex === 0) {
          wx.showToast({
            title: `查看订单 ${order.orderNumber} 详情 (功能待开发)`,
            icon: 'none'
          });
        } else if (res.tapIndex === 1) {
          wx.makePhoneCall({
            phoneNumber: order.employer.phone
          });
        } else if (res.tapIndex === 2) {
          wx.makePhoneCall({
            phoneNumber: order.nurse.phone
          });
        } else if (res.tapIndex === 3) {
          wx.showToast({
            title: '更新订单状态 (功能待开发)',
            icon: 'none'
          });
        }
      }
    });
  }
})
