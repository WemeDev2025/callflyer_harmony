const { silentLogin, isTokenExpired } = require('./utils/auth.js');
const { parseLRC, getCurrentLyricIndex, loadLyric } = require('./utils/lyric.js');
const { getDeviceInfo, reportDeviceInfo, getDeviceType } = require('./utils/device.js');

App({
  globalData: {
    bgAudioManager: null, // 背景音乐管理器
    lyrics: [], // 解析后的歌词数组
    currentLyricIndex: -1, // 当前歌词索引
    lyricUpdateTimer: null, // 歌词更新定时器
    isAudioPlaying: false, // 音频是否正在播放
    audioStartTime: 0, // 音频开始播放的时间戳（用于补偿）
    timeOffset: 0, // 时间偏移量（用于Android平台补偿）
    isUserControlled: false, // 是否由用户手动控制播放
    deviceInfo: null, // 设备信息
    deviceType: 'unknown' // 设备类型
  },
  onLaunch() {
    // 立即获取设备信息（同步，不等待）
    this.initDeviceInfo();

    // 静默登录
    this.silentLoginOnLaunch();

    // 初始化背景音乐
    this.initBackgroundAudio();
  },
  // 初始化设备信息
  initDeviceInfo() {
    try {
      const deviceInfo = getDeviceInfo();
      const deviceType = getDeviceType();
      
      this.globalData.deviceInfo = deviceInfo;
      this.globalData.deviceType = deviceType;
      
      console.log('[设备信息] 设备信息已获取:', {
        brand: deviceInfo.brand,
        model: deviceInfo.model,
        platform: deviceInfo.platform,
        system: deviceInfo.system,
        deviceType: deviceType
      });
      
      // 延迟上报设备信息（等待登录完成）
      // 先尝试立即上报，如果未登录会在内部延迟重试
      setTimeout(() => {
        reportDeviceInfo(deviceInfo).catch(err => {
          console.error('[设备信息] 上报设备信息失败', err);
        });
      }, 1000);
    } catch (err) {
      console.error('[设备信息] 初始化设备信息失败', err);
    }
  },
  // 启动时静默登录
  silentLoginOnLaunch() {
    // 检查 token 是否存在且未过期
    if (!isTokenExpired()) {
      console.log('Token 有效，跳过登录');
      // Token 有效时，触发登录成功事件，让页面可以加载用户资料
      this.onLoginSuccess();
      return;
    }

    // 执行静默登录
    silentLogin()
      .then((result) => {
        console.log('静默登录成功', result);
        // 登录成功后，触发登录成功事件
        this.onLoginSuccess();
      })
      .catch((err) => {
        console.error('静默登录失败', err);
        // 登录失败不影响小程序正常使用，可以稍后重试
      });
  },
  // 登录成功回调
  onLoginSuccess() {
    // 通知所有页面登录成功，可以加载用户资料
    const pages = getCurrentPages();
    pages.forEach(page => {
      if (page.onLoginSuccess && typeof page.onLoginSuccess === 'function') {
        page.onLoginSuccess();
      }
    });
    
    // 登录成功后，上报设备信息
    if (this.globalData.deviceInfo) {
      console.log('[设备信息] 登录成功，上报设备信息');
      reportDeviceInfo(this.globalData.deviceInfo).catch(err => {
        console.error('[设备信息] 登录后上报设备信息失败', err);
      });
    }
  },
  // 初始化背景音乐
  initBackgroundAudio() {
    try {
      const bgAudioManager = wx.getBackgroundAudioManager();
      this.globalData.bgAudioManager = bgAudioManager;

      // 先停止之前的音乐（如果有），清除缓存
      bgAudioManager.stop();
      
      // 设置音乐信息
      bgAudioManager.title = '《轻轻点点就行》';
      bgAudioManager.epname = '背景音乐';
      bgAudioManager.singer = '';
      bgAudioManager.coverImgUrl = 'https://wemedev.com/data/festival/audio/cover.jpg'; // 封面图URL
      bgAudioManager.volume = 0.1; // 设置默认音量 0-1，0.1 表示 10% 音量（较安静）
      
      // 延迟设置 src，避免自动播放
      // 不在初始化时设置 src，只在用户手动播放时才设置

      bgAudioManager.onPlay(() => {
        console.log('背景音乐开始播放');
        this.globalData.isAudioPlaying = true;
        // 记录开始播放的时间戳
        this.globalData.audioStartTime = Date.now();
        // 重置歌词索引
        this.globalData.currentLyricIndex = -1;
        this.globalData.timeOffset = 0;
        // 通知页面更新（清空当前歌词，等待新歌词）
        this.notifyLyricUpdate();
      });

      bgAudioManager.onPause(() => {
        console.log('背景音乐已暂停');
        this.globalData.isAudioPlaying = false;
      });

      bgAudioManager.onStop(() => {
        console.log('背景音乐已停止');
        this.globalData.isAudioPlaying = false;
        // 重置用户控制标志
        this.globalData.isUserControlled = false;
        // 重置歌词索引
        this.globalData.currentLyricIndex = -1;
        this.notifyLyricUpdate();
      });

      bgAudioManager.onError((res) => {
        console.error('背景音乐播放错误', res);
      });

      bgAudioManager.onEnded(() => {
        console.log('背景音乐播放结束');
        // 只有用户手动控制播放时才自动循环播放
        if (this.globalData.isUserControlled) {
          console.log('用户控制的播放结束，重新播放');
          bgAudioManager.seek(0);
          bgAudioManager.play();
        } else {
          // 如果不是用户控制的，停止播放
          this.globalData.isAudioPlaying = false;
        }
        // 重置歌词索引
        this.globalData.currentLyricIndex = -1;
        this.notifyLyricUpdate();
      });

      // 加载歌词文件
      this.loadLyrics();

      // 启动歌词同步（不依赖播放状态，让定时器始终运行）
      // 在 updateCurrentLyric 中会检查播放状态
      this.startLyricUpdate();

      // 不自动播放，等待用户手动控制
      // bgAudioManager.play();
    } catch (e) {
      console.error('初始化背景音乐失败', e);
    }
  },
  // 加载歌词文件
  loadLyrics() {
    const lyricUrl = 'https://wemedev.com/data/festival/audio/lyric.lrc';
    loadLyric(lyricUrl)
      .then((lrcText) => {
        const lyrics = parseLRC(lrcText);
        this.globalData.lyrics = lyrics;
        console.log('歌词加载成功，共', lyrics.length, '行');
        // 通知页面歌词已加载
        this.notifyLyricUpdate();
      })
      .catch((err) => {
        console.warn('歌词加载失败，将不显示歌词', err);
        this.globalData.lyrics = [];
      });
  },
  // 开始监听播放进度并更新歌词
  startLyricUpdate() {
    // 清除之前的定时器
    if (this.globalData.lyricUpdateTimer) {
      clearInterval(this.globalData.lyricUpdateTimer);
    }
    
    // 每500ms检查一次播放进度
    this.globalData.lyricUpdateTimer = setInterval(() => {
      this.updateCurrentLyric();
    }, 500);
  },
  // 更新当前歌词
  updateCurrentLyric() {
    const bgAudioManager = this.globalData.bgAudioManager;
    const lyrics = this.globalData.lyrics;
    
    // 基础检查：必须有音频管理器和歌词
    if (!bgAudioManager || !lyrics || lyrics.length === 0) {
      return;
    }
    
    try {
      // 获取当前播放时间（秒）
      let currentTime = bgAudioManager.currentTime || 0;
      
      // 检查播放状态：如果 currentTime 为 0 且没有播放标志，可能是未开始播放
      // 但真机上 currentTime 可能一开始就是 0，所以不严格依赖 isAudioPlaying
      // 只要 currentTime 有值或音频管理器存在，就尝试更新
      
      // Android 平台补偿：如果 currentTime 为 0 但音频已开始播放
      if (currentTime === 0 && this.globalData.audioStartTime > 0) {
        const elapsedTime = (Date.now() - this.globalData.audioStartTime) / 1000;
        // 如果实际播放时长大于 0.5 秒，使用实际时长
        if (elapsedTime > 0.5) {
          currentTime = elapsedTime;
        }
      }
      
      // 如果 currentTime 仍然为 0，可能是音频还未开始播放，但不阻止更新
      // 让歌词匹配逻辑自己处理（会返回 -1，不显示歌词）
      
      // 应用时间偏移量（如果需要补偿）
      currentTime = currentTime + this.globalData.timeOffset;
      
      // 确保时间不为负
      if (currentTime < 0) {
        currentTime = 0;
      }
      
      // 获取当前歌词索引
      const newIndex = getCurrentLyricIndex(lyrics, currentTime);
      
      // 如果歌词索引发生变化，通知页面更新
      if (newIndex !== this.globalData.currentLyricIndex) {
        this.globalData.currentLyricIndex = newIndex;
        this.notifyLyricUpdate();
        
        // 调试日志
        if (newIndex >= 0 && lyrics[newIndex]) {
          console.log(`歌词更新: [${lyrics[newIndex].time.toFixed(2)}s] ${lyrics[newIndex].text}, 当前时间: ${currentTime.toFixed(2)}s`);
        } else if (newIndex === -1) {
          // 没有匹配的歌词，清空显示
          console.log(`无匹配歌词，当前时间: ${currentTime.toFixed(2)}s`);
        }
      }
    } catch (e) {
      // 忽略错误，继续尝试
      console.warn('更新歌词时出错', e);
    }
  },
  // 通知页面歌词更新
  notifyLyricUpdate() {
    const pages = getCurrentPages();
    pages.forEach(page => {
      if (page.onLyricUpdate && typeof page.onLyricUpdate === 'function') {
        page.onLyricUpdate({
          lyrics: this.globalData.lyrics,
          currentIndex: this.globalData.currentLyricIndex
        });
      }
    });
  },
  // 播放背景音乐
  playBackgroundAudio() {
    const bgAudioManager = this.globalData.bgAudioManager;
    if (bgAudioManager) {
      // 标记为用户手动控制
      this.globalData.isUserControlled = true;
      // 如果还没有设置 src，先设置
      if (!bgAudioManager.src) {
        bgAudioManager.src = 'https://wemedev.com/data/festival/audio/bgm.MP3';
      }
      bgAudioManager.play();
    }
  },
  // 暂停背景音乐
  pauseBackgroundAudio() {
    if (this.globalData.bgAudioManager) {
      this.globalData.bgAudioManager.pause();
    }
  },
  // 停止背景音乐
  stopBackgroundAudio() {
    if (this.globalData.bgAudioManager) {
      this.globalData.bgAudioManager.stop();
    }
  }
})
