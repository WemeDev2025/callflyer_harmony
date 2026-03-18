// pages/course-schedule/course-schedule.js
const app = getApp();
const RecycleContext = require('miniprogram-recycle-view');
const plugin = requirePlugin('WechatSI');
const manager = plugin.getRecordRecognitionManager();
const { createReminder, cancelReminder, getReminderById, getMySchedule, saveMySchedule, createScheduleTemplate, cloneScheduleTemplate } = require('../../utils/api.js');

Page({
  data: {
    currentDateStr: '',
    currentDayIndex: 0,
    statusBarHeight: 20,
    menuButtonTop: 24, // 默认胶囊顶部偏移
    menuButtonHeight: 32, // 默认胶囊高度
    weekDays: [
      { name: '星期一', shortName: '周一' },
      { name: '星期二', shortName: '周二' },
      { name: '星期三', shortName: '周三' },
      { name: '星期四', shortName: '周四' },
      { name: '星期五', shortName: '周五' },
      { name: '星期六', shortName: '周六' },
      { name: '星期日', shortName: '周日' }
    ],
    scheduleData: [
      [], [], [], [], [], [], [] // 7 days
    ],
    showModal: false,
    isRecording: false,
    isEditing: false,
    editingIndex: -1,
    editingDay: -1,
    newCourse: {
      name: '',
      location: '',
      startTime: '08:00',
      endTime: '09:50',
      dayIdx: 0,
      isEndReminderEnabled: false,
      reminderId: null  // 已有提醒的ID，用于编辑时取消旧提醒
    },
    reminderOptions: ['准时', '5分钟前', '10分钟前', '15分钟前'],
    reminderValues: [0, 5, 10, 15],
    reminderIndex: 0,
    colors: ['#E3F2FD', '#F3E5F5', '#E8F5E9', '#FFFDE7', '#FBE9E7', '#EFEBE9'],
    textColors: ['#1A1A1A', '#FFFFFF', '#5C7CFA', '#FF6B35', '#2F9E44', '#E03131'],
    showBgModal: false,
    showModal: false,
    modalClosing: false,
    bgModalClosing: false,
    bgConfig: {
      url: '',
      opacity: 0.2,
      blur: 0,
      textColor: '#1A1A1A'
    },
    defaultBgConfig: {
      url: '',
      opacity: 0.2,
      blur: 0,
      textColor: '#1A1A1A'
    },
    vipBackgrounds: [],
    emptyImgTimestamp: Date.now(),
    isAdjustingBg: false,
    scrollTop: 0,
    emptyImages: [
      '/images/emo1.png',
      '/images/emo2.png',
      '/images/emo3.png',
      '/images/emo4.png',
      '/images/emo5.png',
      '/images/icon_home.png',
      '/images/icon_home.png'
    ],
    scrollIntoView: '',
    renderMin: 0,
    renderMax: 2,
    shareCodeResult: '',
    shareLoading: false,
    shareCodeReady: false,
    shareDirty: false,
    isSamsung: false,
    menuButtonHeightRpx: 64,
    iconSizeRpx: 58,
    iconAnim: {},
    iconLoadError: false,
    iconVisible: true,
    isVip: false,
    recycleList: [],
    batchSetRecycleData: false,
    swipeDir: 'left',
    cardAnimKey: 0,
    listAnimName: 'listInFromRight',
    _lastSwiperIndex: 0,
    swiperAnimating: false,
  },

  onLoad(options) {
    this._loadOptions = options || {};
    this.initDate();
    this.initVoiceManager();
    const todayIdx = this.getTodayIndex();
    this.setData({
      currentDayIndex: todayIdx,
      renderMin: Math.max(0, todayIdx - 2),
      renderMax: Math.min(6, todayIdx + 2),
      isVip: !!(app.globalData && app.globalData.isVip),
      _lastSwiperIndex: todayIdx
    });
    // globalData.isVip 可能还未就绪（登录异步），主动查一次确保准确
    if (!app.globalData.isVip) {
      this._fetchVipStatus();
    }
    this._recycleListCache = {}; // cache 当前可复用的 recycle-view 列表数据
    this.loadScheduleFromServer();

    this.fetchVipBackgrounds();

    // 获取系统状态栏高度及胶囊按钮位置
    const info = wx.getSystemInfoSync();
    const model = (info.model || '').toLowerCase();
    const brand = (info.brand || '').toLowerCase();
    const isSamsung = model.includes('samsung') || brand.includes('samsung') || brand.includes('三星');
    try {
      const menuButton = wx.getMenuButtonBoundingClientRect();
      this.setData({
        statusBarHeight: info.statusBarHeight,
        menuButtonTop: menuButton.top,
        menuButtonHeight: menuButton.height,
        menuButtonHeightRpx: menuButton.height * 2,
        iconSizeRpx: Math.round(menuButton.height * 2 * 1.53),
        isSamsung: isSamsung
      }, () => {
        console.log('[Schedule] iconSizeRpx:', this.data.iconSizeRpx);
      });
    } catch (e) {
      this.setData({
        statusBarHeight: info.statusBarHeight,
        menuButtonHeightRpx: 64,
        iconSizeRpx: 99,
        isSamsung: isSamsung
      });
    }
  },

  onReady() {
    this._initRecycleView();
    this._updateRecycleList(true);
    // 额外 selectComponent 静态 id，debug
    const debugComp = this.selectComponent('#course-recycle-debug');
    if (debugComp) {
      console.log('[DEBUG] 成功 selectComponent #course-recycle-debug:', debugComp);
    } else {
      console.warn('[DEBUG] selectComponent #course-recycle-debug 失败');
    }
  },

  onShareAppMessage() {
    const shareCode = this.data.shareCodeResult || wx.getStorageSync('course_share_code') || '';
    const title = shareCode ? '欢迎使用我的课程表' : '我的课程表';
    const path = shareCode ? `/pages/course-schedule/course-schedule?shareCode=${shareCode}` : '/pages/course-schedule/course-schedule';

    return {
      title: title,
      path: path,
      imageUrl: 'https://wemedev.com/wok/data/bg/pic_share.png'
    };
  },

  onShareTimeline() {
    const shareCode = this.data.shareCodeResult || wx.getStorageSync('course_share_code') || '';
    const title = shareCode ? '欢迎使用我的课程表' : '我的课程表';
    const query = shareCode ? `shareCode=${shareCode}` : '';

    return {
      title: title,
      query: query,
      imageUrl: 'https://wemedev.com/wok/data/bg/pic_share.png'
    };
  },

  onShow() {
    const t0 = Date.now();
    console.log('[Schedule] onShow START')
    
    // VIP 状态同步（同步执行，不延迟）
    const isVip = !!(app.globalData && app.globalData.isVip);
    if (isVip !== this.data.isVip) {
      console.log('[Schedule] updating isVip:', isVip)
      this.setData({ isVip });
    }
    if (!isVip) {
      setTimeout(() => this._fetchVipStatus(), 100);
    }

    // 背景图更新（同步执行）
    const pendingUrl = app.globalData.pendingBgUrl;
    if (pendingUrl) {
      console.log('[Schedule] applying pending bg:', pendingUrl.substring(0, 50))
      app.globalData.pendingBgUrl = null;
      const newBgConfig = Object.assign({}, this.data.bgConfig, { url: pendingUrl });
      this.setData({ bgConfig: newBgConfig });
      wx.setStorageSync('course_bg_config', newBgConfig);
      this.queueScheduleSync(300);
    } else {
      const savedBg = wx.getStorageSync('course_bg_config');
      if (savedBg && savedBg.url !== this.data.bgConfig.url) {
        console.log('[Schedule] updating bg from storage')
        this.setData({ bgConfig: Object.assign({}, this.data.bgConfig, savedBg) });
      }
    }

    // emptyImgTimestamp 仅在“可见范围内存在空状态”时更新，避免返回页时无意义的大范围重绘
    try {
      const schedule = this.data.scheduleData || []
      const min = Math.max(0, this.data.renderMin || 0)
      const max = Math.min(6, this.data.renderMax || 6)
      let hasEmptyVisibleDay = false
      for (let i = min; i <= max; i++) {
        const day = schedule[i]
        if (!day || day.length === 0) { hasEmptyVisibleDay = true; break }
      }
      if (hasEmptyVisibleDay) {
        if (this._emptyImgTsTimer) clearTimeout(this._emptyImgTsTimer)
        this._emptyImgTsTimer = setTimeout(() => {
          this._emptyImgTsTimer = null
          this.setData({ emptyImgTimestamp: Date.now() })
        }, 200)
      }
    } catch (e) {}
    
    const t1 = Date.now();
    console.log('[Schedule] onShow DONE, total:', t1 - t0, 'ms')

    // 避免页面未渲染完成时触发 recycle-view 更新
  },

  /**
   * app.js refreshVipStatus 完成后的回调，保持页面状态同步
   */
  onVipUpdate(isVip) {
    this.setData({ isVip: !!isVip });
  },

  /**
   * 主动查询 VIP 状态（onLoad 时 globalData 可能还未就绪）
   * 直接从 profile 接口读 isVip，与 app.js 保持一致
   */
  async _fetchVipStatus() {
    try {
      const { getProfile } = require('../../utils/api.js');
      const profile = await getProfile();
      const isVip = !!(profile && profile.isVip);
      app.globalData.isVip = isVip;
      this.setData({ isVip });
      console.log('[Schedule] VIP 状态:', isVip);
    } catch (e) {
      console.warn('[Schedule] 获取 VIP 状态失败:', e.message || e);
    }
  },

  onUnload() {
    // 页面卸载时停止识别
    manager.stop();
    if (this._scheduleSyncTimer) {
      clearTimeout(this._scheduleSyncTimer);
      this._scheduleSyncTimer = null;
    }
    if (this._swiperChangeTimer) {
      clearTimeout(this._swiperChangeTimer);
      this._swiperChangeTimer = null;
    }
    if (this._renderExpandTimer) {
      clearTimeout(this._renderExpandTimer);
      this._renderExpandTimer = null;
    }
    if (this._emptyImgTsTimer) {
      clearTimeout(this._emptyImgTsTimer)
      this._emptyImgTsTimer = null
    }
    if (this._recycleRetryTimer) {
      clearTimeout(this._recycleRetryTimer)
      this._recycleRetryTimer = null
    }
    if (this._recycleInitTimer) {
      clearTimeout(this._recycleInitTimer)
      this._recycleInitTimer = null
    }
    if (this._shareCodeTimer) {
      clearTimeout(this._shareCodeTimer);
      this._shareCodeTimer = null;
    }
  },

  initDate() {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const day = now.getDate();
    this.setData({
      currentDateStr: `${year}年${month}月${day}日`
    });
  },

  initVoiceManager() {
    manager.onRecognize = (res) => {
      console.log('Voice recognizing...', res.result);
    };
    manager.onStop = (res) => {
      console.log('Voice recognized:', res.result);
      this.handleVoiceResult(res.result);
    };
    manager.onError = (res) => {
      console.error('Voice error:', res.msg, res);
      this.setData({ isRecording: false });
    };
  },

  getTodayIndex() {
    const day = new Date().getDay(); // 0 (Sun) to 6 (Sat)
    // 转换: Mon(1)->0, Tue(2)->1, ..., Sat(6)->5, Sun(0)->6
    return day === 0 ? 6 : day - 1;
  },

  _initRecycleView() {
    if (this._recycleCtx) return;
    // 尝试找到任意一个可用的 recycle-view 实例（支持 debug id 或按 dayIdx 的 id）
    let foundId = null;
    const tryIds = ['#course-recycle', '#course-recycle-debug'];
    for (let i = 0; i < 7; i++) tryIds.push(`#course-recycle-${i}`);

    for (const sel of tryIds) {
      const c = this.selectComponent(sel);
      if (c) {
        foundId = sel.replace(/^#/, '');
        console.log('[Schedule] found recycle-view component:', sel);
        break;
      }
    }

    if (!foundId) {
      if (this._recycleInitTimer) clearTimeout(this._recycleInitTimer);
      this._recycleInitTimer = setTimeout(() => {
        this._recycleInitTimer = null;
        this._initRecycleView();
      }, 50);
      return;
    }

    try {
      this._recycleCtx = new RecycleContext({
        id: foundId,
        dataKey: 'recycleList',
        page: this,
        itemSize: function () {
          return {
            width: this.transformRpx(750),
            height: this.transformRpx(200)
          };
        }
      });
      if (this._recycleCtx && this._recycleCtx.page && this._recycleCtx.page._recycleViewportChange) {
        this._recycleCtx.page._recycleViewportChange = this._recycleCtx.page._recycleViewportChange.bind(this._recycleCtx.page);
      }
      this._recycleCompId = foundId;
      console.log('[Schedule] recycle-view initialized with id:', foundId);
    } catch (e) {
      console.warn('[Schedule] recycle-view init failed:', e && e.message);
    }
  },

  _invalidateRecycleCache() {
    this._recycleListCache = {};
  },

  _buildRecycleList(dayIdx, dir, animKey) {
    const idx = typeof dayIdx === 'number' ? dayIdx : (this.data.currentDayIndex || 0);
    const useDir = dir || this.data.swipeDir;
    const useAnimKey = typeof animKey === 'number' ? animKey : this.data.cardAnimKey;
    const cacheKey = `${idx}:${useDir}:${useAnimKey}`;

    if (!this._recycleListCache) {
      this._recycleListCache = {};
    }

    const cached = this._recycleListCache[cacheKey];
    if (cached) {
      return cached;
    }

    const list = (this.data.scheduleData && this.data.scheduleData[idx]) || [];
    const mapped = list.map((item, index) => Object.assign({}, item, { __index__: index, __dir__: useDir, __anim__: useAnimKey }));
    this._recycleListCache[cacheKey] = mapped;
    return mapped;
  },

  _getListAnimName(dir, animKey) {
    const useDir = dir || this.data.swipeDir;
    const useKey = typeof animKey === 'number' ? animKey : this.data.cardAnimKey;
    // dir 表示滑动方向：'left' = 向左滑动（手指从右向左），内容从右侧进入
    // 'right' = 向右滑动（手指从左向右），内容从左侧进入
    let animName;
    if (useDir === 'left') {
      animName = useKey ? 'listInFromRight' : 'listInFromRight2';
    } else {
      animName = useKey ? 'listInFromLeft' : 'listInFromLeft2';
    }
    console.log('[Schedule] _getListAnimName:', { dir: useDir, animKey: useKey, result: animName });
    return animName;
  },

  _updateRecycleList(allowRetry) {
    console.log('[测试] _updateRecycleList 被调用');
    // 遍历所有 dayIdx 的 recycle-view
    for (let dayIdx = 0; dayIdx < 7; dayIdx++) {
      const comp = this.selectComponent(`#course-recycle-${dayIdx}`);
      if (!comp) {
        console.log(`[调试] selectComponent #course-recycle-${dayIdx} 为空`);
        continue;
      }
      if (!this._recycleCtx) {
        console.log('[调试] _recycleCtx 为空，尝试初始化');
        this._initRecycleView();
        // 不再 continue，让后续 setData 仍然尝试更新列表（若 _recycleCtx 尚未就绪，更新会走 setData 路径）
      }
      const list = (this.data.scheduleData && this.data.scheduleData[dayIdx]) || [];
      console.log('[调试] list:', list, '当前 dayIdx:', dayIdx, 'scheduleData:', this.data.scheduleData);
      if (!Array.isArray(list) || list.length === 0) {
        console.log('[调试] list 为空，未遍历课程');
      }
      list.forEach((course, idx) => {
        const show = !!(course && course.reminderId);
        console.log('[铃铛判断]', JSON.stringify({
          name: course && course.name,
          reminderId: course && course.reminderId,
          reminderIdType: typeof (course && course.reminderId),
          reminderIdRaw: course && course.reminderId,
          show,
          idx,
          id: `course-${dayIdx}-${idx}`,
          courseObj: course
        }));
      });
      try {
        // 先同步一次 dataKey，避免组件尚未完成内部计算时空白
        this.setData({ [`recycleList[${dayIdx}]`]: list });
        if (this._recycleCtx && this._recycleCtx.update) {
          this._recycleCtx.update(0, list);
        }
      } catch (e) {
        console.warn('[Schedule] recycle-view update failed:', e && e.message);
        // 兜底：至少让列表显示出来
        this.setData({ [`recycleList[${dayIdx}]`]: list });
        if (this._recycleCtx && this._recycleCtx.update) {
          this._recycleCtx = null;
          this._initRecycleView();
        }
      }
    }
  },

  onSwiperChange(e) {
    const idx = e.detail.current;
    const prev = typeof this.data._lastSwiperIndex === 'number' ? this.data._lastSwiperIndex : this.data.currentDayIndex;
    const dir = idx > prev ? 'left' : 'right';

    // 节流：同一帧内多次触发只处理最后一次
    if (this._swiperChangeTimer) clearTimeout(this._swiperChangeTimer);
    this._swiperChangeTimer = setTimeout(() => {
      this._swiperChangeTimer = null;
      const nearMin = Math.max(0, idx - 1);
      const nearMax = Math.min(6, idx + 1);
      const updates = {};

      if (idx !== this.data.currentDayIndex) {
        updates.currentDayIndex = idx;
        console.log('[Schedule] swipe', { prev, idx, dir });
        updates.swipeDir = dir;
        updates.cardAnimKey = (this.data.cardAnimKey + 1) % 2;
        updates._lastSwiperIndex = idx;
      }

      if (this.data.renderMin !== nearMin) updates.renderMin = nearMin;
      if (this.data.renderMax !== nearMax) updates.renderMax = nearMax;
      if (this.data.iconLoadError) updates.iconLoadError = false;

      const nextDir = typeof updates.swipeDir === 'string' ? updates.swipeDir : this.data.swipeDir;
      const nextAnimKey = typeof updates.cardAnimKey === 'number' ? updates.cardAnimKey : this.data.cardAnimKey;
      updates.listAnimName = this._getListAnimName(nextDir, nextAnimKey);

      const nextList = this._buildRecycleList(idx, nextDir, nextAnimKey);

      if (Object.keys(updates).length > 0) {
        this.setData(Object.assign({}, updates, { recycleList: nextList }), () => {
          wx.nextTick(() => this._updateRecycleList(true));
        });
      } else {
        this.setData({ recycleList: nextList }, () => {
          wx.nextTick(() => this._updateRecycleList(true));
        });
      }

      // 逐步扩展渲染范围：先 +1，后续按需扩展到 +2
      if (this._renderExpandTimer) clearTimeout(this._renderExpandTimer);
      this._renderExpandTimer = setTimeout(() => {
        this._renderExpandTimer = null;
        const farMin = Math.max(0, idx - 2);
        const farMax = Math.min(6, idx + 2);
        if (this.data.renderMin !== farMin || this.data.renderMax !== farMax) {
          this.setData({ renderMin: farMin, renderMax: farMax });
        }
      }, 120);
    }, 16); // 一帧时间，合并连续触发
  },

  onSwiperAnimationFinish(e) {
    // swiper 动画完成的回调（保留以防后续需要）
  },

  playIconEntrance() {},

  onIconError(e) {
    console.warn('[Schedule] icon load error:', e);
    this.setData({
      iconLoadError: true
    });
  },

  showAddModal() {
    const dayIdx = this.data.currentDayIndex;
    const { startTime, endTime } = this._calcNextCourseTime(dayIdx);

    this.setData({
      showModal: true,
      isEditing: false,
      'newCourse.dayIdx': dayIdx,
      'newCourse.name': '',
      'newCourse.location': '',
      'newCourse.startTime': startTime,
      'newCourse.endTime': endTime,
      'newCourse.isEndReminderEnabled': false,
      'newCourse.reminderId': null
    });
  },

  hideAddModal() {
    this.setData({ modalClosing: true });
    setTimeout(() => {
      this.setData({ 
        showModal: false,
        modalClosing: false,
        isEditing: false,
        editingIndex: -1,
        editingDay: -1
      });
    }, 250);
  },

  onCourseTap(e) {
    const { day, index } = e.currentTarget.dataset;
    const course = this.data.scheduleData[day][index];
    console.log('[Schedule] onCourseTap course:', JSON.stringify(course));
    
    this.setData({
      showModal: true,
      isEditing: true,
      editingIndex: index,
      editingDay: day,
      newCourse: {
        name: course.name,
        location: course.location || '',
        startTime: course.startTime,
        endTime: course.endTime,
        dayIdx: parseInt(day),
        isEndReminderEnabled: !!course.reminderId,
        reminderId: course.reminderId || null
      }
    });
    // 恢复提醒时间选项
    if (course.reminderId && course.reminderMinutes !== undefined) {
      const idx = this.data.reminderValues.indexOf(course.reminderMinutes)
      this.setData({ reminderIndex: idx >= 0 ? idx : 0 })
    } else {
      this.setData({ reminderIndex: 0 })
    }

    // 如果有 reminderId，异步检查是否已发送完成
    if (course.reminderId) {
      getReminderById(course.reminderId).then(reminder => {
        const done = reminder && (reminder.status === 'sent' || reminder.status === 'failed')
        if (done) {
          console.log('[Reminder] status:', reminder.status, '- clearing reminderId')
          this.setData({
            'newCourse.isEndReminderEnabled': false,
            'newCourse.reminderId': null,
            reminderIndex: 0
          })
          const updatedSchedule = JSON.parse(JSON.stringify(this.data.scheduleData))
          const courses = updatedSchedule[day]
          if (courses[index]) {
            courses[index].reminderId = null
            courses[index].reminderMinutes = undefined
            this._invalidateRecycleCache();
          this.setData({ scheduleData: updatedSchedule }, () => {
              this._updateRecycleList();
              wx.setStorageSync('course_schedule', updatedSchedule)
              this.queueScheduleSync(300)
            })
          }
        }
      }).catch(() => {
        // 查询失败静默处理，不影响编辑
      })
    }
  },

  showBgEditor() {
    this.setData({ showBgModal: true });
    console.log('[BG] Editor opened, current config:', this.data.bgConfig);
  },

  openBgGallery() {
    wx.navigateTo({ url: '/pages/bg-gallery/bg-gallery' });
  },

  hideBgEditor() {
    this.setData({ bgModalClosing: true });
    setTimeout(() => {
      this.setData({ 
        showBgModal: false,
        bgModalClosing: false
      });
    }, 250);
  },

  fetchVipBackgrounds() {
    if (!app || typeof app.getBgList !== 'function') return
    app.getBgList({ backgroundRefresh: true })
      .then(list => {
        if (Array.isArray(list) && list.length > 0) {
          this.setData({ vipBackgrounds: list })
        }
      })
      .catch(() => {})
  },

  /**
   * 加载课表（优先服务器，失败再读本地）
   */
  async loadScheduleFromServer() {
    const options = this._loadOptions;
    if (options && options.shareCode) {
      this.ensureLoginThenImport(options.shareCode);
      return;
    }

    try {
      const result = await getMySchedule();
      if (result) {
        const serverContent = result.contentJson || {
          scheduleData: result.scheduleData,
          bgConfig: result.bgConfig
        };
        this.applyScheduleContent(serverContent, true);
        return;
      }
    } catch (error) {
      if (error && error.message && error.message.includes('资源不存在')) {
        console.log('[Schedule] server has no schedule, fallback to local');
      } else {
        console.warn('[Schedule] load from server failed, fallback to local:', error && error.message);
      }
    }

    const savedData = wx.getStorageSync('course_schedule');
    const savedBg = wx.getStorageSync('course_bg_config');
    const fallbackContent = {
      scheduleData: savedData || null,
      bgConfig: savedBg || null
    };
    this.applyScheduleContent(fallbackContent, false);

    if (savedData && savedData.length > 0) {
      this.queueScheduleSync();
    }
  },

  ensureLoginThenImport(shareCode) {
    const app = getApp();
    if (app && app.globalData && app.globalData.isLoggedIn) {
      this.importShareCode(shareCode);
      return;
    }

    if (app && typeof app.silentLogin === 'function') {
      app.silentLogin()
        .then(() => this.importShareCode(shareCode))
        .catch(() => {
          wx.showModal({
            title: '需要登录',
            content: '登录后才可以查看分享的课程表，是否现在登录？',
            confirmText: '登录',
            cancelText: '取消',
            success: res => {
              if (res.confirm) {
                app.silentLogin()
                  .then(() => this.importShareCode(shareCode))
                  .catch(() => {
                    wx.showToast({
                      title: '登录失败，请稍后重试',
                      icon: 'none'
                    });
                  });
              }
            }
          });
        });
      return;
    }

    wx.showToast({
      title: '请先登录后查看',
      icon: 'none'
    });
  },

  /**
   * 规范化并应用课表内容
   */
  applyScheduleContent(content, persistLocal) {
    const normalized = this.normalizeScheduleContent(content);
    this._invalidateRecycleCache();
    this.setData({
      scheduleData: normalized.scheduleData,
      bgConfig: normalized.bgConfig,
      shareDirty: false
    }, () => {
      console.log('[DEBUG] scheduleData after applyScheduleContent:', JSON.stringify(this.data.scheduleData && this.data.scheduleData.map((d, i) => ({day: i, len: (d && d.length) || 0, sample: (d && d.slice(0,3)) || []}))))
      this._updateRecycleList();
    });

    if (persistLocal) {
      wx.setStorageSync('course_schedule', normalized.scheduleData);
      wx.setStorageSync('course_bg_config', normalized.bgConfig);
    }
  },

  /**
   * 规范化课程表内容
   */
  normalizeScheduleContent(content) {
    const scheduleData = Array.isArray(content && content.scheduleData)
      ? JSON.parse(JSON.stringify(content.scheduleData))
      : null;

    const normalizedSchedule = scheduleData && scheduleData.length > 0
      ? scheduleData
      : [[], [], [], [], [], [], []];

    while (normalizedSchedule.length < 7) {
      normalizedSchedule.push([]);
    }

    const bgConfig = Object.assign(
      {},
      this.data.defaultBgConfig,
      content && content.bgConfig ? content.bgConfig : {}
    );

    return {
      scheduleData: normalizedSchedule,
      bgConfig: bgConfig
    };
  },

  buildSchedulePayload() {
    return {
      title: '我的课程表',
      contentJson: {
        scheduleData: this.data.scheduleData,
        bgConfig: this.data.bgConfig
      }
    };
  },

  buildSharePayload() {
    const sanitized = JSON.parse(JSON.stringify(this.data.scheduleData || []));
    sanitized.forEach(day => {
      if (Array.isArray(day)) {
        day.forEach(course => {
          if (course && course.reminderId) {
            course.reminderId = null;
          }
        });
      }
    });

    return {
      title: '我的课程表',
      contentJson: {
        scheduleData: sanitized,
        bgConfig: this.data.bgConfig
      }
    };
  },

  queueShareCodeRefresh(delay = 1200) {
    clearTimeout(this._shareCodeTimer);
    this._shareCodeTimer = setTimeout(() => {
      if (this.data.shareLoading) return;
      if (!this.data.shareDirty) return;
      this.generateShareCode();
    }, delay);
  },

  queueScheduleSync(delay = 600) {
    clearTimeout(this._scheduleSyncTimer);
    this._scheduleSyncTimer = setTimeout(() => {
      this.syncScheduleToServer();
    }, delay);
  },

  async syncScheduleToServer() {
    try {
      await saveMySchedule(this.buildSchedulePayload());
    } catch (error) {
      if (error && error.message && (error.message.includes('过期') || error.message.includes('401'))) {
        const app = getApp();
        if (app && typeof app.silentLogin === 'function') {
          try {
            await app.silentLogin();
            await saveMySchedule(this.buildSchedulePayload());
            return;
          } catch (loginErr) {
            console.warn('[Schedule] sync failed after re-login:', loginErr && loginErr.message);
          }
        }
      }
      console.warn('[Schedule] sync failed:', error && error.message);
    }
  },

  selectVipBackground(e) {
    const { url } = e.currentTarget.dataset;
    // VIP 门控：选择精品背景需要 VIP
    if (!this.data.isVip) {
      wx.showModal({
        title: '解锁 VIP',
        content: '精品背景是 VIP 专属功能\n\n解锁内容：VIP 背景 + 下课提醒\n价格：¥6 永久解锁',
        confirmText: '去解锁',
        cancelText: '取消',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({ url: '/pages/profile/profile' });
          }
        }
      });
      return;
    }
    wx.vibrateShort({ type: 'medium' });
    this.setData({ 'bgConfig.url': url }, () => { this.saveBgConfig(); });
  },

  chooseBackground() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const tempFilePath = res.tempFiles[0].tempFilePath;
        console.log('[BG] Image chosen:', tempFilePath);
        this.setData({
          'bgConfig.url': tempFilePath
        }, () => {
          this.saveBgConfig();
        });
      }
    });
  },

  onOpacityChange(e) {
    const val = parseFloat(e.detail.value).toFixed(1);
    console.log('[BG] Opacity changing:', val);
    this.setData({
      'bgConfig.opacity': val
    }, () => {
      this.saveBgConfig();
    });
  },

  onBlurChange(e) {
    const val = parseInt(e.detail.value);
    console.log('[BG] Blur changing:', val);
    this.setData({
      'bgConfig.blur': val
    }, () => {
      this.saveBgConfig();
    });
  },

  onEndReminderToggle(e) {
    const enabled = e.detail.value;
    // VIP 门控：下课提醒需要 VIP
    if (enabled && !this.data.isVip) {
      this.setData({ 'newCourse.isEndReminderEnabled': false });
      wx.showModal({
        title: '解锁 VIP',
        content: '下课提醒是 VIP 专属功能\n\n解锁内容：VIP 背景 + 下课提醒\n价格：¥6 永久解锁',
        confirmText: '去解锁',
        cancelText: '取消',
        success: (res) => {
          if (res.confirm) {
            wx.navigateTo({ url: '/pages/profile/profile' });
          }
        }
      });
      return;
    }
    this.setData({ 'newCourse.isEndReminderEnabled': enabled });
  },

  onEndReminderTimeChange(e) {
    this.setData({ reminderIndex: e.detail.value });
  },

  startAdjusting() {
    this.setData({ isAdjustingBg: true });
    wx.vibrateShort({ type: 'medium' });
  },

  stopAdjusting() {
    this.setData({ isAdjustingBg: false });
  },

  clearBackground() {
    this.setData({
      'bgConfig.url': '',
      'bgConfig.opacity': 0.5,
      'bgConfig.blur': 0,
      'bgConfig.textColor': '#1A1A1A'
    }, () => {
      this.saveBgConfig();
    });
  },

  onTextColorChange(e) {
    const color = e.currentTarget.dataset.color;
    wx.vibrateShort({ type: 'medium' });
    console.log('[BG] Text color changing:', color);
    this.setData({
      'bgConfig.textColor': color
    }, () => {
      this.saveBgConfig();
    });
  },

  saveBgConfig() {
    wx.setStorageSync('course_bg_config', this.data.bgConfig);
    this.queueScheduleSync();
    this.setData({ shareDirty: true });
    this.queueShareCodeRefresh(2000);
  },

  onStartTimeChange(e) {
    this.setData({ 'newCourse.startTime': e.detail.value });
  },

  onEndTimeChange(e) {
    this.setData({ 'newCourse.endTime': e.detail.value });
  },

  onCourseNameInput(e) {
    this.setData({ 'newCourse.name': e.detail.value });
  },

  onCourseLocationInput(e) {
    this.setData({ 'newCourse.location': e.detail.value });
  },

  selectNewCourseDay(e) {
    this.setData({ 'newCourse.dayIdx': e.currentTarget.dataset.index });
  },

  saveCourse() {
    const { name, startTime, endTime, dayIdx, location, isEndReminderEnabled, reminderId } = this.data.newCourse;
    const { isEditing, editingIndex, editingDay } = this.data;
    
    console.log('[Schedule] Trying to save course:', { name, startTime, dayIdx, isEditing });
    
    if (!name) {
      wx.showToast({ title: '请输入课程名', icon: 'none' });
      return;
    }

    const scheduleData = JSON.parse(JSON.stringify(this.data.scheduleData));
    
    const entry = {
      name,
      startTime,
      endTime,
      location,
      color: isEditing ? this.data.scheduleData[editingDay][editingIndex].color : this.data.colors[Math.floor(Math.random() * this.data.colors.length)],
      reminderId: reminderId || null,  // 保留已有提醒ID
      reminderMinutes: isEndReminderEnabled ? (this.data.reminderValues[this.data.reminderIndex] || 0) : undefined
    };

    if (isEditing) {
      scheduleData[editingDay].splice(editingIndex, 1);
      scheduleData[dayIdx].push(entry);
    } else {
      scheduleData[dayIdx].push(entry);
    }
    
    // 重新排序
    scheduleData[dayIdx].sort((a, b) => a.startTime.localeCompare(b.startTime));

    // 如果开启了下课提醒，必须在用户点击事件的同步链中直接调用 requestSubscribeMessage
    if (isEndReminderEnabled) {
      // 已有提醒ID，直接保存，不重复创建
      if (reminderId) {
        this._saveScheduleData(scheduleData, dayIdx, entry, isEditing, editingDay, editingIndex);
        return;
      }

      const REMINDER_TEMPLATE_ID = '4ulitsyR2Oor9s9pyBnD1uf7GQEwqeQMYIQdCDm7HwU';
      
      wx.requestSubscribeMessage({
        tmplIds: [REMINDER_TEMPLATE_ID],
        success: (res) => {
          const status = res[REMINDER_TEMPLATE_ID];
          if (status === 'accept') {
            // 用户授权，先保存课程，再调后端创建提醒
            this._saveScheduleData(scheduleData, dayIdx, entry, isEditing, editingDay, editingIndex, (savedEntry) => {
              this._createCourseReminder(savedEntry, dayIdx, scheduleData);
            });
          } else {
            // 用户拒绝或关闭，仍然保存课程，但不设置提醒
            entry.reminderId = null;
            wx.showToast({ title: status === 'deny' ? '提醒授权已拒绝' : '未授权，提醒未设置', icon: 'none' });
            this._saveScheduleData(scheduleData, dayIdx, entry, isEditing, editingDay, editingIndex);
          }
        },
        fail: (err) => {
          console.error('[Reminder] requestSubscribeMessage failed:', err);
          wx.showToast({ title: '授权失败，提醒未设置', icon: 'none' });
          entry.reminderId = null;
          this._saveScheduleData(scheduleData, dayIdx, entry, isEditing, editingDay, editingIndex);
        }
      });
    } else {
      // 未开启提醒：如果之前有提醒，取消它
      if (reminderId) {
        cancelReminder(reminderId).catch(err => {
          console.error('[Reminder] cancel failed:', err);
        });
        entry.reminderId = null;
        // 更新 scheduleData 中的 reminderId
        const idx = scheduleData[dayIdx].findIndex(c => c.name === entry.name && c.startTime === entry.startTime);
        if (idx !== -1) scheduleData[dayIdx][idx].reminderId = null;
      }
      this._saveScheduleData(scheduleData, dayIdx, entry, isEditing, editingDay, editingIndex);
    }
  },

  /**
   * 实际保存课程数据到 storage 和 state
   * @param {Array} scheduleData 完整课程数据
   * @param {number} dayIdx 目标日期索引
   * @param {Object} entry 课程条目
   * @param {boolean} isEditing 是否编辑模式
   * @param {number} editingDay 原来的日期索引
   * @param {number} editingIndex 原来的课程索引
   * @param {Function} callback 保存成功后的回调，参数为最终的 entry
   */
  _saveScheduleData(scheduleData, dayIdx, entry, isEditing, editingDay, editingIndex, callback) {
    this._invalidateRecycleCache();
    const targetIndex = scheduleData[dayIdx].findIndex(c => 
      c.name === entry.name && c.startTime === entry.startTime
    );
    const targetViewId = targetIndex >= 0 ? `course-${dayIdx}-${targetIndex}` : '';

    // 立即更新数据，同时触发关闭动画，两者并行
    this.setData({
      scheduleData: scheduleData,
      modalClosing: true,
      scrollTop: 99999,
      scrollIntoView: targetViewId
    }, () => {
      this._updateRecycleList();
    });
    setTimeout(() => {
      this.setData({
        showModal: false,
        modalClosing: false,
        scrollIntoView: targetViewId
      }, () => {
        wx.setStorageSync('course_schedule', scheduleData);
        this.queueScheduleSync(200);
        this.setData({ shareDirty: true });
        this.queueShareCodeRefresh(2000);
        if (callback) callback(entry);
      });
    }, 250);
  },

  /**
   * 调后端创建下课提醒，并把返回的 reminderId 存回课程数据
   */
  async _createCourseReminder(entry, dayIdx, scheduleData) {
    try {
      // 检查全局提醒开关
      const { getConfig } = require('../../utils/config.js')
      const config = await getConfig(0)
      if (config && config.remindersEnabled === false) {
        wx.showToast({ title: '提醒功能暂未开放', icon: 'none' })
        return
      }

      const userInfo = app.globalData && app.globalData.userInfo;
      const userName = (userInfo && userInfo.nickname) || '同学';
      
      // 计算下课时间（ISO 8601 +08:00）
      const reservationTime = this._buildCourseDateTime(dayIdx, entry.endTime);
      // 提醒时间 = 下课前 N 分钟
      const minutesBefore = this.data.reminderValues[this.data.reminderIndex] || 0;
      const remindTime = this._calcRemindTime(reservationTime, minutesBefore);
      
      console.log('[Reminder] creating:', { userName, course: entry.name, reservationTime, remindTime });
      
      const result = await createReminder({
        userName: userName,
        project: entry.name,
        reservationTime: reservationTime,
        remindTime: remindTime,
        tips: entry.location ? `上课地点：${entry.location}` : '请准时到达',
        page: '/pages/course-schedule/course-schedule'
      });
      
      console.log('[Reminder] created:', result);
      
      // 把 reminderId 存回课程数据
      const newReminderId = result && (result.id || result.reminderId)
      console.log('[Reminder] result fields:', result && Object.keys(result), 'reminderId:', newReminderId)
      if (newReminderId) {
        const updatedSchedule = JSON.parse(JSON.stringify(this.data.scheduleData));
        const courses = updatedSchedule[dayIdx];
        const idx = courses.findIndex(c => c.name === entry.name && c.startTime === entry.startTime);
        console.log('[Reminder] writing reminderId back, idx:', idx, 'entry:', entry.name, entry.startTime, 'reminderId:', newReminderId);
        if (idx !== -1) {
          courses[idx].reminderId = newReminderId;
          courses[idx].reminderMinutes = this.data.reminderValues[this.data.reminderIndex] || 0;
          console.log('[Reminder] scheduleData after update:', JSON.stringify(courses[idx]));
          this.setData({ scheduleData: updatedSchedule }, () => {
            wx.setStorageSync('course_schedule', updatedSchedule);
            console.log('[Reminder] saved to storage, reminderId:', updatedSchedule[dayIdx][idx].reminderId);
            this.queueScheduleSync(300);
          });
        } else {
          console.warn('[Reminder] course not found in scheduleData! entry:', entry.name, entry.startTime, 'day courses:', JSON.stringify(courses.map(c => ({name: c.name, startTime: c.startTime}))));
        }
      }
      
      wx.showToast({ title: '提醒设置成功', icon: 'success' });
    } catch (err) {
      console.error('[Reminder] create failed:', err);
      wx.showToast({ title: '提醒设置失败', icon: 'none' });
    }
  },

  /**
   * 根据星期索引和时间字符串，构建本周对应日期的 ISO 8601 时间
   * dayIdx: 0=周一, 1=周二, ..., 6=周日
   */
  _buildCourseDateTime(dayIdx, timeStr) {
    const now = new Date();
    const todayDow = now.getDay(); // 0=周日, 1=周一, ...
    // 转换为 0=周一 的索引
    const todayIdx = todayDow === 0 ? 6 : todayDow - 1;
    let diff = dayIdx - todayIdx;
    // 如果是今天但时间已过，或者是过去的日期，取下周
    const target = new Date(now);
    target.setDate(now.getDate() + diff);
    
    const [h, m] = timeStr.split(':').map(Number);
    target.setHours(h, m, 0, 0);
    
    // 如果目标时间已过，加7天
    if (target.getTime() <= now.getTime()) {
      target.setDate(target.getDate() + 7);
    }
    
    // 格式化为 ISO 8601 +08:00
    const pad = n => String(n).padStart(2, '0');
    const year = target.getFullYear();
    const month = pad(target.getMonth() + 1);
    const day = pad(target.getDate());
    const hour = pad(target.getHours());
    const min = pad(target.getMinutes());
    return `${year}-${month}-${day}T${hour}:${min}:00+08:00`;
  },

  /**
   * 根据到达时间计算提醒时间（提前 N 分钟）
   */
  _calcRemindTime(isoTimeStr, minutesBefore) {
    if (minutesBefore === 0) return isoTimeStr;
    const ts = new Date(isoTimeStr).getTime();
    const remindTs = ts - minutesBefore * 60 * 1000;
    const d = new Date(remindTs);
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:00+08:00`;
  },

  deleteCourse() {
    const { editingDay, editingIndex } = this.data;
    wx.showModal({
      title: '提示',
      content: '确定要删除这门课吗？',
      success: (res) => {
        if (res.confirm) {
          const scheduleData = JSON.parse(JSON.stringify(this.data.scheduleData));
          const course = scheduleData[editingDay][editingIndex];
          
          // 如果有提醒，先取消
          if (course && course.reminderId) {
            cancelReminder(course.reminderId).catch(err => {
              console.error('[Reminder] cancel on delete failed:', err);
            });
          }
          
          scheduleData[editingDay].splice(editingIndex, 1);
          this._invalidateRecycleCache();
          this.setData({
            scheduleData: scheduleData,
            showModal: false,
            isEditing: false,
            editingIndex: -1
          }, () => {
            wx.setStorageSync('course_schedule', scheduleData);
            this.queueScheduleSync(200);
            this.setData({ shareDirty: true });
            this.queueShareCodeRefresh(2000);
          });
        }
      }
    });
  },

  clearAllCourses() {
    wx.showModal({
      title: '清空课程表',
      content: '确认清空当前课程表吗？此操作不可恢复',
      confirmText: '清空',
      cancelText: '取消',
      success: (res) => {
        if (!res.confirm) return;

        const current = this.data.scheduleData || [];
        const reminderIds = [];
        current.forEach(day => {
          if (Array.isArray(day)) {
            day.forEach(course => {
              if (course && course.reminderId) {
                reminderIds.push(course.reminderId);
              }
            });
          }
        });

        reminderIds.forEach(id => {
          cancelReminder(id).catch(err => {
            console.error('[Reminder] cancel on clear failed:', err);
          });
        });

        const cleared = [[], [], [], [], [], [], []];
        this._invalidateRecycleCache();
        this.setData({
          scheduleData: cleared
        }, () => {
          wx.setStorageSync('course_schedule', cleared);
          this.queueScheduleSync(200);
        });
      }
    });
  },

  async prepareShare() {
    if (this.data.shareLoading) return;
    if (this.data.shareCodeReady && !this.data.shareDirty) return;

    this.generateShareCode();
  },

  async generateShareCode() {
    if (this.data.shareLoading) return;

    this.setData({ shareLoading: true, shareCodeReady: false });
    try {
      await saveMySchedule(this.buildSchedulePayload());
      const result = await createScheduleTemplate(this.buildSharePayload());
      const shareCode = result && (result.shareCode || result.share_code || result.code);

      if (!shareCode) {
        throw new Error('分享码生成失败');
      }

      this.setData({
        shareCodeResult: String(shareCode),
        shareCodeReady: true,
        shareDirty: false
      });
      wx.setStorageSync('course_share_code', String(shareCode));
      return String(shareCode);
    } catch (error) {
      wx.showToast({
        title: error.message || '生成失败',
        icon: 'none'
      });
    } finally {
      this.setData({ shareLoading: false });
    }
  },

  copyShareCode() {
    const code = this.data.shareCodeResult;
    if (!code) return;

    wx.setClipboardData({
      data: code,
      success: () => {
        wx.showToast({
          title: '已复制',
          icon: 'success'
        });
      }
    });
  },

  async importShareCode(codeOverride) {
    const code = (codeOverride || '').trim();
    if (!code) {
      wx.showToast({
        title: '分享码无效',
        icon: 'none'
      });
      return;
    }

    if (this.data.shareLoading) return;
    this.setData({ shareLoading: true });

    try {
      await cloneScheduleTemplate(code);
      const result = await getMySchedule();
      if (result) {
        const serverContent = result.contentJson || {
          scheduleData: result.scheduleData,
          bgConfig: result.bgConfig
        };
        this.applyScheduleContent(serverContent, true);
      }

      wx.showToast({
        title: '导入成功',
        icon: 'success'
      });
      this.setData({
        shareDirty: true,
        shareCodeReady: false,
        shareCodeResult: ''
      });
      wx.removeStorageSync('course_share_code');
      this.queueShareCodeRefresh(800);
      if (this._loadOptions) {
        this._loadOptions = Object.assign({}, this._loadOptions, { shareCode: '' });
      }
    } catch (error) {
      if (error && error.message && (error.message.includes('过期') || error.message.includes('401'))) {
        const app = getApp();
        if (app && typeof app.silentLogin === 'function') {
          try {
            await app.silentLogin();
            this.setData({ shareLoading: false });
            this.importShareCode(code);
            return;
          } catch (loginErr) {
            console.error('[Schedule] re-login failed:', loginErr);
            wx.showModal({
              title: '需要登录',
              content: '登录后才可以查看分享的课程表，请先登录',
              showCancel: false,
              confirmText: '知道了'
            });
          }
        }
      }
      wx.showToast({
        title: error.message || '导入失败',
        icon: 'none'
      });
    } finally {
      this.setData({ shareLoading: false });
    }
  },

  // Start Real Voice Recording
  startVoice() {
    wx.vibrateShort({ type: 'medium' });
    manager.start({ duration: 60000, lang: 'zh_CN' });
    this.setData({ isRecording: true });
  },

  stopVoice() {
    wx.vibrateShort({ type: 'medium' });
    manager.stop();
    this.setData({ isRecording: false });
  },

  handleVoiceResult(text) {
    if (!text) {
      wx.showToast({ title: '没听清，再试一次吧', icon: 'none' });
      return;
    }

    let dayIdx = this.data.currentDayIndex;
    const days = ['一', '二', '三', '四', '五'];
    days.forEach((d, idx) => {
      if (text.includes(`周${d}`) || text.includes(`星期${d}`)) {
        dayIdx = idx;
      }
    });

    let startTime, endTime;
    const timeMatch = text.match(/(\d{1,2})点(\d{1,2})?|(\d{1,2}):(\d{2})/);
    if (timeMatch) {
      const hour = timeMatch[1] || timeMatch[3];
      const min = timeMatch[2] || timeMatch[4] || '00';
      startTime = `${hour.padStart(2, '0')}:${min.padStart(2, '0')}`;
      endTime = this.calculateEndTime(startTime);
    } else {
      const next = this._calcNextCourseTime(dayIdx);
      startTime = next.startTime;
      endTime = next.endTime;
    }

    let courseName = text.replace(/周.|星期.|点.|在.|去.|上./g, '').trim();
    if (!courseName) courseName = '新课程';

    this.setData({
      showModal: true,
      'newCourse.name': courseName,
      'newCourse.dayIdx': dayIdx,
      'newCourse.startTime': startTime,
      'newCourse.endTime': endTime,
      'newCourse.location': text.includes('在') ? text.split('在')[1].substring(0, 10) : ''
    });
  },

  /**
   * 根据当天已有课程，推算下一节课的默认开始和结束时间
   * 逻辑：取最后一节课的时长，接在它结束后（+10分钟间隔）
   */
  _calcNextCourseTime(dayIdx) {
    const courses = this.data.scheduleData[dayIdx];
    if (!courses || courses.length === 0) {
      return { startTime: '08:00', endTime: this.calculateEndTime('08:00') };
    }

    // 找结束时间最晚的课程
    const valid = courses.filter(c => c.startTime && c.endTime && /^\d{2}:\d{2}$/.test(c.startTime) && /^\d{2}:\d{2}$/.test(c.endTime));
    if (valid.length === 0) {
      return { startTime: '08:00', endTime: this.calculateEndTime('08:00') };
    }

    const last = valid.sort((a, b) => b.endTime.localeCompare(a.endTime))[0];
    const [sh, sm] = last.startTime.split(':').map(Number);
    const [eh, em] = last.endTime.split(':').map(Number);
    const duration = (eh * 60 + em) - (sh * 60 + sm); // 上节课时长（分钟）

    // 下节开始 = 上节结束 + 10分钟
    const nextStartMin = eh * 60 + em + 10;
    const nextEndMin = nextStartMin + (duration > 0 ? duration : 45);

    const fmt = min => `${String(Math.floor(min / 60) % 24).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;
    return { startTime: fmt(nextStartMin), endTime: fmt(nextEndMin) };
  },

  calculateEndTime(startTime) {
    const [h, m] = startTime.split(':').map(Number);
    let endH = h;
    let endM = m + 45;
    if (endM >= 60) {
      endH += 1;
      endM -= 60;
    }
    return `${String(endH).padStart(2, '0')}:${String(endM).padStart(2, '0')}`;
  },

  goBack() {
    wx.navigateBack({
      fail: () => {
        wx.reLaunch({ url: '/pages/index/index' });
      }
    });
  },

  stopPropagation() {},

  // 用于wxml判断和打印log
  logBell(course) {
    const show = !!(course && course.reminderId);
    console.log('[铃铛判断]', {
      name: course && course.name,
      reminderId: course && course.reminderId,
      show
    });
    return show;
  }
});

// 全局文件加载测试
  console.log('[全局测试] course-schedule.js 已加载');
