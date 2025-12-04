// pages/cards/index.js
const auth = require('../../utils/auth');

const API_BASE_URL = 'https://wemedev.com/api/festival';

Page({
  data: {
    statusBarHeight: 0,
    navBarHeight: 44,
    cards: [], // 卡片列表
    loading: false,
    hasMore: true,
    page: 0, // 当前页码
    pageSize: 20, // 每页数量
    cardsAnimated: false, // 卡片动画状态
    windowHeight: 0, // 窗口高度
    scrollViewHeight: 0, // scroll-view 高度
    likeAnimationList: [], // 点赞动画列表（支持叠加）
    showLongPressAnimation: false, // 长按动画显示状态
    explosionParticles: [], // 爆炸粒子列表
    continuousLikeCount: 0, // 连续点赞计数
    lastLikeTime: 0, // 上次点赞时间戳
    isPulling: false, // 是否正在下拉
    // 当前用户卡片数据（用于筛选匹配）
    userCard: {
      whenDate: '',
      whenText: '',
      whoText: '',
      howText: '',
      whereText: '',
      mustDoText: '',
      availableTime: '',
      availableTimeText: ''
    },
    // 筛选条件
    activeFilters: {
      whenDate: '',
      whoText: '',
      howText: '',
      whereText: '',
      mustDoText: '',
      availableTime: ''
    },
    hasActiveFilters: false, // 是否有激活的筛选
    // 筛选标签显示文本
    filterLabels: {
      whenDate: '',
      whoText: '',
      howText: '',
      whereText: '',
      mustDoText: '',
      availableTime: ''
    },
    // 搜索相关
    searchKeyword: '', // 搜索关键词
    searchTimer: null // 搜索防抖定时器
  },
  onLoad() {
    // 初始化变量
    this.loadMoreObserver = null;
    this.lastLoadMoreTime = 0; // 防抖标记
    
    // 获取系统信息，计算导航栏高度
    try {
      const windowInfo = wx.getWindowInfo();
      const statusBarHeight = windowInfo.statusBarHeight || 0;
      const navBarHeight = statusBarHeight + 44;
      const windowHeight = windowInfo.windowHeight || 0;
      
      // 先设置基础数据
      this.setData({
        statusBarHeight: statusBarHeight,
        navBarHeight: navBarHeight,
        windowHeight: windowHeight
      });
      
      // 使用 setTimeout 确保 DOM 渲染完成后再计算筛选区域高度
      setTimeout(() => {
        const query = wx.createSelectorQuery().in(this);
        query.select('.filter-container').boundingClientRect((filterRect) => {
          if (filterRect) {
            // 筛选区域底部位置（筛选区域的 top + height）
            const filterBottom = filterRect.top + filterRect.height;
            // scroll-view 的 padding-top (10px)
            const scrollPaddingTop = 10;
            // scroll-view 高度 = 窗口高度 - 筛选区域底部位置 - scroll-view padding-top
            const scrollViewHeight = windowHeight - filterBottom - scrollPaddingTop;
            
            console.log('[Cards] 系统信息:', {
              statusBarHeight,
              navBarHeight,
              windowHeight,
              filterHeight: filterRect.height,
              filterTop: filterRect.top,
              filterBottom: filterBottom,
              scrollPaddingTop,
              scrollViewHeight,
              calculatedHeight: `${scrollViewHeight}px`
            });
            
            this.setData({
              scrollViewHeight: Math.max(0, scrollViewHeight)
            });
          } else {
            console.warn('[Cards] 未找到筛选区域，使用默认计算');
            // 备用计算：窗口高度 - 导航栏高度 - 估算筛选区域高度 - padding-top
            const defaultFilterHeight = 60;
            const scrollPaddingTop = 10;
            const scrollViewHeight = windowHeight - navBarHeight - defaultFilterHeight - scrollPaddingTop;
            this.setData({
              scrollViewHeight: Math.max(0, scrollViewHeight)
            });
          }
        }).exec();
      }, 200);
    } catch (e) {
      console.error('获取系统信息失败', e);
    }

    // 加载当前用户卡片数据（用于筛选匹配）
    this.loadUserCard();

    // 延迟加载卡片列表，避免与高度计算冲突
    setTimeout(() => {
      // 加载卡片列表
      this.loadCards(true);
    }, 300);
  },
  // 返回上一页
  goBack() {
    wx.navigateBack();
  },
  // 页面卸载时清理
  onUnload() {
    // 销毁 IntersectionObserver
    if (this.loadMoreObserver) {
      this.loadMoreObserver.disconnect();
      this.loadMoreObserver = null;
    }
  },
  // 切换筛选标签
  toggleFilter(e) {
    const type = e.currentTarget.dataset.type;
    const currentValue = this.data.activeFilters[type];
    
    // 如果当前筛选已激活，则清除
    if (currentValue) {
      const newFilters = { ...this.data.activeFilters };
      const newLabels = { ...this.data.filterLabels };
      newFilters[type] = '';
      newLabels[type] = '';
      const hasActiveFilters = Object.values(newFilters).some(v => v !== '');
      
      this.setData({
        activeFilters: newFilters,
        filterLabels: newLabels,
        hasActiveFilters: hasActiveFilters
      });
      // 重新加载卡片
      this.loadCards(true);
    } else {
      // 从当前用户卡片中获取筛选值
      const userCard = this.data.userCard;
      let filterValue = '';
      let filterLabel = '';
      
      if (type === 'whenDate') {
        // 日期筛选：使用 whenDate（格式：2025-12-31）
        filterValue = userCard.whenDate || '';
        filterLabel = userCard.whenText || '';
      } else if (type === 'availableTime') {
        // 几号有空筛选：使用 availableTime（格式：M/d，例如 "2/15"）
        filterValue = userCard.availableTime || '';
        filterLabel = userCard.availableTimeText || '';
      } else {
        // 其他筛选：直接使用对应的文本值
        filterValue = userCard[type] || '';
        filterLabel = userCard[type] || '';
      }
      
      // 如果没有用户卡片数据，提示用户
      if (!filterValue) {
        wx.showToast({
          title: '请先在"我的"页面填写相关信息',
          icon: 'none',
          duration: 2000
        });
        return;
      }
      
      // 设置筛选条件和标签
      const newFilters = { ...this.data.activeFilters };
      const newLabels = { ...this.data.filterLabels };
      newFilters[type] = filterValue;
      newLabels[type] = filterLabel;
      const hasActiveFilters = true;
      
      this.setData({
        activeFilters: newFilters,
        filterLabels: newLabels,
        hasActiveFilters: hasActiveFilters
      });
      
      // 重新加载卡片
      this.loadCards(true);
    }
  },
  // 加载当前用户卡片数据（用于筛选匹配）
  loadUserCard() {
    const makeRequest = () => {
      const token = auth.getToken();
      const openid = auth.getOpenId();
      
      if (!token || !openid) {
        console.log('未登录，无法加载用户卡片数据');
        return;
      }

      wx.request({
        url: `${API_BASE_URL}/profiles/${openid}`,
        method: 'GET',
        header: {
          'Authorization': 'Bearer ' + token
        },
        success: (res) => {
          if (res.statusCode === 200 && res.data) {
            const data = res.data;
            // 映射后端字段到前端字段
            const userCard = {
              whenDate: data.whenDate || data.when_date || '',
              whenText: data.whenText || data.when_text || '',
              whoText: data.whoText || data.who_text || '',
              howText: data.howText || data.how_text || '',
              whereText: data.whereText || data.where_text || '',
              mustDoText: data.mustDoText || data.must_do_text || '',
              availableTime: data.availableTime || data.available_time || '',
              availableTimeText: data.availableTimeText || data.available_time_text || ''
            };
            
            this.setData({
              userCard: userCard
            });
          } else if (res.statusCode === 401) {
            // token 过期，尝试重新登录后重试
            console.log('Token 已过期，尝试重新登录...');
            const { silentLogin } = require('../../utils/auth');
            silentLogin()
              .then(() => {
                console.log('重新登录成功，重试加载用户卡片数据');
                // 重新发起请求
                makeRequest();
              })
              .catch((err) => {
                console.error('重新登录失败', err);
                console.error('获取用户卡片数据失败', res);
              });
          } else if (res.statusCode === 404) {
            // 用户资料不存在，这是正常的
            console.log('用户资料不存在');
          } else {
            console.error('获取用户卡片数据失败', res);
          }
        },
        fail: (err) => {
          console.error('获取用户卡片数据请求失败', err);
        }
      });
    };

    // 发起请求
    makeRequest();
  },
  // 检查两个字符串是否有至少两个字符相同（模糊匹配）
  hasAtLeastTwoCommonChars(str1, str2) {
    if (!str1 || !str2) return false;
    // 去除空格，只比较有效字符
    const s1 = str1.trim();
    const s2 = str2.trim();
    if (!s1 || !s2) return false;
    
    const chars1 = s1.split('');
    const chars2 = s2.split('');
    let commonCount = 0;
    const usedChars2 = [...chars2]; // 复制数组，避免修改原数组
    
    // 检查每个字符是否在另一个字符串中出现
    for (let i = 0; i < chars1.length; i++) {
      const char = chars1[i];
      const index = usedChars2.indexOf(char);
      if (index !== -1) {
        commonCount++;
        // 移除已匹配的字符，避免重复计数
        usedChars2.splice(index, 1);
      }
    }
    
    return commonCount >= 2;
  },
  // 加载卡片列表
  loadCards(reset = false) {
    if (this.data.loading) return;
    
    if (reset) {
      this.setData({
        page: 0,
        cards: [],
        hasMore: true
      });
    }
    
    this.setData({ loading: true });
    
    // 构建筛选参数
    const params = {};
    const filters = this.data.activeFilters;
    
    // 搜索参数（后端支持）
    const searchKeyword = (this.data.searchKeyword || '').trim();
    if (searchKeyword !== '') {
      params.search = searchKeyword;
    }
    
    // 对于 whereText 和 mustDoText，不发送到后端，在前端进行模糊匹配
    if (filters.whenDate && filters.whenDate !== '') {
      params.when_date = filters.whenDate;
    }
    if (filters.whoText && filters.whoText !== '') {
      params.who_text = filters.whoText;
    }
    if (filters.howText && filters.howText !== '') {
      params.how_text = filters.howText;
    }
    if (filters.availableTime && filters.availableTime !== '') {
      params.available_time = filters.availableTime;
    }
    // whereText 和 mustDoText 不发送到后端，在前端进行模糊匹配
    
    // 分页参数
    params.limit = this.data.pageSize;
    params.skip = this.data.page * this.data.pageSize;
    
    const makeRequest = () => {
      const token = auth.getToken();
      const headers = {
        'Content-Type': 'application/json'
      };
      if (token) {
        headers['Authorization'] = 'Bearer ' + token;
      }
      
      wx.request({
        url: `${API_BASE_URL}/cards`,
        method: 'GET',
        header: headers,
        data: params,
        success: (res) => {
          if (res.statusCode === 200) {
          const rawCards = res.data.items || [];
          
          console.log('[Cards] API 返回数据:', {
            total: res.data.total || 0,
            itemsCount: rawCards.length,
            rawData: rawCards.slice(0, 3).map(card => ({
              openid: card.openid || card.open_id,
              nickname: card.nickname,
              hasInfoText: !!(card.info_text || card.custom_text || card.infoText),
              hasWhenText: !!(card.when_text || card.whenText),
              hasWhoText: !!(card.who_text || card.whoText),
              hasHowText: !!(card.how_text || card.howText)
            }))
          });
          
          // 过滤掉无效数据（没有 openid 的）
          const validRawCards = rawCards.filter(card => {
            const openid = card.openid || card.open_id;
            if (!openid) {
              console.warn('[Cards] 发现无效卡片数据（缺少 openid）:', card);
              return false;
            }
            return true;
          });
          
          // 转换后端下划线命名到前端驼峰命名
          let newCards = validRawCards.map(card => this.mapCardFields(card));
          
          // 对 whereText 和 mustDoText 进行模糊匹配过滤
          // 对 availableTime 进行精确匹配过滤（如果后端不支持筛选，则在前端筛选）
          const filters = this.data.activeFilters;
          if (filters.whereText && filters.whereText !== '') {
            newCards = newCards.filter(card => {
              const cardWhereText = card.whereText || '';
              return this.hasAtLeastTwoCommonChars(filters.whereText, cardWhereText);
            });
          }
          if (filters.mustDoText && filters.mustDoText !== '') {
            newCards = newCards.filter(card => {
              const cardMustDoText = card.mustDoText || '';
              return this.hasAtLeastTwoCommonChars(filters.mustDoText, cardMustDoText);
            });
          }
          if (filters.availableTime && filters.availableTime !== '') {
            newCards = newCards.filter(card => {
              const cardAvailableTime = card.availableTime || '';
              // 精确匹配 availableTime（格式：M/d，例如 "2/15"）
              return cardAvailableTime === filters.availableTime;
            });
          }
          
          // 注意：搜索功能已移至后端，通过 search 参数实现
          // 如果后端搜索失败，可以在这里添加前端备用搜索逻辑
          
          const allCards = reset ? newCards : [...this.data.cards, ...newCards];
          
          console.log('[Cards] 加载卡片:', {
            reset,
            rawCardsCount: rawCards.length,
            validCardsCount: validRawCards.length,
            newCardsCount: newCards.length,
            allCardsCount: allCards.length,
            hasMore: newCards.length >= this.data.pageSize,
            page: this.data.page + 1
          });
          
          // 调试：打印第一条卡片数据
          if (allCards.length > 0) {
            console.log('[Cards] 第一条卡片数据:', {
              openid: allCards[0].openid,
              nickname: allCards[0].nickname,
              hasAvatar: !!allCards[0].avatarUrl,
              hasInfoText: !!allCards[0].infoText
            });
          }
          
          // 重置动画状态（只在重置时）
          if (reset) {
            this.setData({
              cards: allCards,
              cardsAnimated: false,
              loading: false,
              hasMore: newCards.length >= this.data.pageSize,
              page: this.data.page + 1
            }, () => {
              // 数据加载完成后，初始化 IntersectionObserver
              if (this.data.hasMore) {
                this.initLoadMoreObserver();
              }
            });
            
            // 触发动画
            if (allCards.length > 0) {
              setTimeout(() => {
                this.setData({
                  cardsAnimated: true
                });
              }, 50);
            }
          } else {
            // 加载更多时，保持动画状态，直接更新数据
            this.setData({
              cards: allCards,
              loading: false,
              hasMore: newCards.length >= this.data.pageSize,
              page: this.data.page + 1
            }, () => {
              // 数据加载完成后，重新初始化 IntersectionObserver（如果还没有或已断开）
              if (this.data.hasMore && (!this.loadMoreObserver || !this.loadMoreObserver._connected)) {
                this.initLoadMoreObserver();
              }
            });
          }
        } else if (res.statusCode === 401 && token) {
          // token 过期，尝试重新登录后重试（只有在有 token 的情况下才重试）
          console.log('Token 已过期，尝试重新登录...');
          const { silentLogin } = require('../../utils/auth');
          silentLogin()
            .then(() => {
              console.log('重新登录成功，重试加载卡片列表');
              // 重新发起请求
              makeRequest();
            })
            .catch((err) => {
              console.error('重新登录失败', err);
              console.error('获取卡片列表失败', res);
              this.setData({ loading: false });
            });
        } else {
          console.error('获取卡片列表失败', res);
          this.setData({ loading: false });
        }
      },
      fail: (err) => {
        console.error('请求失败', err);
        this.setData({ loading: false });
      }
    });
    };

    // 发起请求
    makeRequest();
  },
  // 加载更多
  onLoadMore() {
    console.log('[Cards] 触发加载更多:', {
      hasMore: this.data.hasMore,
      loading: this.data.loading,
      currentPage: this.data.page,
      cardsCount: this.data.cards.length
    });
    
    if (this.data.hasMore && !this.data.loading) {
      this.loadCards(false);
    } else {
      console.log('[Cards] 不加载更多:', {
        hasMore: this.data.hasMore,
        loading: this.data.loading
      });
    }
  },
  // 初始化 IntersectionObserver 监听底部元素
  initLoadMoreObserver() {
    // 销毁旧的 observer
    if (this.loadMoreObserver) {
      this.loadMoreObserver.disconnect();
      this.loadMoreObserver = null;
    }
    
    // 如果正在加载或没有更多数据，不初始化 observer
    if (this.data.loading || !this.data.hasMore) {
      return;
    }
    
    // 延迟初始化，确保 DOM 已渲染
    setTimeout(() => {
      // 再次检查，防止在延迟期间状态已改变
      if (this.data.loading || !this.data.hasMore) {
        return;
      }
      
      // 创建新的 observer
      this.loadMoreObserver = wx.createIntersectionObserver(this, {
        thresholds: [0.1],
        initialRatio: 0.1
      });
      
      const DEBOUNCE_TIME = 500; // 500ms 防抖
      
      // 监听底部触发元素
      this.loadMoreObserver.relativeTo('.cards-scroll').observe('#loadMoreTrigger', (res) => {
        const now = Date.now();
        // 防抖：如果距离上次触发时间太短，忽略
        if (now - this.lastLoadMoreTime < DEBOUNCE_TIME) {
          return;
        }
        
        if (res.intersectionRatio > 0 && this.data.hasMore && !this.data.loading) {
          this.lastLoadMoreTime = now;
          console.log('[Cards] IntersectionObserver 触发加载更多');
          this.onLoadMore();
        }
      });
    }, 300);
  },
  // 处理API错误
  handleApiError(res) {
    if (res.statusCode === 401) {
      auth.clearAuth();
      wx.showToast({
        title: '登录已过期',
        icon: 'none'
      });
    } else {
      const errorMsg = (res.data && res.data.message) ? res.data.message : '';
      wx.showToast({
        title: errorMsg,
        icon: 'none'
      });
    }
  },
  // 映射后端字段到前端字段（下划线转驼峰）
  mapCardFields(card) {
    return {
      openid: card.openid || card.open_id || '',
      nickname: card.nickname || '',
      avatarUrl: card.avatar_url || card.avatarUrl || '',
      infoText: card.info_text || card.custom_text || card.infoText || '',
      whenDate: card.when_date || card.whenDate || '',
      whenText: card.when_text || card.whenText || '',
      whoText: card.who_text || card.whoText || '',
      howText: card.how_text || card.howText || '',
      whereText: card.where_text || card.whereText || '',
      mustDoText: card.must_do_text || card.mustDoText || '',
      availableTime: card.available_time || card.availableTime || '',
      // 如果后端返回的文本没有"有空"，则添加
      availableTimeText: this.formatAvailableTimeText(card.available_time_text || card.availableTimeText || ''),
      likeCount: card.like_count || card.likeCount || 0,
      selectedTags: card.selected_tags || card.selectedTags || [],
      createdAt: card.created_at || card.createdAt || '',
      updatedAt: card.updated_at || card.updatedAt || ''
    };
  },
  // 格式化"几号有空"文本，确保包含"有空"
  formatAvailableTimeText(text) {
    if (!text || text === '几号有空') {
      return '';
    }
    // 如果文本中已经包含"有空"，直接返回
    if (text.includes('有空')) {
      return text;
    }
    // 否则添加"有空"
    return `${text} 有空`;
  },
  // 搜索输入
  onSearchInput(e) {
    const keyword = e.detail.value;
    this.setData({
      searchKeyword: keyword
    });
    
    // 防抖：延迟执行搜索
    if (this.data.searchTimer) {
      clearTimeout(this.data.searchTimer);
    }
    
    this.data.searchTimer = setTimeout(() => {
      // 重新加载卡片（会触发搜索过滤）
      this.loadCards(true);
    }, 300);
  },
  // 搜索确认
  onSearchConfirm(e) {
    const keyword = e.detail.value;
    this.setData({
      searchKeyword: keyword
    });
    // 立即执行搜索
    if (this.data.searchTimer) {
      clearTimeout(this.data.searchTimer);
    }
    this.loadCards(true);
  },
  // 清除搜索
  clearSearch() {
    this.setData({
      searchKeyword: ''
    });
    // 重新加载卡片
    this.loadCards(true);
  },
  // 点赞
  onLikeTap(e) {
    const openid = e.currentTarget.dataset.openid;
    if (!openid) {
      console.error('缺少 openid');
      return;
    }

    const currentTime = Date.now();
    const lastLikeTime = this.data.lastLikeTime || 0;
    const timeDiff = currentTime - lastLikeTime;
    
    // 判断是否为连续点赞（2秒内的点赞算作连续）
    let continuousCount = this.data.continuousLikeCount || 0;
    if (timeDiff < 2000) {
      continuousCount += 1;
    } else {
      // 超过2秒，重置计数
      continuousCount = 1;
    }

    // 更新连续点赞计数和时间戳
    this.setData({
      continuousLikeCount: continuousCount,
      lastLikeTime: currentTime
    });

    // 如果连续点赞达到10次，触发爆炸动画和音效
    if (continuousCount >= 10) {
      console.log('[Cards] 连续点赞10次，触发爆炸动画');
      
      // 重置计数器
      this.setData({
        continuousLikeCount: 0,
        lastLikeTime: 0
      });

      // 触发长按动画效果（但不调用API，因为已经在下面调用了）
      this.setData({
        showLongPressAnimation: true
      });

      // 0.5秒后播放爆炸音效
      setTimeout(() => {
        this.playExplosionSound();
      }, 500);

      // 1秒后完成呼吸动画，然后爆炸
      setTimeout(() => {
        // 生成爆炸粒子（从上往下掉落）
        this.createExplosionParticles();
        
        // 立即隐藏中心图标，开始爆炸
        this.setData({
          showLongPressAnimation: false
        });
      }, 1000);
    }

    // 触发点赞动画（支持叠加）
    const animationId = Date.now() + Math.random(); // 确保唯一性
    const currentList = this.data.likeAnimationList || [];
    const animationList = [...currentList, { id: animationId, delay: 0 }];
    this.setData({
      likeAnimationList: animationList
    });
    
    // 动画结束后自动移除（动画总时长1.2秒）
    setTimeout(() => {
      // 使用最新的数据来过滤
      const currentAnimationList = this.data.likeAnimationList || [];
      const updatedList = currentAnimationList.filter(item => item.id !== animationId);
      this.setData({
        likeAnimationList: updatedList
      });
    }, 1200);

    // 调用震动 API
    wx.vibrateShort({
      type: 'medium',
      success: () => {
        console.log('震动成功');
      },
      fail: (err) => {
        console.log('震动失败', err);
      }
    });

    const makeRequest = () => {
      const token = auth.getToken();
      const headers = {
        'Content-Type': 'application/json'
      };
      if (token) {
        headers['Authorization'] = 'Bearer ' + token;
      }

      wx.request({
        url: `${API_BASE_URL}/profiles/${openid}/like`,
        method: 'POST',
        header: headers,
        success: (res) => {
          if (res.statusCode === 200 && res.data) {
            // 更新对应卡片的点赞数
            const cards = this.data.cards.map(card => {
              if (card.openid === openid) {
                return {
                  ...card,
                  likeCount: res.data.likeCount || res.data.like_count || card.likeCount + 1
                };
              }
              return card;
            });
            
            this.setData({ cards: cards });
          } else if (res.statusCode === 401) {
            // token 过期，尝试重新登录后重试
            console.log('Token 已过期，尝试重新登录...');
            const { silentLogin } = require('../../utils/auth');
            silentLogin()
              .then(() => {
                console.log('重新登录成功，重试点赞');
                // 重新发起请求
                makeRequest();
              })
              .catch((err) => {
                console.error('重新登录失败', err);
                console.error('点赞失败', res);
                wx.showToast({
                  title: '点赞失败',
                  icon: 'none'
                });
              });
          } else {
            console.error('点赞失败', res);
            wx.showToast({
              title: '点赞失败',
              icon: 'none'
            });
          }
        },
        fail: (err) => {
          console.error('点赞请求失败', err);
          wx.showToast({
            title: '网络错误',
            icon: 'none'
          });
        }
      });
    };

    // 发起请求
    makeRequest();
  },
  // 长按点赞
  onLikeLongPress(e) {
    const openid = e.currentTarget.dataset.openid;
    if (!openid) {
      console.error('缺少 openid');
      return;
    }

    console.log('[Cards] 长按点赞触发', openid);

    // 触发长按动画：图标放大到5倍，缩小到4倍，再回到5倍
    this.setData({
      showLongPressAnimation: true
    });

    // 0.5秒后播放爆炸音效（与动画50%位置同步，图标缩小到4倍时）
    setTimeout(() => {
      // 播放爆炸音效
      this.playExplosionSound();
    }, 500);

    // 1秒后完成呼吸动画，然后爆炸
    setTimeout(() => {
      // 生成爆炸粒子（从上往下掉落）
      this.createExplosionParticles();
      
      // 立即隐藏中心图标，开始爆炸
      this.setData({
        showLongPressAnimation: false
      });
      
      // 调用点赞API
      this.performLike(openid);
    }, 1000);
  },
  // 创建爆炸粒子
  createExplosionParticles() {
    const particleCount = 20 + Math.floor(Math.random() * 10); // 随机粒子数量 20-30
    const particles = [];
    const centerX = 40 + Math.random() * 20; // 随机中心X位置（40%-60%）
    const centerY = 20 + Math.random() * 15; // 随机起始Y位置（20%-35%）
    
    for (let i = 0; i < particleCount; i++) {
      // 完全随机的角度
      const angle = Math.random() * Math.PI * 2;
      // 随机爆炸距离
      const distance = 15 + Math.random() * 40;
      // 随机X偏移
      const left = centerX + Math.cos(angle) * distance + (Math.random() - 0.5) * 20;
      // 主要向下，但有一定随机性
      const top = centerY + Math.sin(angle) * distance * (0.3 + Math.random() * 0.4);
      
      // 随机水平偏移（向左或向右）
      const horizontalOffset = (Math.random() - 0.5) * 200; // -100到100px
      
      const rotation = Math.random() * 720 - 360; // 随机旋转角度 -360到360度
      const scale = 0.5 + Math.random() * 0.8; // 随机缩放 0.5-1.3
      
      const leftValue = Math.max(0, Math.min(100, left)); // 限制在0-100%范围内
      const topValue = Math.max(0, Math.min(100, top)); // 限制在0-100%范围内
      
      // 计算完整的 transform 字符串（包含所有随机值）
      // 初始状态：水平偏移、缩放、旋转
      const initialTransform = `translate(${horizontalOffset}px, 0) scale(${scale}) rotate(${rotation}deg)`;
      // 中间状态（30%）：水平偏移减少、垂直位移、放大、旋转减少
      const midTransform = `translate(${horizontalOffset * 0.3}px, 30vh) scale(${scale * 1.2}) rotate(${rotation * 0.3}deg)`;
      // 结束状态（100%）：水平偏移、垂直位移到底部、缩小、完整旋转
      const endTransform = `translate(${horizontalOffset}px, 100vh) scale(${scale * 0.3}) rotate(${rotation}deg)`;
      
      particles.push({
        id: Date.now() + i + Math.random() * 1000,
        left: leftValue,
        top: topValue,
        leftPercent: leftValue + '%', // 预计算百分号字符串
        topPercent: topValue + '%', // 预计算百分号字符串
        delay: Math.random() * 0.3, // 随机延迟 0-0.3秒
        rotation: rotation,
        scale: scale,
        offsetX: horizontalOffset, // 随机水平偏移
        initialTransform: initialTransform, // 初始 transform
        midTransform: midTransform, // 中间 transform
        endTransform: endTransform // 结束 transform
      });
    }
    
    console.log('[Cards] 创建爆炸粒子', particles.length, '中心位置:', centerX, centerY);
    this.setData({
      explosionParticles: particles
    });
    
    // 2秒后清除粒子
    setTimeout(() => {
      this.setData({
        explosionParticles: []
      });
    }, 2000);
  },
  // 执行点赞操作
  performLike(openid) {
    const makeRequest = () => {
      // 调用震动 API
      wx.vibrateShort({
        type: 'heavy',
        success: () => {
          console.log('震动成功');
        },
        fail: (err) => {
          console.log('震动失败', err);
        }
      });

      const token = auth.getToken();
      const headers = {
        'Content-Type': 'application/json'
      };
      if (token) {
        headers['Authorization'] = 'Bearer ' + token;
      }

      wx.request({
        url: `${API_BASE_URL}/profiles/${openid}/like`,
        method: 'POST',
        header: headers,
        success: (res) => {
          if (res.statusCode === 200 && res.data) {
            // 更新对应卡片的点赞数
            const cards = this.data.cards.map(card => {
              if (card.openid === openid) {
                return {
                  ...card,
                  likeCount: res.data.likeCount || res.data.like_count || card.likeCount + 1
                };
              }
              return card;
            });
            
            this.setData({ cards: cards });
          } else if (res.statusCode === 401) {
            // token 过期，尝试重新登录后重试
            console.log('Token 已过期，尝试重新登录...');
            const { silentLogin } = require('../../utils/auth');
            silentLogin()
              .then(() => {
                console.log('重新登录成功，重试点赞');
                // 重新发起请求
                makeRequest();
              })
              .catch((err) => {
                console.error('重新登录失败', err);
                console.error('点赞失败', res);
              });
          } else {
            console.error('点赞失败', res);
          }
        },
        fail: (err) => {
          console.error('请求失败', err);
        }
      });
    };

    // 发起请求
    makeRequest();
  },
  // 播放爆炸音效
  playExplosionSound() {
    try {
      const audioContext = wx.createInnerAudioContext();
      // 使用绝对路径，从项目根目录开始（以 / 开头）
      audioContext.src = '/images/audio_boom.mp3';
      audioContext.volume = 0.8; // 音量 0-1
      
      // 音频可以播放时
      audioContext.onCanplay(() => {
        console.log('[Cards] 爆炸音效可以播放');
        audioContext.play();
      });
      
      // 播放结束后销毁音频上下文
      audioContext.onEnded(() => {
        console.log('[Cards] 爆炸音效播放完成');
        audioContext.destroy();
      });
      
      // 错误处理
      audioContext.onError((err) => {
        console.error('[Cards] 播放爆炸音效失败', err);
        audioContext.destroy();
      });
      
      // 立即尝试播放
      audioContext.play();
    } catch (e) {
      console.error('[Cards] 创建音频上下文失败', e);
    }
  }
});

