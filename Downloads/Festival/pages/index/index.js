// pages/index/index.js
const TARGET = new Date(2026, 1, 17, 0, 0, 0); // 2026-02-17 00:00:00 (month is 0-based)
const app = getApp();
const auth = require('../../utils/auth');
const config = require('../../utils/config');
const imageCache = require('../../utils/imageCache');

const API_BASE_URL = 'https://wemedev.com/api/festival';

Page({
  data: {
    days: '0',
    hours: '00',
    minutes: '00',
    seconds: '00',
    sparkleArray: [],
    typewriterText: '',
    statusBarHeight: 0, // 状态栏高度
    navBarHeight: 44, // 导航栏高度（默认44px）
    sparkStartTop: 0, // 粒子起始位置（rpx）
    sparkInstances: [], // 存储多个粒子实例的ID数组
    avatarUrl: '', // 用户头像URL
    nickname: '昵称', // 用户昵称
    likeCount: 0, // 点赞数量
    isMusicPlaying: false, // 音乐是否正在播放
    isVip: false, // 是否为VIP用户
    // 歌词相关
    lyrics: [], // 歌词数组
    currentLyricIndex: -1, // 当前歌词索引
    currentLyricText: '', // 当前歌词文本
    // 按钮选择数据
    whoOptions: ['一个人', '和对象', '一家人', '喵星人', '汪星人'],
    whoIndex: 0,
    whoText: '和谁',
    howOptions: ['飞机', '高铁', '开车', '直升机', '轮船', '地铁',  '滑翔翼',  '潜水艇', '电瓶车', '自行车', '三轮车', '滑板', '旱冰鞋',  '走路', '轮椅', '家里蹲'],
    howIndex: 0,
    howText: '怎么回',
    whenDate: '', // 哪天回
    whenText: '哪天回',
    // 几号有空（月/号选择器）
    availableDateOptions: [
      ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      ['1号', '2号', '3号', '4号', '5号', '6号', '7号', '8号', '9号', '10号', '11号', '12号', '13号', '14号', '15号', '16号', '17号', '18号', '19号', '20号', '21号', '22号', '23号', '24号', '25号', '26号', '27号', '28号', '29号', '30号', '31号']
    ],
    availableDateIndex: [0, 0], // [月份索引, 日期索引]
    availableTime: '', // 几号有空（存储值，格式：M/d，例如 "2/15"）
    availableTimeText: '几号有空', // 几号有空（显示文本，例如 "2月15号"）
    whereText: '回哪里',
    mustDoText: '过节必须干件事',
    infoText: '关于春节说点啥～',
    // 输入卡片显示
    showInputCard: false,
    inputCardShow: false,
    inputValue: '',
    inputFocus: false,
    showWhereInputCard: false,
    whereInputCardShow: false,
    whereInputValue: '',
    whereInputFocus: false,
    showInfoTextInputCard: false,
    infoTextInputCardShow: false,
    infoTextInputValue: '',
    infoTextInputFocus: false,
    // 激活解锁码
    showUnlockCodeCard: false,
    unlockCodeCardShow: false,
    unlockCodeValue: '',
    unlockCodeFocus: false,
    isActivating: false, // 是否正在激活
    // 远程配置
    showNewYearButton: true, // 是否显示拜年卡片按钮，默认显示
    // 广告图
    showAdImage: false, // 是否显示广告图
    adImagePath: '', // 广告图本地路径
    adImageAnimating: false, // 广告图动画状态
    adImageWidth: null, // 广告图宽度（rpx，自动适配）
    adImageHeight: null, // 广告图高度（rpx，自动适配）
    adClickType: 'none', // 广告点击类型：none, page, url, miniprogram
    adClickPage: null, // 小程序页面路径
    adClickUrl: null, // 网页URL
    adClickMiniprogram: null, // 跳转其他小程序的配置（JSON字符串）
    // 倒计时结束后的拜年图片
    isCountdownEnded: false, // 倒计时是否已结束
    hasManuallySwitched: false, // 用户是否手动切换过状态（如果手动切换过，不再自动切换）
    newYearImageUrl: 'https://wemedev.com/data/festival/images/bg_go2.png', // 拜年图片URL
    // 点赞列表
    showLikesList: false, // 是否显示点赞列表
    likesList: [], // 点赞列表数据
    likesListLoading: false // 点赞列表加载状态
  },
  onLoad() {
    // 获取系统信息，计算状态栏和导航栏高度
    try {
      const windowInfo = wx.getWindowInfo();
      const statusBarHeight = windowInfo.statusBarHeight || 0;
      const screenWidth = windowInfo.windowWidth || 375; // px
      // 导航栏高度 = 状态栏高度 + 44px（标准导航栏高度）
      const navBarHeight = statusBarHeight + 44;
      
      // 计算粒子起始位置：从卡片底部外面100rpx开始，让粒子穿过卡片
      // 卡片是16:9比例，通过CSS自动计算，这里只需要计算大概位置
      const offsetOutside = 50; // 卡片底部外面100rpx = 50px
      // 估算卡片高度：屏幕宽度 - 容器padding(40px) * 9/16
      const estimatedCardHeight = Math.round((screenWidth - 40) * 9 / 16);
      const sparkStartTopPx = estimatedCardHeight + offsetOutside;
      const sparkStartTop = Math.round(sparkStartTopPx * 2); // 转换为rpx
      
      this.setData({
        statusBarHeight: statusBarHeight,
        navBarHeight: navBarHeight,
        sparkStartTop: sparkStartTop
      });
    } catch (e) {
      console.error('获取系统信息失败', e);
    }

    // 初始显示粒子动画
    setTimeout(() => {
      this.addSparkInstance();
    }, 600);

    this.update();
    this.timer = setInterval(() => this.update(), 1000);
    
    // 打字机效果初始化
    this.startTypewriter();
    
    // 确保登录后加载用户资料
    this.ensureLoginAndLoadProfile();
    
    // 初始化VIP状态
    const isVip = auth.getVipStatus();
    console.log('初始化VIP状态:', isVip);
    this.setData({ isVip });
    
    // 加载 Douyin 字体
    this.loadDouyinFont();
    
    // 监听背景音乐播放状态
    this.listenToMusicStatus();
    
    // 初始化歌词数据
    this.initLyrics();
    
    // 加载远程配置
    this.loadRemoteConfig();
  },
  // 初始化歌词数据
  initLyrics() {
    const lyrics = app.globalData.lyrics || [];
    const currentIndex = app.globalData.currentLyricIndex || -1;
    this.setData({
      lyrics: lyrics,
      currentLyricIndex: currentIndex,
      currentLyricText: currentIndex >= 0 && lyrics[currentIndex] ? lyrics[currentIndex].text : ''
    });
  },
  // 歌词更新回调
  onLyricUpdate(data) {
    if (data && data.lyrics) {
      this.setData({
        lyrics: data.lyrics,
        currentLyricIndex: data.currentIndex || -1,
        currentLyricText: data.currentIndex >= 0 && data.lyrics[data.currentIndex] 
          ? data.lyrics[data.currentIndex].text 
          : ''
      });
    }
  },
  // 监听背景音乐播放状态
  listenToMusicStatus() {
    const bgAudioManager = app.globalData.bgAudioManager;
    if (!bgAudioManager) {
      // 如果音乐管理器还未初始化，延迟监听
      setTimeout(() => {
        this.listenToMusicStatus();
      }, 500);
      return;
    }

    // 监听播放事件
    bgAudioManager.onPlay(() => {
      this.setData({
        isMusicPlaying: true
      });
    });

    // 监听暂停事件
    bgAudioManager.onPause(() => {
      this.setData({
        isMusicPlaying: false
      });
    });

    // 监听停止事件
    bgAudioManager.onStop(() => {
      this.setData({
        isMusicPlaying: false
      });
    });

    // 监听播放结束事件
    bgAudioManager.onEnded(() => {
      // 音乐播放结束，先停止旋转
      this.setData({
        isMusicPlaying: false
      });
      // 音乐会自动重新播放，等待 onPlay 事件触发时再开始旋转
    });

    // 初始化时不自动播放，所以初始状态为 false
    // 用户需要手动控制音乐播放
      this.setData({
      isMusicPlaying: false
      });
  },
  // 确保登录并加载用户资料
  ensureLoginAndLoadProfile() {
    const token = auth.getToken();
    const isExpired = auth.isTokenExpired();
    
    if (token && !isExpired) {
      // 已登录，直接加载用户资料
      this.loadUserProfile();
    } else {
      // 未登录或token过期，先登录
      this.loginAndLoadProfile();
    }
  },
  // 登录并加载用户资料
  loginAndLoadProfile() {
    const { silentLogin } = require('../../utils/auth');
    silentLogin()
      .then((result) => {
        console.log('登录成功，开始加载用户资料', result);
        // 登录成功后加载用户资料
        this.loadUserProfile();
      })
      .catch((err) => {
        console.error('登录失败', err);
        // 登录失败不影响使用，但无法加载用户资料
      });
  },
  // 登录成功回调（由 app.js 调用）
  onLoginSuccess() {
    // 更新VIP状态
    const isVip = auth.getVipStatus();
    this.setData({ isVip });
    // 登录成功后加载用户资料
    this.loadUserProfile();
  },
  onUnload() {
    clearInterval(this.timer);
    if (this.typewriterTimer) clearInterval(this.typewriterTimer);
  },
  // 点击卡片触发粒子动画
  triggerSparks() {
    // 添加新的粒子实例，不终止现有动画
    this.addSparkInstance();
  },
  // 添加新的粒子实例
  addSparkInstance() {
    const instanceId = Date.now() + Math.random(); // 生成唯一ID
    const instances = this.data.sparkInstances || [];
    instances.push(instanceId);
    
    this.setData({
      sparkInstances: instances
    });
    
    // 14秒后自动移除该实例（2次循环 × 7秒）
    setTimeout(() => {
      this.removeSparkInstance(instanceId);
    }, 14000);
  },
  // 移除粒子实例
  removeSparkInstance(instanceId) {
    const instances = this.data.sparkInstances || [];
    const index = instances.indexOf(instanceId);
    if (index > -1) {
      instances.splice(index, 1);
      this.setData({
        sparkInstances: instances
      });
    }
  },
  // 打字机效果
  startTypewriter() {
    const fullText = '新年快乐！恭迎丙午（马）年';
    let index = 0;
    this.typewriterTimer = setInterval(() => {
      if (index < fullText.length) {
        this.setData({
          typewriterText: fullText.substring(0, index + 1)
        });
        index++;
      } else {
        clearInterval(this.typewriterTimer);
      }
    }, 150);
  },
  update() {
    const now = new Date();
    let diff = TARGET.getTime() - now.getTime();
    const isEnded = diff <= 0;
    
    // 检测倒计时是否刚结束（从未结束变为已结束）
    // 只有在用户没有手动切换过状态时，才自动切换
    if (isEnded && !this.data.isCountdownEnded && !this.data.hasManuallySwitched) {
      this.setData({
        isCountdownEnded: true
      });
    }
    
    if (diff < 0) diff = 0;

    const s = Math.floor(diff / 1000);
    const days = Math.floor(s / (24*3600));
    const hours = Math.floor((s % (24*3600)) / 3600);
    const minutes = Math.floor((s % 3600) / 60);
    const seconds = s % 60;

    this.setData({
      days: String(days),
      hours: hours.toString().padStart(2,'0'),
      minutes: minutes.toString().padStart(2,'0'),
      seconds: seconds.toString().padStart(2,'0')
    });
  },
  // 选择头像（使用 view 替代 button，避免微信组件的默认 loading）
  onChooseAvatarTap() {
    wx.chooseMedia({
      count: 1,
      mediaType: ['image'],
      sourceType: ['album', 'camera'],
      success: (res) => {
        const tempFilePath = res.tempFiles[0].tempFilePath;
        // 先显示临时头像
        this.setData({
          avatarUrl: tempFilePath
        });
        
        // 上传头像到服务器
        this.uploadAvatar(tempFilePath);
      },
      fail: (err) => {
        console.error('选择头像失败', err);
      }
    });
  },
  // 兼容旧的事件处理（如果微信组件仍然触发）
  onChooseAvatar(e) {
    const { avatarUrl } = e.detail;
    // 先显示临时头像
    this.setData({
      avatarUrl: avatarUrl
    });
    
    // 上传头像到服务器
    this.uploadAvatar(avatarUrl);
  },
  // 上传头像
  uploadAvatar(tempFilePath) {
    const token = auth.getToken();
    if (!token) {
      wx.showToast({
        title: '请先登录',
        icon: 'none'
      });
      return;
    }

    // 静默上传，不显示加载提示
    wx.uploadFile({
      url: `${API_BASE_URL}/upload/avatar`,
      filePath: tempFilePath,
      name: 'file',
      header: {
        'Authorization': 'Bearer ' + token
      },
      success: (uploadRes) => {
        try {
          const data = JSON.parse(uploadRes.data);
          if (data.url) {
            // 上传成功后，更新用户资料（静默更新，不显示加载提示）
            this.updateProfile({
              avatarUrl: data.url
            }, false);
          } else {
            console.error('上传失败：服务器返回数据无效');
          }
        } catch (err) {
          console.error('解析上传结果失败', err);
        }
      },
      fail: (err) => {
        console.error('上传头像失败', err);
      }
    });
  },
  // 昵称输入
  onNicknameInput(e) {
    const nickname = e.detail.value || '昵称';
    this.setData({
      nickname: nickname
    });
    
    // 更新昵称到服务器（静默更新，不显示加载提示）
    this.updateProfile({
      nickname: nickname
    }, false); // 不显示加载提示
  },
  // 更新用户资料
  updateProfile(data, showLoading = false) {
    const makeRequest = () => {
      const token = auth.getToken();
      if (!token) {
        console.warn('未登录，无法更新资料');
        if (showLoading) {
          wx.hideLoading();
        }
        return;
      }

      wx.request({
        url: `${API_BASE_URL}/profiles`,
        method: 'PUT',
        header: {
          'Authorization': 'Bearer ' + token,
          'Content-Type': 'application/json'
        },
        data: data,
        success: (res) => {
          if (res.statusCode === 200) {
            console.log('资料更新成功', res.data);
            // 更新本地数据
            if (res.data.avatarUrl) {
              this.setData({
                avatarUrl: res.data.avatarUrl
              });
            }
            if (res.data.nickname) {
              this.setData({
                nickname: res.data.nickname
              });
            }
          } else if (res.statusCode === 401) {
            // token 过期，尝试重新登录后重试
            console.log('Token 已过期，尝试重新登录...');
            const { silentLogin } = require('../../utils/auth');
            silentLogin()
              .then(() => {
                console.log('重新登录成功，重试更新资料');
                // 重新发起请求
                makeRequest();
              })
              .catch((err) => {
                console.error('重新登录失败', err);
                if (showLoading) {
                  wx.hideLoading();
                }
                this.handleApiError(res);
              });
          } else {
            console.error('更新资料失败', res);
            if (showLoading) {
              wx.hideLoading();
              // 只有在显示 loading 时才显示错误提示
              this.handleApiError(res);
            } else {
              // 静默更新时，失败也不显示 toast
              console.error('静默更新失败，不显示提示');
            }
          }
        },
        fail: (err) => {
          console.error('更新资料请求失败', err);
          if (showLoading) {
            wx.hideLoading();
          }
          // 静默失败，不显示 toast 提示
        },
        complete: () => {
          // 注意：这里不隐藏 loading，因为可能在 401 重试时还需要显示
        }
      });
    };

    // 如果需要显示加载提示
    if (showLoading) {
      wx.showLoading({
        title: '加载中...',
        mask: true
      });
    }

    // 发起请求
    makeRequest();
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
            // 更新本地数据
            const data = res.data;
            // 如果服务器返回的是 "nick name"，替换为 "昵称"
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
              likeCount: data.likeCount || data.like_count || 0,
              isVip: data.is_vip || false,
              // 卡片内容
              infoText: data.infoText || '关于春节说点啥～',
              // 按钮选择
              whoText: data.whoText || '和谁',
              howText: data.howText || '怎么回',
              whenDate: data.whenDate || '',
              whenText: data.whenText || '哪天回',
              availableTime: data.availableTime || '',
              availableTimeText: data.availableTimeText || '几号有空',
              // 从存储值恢复索引（格式：M/d，例如 "2/15"）
              availableDateIndex: this.parseAvailableDateIndex(data.availableTime || ''),
              whereText: data.whereText || '回哪里',
              mustDoText: data.mustDoText || '过节必须干件事'
            });
            
            // 如果有选择值，需要同步索引
            if (data.whoText) {
              const whoIndex = this.data.whoOptions.indexOf(data.whoText);
              if (whoIndex >= 0) {
                this.setData({ whoIndex: whoIndex });
              }
            }
            if (data.howText) {
              const howIndex = this.data.howOptions.indexOf(data.howText);
              if (howIndex >= 0) {
                this.setData({ howIndex: howIndex });
              }
            }
          } else if (res.statusCode === 401) {
            // token 过期，尝试重新登录后重试
            console.log('Token 已过期，尝试重新登录...');
            const { silentLogin } = require('../../utils/auth');
            silentLogin()
              .then(() => {
                console.log('重新登录成功，重试加载用户资料');
                // 重新发起请求
                makeRequest();
              })
              .catch((err) => {
                console.error('重新登录失败', err);
                console.error('获取用户资料失败', res);
              });
          } else if (res.statusCode === 404) {
            // 用户资料不存在，这是正常的，新用户还没有创建资料
            console.log('用户资料不存在，等待用户创建');
          } else {
            console.error('获取用户资料失败', res);
          }
        },
        fail: (err) => {
          console.error('获取用户资料请求失败', err);
        }
      });
    };

    // 发起请求
    makeRequest();
  },
  // 处理API错误
  handleApiError(res) {
    if (res.statusCode === 401) {
      // token 无效或过期，清除登录信息
      auth.clearAuth();
      wx.showToast({
        title: '登录已过期，请重新登录',
        icon: 'none'
      });
    } else if (res.statusCode === 403) {
      wx.showToast({
        title: '无权访问',
        icon: 'none'
      });
    } else if (res.statusCode === 415) {
      wx.showToast({
        title: '文件格式不支持',
        icon: 'none'
      });
    } else if (res.statusCode === 413) {
      wx.showToast({
        title: '文件大小超过限制',
        icon: 'none'
      });
    } else {
      const errorMsg = (res.data && res.data.message) ? res.data.message : '操作失败';
      wx.showToast({
        title: errorMsg,
        icon: 'none'
      });
    }
  },
  // "和谁"选择器改变
  onWhoPickerChange(e) {
    const index = e.detail.value;
    const text = this.data.whoOptions[index];
    this.setData({
      whoIndex: index,
      whoText: text
    });
    // 保存到服务器
    this.saveAllProfileData();
  },
  // "怎么回"选择器改变
  onHowPickerChange(e) {
    const index = e.detail.value;
    const text = this.data.howOptions[index];
    this.setData({
      howIndex: index,
      howText: text
    });
    // 保存到服务器
    this.saveAllProfileData();
  },
  // "哪天回"日期选择器改变
  onWhenDateChange(e) {
    const date = e.detail.value;
    // 格式化日期显示：2026-02-17 -> 2月17日
    const dateObj = new Date(date);
    const month = dateObj.getMonth() + 1;
    const day = dateObj.getDate();
    const formattedDate = `${month}月${day}日`;
    
    this.setData({
      whenDate: date,
      whenText: formattedDate
    });
    // 保存到服务器
    this.saveAllProfileData();
  },
  
  // "几号有空"月/号选择器改变
  onAvailableDateChange(e) {
    const indices = e.detail.value; // [月份索引, 日期索引]
    const monthIndex = indices[0]; // 0-11
    const dayIndex = indices[1]; // 0-30
    
    const month = monthIndex + 1; // 1-12
    const day = dayIndex + 1; // 1-31
    
    // 格式化显示文本：2月15号 有空
    const formattedText = `${month}月${day}号 有空`;
    // 存储值：2/15
    const storedValue = `${month}/${day}`;
    
    this.setData({
      availableDateIndex: indices,
      availableTime: storedValue,
      availableTimeText: formattedText
    });
    
    // 保存到服务器
    this.saveAllProfileData();
  },
  
  // 解析存储值为索引（格式：M/d，例如 "2/15" -> [1, 14]）
  parseAvailableDateIndex(storedValue) {
    if (!storedValue || !storedValue.includes('/')) {
      return [0, 0]; // 默认值
    }
    
    const parts = storedValue.split('/');
    if (parts.length !== 2) {
      return [0, 0];
    }
    
    const month = parseInt(parts[0], 10);
    const day = parseInt(parts[1], 10);
    
    // 验证范围
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return [0, 0];
    }
    
    // 转换为索引（月份：1-12 -> 0-11，日期：1-31 -> 0-30）
    return [month - 1, day - 1];
  },
  
  // 点击"回哪里"按钮
  onWhereBtnTap() {
    // 先显示遮罩，然后显示卡片（通过延迟实现动画效果）
    this.setData({
      showWhereInputCard: true,
      whereInputValue: ''
    });
    // 延迟一帧确保遮罩先显示，然后触发卡片动画
    setTimeout(() => {
      this.setData({
        whereInputCardShow: true
      });
      // 卡片显示后，延迟聚焦输入框
      setTimeout(() => {
        this.setData({
          whereInputFocus: true
        });
      }, 350); // 等待动画完成后再聚焦
    }, 50);
  },
  // 关闭"回哪里"输入卡片
  closeWhereInputCard() {
    // 先隐藏卡片，再隐藏遮罩
    this.setData({
      whereInputCardShow: false,
      whereInputFocus: false
    });
    setTimeout(() => {
      this.setData({
        showWhereInputCard: false
      });
    }, 300);
  },
  // "回哪里"输入内容改变
  onWhereInputChange(e) {
    this.setData({
      whereInputValue: e.detail.value
    });
  },
  // 点击键盘完成按钮（回哪里）
  onWhereInputConfirm(e) {
    // 收起键盘
    wx.hideKeyboard();
    // 执行确认逻辑
    this.confirmWhereInput();
  },
  // 确认"回哪里"输入
  confirmWhereInput() {
    const value = this.data.whereInputValue.trim();
    if (value) {
      this.setData({
        whereText: value,
        whereInputCardShow: false,
        whereInputFocus: false
      });
      // 延迟关闭遮罩，让动画完成
      setTimeout(() => {
        this.setData({
          showWhereInputCard: false
        });
      }, 300);
      // 保存到服务器
      this.saveAllProfileData();
    } else {
      wx.showToast({
        title: '请输入内容',
        icon: 'none'
      });
    }
  },
  // 点击"关于春节说点啥"文本
  onInfoTextTap() {
    // 先显示遮罩，然后显示卡片（通过延迟实现动画效果）
    this.setData({
      showInfoTextInputCard: true,
      infoTextInputValue: this.data.infoText === '关于春节说点啥～' ? '' : this.data.infoText
    });
    // 延迟一帧确保遮罩先显示，然后触发卡片动画
    setTimeout(() => {
      this.setData({
        infoTextInputCardShow: true
      });
      // 卡片显示后，延迟聚焦输入框
      setTimeout(() => {
        this.setData({
          infoTextInputFocus: true
        });
      }, 350); // 等待动画完成后再聚焦
    }, 50);
  },
  // 关闭"关于春节说点啥"输入卡片
  closeInfoTextInputCard() {
    // 先隐藏卡片，再隐藏遮罩
    this.setData({
      infoTextInputCardShow: false,
      infoTextInputFocus: false
    });
    setTimeout(() => {
      this.setData({
        showInfoTextInputCard: false
      });
    }, 300);
  },
  // "关于春节说点啥"输入内容改变
  onInfoTextInputChange(e) {
    this.setData({
      infoTextInputValue: e.detail.value
    });
  },
  // 点击键盘完成按钮（关于春节说点啥）
  onInfoTextInputConfirm(e) {
    // 收起键盘
    wx.hideKeyboard();
    // 执行确认逻辑
    this.confirmInfoTextInput();
  },
  // 确认"关于春节说点啥"输入
  confirmInfoTextInput() {
    const value = this.data.infoTextInputValue.trim();
    if (value) {
      this.setData({
        infoText: value,
        infoTextInputCardShow: false,
        infoTextInputFocus: false
      });
      // 延迟关闭遮罩，让动画完成
      setTimeout(() => {
        this.setData({
          showInfoTextInputCard: false
        });
      }, 300);
      // 保存到服务器
      this.saveAllProfileData();
    } else {
      wx.showToast({
        title: '请输入内容',
        icon: 'none'
      });
    }
  },
  // 点击"过节必须干件事"按钮
  onMustDoBtnTap() {
    // 先显示遮罩，然后显示卡片（通过延迟实现动画效果）
    this.setData({
      showInputCard: true,
      inputValue: '',
      inputFocus: false
    });
    // 延迟一帧确保遮罩先显示，然后触发卡片动画
    setTimeout(() => {
      this.setData({
        inputCardShow: true
      });
      // 卡片显示后，延迟聚焦输入框
      setTimeout(() => {
        this.setData({
          inputFocus: true
        });
      }, 350); // 等待动画完成后再聚焦
    }, 50);
  },
  // 关闭输入卡片
  closeInputCard() {
    // 先隐藏卡片，再隐藏遮罩
    this.setData({
      inputCardShow: false,
      inputFocus: false
    });
    setTimeout(() => {
      this.setData({
        showInputCard: false
      });
    }, 300);
  },
  // 输入内容改变
  onInputChange(e) {
    this.setData({
      inputValue: e.detail.value
    });
  },
  // 点击键盘完成按钮
  onInputConfirm(e) {
    // 收起键盘
    wx.hideKeyboard();
    // 执行确认逻辑
    this.confirmInput();
  },
  // 确认输入
  confirmInput() {
    const value = this.data.inputValue.trim();
    if (value) {
      this.setData({
        mustDoText: value,
        inputCardShow: false
      });
      // 延迟关闭遮罩，让动画完成
      setTimeout(() => {
        this.setData({
          showInputCard: false
        });
      }, 300);
      // 保存到服务器
      this.saveAllProfileData();
    } else {
      wx.showToast({
        title: '请输入内容',
        icon: 'none'
      });
    }
  },
  // 保存所有资料数据到服务器
  saveAllProfileData() {
    const profileData = {
      // 基本信息
      nickname: this.data.nickname,
      avatarUrl: this.data.avatarUrl,
      // 卡片内容
      infoText: this.data.infoText,
      // 按钮选择
      whoText: this.data.whoText,
      howText: this.data.howText,
      whenDate: this.data.whenDate,
      whenText: this.data.whenText,
      availableTime: this.data.availableTime,
      availableTimeText: this.data.availableTimeText,
      whereText: this.data.whereText,
      mustDoText: this.data.mustDoText
    };
    
    // 静默保存，不显示加载提示
    this.updateProfile(profileData, false);
  },
  // 分享按钮点击
  onShareTap() {
    // 分享功能由微信自动处理，这里可以添加一些日志
    console.log('用户点击分享按钮');
  },
  // 分享给朋友
  onShareAppMessage() {
    const nickname = this.data.nickname || '昵称';
    return {
      title: `哈喽～ ${nickname} 喊你制定春节计划🧨🧨🧨`,
      path: '/pages/index/index',
      imageUrl: 'https://wemedev.com/data/festival/images/bg_share.png'
    };
  },
  // 分享到朋友圈
  onShareTimeline() {
    const nickname = this.data.nickname || '昵称';
    return {
      title: `哈喽～ ${nickname} 喊你制定春节计划🧨🧨🧨`,
      imageUrl: 'https://wemedev.com/data/festival/images/bg_share.png'
    };
  },
  // 跳转到卡片列表页面
  navigateToCards() {
    wx.navigateTo({
      url: '/pages/cards/index'
    });
  },

  navigateToNewYear() {
    wx.navigateTo({
      url: '/pages/newyear/index'
    });
  },
  
  // 加载远程配置
  loadRemoteConfig() {
    config.getConfig().then((remoteConfig) => {
      console.log('加载远程配置成功', remoteConfig);
      
      // 更新按钮显示状态和广告点击配置
      this.setData({
        showNewYearButton: remoteConfig.showNewYearButton !== false, // 默认为 true，只有明确设置为 false 时才隐藏
        // 广告点击配置
        adClickType: remoteConfig.adClickType || 'none',
        adClickPage: remoteConfig.adClickPage || null,
        adClickUrl: remoteConfig.adClickUrl || null,
        adClickMiniprogram: remoteConfig.adClickMiniprogram || null
      });
      
      // 处理广告图
      if (remoteConfig.showAdImage && remoteConfig.adImageUrl) {
        this.loadAdImage(remoteConfig.adImageUrl);
      }
    }).catch((err) => {
      console.error('加载远程配置失败，使用默认配置', err);
      // 失败时使用默认配置（显示按钮）
      this.setData({
        showNewYearButton: true,
        adClickType: 'none',
        adClickPage: null,
        adClickUrl: null,
        adClickMiniprogram: null
      });
    });
  },
  
  // 加载广告图
  loadAdImage(imageUrl) {
    if (!imageUrl) {
      console.warn('[广告图] URL为空');
      return;
    }

    console.log('[广告图] 开始加载', imageUrl);

    // 先检查本地缓存
    imageCache.getCachedImagePath(imageUrl).then(cachedPath => {
      console.log('[广告图] 缓存检查结果:', cachedPath);
      if (cachedPath) {
        // 有缓存，直接显示
        console.log('[广告图] 使用缓存的广告图', cachedPath);
        this.showAdImage(cachedPath);
      } else {
        // 无缓存，后台静默下载，不显示
        console.log('[广告图] 无缓存，后台静默下载，不显示', imageUrl);
        
        // 后台下载并缓存（不显示）
        imageCache.downloadAndCacheImage(imageUrl).then(localPath => {
          console.log('[广告图] 下载并缓存成功，下次启动时会显示', localPath);
          // 不显示，只在后台下载
        }).catch(err => {
          console.error('[广告图] 下载失败', err);
        });
      }
    }).catch(err => {
      console.error('[广告图] 检查缓存失败', err);
      // 出错时不显示，尝试后台下载
      imageCache.downloadAndCacheImage(imageUrl).then(localPath => {
        console.log('[广告图] 下载并缓存成功（重试），下次启动时会显示', localPath);
        // 不显示，只在后台下载
      }).catch(downloadErr => {
        console.error('[广告图] 下载失败（重试）', downloadErr);
      });
    });
  },
  
  // 显示广告图
  showAdImage(imagePath) {
    console.log('[广告图] 准备显示', imagePath);
    if (!imagePath) {
      console.warn('[广告图] 路径为空');
      return;
    }
    
    // 验证本地文件路径是否存在（如果是本地路径）
    if (imagePath.startsWith('http://store/') || imagePath.startsWith('wxfile://') || !imagePath.startsWith('http')) {
      const fs = wx.getFileSystemManager();
      try {
        // 尝试访问文件，验证路径是否有效
        fs.accessSync(imagePath);
        console.log('[广告图] 本地文件路径有效', imagePath);
      } catch (e) {
        console.warn('[广告图] 本地文件路径无效，尝试使用网络URL', imagePath, e);
        // 如果本地路径无效，尝试从配置中获取原始网络URL
        config.getConfig().then(remoteConfig => {
          if (remoteConfig && remoteConfig.adImageUrl) {
            console.log('[广告图] 使用网络URL作为备用', remoteConfig.adImageUrl);
            imagePath = remoteConfig.adImageUrl;
          }
          this.doShowAdImage(imagePath);
        }).catch(() => {
          // 如果获取配置失败，直接使用原路径尝试
          this.doShowAdImage(imagePath);
        });
        return;
      }
    }
    
    this.doShowAdImage(imagePath);
  },
  
  // 执行显示广告图
  doShowAdImage(imagePath) {
    console.log('[广告图] 执行显示，设置数据', {
      adImagePath: imagePath,
      showAdImage: true,
      adImageAnimating: false
    });
    
    // 先设置图片路径和显示状态，同时立即设置动画状态
    this.setData({
      adImagePath: imagePath,
      showAdImage: true,
      adImageAnimating: false // 先设置为false
    }, () => {
      console.log('[广告图] setData回调执行，当前状态:', {
        adImagePath: this.data.adImagePath,
        showAdImage: this.data.showAdImage,
        adImageAnimating: this.data.adImageAnimating
      });
      
      // DOM渲染完成后立即触发动画
      setTimeout(() => {
        this.setData({
          adImageAnimating: true
        });
        console.log('[广告图] 动画已触发，最终状态:', {
          adImagePath: this.data.adImagePath,
          showAdImage: this.data.showAdImage,
          adImageAnimating: this.data.adImageAnimating
        });
        
        // 验证DOM元素是否存在
        setTimeout(() => {
          const query = wx.createSelectorQuery().in(this);
          query.select('.ad-image-mask').boundingClientRect((rect) => {
            console.log('[广告图] DOM元素检查:', {
              exists: !!rect,
              width: rect ? rect.width : 0,
              height: rect ? rect.height : 0,
              top: rect ? rect.top : 0,
              left: rect ? rect.left : 0
            });
          }).exec();
        }, 100);
      }, 50); // 减少延迟，快速显示
    });
  },
  
  // 关闭广告图
  closeAdImage() {
    this.setData({
      adImageAnimating: false
    });
    
    // 动画结束后隐藏
    setTimeout(() => {
      this.setData({
        showAdImage: false,
        adImagePath: '',
        adImageWidth: null, // 清除尺寸
        adImageHeight: null // 清除尺寸
      });
    }, 300);
  },
  
  // 广告图加载成功
  onAdImageLoad(e) {
    const detail = e.detail || {};
    const imageWidth = detail.width || 0;
    const imageHeight = detail.height || 0;
    
    console.log('[广告图] 图片加载成功', {
      detail: detail,
      width: imageWidth,
      height: imageHeight,
      currentState: {
        adImagePath: this.data.adImagePath,
        showAdImage: this.data.showAdImage,
        adImageAnimating: this.data.adImageAnimating
      }
    });
    
    // 自动适配图片尺寸
    if (imageWidth > 0 && imageHeight > 0) {
      this.adaptImageSize(imageWidth, imageHeight);
    }
  },
  
  // 自动适配图片尺寸
  adaptImageSize(imageWidth, imageHeight) {
    const systemInfo = wx.getSystemInfoSync();
    const screenWidth = systemInfo.windowWidth; // px
    const screenHeight = systemInfo.windowHeight; // px
    
    // 计算可用显示区域（留出边距）
    const maxDisplayWidth = screenWidth * 0.9; // 90% 屏幕宽度
    const maxDisplayHeight = screenHeight * 0.8; // 80% 屏幕高度
    
    // 计算缩放比例，保持宽高比
    const scaleX = maxDisplayWidth / imageWidth;
    const scaleY = maxDisplayHeight / imageHeight;
    const scale = Math.min(scaleX, scaleY, 1); // 不放大，只缩小
    
    // 计算适配后的尺寸（转换为 rpx：1px = 2rpx）
    const adaptedWidth = Math.round(imageWidth * scale * 2);
    const adaptedHeight = Math.round(imageHeight * scale * 2);
    
    console.log('[广告图] 自动适配尺寸', {
      原始尺寸: `${imageWidth}x${imageHeight}`,
      屏幕尺寸: `${screenWidth}x${screenHeight}`,
      最大显示区域: `${maxDisplayWidth}x${maxDisplayHeight}`,
      缩放比例: scale,
      适配后尺寸: `${adaptedWidth}rpx x ${adaptedHeight}rpx`
    });
    
    // 动态设置图片尺寸
    this.setData({
      adImageWidth: adaptedWidth,
      adImageHeight: adaptedHeight
    });
  },
  
  // 广告图加载失败
  onAdImageError(e) {
    console.error('[广告图] 图片加载失败', {
      error: e,
      path: this.data.adImagePath,
      currentState: {
        showAdImage: this.data.showAdImage,
        adImageAnimating: this.data.adImageAnimating
      }
    });
    
    // 如果本地路径加载失败，尝试使用网络URL
    const currentPath = this.data.adImagePath;
    if (currentPath && (currentPath.startsWith('http://store/') || currentPath.startsWith('wxfile://') || !currentPath.startsWith('http'))) {
      // 如果是本地路径但加载失败，使用网络URL作为备用
      console.log('[广告图] 本地图片加载失败，尝试使用网络URL');
      config.getConfig().then(remoteConfig => {
        if (remoteConfig && remoteConfig.adImageUrl) {
          console.log('[广告图] 切换到网络URL', remoteConfig.adImageUrl);
          this.setData({
            adImagePath: remoteConfig.adImageUrl
          });
        }
      }).catch(err => {
        console.error('[广告图] 获取网络URL失败', err);
      });
    }
  },
  
  // 广告图点击事件
  onAdImageClick(e) {
    const { adClickType, adClickPage, adClickUrl, adClickMiniprogram } = this.data;
    
    console.log('[广告图] 点击事件', {
      adClickType,
      adClickPage,
      adClickUrl,
      adClickMiniprogram
    });
    
    // 先关闭广告图
    this.closeAdImage();
    
    // 根据点击类型执行不同操作
    switch (adClickType) {
      case 'none':
        // 无跳转，只关闭广告图
        console.log('[广告图] 点击类型：无跳转');
        break;
        
      case 'page':
        // 跳转到小程序页面
        if (adClickPage) {
          console.log('[广告图] 跳转到小程序页面:', adClickPage);
          setTimeout(() => {
            wx.navigateTo({
              url: adClickPage.startsWith('/') ? adClickPage : `/${adClickPage}`,
              fail: (err) => {
                console.error('[广告图] 页面跳转失败', err);
                // 尝试使用 reLaunch
                wx.reLaunch({
                  url: adClickPage.startsWith('/') ? adClickPage : `/${adClickPage}`,
                  fail: (reLaunchErr) => {
                    console.error('[广告图] reLaunch 跳转失败', reLaunchErr);
                  }
                });
              }
            });
          }, 300); // 等待关闭动画完成
        } else {
          console.warn('[广告图] 页面路径为空');
        }
        break;
        
      case 'url':
        // 跳转到网页
        if (adClickUrl) {
          console.log('[广告图] 跳转到网页:', adClickUrl);
          setTimeout(() => {
            // 检查URL格式
            let targetUrl = adClickUrl;
            if (!targetUrl.startsWith('http://') && !targetUrl.startsWith('https://')) {
              targetUrl = 'https://' + targetUrl;
            }
            
            wx.navigateTo({
              url: `/pages/webview/index?url=${encodeURIComponent(targetUrl)}`,
              fail: (err) => {
                console.error('[广告图] 网页跳转失败', err);
                // 跳转失败时，提供备用方案
                wx.showModal({
                  title: '提示',
                  content: '网页跳转失败，是否复制链接到剪贴板？',
                  confirmText: '复制',
                  cancelText: '取消',
                  success: (res) => {
                    if (res.confirm) {
                      wx.setClipboardData({
                        data: targetUrl,
                        success: () => {
                          wx.showToast({
                            title: '链接已复制',
                            icon: 'success'
                          });
                        }
                      });
                    }
                  }
                });
              }
            });
          }, 300);
        } else {
          console.warn('[广告图] 网页URL为空');
        }
        break;
        
      case 'miniprogram':
        // 跳转到其他小程序
        if (adClickMiniprogram) {
          try {
            let miniprogramConfig;
            // 如果是字符串，尝试解析为 JSON
            if (typeof adClickMiniprogram === 'string') {
              try {
                // 先尝试解析为 JSON
                miniprogramConfig = JSON.parse(adClickMiniprogram);
              } catch (parseError) {
                // 如果解析失败，说明是简单的 appId 字符串
                console.log('[广告图] 检测到简单 appId 格式:', adClickMiniprogram);
                miniprogramConfig = {
                  appId: adClickMiniprogram,
                  path: '',
                  extraData: {}
                };
              }
            } else {
              miniprogramConfig = adClickMiniprogram;
            }
            
            const { appId, path = '', extraData = {} } = miniprogramConfig;
            
            if (appId) {
              console.log('[广告图] 跳转到其他小程序:', { appId, path, extraData });
              setTimeout(() => {
                wx.navigateToMiniProgram({
                  appId: appId,
                  path: path || '',
                  extraData: extraData || {},
                  envVersion: 'release', // release, trial, develop
                  success: (res) => {
                    console.log('[广告图] 跳转小程序成功', res);
                  },
                  fail: (err) => {
                    console.error('[广告图] 跳转小程序失败', err);
                    wx.showToast({
                      title: '跳转失败',
                      icon: 'none'
                    });
                  }
                });
              }, 300);
            } else {
              console.warn('[广告图] 小程序 appId 为空');
            }
          } catch (e) {
            console.error('[广告图] 解析小程序配置失败', e, adClickMiniprogram);
            wx.showToast({
              title: '配置错误',
              icon: 'none'
            });
          }
        } else {
          console.warn('[广告图] 小程序配置为空');
        }
        break;
        
      default:
        console.warn('[广告图] 未知的点击类型:', adClickType);
        break;
    }
  },
  
  // 阻止事件冒泡
  stopPropagation() {
    // 空函数，用于阻止事件冒泡
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
        // 字体加载失败不影响使用，会使用后备字体
      }
    });
  },
  
  // 点击"激活解锁码"按钮
  onUnlockCodeTap() {
    // 如果是VIP，复制解锁码
    if (this.data.isVip) {
      const token = auth.getToken();
      if (!token) {
        wx.showToast({
          title: '请先登录',
          icon: 'none'
        });
        return;
      }
      
      // 获取用户解锁码
      auth.getUserUnlockCode()
        .then((unlockCode) => {
          // 复制解锁码到剪贴板
          wx.setClipboardData({
            data: unlockCode,
            success: () => {
              wx.showToast({
                title: '已复制解锁码',
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
        })
        .catch((err) => {
          console.error('获取解锁码失败', err);
          wx.showToast({
            title: '获取解锁码失败',
            icon: 'none'
          });
        });
      return;
    }
    
    // 非VIP，显示激活弹窗
    // 先显示遮罩，然后显示卡片（通过延迟实现动画效果）
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
      // 卡片显示后，延迟聚焦输入框
      setTimeout(() => {
        this.setData({
          unlockCodeFocus: true
        });
      }, 350); // 等待动画完成后再聚焦
    }, 50);
  },
  
  // 关闭"激活解锁码"输入卡片
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
        
        // 重新加载用户资料以同步VIP状态
        setTimeout(() => {
          this.loadUserProfile();
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
  
  // 拜年图片加载成功
  onNewYearImageLoad(e) {
    console.log('[拜年图片] 图片加载成功');
  },
  
  // 长按倒计时卡片 - 调试方法：切换到拜年图片模式
  onCardLongPress() {
    console.log('[调试] 长按倒计时卡片，切换到拜年图片模式');
    this.setData({
      isCountdownEnded: true,
      hasManuallySwitched: true // 标记为手动切换
    });
    wx.showToast({
      title: '已切换到拜年图片模式',
      icon: 'none',
      duration: 2000
    });
  },
  
  // 测试倒计时归零 - 模拟自动切换到拜年图片（用于测试自动切换功能）
  // 在控制台调用：getCurrentPages()[0].testCountdownEnd()
  testCountdownEnd() {
    console.log('[测试] 模拟倒计时归零，测试自动切换到拜年图片');
    // 重置手动切换标记，模拟自动切换
    this.setData({
      hasManuallySwitched: false,
      isCountdownEnded: false // 先设为false，让update()函数检测到变化
    });
    // 触发update()函数，模拟倒计时归零
    this.update();
    wx.showToast({
      title: '已模拟倒计时归零',
      icon: 'none',
      duration: 2000
    });
  },
  
  // 拜年图片点击事件
  onNewYearImageTap() {
    // 点击图片跳转到拜年页面
    console.log('[拜年图片] 点击图片，跳转到拜年页面');
    wx.navigateTo({
      url: '/pages/newyear/index'
    });
  },
  
  // 长按拜年图片 - 调试方法：返回倒计时状态
  onNewYearImageLongPress(e) {
    // 防止重复触发
    if (this._longPressHandling) {
      return;
    }
    this._longPressHandling = true;
    
    console.log('[调试] 长按拜年图片，返回倒计时状态', e);
    
    // 立即设置状态，防止 update() 函数再次切换
    this.setData({
      isCountdownEnded: false,
      hasManuallySwitched: true // 标记为手动切换
    });
    
    wx.showToast({
      title: '已返回倒计时状态',
      icon: 'none',
      duration: 2000
    });
    
    // 500ms 后重置标志，允许下次长按
    setTimeout(() => {
      this._longPressHandling = false;
    }, 500);
  },
  
  // 拜年图片加载错误处理
  onNewYearImageError(e) {
    console.error('[拜年图片] 图片加载失败', e);
    // 图片加载失败时，可以显示默认文本或保持倒计时显示
    // 这里可以选择回退到倒计时显示，或者显示错误提示
    wx.showToast({
      title: '图片加载失败',
      icon: 'none',
      duration: 2000
    });
  },
  
  // 点击点赞数 - 显示点赞列表
  onLikeCountTap() {
    const openid = auth.getOpenId();
    if (!openid) {
      wx.showToast({
        title: '请先登录',
        icon: 'none'
      });
      return;
    }
    
    // 如果点赞数为0，不显示列表
    if (this.data.likeCount === 0) {
      wx.showToast({
        title: '还没有人点赞',
        icon: 'none'
      });
      return;
    }
    
    // 显示点赞列表
    this.loadLikesList(openid);
  },
  
  // 加载点赞列表
  loadLikesList(openid) {
    if (this.data.likesListLoading) {
      return; // 正在加载中，避免重复请求
    }
    
    this.setData({
      likesListLoading: true,
      showLikesList: true
    });
    
    wx.request({
      url: `${API_BASE_URL}/profiles/${openid}/likes`,
      method: 'GET',
      data: {
        limit: 100, // 最多显示100条
        skip: 0
      },
      success: (res) => {
        this.setData({
          likesListLoading: false
        });
        
        if (res.statusCode === 200 && res.data) {
          const items = res.data.items || [];
          // 格式化时间
          const formattedItems = items.map(item => {
            let timeStr = '';
            if (item.createdAt) {
              const date = new Date(item.createdAt);
              const now = new Date();
              const diff = now - date;
              const minutes = Math.floor(diff / 60000);
              const hours = Math.floor(diff / 3600000);
              const days = Math.floor(diff / 86400000);
              
              if (minutes < 1) {
                timeStr = '刚刚';
              } else if (minutes < 60) {
                timeStr = `${minutes}分钟前`;
              } else if (hours < 24) {
                timeStr = `${hours}小时前`;
              } else if (days < 7) {
                timeStr = `${days}天前`;
              } else {
                timeStr = `${date.getMonth() + 1}月${date.getDate()}日`;
              }
            }
            return {
              ...item,
              createdAt: timeStr
            };
          });
          
          this.setData({
            likesList: formattedItems
          });
          console.log('[点赞列表] 加载成功', formattedItems);
        } else {
          console.error('[点赞列表] 加载失败', res);
          wx.showToast({
            title: '加载失败',
            icon: 'none'
          });
          this.setData({
            showLikesList: false
          });
        }
      },
      fail: (err) => {
        console.error('[点赞列表] 请求失败', err);
        this.setData({
          likesListLoading: false,
          showLikesList: false
        });
        wx.showToast({
          title: '网络错误',
          icon: 'none'
        });
      }
    });
  },
  
  // 关闭点赞列表
  closeLikesList() {
    this.setData({
      showLikesList: false,
      likesList: []
    });
  }
})
