// pages/course-schedule/course-schedule.js
const app = getApp();
const plugin = requirePlugin('WechatSI');
const manager = plugin.getRecordRecognitionManager();

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
      dayIdx: 0
    },
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
    vipBackgrounds: [],
    emptyImgTimestamp: Date.now(),
    isAdjustingBg: false,
    reminderOptions: ['5分钟前', '10分钟前', '15分钟前', '30分钟前', '1小时前'],
    reminderValues: [5, 10, 15, 30, 60],
    reminderIndex: 1
  },

  onLoad() {
    this.initDate();
    this.initVoiceManager();
    this.setData({
      currentDayIndex: this.getTodayIndex()
    });
    // 从持久化存储恢复数据
    let savedData = wx.getStorageSync('course_schedule');
    if (savedData && savedData.length > 0) {
      // 兼容旧版 5 天数据，自动补全到 7 天
      while (savedData.length < 7) {
        savedData.push([]);
      }
      this.setData({ scheduleData: savedData });
    }

    const savedBg = wx.getStorageSync('course_bg_config');
    if (savedBg) {
      this.setData({ bgConfig: savedBg });
    }

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

  onShow() {
    this.setData({
      emptyImgTimestamp: Date.now()
    });
  },

  onUnload() {
    // 页面卸载时停止识别
    manager.stop();
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
    this.setData({
      showModal: true,
      isEditing: false,
      'newCourse.dayIdx': this.data.currentDayIndex,
      'newCourse.name': '',
      'newCourse.location': '',
      'newCourse.startTime': '08:00',
      'newCourse.endTime': '09:50'
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
        dayIdx: parseInt(day)
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
          const filtered = res.data.items.filter(item => item.filename !== 'pic_default.png');
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

  startAdjusting() {
    this.setData({ isAdjustingBg: true });
    wx.vibrateShort({ type: 'medium' });
  },

  onReminderToggle(e) {
    this.setData({ 'newCourse.isReminderEnabled': e.detail.value });
  },

  onReminderTimeChange(e) {
    this.setData({ reminderIndex: e.detail.value });
  },

  onShareTap() {
    wx.vibrateShort({ type: 'medium' });
    wx.showActionSheet({
      itemList: ['生成朋友圈海报', '直接转发给好友'],
      success: (res) => {
        if (res.tapIndex === 0) {
          this.drawPoster();
        } else {
          // 触发原生分享通常需要 button open-type="share"
          // 这里可以弹窗提示用户点击右上角或点击特定按钮
          wx.showModal({
            title: '提示',
            content: '请点击课程列表右下角的分享按钮进行转发',
            showCancel: false
          });
        }
      }
    });
  },

  async drawPoster() {
    wx.showLoading({ title: '正在设计海报...' });
    const ctx = wx.createCanvasContext('shareCanvas');
    const systemInfo = wx.getSystemInfoSync();
    const posterW = 750;
    const posterH = 1334;
    
    // 1. 背景绘制
    if (this.data.bgConfig.url) {
      try {
        const imgInfo = await new Promise((resolve, reject) => {
          wx.getImageInfo({
            src: this.data.bgConfig.url,
            success: resolve,
            fail: reject
          });
        });
        ctx.drawImage(imgInfo.path, 0, 0, posterW, posterH);
      } catch (e) {
        ctx.setFillStyle('#FFFFFF');
        ctx.fillRect(0, 0, posterW, posterH);
      }
    } else {
      ctx.setFillStyle('#FFFFFF');
      ctx.fillRect(0, 0, posterW, posterH);
    }

    // 2. 蒙层叠加
    ctx.setFillStyle(`rgba(255, 255, 255, ${this.data.bgConfig.opacity})`);
    ctx.fillRect(0, 0, posterW, posterH);

    // 3. 绘制标题
    ctx.setFillStyle(this.data.bgConfig.textColor || '#1A1A1A');
    ctx.setFontSize(50);
    ctx.setTextAlign('center');
    ctx.fillText('我的课程表', posterW / 2, 120);
    
    const todayStr = this.data.weekDays[this.data.currentDayIndex].name;
    ctx.setFontSize(32);
    ctx.fillText(todayStr, posterW / 2, 180);

    // 4. 绘制课程卡片
    const currentCourses = this.data.scheduleData[this.data.currentDayIndex] || [];
    let startY = 280;
    
    if (currentCourses.length === 0) {
      ctx.setFontSize(36);
      ctx.setFillStyle('#999999');
      ctx.fillText('今天没有课哦，享受时光～', posterW / 2, 600);
    }

    currentCourses.slice(0, 6).forEach((course, index) => {
      const cardX = 60;
      const cardW = posterW - 120;
      const cardH = 150;
      
      // 绘制卡片背景 (毛玻璃感)
      ctx.save();
      ctx.setShadow(0, 10, 30, 'rgba(0,0,0,0.05)');
      ctx.setFillStyle(course.color || '#F0F3FF');
      this.drawRoundRect(ctx, cardX, startY, cardW, cardH, 30);
      ctx.fill();
      ctx.restore();

      // 时间
      ctx.setTextAlign('left');
      ctx.setFillStyle('#333333');
      ctx.setFontSize(32);
      ctx.fillText(course.startTime, cardX + 40, startY + 65);
      ctx.setFontSize(24);
      ctx.setFillStyle('#666666');
      ctx.fillText(course.endTime, cardX + 40, startY + 110);

      // 课程名
      ctx.setFillStyle('#1A1A1A');
      ctx.setFontSize(36);
      ctx.fillText(course.name, cardX + 160, startY + 70);
      
      // 备注/地点
      ctx.setFillStyle('#888888');
      ctx.setFontSize(26);
      ctx.fillText(course.location || '无备注', cardX + 160, startY + 115);

      startY += cardH + 40;
    });

    // 5. 底部装饰
    ctx.setTextAlign('center');
    ctx.setFillStyle('#999999');
    ctx.setFontSize(24);
    ctx.fillText('-- 由 Wok 智能课表生成 --', posterW / 2, posterH - 100);

    ctx.draw(false, () => {
      setTimeout(() => {
        wx.canvasToTempFilePath({
          canvasId: 'shareCanvas',
          success: (res) => {
            wx.hideLoading();
            wx.previewImage({
              urls: [res.tempFilePath]
            });
          },
          fail: (err) => {
            wx.hideLoading();
            wx.showToast({ title: '海报生成失败', icon: 'none' });
          }
        });
      }, 500);
    });
  },

  drawRoundRect(ctx, x, y, width, height, radius) {
    ctx.beginPath();
    ctx.arc(x + radius, y + radius, radius, Math.PI, Math.PI * 1.5);
    ctx.lineTo(x + width - radius, y);
    ctx.arc(x + width - radius, y + radius, radius, Math.PI * 1.5, Math.PI * 2);
    ctx.lineTo(x + width, y + height - radius);
    ctx.arc(x + width - radius, y + height - radius, radius, 0, Math.PI * 0.5);
    ctx.lineTo(x + radius, y + height);
    ctx.arc(x + radius, y + height - radius, radius, Math.PI * 0.5, Math.PI);
    ctx.closePath();
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
    const { name, startTime, endTime, dayIdx, location } = this.data.newCourse;
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
      isReminderEnabled: this.data.newCourse.isReminderEnabled || false,
      reminderMinutes: this.data.reminderValues[this.data.reminderIndex],
      color: isEditing ? this.data.scheduleData[editingDay][editingIndex].color : this.data.colors[Math.floor(Math.random() * this.data.colors.length)]
    };

    if (isEditing) {
      // 先从旧日删除（以防修改了日期）
      scheduleData[editingDay].splice(editingIndex, 1);
      // 添加到新日
      scheduleData[dayIdx].push(entry);
    } else {
      scheduleData[dayIdx].push(entry);
    }
    
    // 重新排序
    scheduleData[dayIdx].sort((a, b) => a.startTime.localeCompare(b.startTime));

    // 请求订阅消息
    if (this.data.newCourse.isReminderEnabled) {
      wx.requestSubscribeMessage({
        tmplIds: ['fzEGVEMzu6KiGg6hmIOco3OnXdnHK4ADSNrYFJsrsVM'], // 模板ID
        success(res) {
          console.log('[Reminder] Subscription success:', res);
        }
      });
    }

    this.setData({
      scheduleData: scheduleData,
      showModal: false,
      modalClosing: false
    }, () => {
      wx.setStorageSync('course_schedule', scheduleData);
      wx.showToast({ title: '已同步课表', icon: 'success' });
    });
  },

  deleteCourse() {
    const { editingDay, editingIndex } = this.data;
    wx.showModal({
      title: '提示',
      content: '确定要删除这门课吗？',
      success: (res) => {
        if (res.confirm) {
          const scheduleData = JSON.parse(JSON.stringify(this.data.scheduleData));
          scheduleData[editingDay].splice(editingIndex, 1);
          
          this.setData({
            scheduleData: scheduleData,
            showModal: false,
            isEditing: false,
            editingIndex: -1
          }, () => {
            wx.setStorageSync('course_schedule', scheduleData);
          });
        }
      }
    });
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

    // Basic Extraction Logic (Can be improved with LLM)
    let dayIdx = this.data.currentDayIndex;
    const days = ['一', '二', '三', '四', '五'];
    days.forEach((d, idx) => {
      if (text.includes(`周${d}`) || text.includes(`星期${d}`)) {
        dayIdx = idx;
      }
    });

    // Extract time (e.g., "八点", "10点30")
    let startTime = '08:00';
    const timeMatch = text.match(/(\d{1,2})点(\d{1,2})?|(\d{1,2}):(\d{2})/);
    if (timeMatch) {
      const hour = timeMatch[1] || timeMatch[3];
      const min = timeMatch[2] || timeMatch[4] || '00';
      startTime = `${hour.padStart(2, '0')}:${min.padStart(2, '0')}`;
    }

    // Use remaining text as course name (simple heuristic)
    let courseName = text.replace(/周.|星期.|点.|在.|去.|上./g, '').trim();
    if (!courseName) courseName = '新课程';

    this.setData({
      showModal: true,
      'newCourse.name': courseName,
      'newCourse.dayIdx': dayIdx,
      'newCourse.startTime': startTime,
      'newCourse.endTime': this.calculateEndTime(startTime),
      'newCourse.location': text.includes('在') ? text.split('在')[1].substring(0, 10) : '无备注',
      'newCourse.isReminderEnabled': false // 语音默认不开启提醒，让用户手动勾选
    });


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
