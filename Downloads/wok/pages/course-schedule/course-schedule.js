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
      { name: '星期五', shortName: '周五' }
    ],
    scheduleData: [
      [], [], [], [], [] // 5 days, cleared
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
    }
  },

  onLoad() {
    this.initDate();
    this.initVoiceManager();
    this.setData({
      currentDayIndex: this.getTodayIndex()
    });
    // 从持久化存储恢复数据，防止多次操作导致数据丢失
    const savedData = wx.getStorageSync('course_schedule');
    if (savedData && savedData.length > 0) {
      this.setData({ scheduleData: savedData });
    }

    const savedBg = wx.getStorageSync('course_bg_config');
    if (savedBg) {
      this.setData({ bgConfig: savedBg });
    }

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
      let msg = '语音识别失败';
      if (res.msg === 'internal voice data failed') {
        msg = '模拟器暂不支持语音，请在手机真机调试';
      }
      wx.showToast({ title: msg, icon: 'none', duration: 3000 });
      this.setData({ isRecording: false });
    };
  },

  getTodayIndex() {
    const day = new Date().getDay(); // 0 is Sunday, 1-6 Mon-Sat
    if (day === 0 || day > 5) return 0; // Default to Mon for weekends
    return day - 1; 
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

    this.setData({
      scheduleData: scheduleData,
      showModal: false,
      isEditing: false,
      editingIndex: -1
    }, () => {
      wx.setStorageSync('course_schedule', scheduleData);
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
      'newCourse.location': text.includes('在') ? text.split('在')[1].substring(0, 10) : '待定'
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
