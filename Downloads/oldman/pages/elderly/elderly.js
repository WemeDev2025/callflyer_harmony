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
    dataLoaded: false,
    dataLoading: false, // 防止重复加载
    
    // 工作卡显示状态
    showingMyWorkCard: false
  },

  onLoad() {
    console.log('🔄 我要找活页面加载开始');
    this.loadData();
  },

  onShow() {
    // 只有在数据未加载时才重新加载数据，避免重复请求
    if (!this.data.dataLoaded) {
      console.log('🔄 上门助老页面显示，数据未加载，开始加载数据...');
      this.loadData();
    } else {
      console.log('🔄 上门助老页面显示，数据已加载，跳过重复加载');
    }
  },

  // 手动刷新数据（下拉刷新时调用）
  onRefreshData() {
    console.log('🔄 手动刷新数据...');
    // 清除缓存并重新加载
    dataManager.clearCache('all');
    this.setData({
      dataLoaded: false,
      dataLoading: false
    });
    this.loadData();
  },

  // 加载数据
  loadData() {
    // 防止重复加载
    if (this.data.dataLoading) {
      console.log('🔄 数据正在加载中，跳过重复加载');
      return;
    }
    
    console.log('🔄 开始加载所有数据...');
    this.setData({
      dataLoading: true,
      dataLoaded: false
    });
    
    this.loadNurses();
    this.loadEmployers();
    this.loadOrders();
  },

  // 加载护理员数据
  async loadNurses() {
    try {
      console.log('🔄 开始加载护理员数据...');
      // 先检查当前用户是否已经发布过工作卡
      const myWorkCardResult = await dataManager.workCard.getMy();
      console.log('🔍 检查当前用户工作卡:', myWorkCardResult);
      
      let result;
      if (myWorkCardResult.success && myWorkCardResult.data) {
        // 如果当前用户有工作卡，优先显示用户自己的工作卡
        console.log('✅ 当前用户有工作卡，显示用户的工作卡');
        result = {
          success: true,
          data: Array.isArray(myWorkCardResult.data) ? myWorkCardResult.data : [myWorkCardResult.data]
        };
      } else {
        // 如果当前用户没有工作卡，显示所有已发布的工作卡
        console.log('📋 当前用户没有工作卡，显示所有已发布的工作卡');
        result = await dataManager.workCard.getPublished();
      }
      
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
        
        console.log('🔍 设置护理员数据到页面:', processedData);
        this.setData({
          nurses: processedData,
          filteredNurses: processedData
        });
        
        // 立即检查设置后的数据
        console.log('🔍 设置后的页面数据:', {
          nursesLength: this.data.nurses.length,
          filteredNursesLength: this.data.filteredNurses.length,
          activeTab: this.data.activeTab
        });
        
        // 验证数据是否设置成功
        console.log('🔍 验证页面数据设置结果:', {
          nurses: this.data.nurses.length,
          filteredNurses: this.data.filteredNurses.length,
          dataLoaded: this.data.dataLoaded,
          activeTab: this.data.activeTab
        });
        
        // 立即调用筛选方法确保数据显示正确
        this.filterNurses();
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
    
    this.checkDataLoaded();
  },

  // 加载雇主需求数据
  async loadEmployers() {
    try {
      console.log('🔄 开始加载雇主需求数据...');
      const result = await dataManager.hireRequirement.getPublished();
      console.log('🔍 雇主需求数据加载结果:', result);
      
      if (result.success) {
        console.log('✅ 雇主需求数据成功:', result.data);
        console.log('📊 雇主需求数量:', result.data ? result.data.length : 0);
        
        // 处理数据格式，确保前端正确显示
        const processedData = (result.data || []).map(item => {
          console.log('🔍 处理雇主需求数据:', {
            id: item.id,
            contactName: item.contactName,
            contactPhone: item.contactPhone,
            gender: item.gender,
            services: item.services,
            otherRequirements: item.otherRequirements,
            createTime: item.createTime,
            status: item.status
          });
          return item;
        });
        
        console.log('🔍 设置雇主需求数据到页面:', processedData);
        this.setData({
          employers: processedData,
          filteredEmployers: processedData
        });
        
        console.log('🔍 设置后的雇主数据:', {
          employersLength: this.data.employers.length,
          filteredEmployersLength: this.data.filteredEmployers.length
        });
      } else {
        console.log('❌ 雇主需求数据失败:', result);
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

  // 加载匹配数据
  async loadOrders() {
    try {
      console.log('🔄 开始加载匹配数据...');
      const result = await dataManager.match.getMatches();
      console.log('🔍 匹配数据加载结果:', result);
      
      if (result.success) {
        console.log('✅ 匹配数据成功:', result.data);
        console.log('📊 匹配数量:', result.data ? result.data.length : 0);
        
        // 处理匹配数据，将后端数据转换为前端期望的格式
        const processedData = (result.data || []).map(item => {
          console.log('🔍 处理匹配数据:', item);
          
          // 转换数据格式以匹配WXML期望的结构
          const transformedItem = {
            id: item.id,
            orderNumber: `#${item.id.slice(-8)}`, // 使用ID后8位作为订单号
            status: item.service_status === '已完成' ? '已完成' : '进行中',
            careType: '专业护理服务', // 默认护理类型
            startDate: item.contract_start_date ? new Date(item.contract_start_date).toLocaleDateString() : '待定',
            endDate: item.contract_end_date ? new Date(item.contract_end_date).toLocaleDateString() : '待定',
            duration: this.calculateDuration(item.contract_start_date, item.contract_end_date),
            employer: {
              id: item.employer_id,
              name: item.employer_name,
              avatarUrl: item.employer_avatar,
              phone: '***-****-****' // 隐私保护
            },
            nurse: {
              id: item.caregiver_id,
              name: item.caregiver_name,
              avatarUrl: item.caregiver_avatar,
              phone: '***-****-****' // 隐私保护
            },
            createTime: item.created_at ? new Date(item.created_at).toLocaleDateString() : '刚刚',
            matchDate: item.match_date ? new Date(item.match_date).toLocaleDateString() : '未知',
            notes: item.notes || '无备注信息'
          };
          
          console.log('✅ 转换后的数据:', transformedItem);
          return transformedItem;
        });
        
        this.setData({
          orders: processedData,
          filteredOrders: processedData
        });
      } else {
        console.log('❌ 匹配数据失败:', result);
        this.setData({
          orders: [],
          filteredOrders: []
        });
      }
    } catch (error) {
      console.error('加载匹配数据失败:', error);
      this.setData({
        orders: [],
        filteredOrders: []
      });
    }
    
    this.filterOrders();
    this.checkDataLoaded();
  },

  // 计算服务时长
  calculateDuration(startDate, endDate) {
    if (!startDate || !endDate) return '待定';
    
    try {
      const start = new Date(startDate);
      const end = new Date(endDate);
      const diffTime = Math.abs(end - start);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      
      if (diffDays < 30) {
        return `${diffDays}天`;
      } else if (diffDays < 365) {
        const months = Math.floor(diffDays / 30);
        return `${months}个月`;
      } else {
        const years = Math.floor(diffDays / 365);
        return `${years}年`;
      }
    } catch (error) {
      console.error('计算服务时长失败:', error);
      return '待定';
    }
  },

  // 检查数据是否已加载完成
  checkDataLoaded() {
    // 当护理员数据加载完成后就设置dataLoaded为true，不等待雇主数据
    console.log('🔍 检查数据加载状态:', {
      nursesLoaded: Array.isArray(this.data.nurses),
      employersLoaded: Array.isArray(this.data.employers),
      nursesLength: this.data.nurses.length,
      employersLength: this.data.employers.length,
      currentDataLoaded: this.data.dataLoaded,
      dataLoading: this.data.dataLoading
    });
    
    // 只要护理员数据数组已经初始化，就认为加载完成
    if (Array.isArray(this.data.nurses)) {
      this.setData({
        dataLoaded: true,
        dataLoading: false // 重置加载状态
      });
      console.log('✅ 护理员数据加载完成，设置dataLoaded为true，重置dataLoading为false');
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
    console.log('🔍 筛选后的数据:', tempNurses);
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
