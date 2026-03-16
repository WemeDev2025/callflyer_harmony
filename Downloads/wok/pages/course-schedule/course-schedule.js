// pages/course-schedule/course-schedule.js
const app = getApp();
const plugin = requirePlugin('WechatSI');
const manager = plugin.getRecordRecognitionManager();
const { createReminder, cancelReminder, getMySchedule, saveMySchedule, createScheduleTemplate, cloneScheduleTemplate } = require('../../utils/api.js');

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
      opacity: 0.5,
      blur: 0,
      textColor: '#1A1A1A'
    },
    defaultBgConfig: {
      url: '',
      opacity: 0.5,
      blur: 0,
      textColor: '#1A1A1A'
    },
    vipBackgrounds: [],
    emptyImgTimestamp: Date.now(),
    isAdjustingBg: false,
    scrollTop: 0,
    scrollIntoView: '',
    shareCodeResult: '',
    shareLoading: false,
    shareCodeReady: false,
    shareDirty: false
  },

  onLoad(options) {
    this._loadOptions = options || {};
    this.initDate();
    this.initVoiceManager();
    this.setData({
      currentDayIndex: this.getTodayIndex()
    });
    this.loadScheduleFromServer();

    this.fetchVipBackgrounds();

    // 获取系统状态栏高度及胶囊按钮位置
    const info = wx.getSystemInfoSync();
    try {
      const menuButton = wx.getMenuButtonBoundingClientRect();
      this.setData({
        statusBarHeight: info.statusBarHeight,
        menuButtonTop: menuButton.top,
        menuButtonHeight: menuButton.height
      });
    } catch (e) {
      this.setData({
        statusBarHeight: info.statusBarHeight
      });
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
    this.setData({
      emptyImgTimestamp: Date.now()
    });
  },

  onUnload() {
    // 页面卸载时停止识别
    manager.stop();
    if (this._scheduleSyncTimer) {
      clearTimeout(this._scheduleSyncTimer);
      this._scheduleSyncTimer = null;
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

  onSwiperChange(e) {
    this.setData({
      currentDayIndex: e.detail.current
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
  },

  showBgEditor() {
    this.setData({ showBgModal: true });
    console.log('[BG] Editor opened, current config:', this.data.bgConfig);
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
    console.log('[BG] Fetching VIP backgrounds...');
    wx.request({
      url: 'https://wemedev.com/wok/api/bg-images',
      success: (res) => {
        console.log('[BG] API Result:', res.data);
        if (res.data && res.data.items && res.data.items.length > 0) {
          // 过滤掉作为默认缺省图使用的文件
          const filtered = res.data.items.filter(item => 
            item.filename !== 'pic_default.png' && item.filename !== 'pic_share.png'
          );
          this.setData({ vipBackgrounds: filtered });
        } else {
          console.warn('[BG] No backgrounds returned from API, using defaults');
          // 提供一个默认精品背景防止列表为空
          this.setData({
            vipBackgrounds: [
              { url: 'https://wemedev.com/wok/data/images/pic_wok.png', filename: 'demo.png' }
            ]
          });
        }
      },
      fail: (err) => {
        console.error('[BG] API Failed:', err);
      }
    });
  },

  /**
   * 加载课表（优先服务器，失败再读本地）
   */
  async loadScheduleFromServer() {
    const options = this._loadOptions;
    if (options && options.shareCode) {
      this.importShareCode(options.shareCode);
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

  /**
   * 规范化并应用课表内容
   */
  applyScheduleContent(content, persistLocal) {
    const normalized = this.normalizeScheduleContent(content);
    this.setData({
      scheduleData: normalized.scheduleData,
      bgConfig: normalized.bgConfig,
      shareDirty: false
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
      console.warn('[Schedule] sync failed:', error && error.message);
    }
  },

  selectVipBackground(e) {
    const { url } = e.currentTarget.dataset;
    wx.vibrateShort({ type: 'medium' });
    this.setData({
      'bgConfig.url': url
    }, () => {
      this.saveBgConfig();
    });
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
    this.setData({ 'newCourse.isEndReminderEnabled': e.detail.value });
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
  },

  onStartTimeChange(e) {
    this.setData({ 'newCourse.startTime': e.detail.value });
  },

  onEndTimeChange(e) {
    this.setData({ 'newCourse.endTime': e.detail.value });
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
      reminderId: reminderId || null  // 保留已有提醒ID
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
        if (callback) callback(entry);
      });
    }, 250);
  },

  /**
   * 调后端创建下课提醒，并把返回的 reminderId 存回课程数据
   */
  async _createCourseReminder(entry, dayIdx, scheduleData) {
    try {
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
      if (result && result.id) {
        const updatedSchedule = JSON.parse(JSON.stringify(this.data.scheduleData));
        const courses = updatedSchedule[dayIdx];
        const idx = courses.findIndex(c => c.name === entry.name && c.startTime === entry.startTime);
        if (idx !== -1) {
          courses[idx].reminderId = result.id;
          this.setData({ scheduleData: updatedSchedule }, () => {
            wx.setStorageSync('course_schedule', updatedSchedule);
          });
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
          
          this.setData({
            scheduleData: scheduleData,
            showModal: false,
            isEditing: false,
            editingIndex: -1
          }, () => {
            wx.setStorageSync('course_schedule', scheduleData);
            this.queueScheduleSync(200);
            this.setData({ shareDirty: true });
          });
        }
      }
    });
  },

  prepareShare() {
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
      this.setData({ shareDirty: false });
    } catch (error) {
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
    let endH = h + 1;
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

  stopPropagation() {}
});
