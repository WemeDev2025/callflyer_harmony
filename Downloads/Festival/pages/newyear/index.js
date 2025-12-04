// pages/newyear/index.js
const auth = require('../../utils/auth');
const config = require('../../utils/config');
const { getDeviceType, isRealDevice } = require('../../utils/device');

const API_BASE_URL = 'https://wemedev.com/api/festival';
const WXPAY_API_BASE = 'https://wemedev.com/api/wechat/wxpay';
const UNLOCK_CODE_PURCHASE_URL = 'https://wemedev.com/festival';

Page({
  data: {
    statusBarHeight: 0,
    navBarHeight: 44,
    avatarUrl: '',
    nickname: '昵称',
    isRecording: false, // 是否正在录音
    recordingTime: 0, // 录音时长（秒）
    hasRecorded: false, // 是否已录音
    recordFilePath: '', // 录音文件路径（本地或远程URL）
    serverAudioUrl: '', // 服务器返回的合成音频URL
    isPlaying: false, // 是否正在播放
    buttonText: '点击录音', // 按钮文字
    shareId: '', // 分享ID
    audioId: '', // 音频ID
    isSharedPage: false, // 是否是分享进来的页面
    uploaderCount: 0, // 完成拜年任务的用户数
    showTeleprompter: false, // 是否展示提词器
    teleprompterText: '', // 提词器内容
    teleprompterLoading: false, // 提词器加载状态
    teleprompterAnimating: false, // 提词器文本动画
    teleprompterFontFamily: '', // 提词器字体（可通过服务器配置）
    explosionParticles: [], // 爆炸粒子列表
    // 解锁码激活相关
    showUnlockCodeCard: false, // 是否显示解锁码卡片
    unlockCodeCardShow: false, // 卡片显示动画
    unlockCodeValue: '', // 解锁码输入值
    unlockCodeFocus: false, // 输入框聚焦
    isActivating: false, // 是否正在激活
    isVip: false, // 是否为VIP用户
    // 微信支付提示卡片相关
    showWxPayCard: false, // 是否显示微信支付提示卡片
    wxPayCardShow: false // 卡片显示动画
  },

  onLoad(options) {
    // 获取系统信息
    const systemInfo = wx.getSystemInfoSync();
    this.setData({
      statusBarHeight: systemInfo.statusBarHeight || 0,
      navBarHeight: 44
    });
    
    // 初始化VIP状态
    const isVip = auth.getVipStatus();
    this.setData({ isVip });
    
    // 检查是否是分享进来的
    if (options.shareId) {
      console.log('分享进入，shareId:', options.shareId);
      this.setData({
        isSharedPage: true,
        shareId: options.shareId
      });
      // 加载分享的录音
      this.loadSharedAudio(options.shareId);
    } else {
      // 正常进入，加载用户资料
      this.loadUserProfile();
    }
    
    // 初始化录音管理器
    this.initRecorder();
    
    // 加载统计信息
    this.loadUploaderStats();
    
    // 加载远程配置（包括字体配置）
    this.loadRemoteConfig();
  },
  
  // 加载远程配置
  loadRemoteConfig() {
    // 先加载字体文件（使用 wx.loadFontFace API）
    this.loadDouyinFont();
    
    // 加载字体配置
    wx.request({
      url: `${API_BASE_URL}/font/config`,
      method: 'GET',
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          const fontConfig = res.data;
          console.log('加载字体配置成功', fontConfig);
          // 设置提词器字体（如果配置中有，使用配置的；否则使用默认的 Douyin Sans）
          const fontFamily = fontConfig.teleprompterFontFamily || "'Douyin Sans', 'PingFang SC', 'Microsoft YaHei', sans-serif";
          this.setData({
            teleprompterFontFamily: fontFamily
          });
        } else {
          // 接口返回失败，使用默认字体
          this.setData({
            teleprompterFontFamily: "'Douyin Sans', 'PingFang SC', 'Microsoft YaHei', sans-serif"
          });
        }
      },
      fail: (err) => {
        console.error('加载字体配置失败', err);
        // 请求失败，使用默认字体
        this.setData({
          teleprompterFontFamily: "'Douyin Sans', 'PingFang SC', 'Microsoft YaHei', sans-serif"
        });
      }
    });
    
    // 加载其他远程配置
    config.getConfig().then(remoteConfig => {
      console.log('加载远程配置成功', remoteConfig);
    }).catch(err => {
      console.error('加载远程配置失败', err);
    });
  },
  
  // 加载 Douyin 字体
  loadDouyinFont() {
    // 尝试加载字体，如果失败则使用后备字体
    wx.loadFontFace({
      family: 'Douyin Sans',
      source: 'url("https://wemedev.com/data/font/DouyinSans.otf")',
      success: (res) => {
        console.log('Douyin 字体加载成功', res);
      },
      fail: (err) => {
        console.warn('Douyin 字体加载失败，将使用系统后备字体', err);
        // 字体加载失败不影响使用，会使用后备字体（PingFang SC, Microsoft YaHei 等）
        // 不需要特殊处理，CSS 中已设置后备字体
      }
    });
  },

  // 打开提词器
  onOpenTeleprompter() {
    // 如果提词器正在显示，则关闭
    if (this.data.showTeleprompter) {
      this.setData({ showTeleprompter: false });
      return;
    }
    if (this.data.teleprompterLoading) {
      return;
    }
    // 若已有内容则直接显示
    if (this.data.teleprompterText) {
      this.setData({ showTeleprompter: true }, () => {
        this.triggerTeleprompterAnimation();
      });
      return;
    }

    this.fetchTeleprompterContent({ showAfterLoad: true, showLoadingToast: false });
  },

  // 刷新提词器内容
  onRefreshTeleprompter() {
    if (this.data.teleprompterLoading) {
      return;
    }
    
    // 检查VIP状态
    const isVip = auth.getVipStatus();
    this.setData({ isVip });
    
    // 如果不是VIP，根据设备类型决定支付方式
    if (!isVip) {
      const deviceType = getDeviceType();
      
      // Android 用户：显示微信支付提示卡片
      if (deviceType === 'android' && isRealDevice()) {
        console.log('[提词器] Android 用户，显示微信支付提示卡片');
        this.showWxPayCard();
        return;
      }
      
      // iOS 或其他设备：显示解锁码激活弹窗（支持支付宝 H5 支付后的手动激活）
      console.log('[提词器] 非 Android 设备，显示解锁码输入弹窗');
      this.showUnlockCodeCard();
      return;
    }
    
    // 是VIP，继续刷新提词器内容
    this.fetchTeleprompterContent({ showAfterLoad: true, showLoadingToast: false, isRefresh: true });
  },

  // 获取提词器内容
  fetchTeleprompterContent({ showAfterLoad = false, showLoadingToast = false, isRefresh = false } = {}) {
    this.setData({ teleprompterLoading: !isRefresh });
    if (showLoadingToast) {
      // 不再显示加载提示，静默加载
    }

    wx.request({
      url: `${API_BASE_URL}/blessings`,
      method: 'GET',
      data: { limit: 1 },
      success: (res) => {
        if (res.statusCode === 200 && res.data && res.data.items && res.data.items.length > 0) {
          const blessing = res.data.items[0];
          const newText = blessing.content || '';
          const showTeleprompter = showAfterLoad ? true : this.data.showTeleprompter;
          if (isRefresh) {
            // 刷新时保持提词器可见，并触发渐显动画
            this.setData({
              teleprompterText: newText,
              showTeleprompter
            }, () => {
              this.triggerTeleprompterAnimation();
            });
          } else {
            this.setData({
              teleprompterText: newText,
              showTeleprompter
            }, () => {
              this.triggerTeleprompterAnimation();
            });
          }
        } else {
          wx.showToast({
            title: '获取提词器失败',
            icon: 'none'
          });
        }
      },
      fail: (err) => {
        console.error('获取提词器失败', err);
        wx.showToast({
          title: '网络异常',
          icon: 'none'
        });
      },
      complete: () => {
        this.setData({ teleprompterLoading: false });
        if (showLoadingToast) {
          // 无需隐藏加载提示
        }
      }
    });
  },

  // 触发提词器淡入动画
  triggerTeleprompterAnimation() {
    if (this.teleprompterAnimationTimer) {
      clearTimeout(this.teleprompterAnimationTimer);
    }
    this.setData({ teleprompterAnimating: false });
    setTimeout(() => {
      this.setData({ teleprompterAnimating: true });
      this.teleprompterAnimationTimer = setTimeout(() => {
        this.setData({ teleprompterAnimating: false });
      }, 400);
    }, 20);
  },
  
  // 加载完成拜年任务的用户统计
  loadUploaderStats() {
    wx.request({
      url: `${API_BASE_URL}/audio/uploaders/stats`,
      method: 'GET',
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          const total = res.data.total || 0;
          this.setData({
            uploaderCount: total
          });
          console.log('完成拜年任务的用户数:', total);
        } else {
          console.warn('加载统计信息失败，状态码:', res.statusCode);
        }
      },
      fail: (err) => {
        // 网络错误等，静默处理，不影响使用
        console.error('加载统计信息失败', err);
      }
    });
  },

  // 创建爆炸粒子效果
  createExplosionParticles() {
    const particleCount = 20 + Math.floor(Math.random() * 10); // 20-30个粒子
    const particles = [];
    const centerX = 40 + Math.random() * 20; // 40%-60%
    const centerY = 20 + Math.random() * 15; // 20%-35%

    for (let i = 0; i < particleCount; i++) {
      const angle = Math.random() * Math.PI * 2;
      const distance = 15 + Math.random() * 40;
      const left = centerX + Math.cos(angle) * distance + (Math.random() - 0.5) * 20;
      const top = centerY + Math.sin(angle) * distance * (0.3 + Math.random() * 0.4);
      const horizontalOffset = (Math.random() - 0.5) * 200;
      const rotation = Math.random() * 720 - 360;
      const scale = 0.5 + Math.random() * 0.8;

      const leftValue = Math.max(0, Math.min(100, left));
      const topValue = Math.max(0, Math.min(100, top));

      const initialTransform = `translate(${horizontalOffset}px, 0) scale(${scale}) rotate(${rotation}deg)`;
      particles.push({
        id: Date.now() + i + Math.random() * 1000,
        leftPercent: leftValue + '%',
        topPercent: topValue + '%',
        delay: Math.random() * 0.3,
        initialTransform: initialTransform
      });
    }

    this.setData({
      explosionParticles: particles
    });

    setTimeout(() => {
      this.setData({
        explosionParticles: []
      });
    }, 2000);

    this.playExplosionSound();
  },

  // 播放爆炸音效
  playExplosionSound() {
    try {
      const audioContext = wx.createInnerAudioContext();
      audioContext.src = '/images/audio_boom.mp3';
      audioContext.volume = 0.8;

      audioContext.onCanplay(() => {
        audioContext.play();
      });

      audioContext.onEnded(() => {
        audioContext.destroy();
      });

      audioContext.onError(() => {
        audioContext.destroy();
      });

      audioContext.play();
    } catch (e) {
      console.error('播放爆炸音效失败', e);
    }
  },
  
  // 初始化录音管理器
  initRecorder() {
    const recorderManager = wx.getRecorderManager();
    this.recorderManager = recorderManager;
    
    // 录音开始
    recorderManager.onStart(() => {
      console.log('录音开始');
      this.setData({
        isRecording: true,
        recordingTime: 0,
        buttonText: '录音中...'
      });
      // 开始计时
      this.recordingTimer = setInterval(() => {
        this.setData({
          recordingTime: this.data.recordingTime + 1
        });
      }, 1000);
    });
    
    // 录音结束
    recorderManager.onStop((res) => {
      const tempFilePath = res.tempFilePath;
      const duration = res.duration || this.data.recordingTime * 1000; // 录音时长（毫秒）
      
      // 检测文件格式
      const fileExt = tempFilePath.split('.').pop().toLowerCase();
      
      // 微信开发者工具可能返回 webm 格式，真机返回 mp3
      if (fileExt === 'webm') {
        console.warn('⚠️ 开发者工具：录音格式为 webm，无法上传');
      }
      
      // 防止并发上传：如果正在上传，先取消
      if (this.uploading) {
        console.warn('⚠️ 检测到并发上传，取消上一次上传');
        this.uploading = false;
      }
      
      this.setData({
        isRecording: false,
        hasRecorded: true,
        recordFilePath: tempFilePath, // 临时保存本地路径（仅用于显示状态）
        serverAudioUrl: '', // 清空服务器URL，等待上传完成
        buttonText: '点击试听'
      });
      // 清除计时器
      if (this.recordingTimer) {
        clearInterval(this.recordingTimer);
        this.recordingTimer = null;
      }
      
      // 如果不是分享页面，自动上传录音
      if (!this.data.isSharedPage) {
        if (fileExt === 'webm') {
          wx.showToast({
            title: '请在真机上测试录音上传',
            icon: 'none',
            duration: 3000
          });
        } else {
          this.uploadAudio(tempFilePath, duration);
        }
      }
    });
    
    // 录音错误
    recorderManager.onError((err) => {
      console.error('录音错误', err);
      this.setData({
        isRecording: false,
        buttonText: '点击录音'
      });
      if (this.recordingTimer) {
        clearInterval(this.recordingTimer);
        this.recordingTimer = null;
      }
      wx.showToast({
        title: '录音失败',
        icon: 'none'
      });
    });
  },
  
  // 加载用户资料
  loadUserProfile() {
    const makeRequest = () => {
      const token = auth.getToken();
      const openid = auth.getOpenId();
      
      if (!token || !openid) {
        console.log('未登录，跳过加载用户资料');
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
            let nickname = data.nickname || '昵称';
            if (nickname === 'nick name') {
              nickname = '昵称';
            }
            // 保存 VIP 状态到本地存储
            if (data.is_vip !== undefined) {
              wx.setStorageSync('is_vip', data.is_vip);
            }
            this.setData({
              avatarUrl: data.avatarUrl || '',
              nickname: nickname,
              isVip: data.is_vip || false
            });
          } else if (res.statusCode === 401) {
            // token 过期，尝试重新登录后重试
            console.log('Token 已过期，尝试重新登录...');
            const { silentLogin } = require('../../utils/auth');
            silentLogin()
              .then(() => {
                console.log('重新登录成功，重试加载用户资料');
                makeRequest();
              })
              .catch((err) => {
                console.error('重新登录失败', err);
              });
          }
        },
        fail: (err) => {
          console.error('加载用户资料失败', err);
        }
      });
    };

    // 先检查登录状态
    const token = auth.getToken();
    const isExpired = auth.isTokenExpired();
    
    if (token && !isExpired) {
      makeRequest();
    } else {
      // 未登录或token过期，先登录
      const { silentLogin } = require('../../utils/auth');
      silentLogin()
        .then(() => {
          console.log('登录成功，开始加载用户资料');
          makeRequest();
        })
        .catch((err) => {
          console.error('登录失败', err);
        });
    }
  },

  onReady() {
    // 页面渲染完成
  },

  goBack() {
    wx.navigateBack({
      delta: 1
    });
  },

  // 返回主页
  goToHome() {
    wx.reLaunch({
      url: '/pages/index/index'
    });
  },

  onListenBlessing() {
    // 震动反馈
    wx.vibrateShort({
      type: 'medium' // 中等强度震动
    });
    
    // 按钮点击事件
    if (this.data.isRecording) {
      // 如果正在录音，则停止录音
      this.stopRecord();
    } else if (this.data.hasRecorded && this.data.recordFilePath) {
      // 如果已录音，则播放/暂停录音
      this.togglePlayRecord();
    } else {
      // 如果未录音，则开始录音
      this.startRecord();
    }
  },
  
  // 切换播放/暂停
  togglePlayRecord() {
    if (this.data.isPlaying) {
      // 正在播放，则暂停
      this.pauseRecord();
    } else {
      // 未播放，则播放
      this.playRecord();
    }
  },
  
  // 播放录音
  playRecord() {
    // 必须使用服务器返回的合成音频URL，不播放本地音频
    const serverUrl = this.data.serverAudioUrl;
    
    if (!serverUrl) {
      // 检查是否是本地路径（非http/https开头）
      const isLocalPath = this.data.recordFilePath && 
        !this.data.recordFilePath.startsWith('http://') && 
        !this.data.recordFilePath.startsWith('https://');
      
      if (isLocalPath) {
        wx.showToast({
          title: '别急 再试一次',
          icon: 'none',
          duration: 2000
        });
        return;
      }
      
      // 如果没有服务器URL也没有本地路径
      wx.showToast({
        title: '没有可播放的音频',
        icon: 'none'
      });
      return;
    }
    
    // 如果已有音频上下文，先销毁
    if (this.audioContext) {
      this.audioContext.destroy();
    }
    
    const innerAudioContext = wx.createInnerAudioContext();
    this.audioContext = innerAudioContext;
    innerAudioContext.src = serverUrl; // 只播放服务器返回的合成音频URL
    
    // 打印播放的完整URL（不被截断）
    console.log('▶️ 准备播放音频');
    console.log('📁 播放的完整URL:', serverUrl);
    console.log('🎵 URL是否包含_mixed:', serverUrl.includes('_mixed') ? '是' : '否');
    console.log('📏 URL长度:', serverUrl.length);
    
    innerAudioContext.onPlay(() => {
      console.log('▶️ 开始播放录音');
      this.setData({
        isPlaying: true,
        buttonText: '播放中...'
      });
    });
    
    innerAudioContext.onPause(() => {
      console.log('⏸️ 播放暂停');
      this.setData({
        isPlaying: false,
        buttonText: '点击试听'
      });
    });
    
    innerAudioContext.onEnded(() => {
      console.log('⏹️ 播放结束');
      this.setData({
        isPlaying: false,
        buttonText: '点击试听'
      });
      this.createExplosionParticles();
      innerAudioContext.destroy();
      this.audioContext = null;
    });
    
    innerAudioContext.onError((err) => {
      console.error('播放失败', err);
      
      // 检测是否在开发者工具（使用新的API避免废弃警告）
      let isDevTools = false;
      try {
        const windowInfo = wx.getWindowInfo();
        isDevTools = windowInfo.platform === 'devtools';
      } catch (e) {
        // 兼容旧版本
        try {
          const systemInfo = wx.getSystemInfoSync();
          isDevTools = systemInfo.platform === 'devtools';
        } catch (e2) {
          // 忽略错误
        }
      }
      
      if (isDevTools) {
        console.warn('⚠️ 开发者工具环境：播放失败（这是正常现象）');
        console.warn('播放的URL:', serverUrl);
        console.warn('建议在真机上测试音频播放功能');
      }
      
      this.setData({
        isPlaying: false,
        buttonText: '点击试听'
      });
      innerAudioContext.destroy();
      this.audioContext = null;
      
      wx.showToast({
        title: isDevTools ? '开发者工具播放受限，请在真机测试' : '播放失败',
        icon: 'none',
        duration: 3000
      });
    });
    
    innerAudioContext.play();
  },
  
  // 暂停播放
  pauseRecord() {
    if (this.audioContext) {
      this.audioContext.pause();
    }
  },
  
  // 重录
  onReRecord() {
    wx.showModal({
      title: '确认重录',
      content: '确定要重新录音吗？',
      success: (res) => {
        if (res.confirm) {
          // 停止播放
          if (this.audioContext) {
            this.audioContext.stop();
            this.audioContext.destroy();
            this.audioContext = null;
          }
          // 重置状态（清除之前的分享ID）
          this.setData({
            hasRecorded: false,
            recordFilePath: '',
            serverAudioUrl: '', // 清空服务器URL
            isPlaying: false,
            buttonText: '点击录音',
            shareId: '',
            audioId: ''
          });
          // 开始新录音
          this.startRecord();
        }
      }
    });
  },
  
  // 开始录音
  startRecord() {
    // 检查录音权限
    wx.getSetting({
      success: (res) => {
        if (res.authSetting['scope.record']) {
          // 已授权，开始录音
          this.doStartRecord();
        } else if (res.authSetting['scope.record'] === false) {
          // 已拒绝，提示用户去设置中开启
          wx.showModal({
            title: '需要录音权限',
            content: '请在设置中开启录音权限',
            confirmText: '去设置',
            success: (modalRes) => {
              if (modalRes.confirm) {
                wx.openSetting();
              }
            }
          });
        } else {
          // 未询问过，直接开始录音（会自动弹出授权）
          this.doStartRecord();
        }
      },
      fail: (err) => {
        console.error('获取设置失败', err);
        // 直接尝试录音
        this.doStartRecord();
      }
    });
  },
  
  // 执行开始录音
  doStartRecord() {
    if (!this.recorderManager) {
      this.initRecorder();
    }
    
    const options = {
      duration: 60000, // 最长录音时长，单位ms，默认60秒
      sampleRate: 16000, // 采样率
      numberOfChannels: 1, // 录音通道数
      encodeBitRate: 96000, // 编码码率
      format: 'mp3', // 音频格式
      frameSize: 50 // 指定帧大小，单位KB
    };
    
    this.recorderManager.start(options);
  },
  
  // 停止录音
  stopRecord() {
    if (this.recorderManager && this.data.isRecording) {
      this.recorderManager.stop();
    }
  },
  
  // 上传录音文件
  uploadAudio(tempFilePath, duration) {
    const token = auth.getToken();
    if (!token) {
      console.log('未登录，无法上传录音');
      return;
    }

    // 防止并发上传
    if (this.uploading) {
      console.warn('⚠️ 正在上传中，忽略重复请求');
      return;
    }
    this.uploading = true;

    const durationSeconds = Math.round(duration / 1000); // 转换为秒

    // 第一步：上传录音文件
    wx.uploadFile({
      url: `${API_BASE_URL}/upload/audio`,
      filePath: tempFilePath,
      name: 'file',
      formData: {
        duration: durationSeconds,
        mix_with_bgm: 'true'  // 添加背景音乐混合参数
      },
      header: {
        'Authorization': 'Bearer ' + token
      },
      success: (uploadRes) => {
        try {
          const uploadData = JSON.parse(uploadRes.data);
          
          // 后端返回: {url, audioId, duration}
          // url 字段就是合成后的URL（如果合成成功，会带 _mixed 后缀）
          // 前端直接使用返回的 url 字段即可
          const audioUrl = uploadData.url;
          
          if (audioUrl && uploadData.audioId) {
            const isMixed = audioUrl.includes('_mixed');
            
            // 打印完整的URL（不被截断）
            console.log('✅ 录音上传成功');
            console.log('📁 完整音频URL:', audioUrl);
            console.log('🔑 音频ID:', uploadData.audioId);
            console.log('⏱️ 时长:', uploadData.duration || durationSeconds, '秒');
            console.log('🎵 是否合成:', isMixed ? '是（带_mixed后缀）' : '否（无_mixed后缀）');
            console.log('📋 服务器返回的完整数据:', JSON.stringify(uploadData, null, 2));
            
            if (!isMixed) {
              console.warn('⚠️ 返回的URL没有 _mixed 后缀');
              console.warn('可能原因：1. 合成失败 2. 合成是异步的，URL会在合成完成后更新');
            }
            
            // 第二步：创建录音记录，获取 shareId
            this.createAudioRecord({
              audioUrl: audioUrl, // 直接使用服务器返回的url（合成后的URL）
              audioId: uploadData.audioId,
              duration: uploadData.duration || durationSeconds
            });
          } else {
            this.uploading = false;
            console.error('上传失败：服务器返回数据无效', uploadData);
            wx.showToast({
              title: '上传失败',
              icon: 'none'
            });
          }
        } catch (err) {
          this.uploading = false;
          console.error('解析上传结果失败', err);
          wx.showToast({
            title: '上传失败',
            icon: 'none'
          });
        }
      },
      // 注意：wx.uploadFile 的 fail 回调不会收到 statusCode
      // 如果服务器返回 401，会在 success 回调中收到，但 statusCode 可能是 200
      // 需要检查返回的数据中是否有错误信息
      fail: (err) => {
        this.uploading = false;
        console.error('上传录音失败', err);
        
        // 检测是否在开发者工具（使用新的API避免废弃警告）
        let isDevTools = false;
        try {
          const windowInfo = wx.getWindowInfo();
          isDevTools = windowInfo.platform === 'devtools';
        } catch (e) {
          // 兼容旧版本，静默失败
        }
        
        if (isDevTools) {
          console.warn('⚠️ 开发者工具：上传失败（正常现象，请在真机测试）');
        }
        
        wx.showToast({
          title: isDevTools ? '开发者工具上传受限，请在真机测试' : '上传失败',
          icon: 'none',
          duration: 3000
        });
      }
    });
  },
  
  // 创建录音记录
  createAudioRecord(audioData) {
    const token = auth.getToken();
    if (!token) {
      return;
    }

    wx.request({
      url: `${API_BASE_URL}/audio/record`,
      method: 'POST',
      header: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      },
      data: {
        audioUrl: audioData.audioUrl,
        audioId: audioData.audioId,
        duration: audioData.duration
      },
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          const data = res.data;
          // 更新状态，保存 shareId 和远程URL
          // 优先使用创建记录接口返回的 audioUrl，如果没有则使用上传时传入的 audioUrl
          const finalAudioUrl = data.audioUrl || audioData.audioUrl;
          
          this.setData({
            shareId: data.shareId,
            audioId: data.audioId,
            recordFilePath: finalAudioUrl, // 使用最终的远程URL
            serverAudioUrl: finalAudioUrl // 保存服务器返回的合成音频URL
          });
          
          this.uploading = false; // 上传完成
          
          const isMixed = finalAudioUrl.includes('_mixed');
          console.log('✅ 录音记录创建成功');
          console.log('🔗 分享ID:', data.shareId);
          console.log('📁 最终音频URL:', finalAudioUrl);
          console.log('🎵 是否合成:', isMixed ? '是（带_mixed后缀）' : '否（无_mixed后缀）');
          console.log('📋 创建记录返回的完整数据:', JSON.stringify(data, null, 2));
          
          if (!isMixed) {
            console.warn('⚠️ 最终使用的URL没有 _mixed 后缀');
            console.warn('如果真机上播放的是合成音频，可能是：');
            console.warn('1. 服务器在后台异步合成，URL会在合成完成后自动更新');
            console.warn('2. 服务器根据请求来源返回不同的URL（不太可能）');
            console.warn('3. 播放时访问的URL已被重定向到合成后的版本');
          }
          
        } else if (res.statusCode === 401) {
          // 401 未授权：token 过期或无效
          console.error('❌ 401 未授权：创建录音记录失败', {
            statusCode: res.statusCode,
            data: res.data
          });
          console.error('可能原因：token 过期、token 无效、或没有权限');
          
          this.uploading = false;
          
          // 尝试重新登录后重试
          const { silentLogin } = require('../../utils/auth');
          silentLogin()
            .then(() => {
              console.log('重新登录成功，重试创建录音记录');
              // 重新发起请求
              this.createAudioRecord(audioData);
            })
            .catch((err) => {
              console.error('重新登录失败', err);
              wx.showToast({
                title: '登录已过期，请重新登录',
                icon: 'none',
                duration: 3000
              });
            });
        } else {
          this.uploading = false;
          console.error('创建录音记录失败', {
            statusCode: res.statusCode,
            data: res.data
          });
          wx.showToast({
            title: '上传成功，但无法分享',
            icon: 'none',
            duration: 2000
          });
        }
      },
      fail: (err) => {
        console.error('创建录音记录失败', err);
        wx.showToast({
          title: '上传成功，但无法分享',
          icon: 'none',
          duration: 2000
        });
      }
    });
  },
  
  // 加载分享的录音
  loadSharedAudio(shareId) {
    wx.showLoading({
      title: '加载中...',
      mask: true
    });

    wx.request({
      url: `${API_BASE_URL}/audio/${shareId}`,
      method: 'GET',
      success: (res) => {
        wx.hideLoading();
        if (res.statusCode === 200 && res.data) {
          const data = res.data;
          // 后端返回: {audioUrl, audioId, duration, userInfo: {nickname, avatarUrl}}
          const audioUrl = data.audioUrl;
          
          if (audioUrl) {
            // 更新用户信息（如果有）
            if (data.userInfo) {
              this.setData({
                nickname: data.userInfo.nickname || '昵称',
                avatarUrl: data.userInfo.avatarUrl || ''
              });
            }
            
            // 设置录音文件（使用服务器返回的合成音频URL）
            this.setData({
              recordFilePath: audioUrl,
              serverAudioUrl: audioUrl, // 保存服务器返回的合成音频URL
              hasRecorded: true,
              buttonText: '点击试听',
              shareId: shareId,
              audioId: data.audioId || shareId
            });
            
            // 自动播放
            setTimeout(() => {
              this.playRecord();
            }, 500);
          } else {
            wx.showToast({
              title: '录音不存在',
              icon: 'none'
            });
          }
        } else {
          wx.showToast({
            title: '加载失败',
            icon: 'none'
          });
        }
      },
      fail: (err) => {
        wx.hideLoading();
        console.error('加载分享录音失败', err);
        wx.showToast({
          title: '加载失败',
          icon: 'none'
        });
      }
    });
  },
  
  // 分享功能
  onShareAppMessage() {
    if (this.data.shareId) {
      return {
        title: `${this.data.nickname} 给您拜年啦 🧨🧨🧨`,
        path: `/pages/newyear/index?shareId=${this.data.shareId}`,
        imageUrl: 'https://wemedev.com/data/festival/images/bg_share.png'
      };
    } else {
      // 如果没有录音，分享默认页面
      return {
        title: '春节倒计时 - 拜年卡片',
        path: '/pages/newyear/index',
        imageUrl: 'https://wemedev.com/data/festival/images/bg_share.png'
      };
    }
  },
  
  // 分享到朋友圈
  onShareTimeline() {
    if (this.data.shareId) {
      return {
        title: `${this.data.nickname} 给您拜年啦 🧨🧨🧨`,
        query: `shareId=${this.data.shareId}`,
        imageUrl: 'https://wemedev.com/data/festival/images/bg_share.png'
      };
    } else {
      return {
        title: '春节倒计时 - 拜年卡片',
        imageUrl: 'https://wemedev.com/data/festival/images/bg_share.png'
      };
    }
  },

  onUnload() {
    // 页面卸载时停止录音并清理
    if (this.recorderManager && this.data.isRecording) {
      this.recorderManager.stop();
    }
    if (this.recordingTimer) {
      clearInterval(this.recordingTimer);
      this.recordingTimer = null;
    }
    // 清理音频上下文
    if (this.audioContext) {
      this.audioContext.destroy();
      this.audioContext = null;
    }
  },

  // 显示解锁码激活卡片
  showUnlockCodeCard() {
    this.setData({
      showUnlockCodeCard: true,
      unlockCodeValue: '',
      unlockCodeFocus: false
    });
    // 延迟一帧确保遮罩先显示，然后触发卡片动画
    setTimeout(() => {
      this.setData({
        unlockCodeCardShow: true
      });
    }, 50);
  },

  // 关闭解锁码激活卡片
  closeUnlockCodeCard() {
    // 如果正在激活，不允许关闭
    if (this.data.isActivating) {
      return;
    }
    // 先隐藏卡片，再隐藏遮罩
    this.setData({
      unlockCodeCardShow: false,
      unlockCodeFocus: false
    });
    setTimeout(() => {
      this.setData({
        showUnlockCodeCard: false,
        unlockCodeValue: ''
      });
    }, 300);
  },

  // 复制购买URL
  copyPurchaseUrl() {
    wx.setClipboardData({
      data: UNLOCK_CODE_PURCHASE_URL,
      success: () => {
        wx.showToast({
          title: '链接已复制',
          icon: 'success',
          duration: 2000
        });
      },
      fail: () => {
        wx.showToast({
          title: '复制失败',
          icon: 'none'
        });
      }
    });
  },

  // 解锁码输入内容改变
  onUnlockCodeInputChange(e) {
    this.setData({
      unlockCodeValue: e.detail.value.trim().toUpperCase() // 自动转换为大写
    });
  },

  // 确认激活解锁码
  confirmUnlockCode() {
    const code = this.data.unlockCodeValue.trim();
    
    if (!code) {
      wx.showToast({
        title: '请输入解锁码',
        icon: 'none'
      });
      return;
    }
    
    // 检查是否已登录
    const openid = auth.getOpenId();
    if (!openid) {
      wx.showToast({
        title: '请先登录',
        icon: 'none'
      });
      // 尝试登录
      auth.silentLogin().then(() => {
        // 登录成功后重试激活
        this.confirmUnlockCode();
      }).catch(() => {
        // 登录失败
      });
      return;
    }
    
    // 开始激活
    this.setData({ isActivating: true });
    
    // 调用激活接口
    auth.activateUnlockCode(code)
      .then((result) => {
        console.log('解锁码激活成功', result);
        
        // 激活成功后，查询VIP状态确认
        return auth.queryVipStatus();
      })
      .then((isVip) => {
        console.log('VIP状态查询成功', isVip);
        
        // 更新VIP状态
        this.setData({ isVip });
        
        // 关闭弹窗
        this.setData({
          unlockCodeCardShow: false,
          unlockCodeFocus: false
        });
        setTimeout(() => {
          this.setData({
            showUnlockCodeCard: false,
            unlockCodeValue: '',
            isActivating: false
          });
        }, 300);
        
        // 显示成功提示
        wx.showToast({
          title: '激活成功！',
          icon: 'success',
          duration: 2000
        });
        
        // 激活成功后，自动刷新提词器内容
        setTimeout(() => {
          this.fetchTeleprompterContent({ showAfterLoad: true, showLoadingToast: false, isRefresh: true });
        }, 500);
      })
      .catch((err) => {
        console.error('激活失败', err);
        this.setData({ isActivating: false });
        
        // 显示错误提示
        const errorMsg = err.message || '激活失败，请稍后重试';
        wx.showToast({
          title: errorMsg,
          icon: 'none',
          duration: 3000
        });
      });
  },

  // 阻止事件冒泡
  stopPropagation() {
    // 空函数，用于阻止事件冒泡
  },

  // ========== 微信支付提示卡片相关方法 ==========
  
  // 显示微信支付提示卡片
  showWxPayCard() {
    this.setData({
      showWxPayCard: true
    });
    // 延迟一帧确保遮罩先显示，然后触发卡片动画
    setTimeout(() => {
      this.setData({
        wxPayCardShow: true
      });
    }, 50);
  },

  // 关闭微信支付提示卡片
  closeWxPayCard() {
    // 先隐藏卡片，再隐藏遮罩
    this.setData({
      wxPayCardShow: false
    });
    setTimeout(() => {
      this.setData({
        showWxPayCard: false
      });
    }, 300);
  },

  // 确认支付（点击确认按钮后调起微信支付）
  confirmWxPay() {
    // 关闭卡片
    this.closeWxPayCard();
    // 延迟一点时间，让卡片关闭动画完成
    setTimeout(() => {
      // 调起微信支付
      this.createWxPayOrder();
    }, 300);
  },

  // ========== 微信支付相关方法 ==========
  
  // 创建微信支付订单
  createWxPayOrder() {
    // 检查登录状态
    const openid = auth.getOpenId();
    const token = auth.getToken();
    
    if (!openid || !token) {
      wx.showToast({
        title: '请先登录',
        icon: 'none'
      });
      // 尝试登录
      auth.silentLogin().then(() => {
        this.createWxPayOrder();
      }).catch(() => {
        // 登录失败
      });
      return;
    }

    wx.showLoading({
      title: '创建订单中...',
      mask: true
    });

    console.log('[微信支付] 创建订单，用户:', openid);

    // 创建微信支付订单
    wx.request({
      url: `${WXPAY_API_BASE}/orders`,
      method: 'POST',
      header: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      data: {
        openid: openid,
        amount: 1, // 1分 = 0.01元（测试用，实际金额需要配置）
        description: 'Festival 解锁码'
      },
      success: (res) => {
        wx.hideLoading();
        
        console.log('[微信支付] 创建订单响应:', {
          statusCode: res.statusCode,
          data: res.data
        });

        if (res.statusCode === 200 && res.data) {
          const orderData = res.data;
          const orderId = orderData.order_id || orderData.out_trade_no || '';
          
          // 保存订单ID，用于支付成功后查询
          this._wxPayOrderId = orderId;
          
          // 调起微信支付
          this.requestWxPayment(orderData.pay_params || orderData);
        } else {
          const errorMsg = res.data?.message || res.data?.detail || '创建订单失败';
          console.error('[微信支付] 创建订单失败:', errorMsg);
          wx.showToast({
            title: errorMsg,
            icon: 'none',
            duration: 3000
          });
        }
      },
      fail: (err) => {
        wx.hideLoading();
        console.error('[微信支付] 创建订单请求失败:', err);
        wx.showToast({
          title: err.errMsg || '网络请求失败',
          icon: 'none',
          duration: 3000
        });
      }
    });
  },

  // 调起微信支付
  requestWxPayment(payParams) {
    if (!payParams) {
      console.error('[微信支付] 支付参数为空');
      wx.showToast({
        title: '支付参数错误',
        icon: 'none'
      });
      return;
    }

    // 确保参数格式正确
    const paymentParams = {
      timeStamp: String(payParams.timeStamp || payParams.time_stamp || ''),
      nonceStr: payParams.nonceStr || payParams.nonce_str || '',
      package: payParams.package || payParams.package_value || '',
      signType: payParams.signType || payParams.sign_type || 'RSA',
      paySign: payParams.paySign || payParams.pay_sign || ''
    };

    // 验证支付参数
    const requiredParams = ['timeStamp', 'nonceStr', 'package', 'paySign'];
    const missingParams = requiredParams.filter(key => !paymentParams[key]);
    
    if (missingParams.length > 0) {
      console.error('[微信支付] 支付参数缺失:', missingParams);
      wx.showToast({
        title: '支付参数不完整',
        icon: 'none',
        duration: 3000
      });
      return;
    }

    console.log('[微信支付] 调起支付，订单ID:', this._wxPayOrderId);

    wx.requestPayment({
      ...paymentParams,
      success: (res) => {
        console.log('[微信支付] 支付成功:', res);
        wx.showToast({
          title: '支付成功',
          icon: 'success',
          duration: 2000
        });
        
        // 支付成功后，查询订单状态并确认VIP状态
        this.checkOrderAndVipStatus();
      },
      fail: (err) => {
        console.error('[微信支付] 支付失败:', err);
        
        let errorMsg = '支付失败';
        if (err.errMsg) {
          if (err.errMsg.includes('cancel') || err.errMsg.includes('取消')) {
            errorMsg = '用户取消支付';
          } else {
            errorMsg = '支付失败：' + err.errMsg;
          }
        }
        
        wx.showToast({
          title: errorMsg,
          icon: 'none',
          duration: 3000
        });
      }
    });
  },

  // 检查订单状态和VIP状态（支付成功后）
  checkOrderAndVipStatus() {
    const orderId = this._wxPayOrderId;
    if (!orderId) {
      console.error('[微信支付] 订单ID为空，无法查询');
      return;
    }

    console.log('[微信支付] 开始查询订单状态，订单ID:', orderId);

    // 轮询查询订单状态（最多10次，间隔2秒）
    let pollCount = 0;
    const maxPollCount = 10;
    const pollInterval = 2000; // 2秒

    const pollOrderStatus = () => {
      if (pollCount >= maxPollCount) {
        console.warn('[微信支付] 轮询超时，停止查询');
        wx.showToast({
          title: '订单状态查询超时，请稍后刷新',
          icon: 'none',
          duration: 3000
        });
        return;
      }

      pollCount++;
      console.log(`[微信支付] 第 ${pollCount} 次查询订单状态`);

      // 查询订单状态
      wx.request({
        url: `${API_BASE_URL}/orders/${orderId}`,
        method: 'GET',
        header: {
          'Authorization': `Bearer ${auth.getToken()}`,
          'Content-Type': 'application/json'
        },
        success: (res) => {
          if (res.statusCode === 200 && res.data) {
            const order = res.data;
            console.log('[微信支付] 订单状态:', {
              orderId: orderId,
              status: order.status,
              unlockCode: order.unlock_code
            });

            // 如果订单已支付且有解锁码，查询VIP状态
            if (order.status === 'paid' && order.unlock_code) {
              console.log('[微信支付] 订单已支付，解锁码:', order.unlock_code);
              // 查询VIP状态确认
              this.checkVipStatusAndRefresh();
            } else if (order.status === 'paid') {
              // 订单已支付但还没有解锁码，继续轮询
              console.log('[微信支付] 订单已支付，等待解锁码分配...');
              setTimeout(pollOrderStatus, pollInterval);
            } else {
              // 订单未支付，继续轮询
              console.log('[微信支付] 订单未支付，继续查询...');
              setTimeout(pollOrderStatus, pollInterval);
            }
          } else {
            // 查询失败，继续轮询
            console.warn('[微信支付] 查询订单状态失败，继续轮询');
            setTimeout(pollOrderStatus, pollInterval);
          }
        },
        fail: (err) => {
          console.error('[微信支付] 查询订单状态请求失败:', err);
          // 请求失败，继续轮询
          setTimeout(pollOrderStatus, pollInterval);
        }
      });
    };

    // 开始轮询
    pollOrderStatus();
  },

  // 查询VIP状态并刷新提词器
  checkVipStatusAndRefresh() {
    const openid = auth.getOpenId();
    if (!openid) {
      console.error('[微信支付] OpenID 为空，无法查询VIP状态');
      return;
    }

    console.log('[微信支付] 查询VIP状态，用户:', openid);

    wx.request({
      url: `${API_BASE_URL}/users/${openid}/vip-status`,
      method: 'GET',
      success: (res) => {
        if (res.statusCode === 200 && res.data) {
          const { is_vip } = res.data;
          console.log('[微信支付] VIP状态查询结果:', is_vip);
          
          // 更新本地VIP状态
          wx.setStorageSync('is_vip', is_vip);
          this.setData({ isVip: is_vip });
          
          if (is_vip) {
            console.log('[微信支付] 用户已是VIP，自动刷新提词器');
            // 自动刷新提词器内容
            setTimeout(() => {
              this.fetchTeleprompterContent({ 
                showAfterLoad: true, 
                showLoadingToast: false, 
                isRefresh: true 
              });
            }, 500);
          } else {
            console.warn('[微信支付] 用户还不是VIP，可能需要等待回调处理');
            wx.showToast({
              title: '支付成功，请稍后刷新',
              icon: 'none',
              duration: 3000
            });
          }
        } else {
          console.error('[微信支付] 查询VIP状态失败:', res);
        }
      },
      fail: (err) => {
        console.error('[微信支付] 查询VIP状态请求失败:', err);
      }
    });
  }
});

