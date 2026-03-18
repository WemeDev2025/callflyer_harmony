// pages/bg-gallery/bg-gallery.js
const app = getApp();
const BG_CACHE_KEY_V2 = 'bg_list_cache_v2';
const BG_CACHE_KEY_LEGACY = 'bg_list_cache';

function readBgCacheSync() {
  try {
    const v2 = wx.getStorageSync(BG_CACHE_KEY_V2);
    if (v2 && typeof v2 === 'object' && Array.isArray(v2.items)) return v2.items;
  } catch (e) {}
  try {
    const legacy = wx.getStorageSync(BG_CACHE_KEY_LEGACY);
    if (Array.isArray(legacy)) return legacy;
  } catch (e) {}
  return [];
}

// 模块级同步初始化（Page 对象创建前执行）
let _cachedList = null;
let _navBar = null;

try {
  const s = readBgCacheSync();
  if (s && s.length > 0) {
    _cachedList = (app && typeof app.normalizeBgList === 'function') ? app.normalizeBgList(s) : s;
  }
} catch (e) {}

// 提前计算导航栏尺寸（同步）
try {
  const info = wx.getSystemInfoSync();
  const mb = wx.getMenuButtonBoundingClientRect();
  _navBar = {
    statusBarHeight: info.statusBarHeight,
    menuButtonTop: mb.top,
    menuButtonHeight: mb.height,
    navBarHeight: mb.bottom + (mb.top - info.statusBarHeight),
  };
} catch (e) {
  _navBar = { statusBarHeight: 54, menuButtonTop: 60, menuButtonHeight: 32, navBarHeight: 98 };
}

// 模块级读取 isVip（同步）
let _isVip = false;
try {
  if (app && app.globalData && app.globalData.isVip) {
    _isVip = true;
  }
} catch (e) {}

Page({
    data: {
      backgrounds: [], // 页面初始不直接用缓存
      isVip: _isVip,
      loading: true,
      refreshing: false,
      ..._navBar,
  },
  onPullDownRefresh() {
    this.setData({ refreshing: true });
    this._ensureBgList(true);
    setTimeout(() => {
      this.setData({ refreshing: false });
      wx.stopPullDownRefresh && wx.stopPullDownRefresh();
    }, 1200);
  },

  onLoad() {
    const t0 = Date.now();
    this._unloaded = false;
    this.setData({ loading: true, backgrounds: [] });
    console.log('[Gallery] onLoad START, data ready:', {
      backgrounds: this.data.backgrounds.length,
      navBarHeight: this.data.navBarHeight,
      isVip: this.data.isVip
    });
    console.log('[Gallery] loading:', this.data.loading);
    // 每次进入都强制刷新图库接口数据
    this._ensureBgList(true);
    const t1 = Date.now();
    console.log('[Gallery] onLoad DONE, duration:', t1 - t0, 'ms');
  },

  onShow() {
    console.log('[Gallery] onShow')
    // 返回该页时（或进入后 app.js 刚更新完 globalData）同步一次 VIP 状态
    const isVip = !!(app.globalData && app.globalData.isVip);
    if (isVip !== this.data.isVip) this.setData({ isVip })
  },

  onReady() {
    console.log('[Gallery] onReady')
  },

  onUnload() {
    console.log('[Gallery] onUnload')
    this._unloaded = true
  },

  _ensureBgList(forceRefresh) {
    if (!app || typeof app.getBgList !== 'function') return
    if (this._fetching) return
    this._fetching = true
    console.log('[Gallery] ensure bgList...', { forceRefresh: !!forceRefresh })
    app.getBgList({ forceRefresh: !!forceRefresh, backgroundRefresh: true })
      .then((list) => {
        if (this._unloaded) return;
        if (!Array.isArray(list) || list.length === 0) {
          setTimeout(() => {
            this.setData({ loading: false, backgrounds: [] });
            console.log('[Gallery] loading:false (empty list)');
          }, 1200);
          return;
        }
        // 优化排序：按 createAt/timestamp 降序排列
        const sortedList = list.slice().sort((a, b) => {
          const ta = a.createAt || a.timestamp || 0;
          const tb = b.createAt || b.timestamp || 0;
          return tb - ta;
        });
        setTimeout(() => {
          this.setData({ backgrounds: sortedList, loading: false });
          console.log('[Gallery] loading:false (data ready), backgrounds:', sortedList.length);
          app.globalData.bgList = sortedList;
          try { wx.setStorageSync(BG_CACHE_KEY_V2, { ts: Date.now(), items: sortedList }); } catch (e) {}
          try { wx.setStorageSync(BG_CACHE_KEY_LEGACY, sortedList); } catch (e) {}
        }, 1200);
      })
      .catch(() => {
        setTimeout(() => {
          this.setData({ loading: false, backgrounds: [] })
          console.log('[Gallery] loading:false (catch)')
        }, 1200);
      })
      .finally(() => { this._fetching = false })
  },

  goBack() {
    wx.navigateBack({ delta: 1 });
  },

  onCardTap(e) {
    const { index } = e.currentTarget.dataset;
    const list = this.data.backgrounds;
    if (!list[index]) return;

    if (!this.data.isVip) {
      wx.showModal({
        title: '解锁 VIP',
        content: '精品背景是 VIP 专属功能\n\n解锁内容：VIP 背景 + 下课提醒\n价格：¥6 永久解锁',
        confirmText: '去解锁',
        cancelText: '取消',
        success: (res) => {
          if (res.confirm) wx.navigateTo({ url: '/pages/profile/profile' });
        }
      });
      return;
    }

    wx.navigateTo({
      url: `/pages/bg-preview/bg-preview?images=${encodeURIComponent(JSON.stringify(list.map(item => item.url)))}&current=${index}`
    });
  },

  onUseTap(e) {
    const { index } = e.currentTarget.dataset;
    const item = this.data.backgrounds[index];
    if (!item) return;
    this._applyBackground(item.url);
  },

  _applyBackground(url) {
    app.globalData.pendingBgUrl = url;
    const saved = wx.getStorageSync('course_bg_config') || {};
    saved.url = url;
    wx.setStorageSync('course_bg_config', saved);
    wx.showToast({ title: '已应用背景', icon: 'success' });
    setTimeout(() => wx.navigateBack({ delta: 1 }), 600);
  },
});
