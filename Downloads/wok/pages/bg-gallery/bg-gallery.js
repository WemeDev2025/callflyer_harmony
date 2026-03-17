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
    backgrounds: _cachedList || [],
    isVip: _isVip,
    ..._navBar,
  },

  onLoad() {
    const t0 = Date.now();
    this._unloaded = false
    console.log('[Gallery] onLoad START, data ready:', {
      backgrounds: this.data.backgrounds.length,
      navBarHeight: this.data.navBarHeight,
      isVip: this.data.isVip
    })

    // 修复历史缓存/接口偶发重复：仅在检测到需要修正时才 setData，避免无意义重渲染
    if (this.data.backgrounds && this.data.backgrounds.length > 0 && app && typeof app.normalizeBgList === 'function') {
      const normalized = app.normalizeBgList(this.data.backgrounds)
      const needFix = normalized.length !== this.data.backgrounds.length || !normalized[0] || !normalized[0].__key
      if (needFix) {
        console.warn('[Gallery] normalized backgrounds:', this.data.backgrounds.length, '->', normalized.length)
        this.setData({ backgrounds: normalized })
        app.globalData.bgList = normalized
        _cachedList = normalized
        try { wx.setStorageSync(BG_CACHE_KEY_V2, { ts: Date.now(), items: normalized }) } catch (e) {}
        try { wx.setStorageSync(BG_CACHE_KEY_LEGACY, normalized) } catch (e) {}
      }
    }

    // 同步到 globalData
    if (this.data.backgrounds.length > 0 && !app.globalData.bgList) {
      app.globalData.bgList = this.data.backgrounds;
    }
    if (!app.globalData._navBar) {
      app.globalData._navBar = _navBar;
    }

    // 统一链路：从 App.getBgList() 取（含 in-flight 锁 + storage/memory 缓存 + 后台刷新）
    this._ensureBgList(false)
    
    const t1 = Date.now();
    console.log('[Gallery] onLoad DONE, duration:', t1 - t0, 'ms')
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
        if (this._unloaded) return
        if (!Array.isArray(list) || list.length === 0) return
        const cur = this.data.backgrounds || []
        const needUpdate =
          cur.length === 0 ||
          cur.length !== list.length ||
          (!!cur[0] && !!list[0] && cur[0].__key !== list[0].__key)
        if (needUpdate) this.setData({ backgrounds: list })
      })
      .catch(() => {})
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

    wx.previewImage({
      current: list[index].url,
      urls: list.map(item => item.url),
      showmenu: true,
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
