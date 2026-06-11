import router from '@ohos.router';
import { BannerItem, PilotItem, OrderItem, PilotContact, fetchBanners, fetchNearbyPilots, fetchPublicOrders, fetchPilotContact, reportVisit, registerPushToken, fetchStandby, StandbyItem, fetchConfig, claimRewardSlot, RewardSlotClaimResult, joinStandby, leaveStandby, fetchRewardSlotStatus, CarouselItem, fetchProfile, ConfigResult, reportStandbyView } from '../service/ApiService';
import display from '@ohos.display';
import AuthService, { HuaweiUserInfo } from '../service/AuthService';
import LocationService from '../service/LocationService';
import { pushService } from '@kit.PushKit';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { advertising, identifier } from '@kit.AdsKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import type { Context } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import promptAction from '@ohos.promptAction';
import call from '@ohos.telephony.call';
import pasteboard from '@ohos.pasteboard';
import curves from '@ohos.curves';
import { imagePreview } from '../components/imagepreview/ImagePreview';
import window from '@ohos.window';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics, matrix4 } from '@kit.ArkUI';
import { PilotCard, PilotCardData } from '../components/PilotCard';
import http from '@ohos.net.http';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

// 默认头像
const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';

// 白色染色矩阵（用于深色模式下图标染色）
const WHITE_FILL_MATRIX: number[] = [
  0, 0, 0, 0, 1,
  0, 0, 0, 0, 1,
  0, 0, 0, 0, 1,
  0, 0, 0, 1, 0
];

// 防抖标记：确保每次启动只上报一次访问
let visitReported = false;

interface FeatureCardParam {
  title: string;
  subtitle: string;
  iconUrl: string | Resource;
  onClick: () => void;
}

interface SystemBarStyleInterface {
  statusBarContentColor?: string;
}

// 激励广告状态订阅处理器
const KEY_REWARD_DATA = 'reward_ad_data';
const KEY_REWARD_STATUS = 'reward_ad_status';

class RewardAdStatusHandler {
  private subscriber: commonEventManager.CommonEventSubscriber | null = null;
  onRewardGranted: (() => void) | null = null;

  // 订阅激励广告状态变化
  registerPPSReceiver(onReward: () => void): void {
    this.onRewardGranted = onReward;
    if (this.subscriber) {
      this.unRegisterPPSReceiver();
    }

    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['com.huawei.hms.pps.action.PPS_REWARD_STATUS_CHANGED'],
      publisherBundleName: 'com.huawei.hms.adsservice'
    };

    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, commonEventSubscriber:
      commonEventManager.CommonEventSubscriber) => {
      if (err) {
        hilog.error(0x0000, 'RewardAd', `Failed to create subscriber. Code is ${err.code}, message is ${err.message}`);
        return;
      }
      hilog.info(0x0000, 'RewardAd', 'Succeeded in creating subscriber');
      this.subscriber = commonEventSubscriber;

      commonEventManager.subscribe(this.subscriber, (err: BusinessError, commonEventSubscriber:
        commonEventManager.CommonEventData) => {
        if (err) {
          hilog.error(0x0000, 'RewardAd', `Failed to subscribe. Code is ${err.code}, message is ${err.message}`);
        } else {
          const status: string = commonEventSubscriber?.parameters?.[KEY_REWARD_STATUS];
          switch (status) {
            case 'onAdClose':
              hilog.info(0x0000, 'RewardAd', 'Status is onAdClose');
              this.unRegisterPPSReceiver();
              break;
            case 'onAdReward':
              hilog.info(0x0000, 'RewardAd', 'Status is onAdReward - 激励发放');
              if (this.onRewardGranted) {
                this.onRewardGranted();
              }
              break;
            case 'onVideoPlayBegin':
              hilog.info(0x0000, 'RewardAd', 'Status is onVideoPlayBegin');
              break;
            case 'onVideoPlayEnd':
              hilog.info(0x0000, 'RewardAd', 'Status is onVideoPlayEnd');
              break;
            default:
              break;
          }
        }
      });
    });
  }

  // 取消订阅
  unRegisterPPSReceiver(): void {
    if (this.subscriber) {
      commonEventManager.unsubscribe(this.subscriber, (err: BusinessError) => {
        if (err) {
          hilog.error(0x0000, 'RewardAd', `Failed to unsubscribe. Code is ${err.code}, message is ${err.message}`);
        } else {
          hilog.info(0x0000, 'RewardAd', 'Succeeded in unsubscribing');
          this.subscriber = null;
        }
      });
    }
  }
}

// 获取 OAID
async function requestOAID(context: Context): Promise<string | undefined> {
  let isPermissionGranted: boolean = false;
  try {
    const atManager = abilityAccessCtrl.createAtManager();
    const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.APP_TRACKING_CONSENT']);
    isPermissionGranted = result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  } catch (err) {
    hilog.error(0x0000, 'RewardAd', `Failed to request permission. Code is ${(err as BusinessError).code}, message is ${(err as BusinessError).message}`);
  }

  if (isPermissionGranted) {
    hilog.info(0x0000, 'RewardAd', 'Succeeded in requesting permission');
    try {
      const oaid = await identifier.getOAID();
      hilog.info(0x0000, 'RewardAd', 'Succeeded in getting OAID');
      return oaid;
    } catch (err) {
      hilog.error(0x0000, 'RewardAd', `Failed to get OAID. Code is ${(err as BusinessError).code}, message is ${(err as BusinessError).message}`);
    }
  } else {
    hilog.error(0x0000, 'RewardAd', 'Failed to request permission. User rejected');
  }
  return undefined;
}

/**
 * 首页 - 轮播图 + 附近飞手 + 最新任务
 */

@CustomDialog
struct StandbyPilotCardDialog {
  controller: CustomDialogController;
  user: PilotCardData = {
    openid: '',
    nickname: '',
    avatar: '',
    city: '',
    userRole: '',
    roleLabel: '',
    licenseType: '',
    licenseStatus: '',
    pilotCode: '',
    company: '',
    position: '',
    droneModel: '',
    businessScopeText: '',
    recentActiveText: '',
    likeCount: 0,
    likedByMe: false,
    phone: '',
    wechatId: '',
    douyinId: '',
    distanceText: '',
    isNew: false,
    workMu: null,
    workKg: null,
    droneImages: [],
    channelsId: '',
    institutionId: '',
    licenseUrl: '',
  };
  onWechatClick: () => void = () => {};
  onCallClick: () => void = () => {};
  onLikeChanged: (likeCount: number, likedByMe: boolean) => void = () => {};

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.05)')
        .onClick(() => { this.controller?.close(); })

      Column() {
        PilotCard({
          user: this.user,
          showDistance: false,
          showRecentActive: false,
          showActions: true,
          onWechatClick: () => {
            console.info('【StandbyPilotCardDialog onWechatClick】被调用');
            this.onWechatClick();
          },
          onCallClick: () => { this.onCallClick(); },
          onLikeChanged: (likeCount: number, likedByMe: boolean) => { this.onLikeChanged(likeCount, likedByMe); }
        })
      }
      .width('92%')
    }
    .width('100%')
    .height('100%')
  }
}

@Entry
@Component
struct Index {
  // 颜色模式监听（跟随系统深浅色）
  @StorageLink('colorMode') @Watch('onColorModeChange') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  // App前后台状态监听（用于刷新奖励位数据）
  @StorageLink('appIsForeground') @Watch('onAppForegroundChange') appIsForeground: boolean = true;

  // 跑马灯渐变色（跟随深浅色模式）
  @State marqueeGradientStart: string = '#E7F8FC';
  @State marqueeGradientEnd: string = 'rgba(231,248,252,0)';

  // 滚动控制器
  scroller: Scroller = new Scroller();

  // 轮播图
  @State imageList: BannerItem[] = [];
  @State currentIndex: number = 0;
  @State bannerLoaded: boolean = false;
  @State bannerOpacity: number = 1;
  @State autoplay: boolean = true;

  // 跑马灯
  @State marqueeText: string = '';
  @State marqueeNeedsScroll: boolean = false;

  // 运营数据
  @State todayActiveUsers: number = 0;
  @State totalPilotCount: number = 0;
  @State totalEmployerCount: number = 0;
  @State totalContactCount: number = 0;

  // 奖励位光晕动画状态
  @State lightAOffsetX: number = 160;  // 左上
  @State lightAOffsetY: number = 60;
  @State lightAOpacity: number = 0.7;
  @State lightAScale: number = 1.0;
  @State lightBOffsetX: number = 180;  // 右上
  @State lightBOffsetY: number = 40;
  @State lightBOpacity: number = 0.7;
  @State lightBScale: number = 1.0;
  @State lightCOffsetX: number = 170;  // 右下
  @State lightCOffsetY: number = 100;
  @State lightCOpacity: number = 0.7;
  @State lightCScale: number = 1.0;

  // 奖励位状态
  @State rewardSlotClaimed: boolean = false;  // 当前用户是否已认领奖励位
  @State rewardSlotUser: PilotItem | null = null;  // 奖励位展示的用户名片
  @State isAdLoading: boolean = false;  // 广告加载中
  @State rewardTitle: string = '';  // 奖励位标题
  @State rewardSubtitle: string = '';  // 奖励位副标题
  @State rewardButtonText: string = '';  // 奖励位按钮文字

  // 平行四边形按钮Canvas上下文（暂时未使用）
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D();

  // 飞手列表
  @State pilots: PilotItem[] = [];
  @State pilotsLoading: boolean = false;
  @State skeletonShimmer: boolean = false;
  private pilotsLat: number = 39.9;
  private pilotsLng: number = 116.4;
  private skeletonTimer: number = -1;

  // 任务列表
  @State orders: OrderItem[] = [];
  @State ordersLoading: boolean = false;
  @State expandedOrderIds: string[] = [];
  @State ordersSkeletonShimmer: boolean = false;
  private ordersSkeletonTimer: number = -1;

  // Tab
  @State currentTab: string = 'pilots';

  // 今日有空
  @State standbyItems: StandbyItem[] = [];
  @State standbyIsJoined: boolean = false;
  @State standbyOpacity: number = 1;
  @State standbyLoading: boolean = false;
  @State expandedStandbyItem: StandbyItem | null = null;
  @State expandedPilotCardData: PilotCardData | null = null;
  @State showExpandedStandby: boolean = false;
  @State showCopySuccess: boolean = false;
  standbyDialogController: CustomDialogController | null = null;
  rewardSlotDialogController: CustomDialogController | null = null;
  @State screenWidth: number = 360;
  @State screenHeight: number = 780;
  @State navBarHeight: number = 0;

  // 缓存数据（用于离线优先）
  private bannerCache: BannerItem[] = [];
  private configCache: ConfigResult | null = null;
  private pilotsCache: PilotItem[] = [];
  private ordersCache: OrderItem[] = [];

  // 登录状态
  @State isLoggedIn: boolean = false;
  @State userInfo: HuaweiUserInfo | null = null;

  @State statusBarHeight: number = 0;
  private bannerLoadedOnce: boolean = false;  // 轮播图是否已首次加载
  private lastRewardSlotRefreshTime: number = 0;  // 上次奖励位刷新时间（防抖）
  private pageHideTime: number = 0;  // 页面隐藏时间

  aboutToAppear() {
    // 初始化渐变颜色
    this.updateMarqueeGradient();
    // 只在首次加载时刷新轮播图，返回页面时不重复刷新
    if (!this.bannerLoadedOnce) {
      this.bannerLoadedOnce = true;
      this.loadBanner();
    }
    this.loadConfig();
    // 先等待登录完成再上报访问（每次启动只上报一次）
    this.handleLogin().then(() => {
      if (!visitReported) {
        visitReported = true;
        const user = AuthService.getCurrentUser();
        reportVisit(user?.openId || '').catch((e: Error) => {
          console.info('【访问上报失败】', e.message);
        });
      }
      this.loadPilots();
      this.loadOrders();
      this.loadStandby();
      this.loadRewardSlotStatus();
    });

    // 如果已登录但本地资料为空，尝试从服务端获取并更新本地缓存
    const token = AppStorage.get<string>('authToken');
    const user = AuthService.getCurrentUser();
    if (token && user && user.openId && (!user.displayName || !user.avatar)) {
      console.info('【资料刷新】已登录但本地资料不完整，尝试从服务端获取');
      this.fetchAndUpdateUserProfile(user.openId, token);
    }

    // 获取状态栏高度并设置状态栏颜色（跟随深浅色模式）
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.statusBarHeight = px2vp(avoidArea.topRect.height);
        console.info('状态栏高度:', this.statusBarHeight, 'vp');
        // 状态栏透明 + 文字颜色跟随深浅色模式
        const isDarkMode = this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: isDarkMode ? '#FFFFFF' : '#14233a'
        });
      });
    } catch (e) {
      console.info('获取状态栏高度失败', JSON.stringify(e));
    }
  }

  // 手机号脱敏
  private maskPhone(phone: string): string {
    if (!phone || phone.length < 11) return phone;
    return phone.substring(0, 3) + '****' + phone.substring(7);
  }

  // 绘制平行四边形按钮（skewX斜切）
  private drawSkewButton(ctx: CanvasRenderingContext2D, text: string): void {
    const w = 130;
    const h = 36;
    const skewDeg = -10;
    const skewRad = skewDeg * Math.PI / 180;

    // 应用skewX(-10)变换
    const matrix = new Matrix2D();
    matrix.rotateY = skewDeg;  // rotateY是Vertical Tilt即skewX
    ctx.setTransform(matrix);

    // 绘制阴影矩形
    ctx.shadowColor = 'rgba(6, 182, 212, 0.4)';
    ctx.shadowBlur = 12;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 4;

    // 绿色渐变填充
    const gradient = ctx.createLinearGradient(0, 0, w, 0);
    gradient.addColorStop(0, '#b2e933');
    gradient.addColorStop(1, '#4ace39');
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.roundRect(0, 0, w, h, 4);
    ctx.fill();

    // 青色边框
    ctx.shadowColor = 'transparent';
    ctx.strokeStyle = 'rgba(103, 232, 249, 0.5)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.roundRect(0, 0, w, h, 4);
    ctx.stroke();
  }

  // 加载奖励位状态（检查用户是否已认领）
  async loadRewardSlotStatus(): Promise<void> {
    // 详细日志：打印调用堆栈
    const now = Date.now();
    hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】被调用: 时间=' + now + ', 距上次=' + (now - this.lastRewardSlotRefreshTime) + 'ms');
    try {
      const token = AppStorage.get<string>('authToken');
      hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】开始请求');
      const status = await fetchRewardSlotStatus();
      hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】返回: claimed=' + status?.claimed + ', profileCard=' + JSON.stringify(status?.profileCard));

      // 记录刷新前的状态，用于对比
      const prevClaimed = this.rewardSlotClaimed;
      const prevUserNickname = this.rewardSlotUser?.nickname || '无';

      if (status && status.profile) {
        // 有profile数据表示奖励位被占用（无论是谁），显示该用户名片
        const p = status.profile;
        const isCurrentUserOwner = status.claimed;
        hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】奖励位有profile: nickname=' + p.nickname + ', claimed=' + isCurrentUserOwner);
        this.rewardSlotUser = {
          openid: '',
          nickname: p.nickname || '匿名用户',
          avatar: p.avatarUrl || DEFAULT_AVATAR,
          city: p.city || '',
          roleLabel: p.userRole || '',
          licenseType: p.licenseType || '',
          licenseStatus: p.licenseType === '已审核' ? '审核通过' : p.licenseType || '',
          pilotCode: '',
          company: p.company || '',
          position: p.position || '',
          droneModel: p.droneModel || '',
          businessScope: '',
          businessScopeText: (p.businessScope || []).join('、'),
          recentActiveText: '刚刚活跃',
          likeCount: p.likeCount || 0,
          likedByMe: false,
          phone: p.phone || '',
          wechatId: p.wechatId || '',
          douyinId: p.douyinId || '',
          distanceText: '',
          isVipSlot: false,
          vipRadiusKm: 0,
          vipLabel: '',
          latitude: 0,
          longitude: 0,
          score: '',
          licenseUrl: p.licenseUrl || '',
          channelsId: p.channelsId || '',
          isNew: false,
          licenseStatusClass: '',
          institutionId: p.institutionId || '',
          workMu: null,
          workKg: null,
          droneImages: [],
        };
        this.rewardSlotClaimed = isCurrentUserOwner;
        hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】已设置: nickname=' + this.rewardSlotUser.nickname + ', claimed=' + this.rewardSlotClaimed);
      } else {
        // 无profile数据，奖励位空闲，显示默认状态
        hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】奖励位空闲，无profile');
        this.rewardSlotClaimed = false;
        this.rewardSlotUser = null;
        // 恢复默认标题/副标题（从缓存的config中读取）
        if (this.configCache) {
          this.rewardTitle = this.configCache.rewardTitle || '呼叫飞手';
          this.rewardSubtitle = this.configCache.rewardSubtitle || '打造职业飞手库';
          this.rewardButtonText = this.configCache.rewardButtonText || '观看解锁';
        }
      }
    } catch (e) {
      hilog.error(0x0000, 'RewardAd', '加载奖励位状态失败: ' + JSON.stringify(e));
      // 加载失败时也要重置为默认状态
      this.rewardSlotClaimed = false;
      this.rewardSlotUser = null;
      hilog.info(0x0000, 'RewardAd', '【loadRewardSlotStatus】加载失败，重置默认状态');
    }
  }

  // 更新跑马灯渐变色（跟随深浅色模式）
  private updateMarqueeGradient(): void {
    const isDarkMode = this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    this.marqueeGradientStart = isDarkMode ? '#121212' : '#E7F8FC';
    this.marqueeGradientEnd = isDarkMode ? 'rgba(18,18,18,0)' : 'rgba(231,248,252,0)';
  }

  // 颜色模式变化回调
  private onColorModeChange(): void {
    this.updateMarqueeGradient();
  }

  // App前台切换回调（后台切回前台时刷新奖励位数据）
  private async onAppForegroundChange(): Promise<void> {
    hilog.info(0x0000, 'RewardAd', '【onAppForegroundChange】appIsForeground=' + this.appIsForeground);
    if (this.appIsForeground) {
      const now = Date.now();
      hilog.info(0x0000, 'RewardAd', '【onAppForegroundChange】now=' + now + ', lastTime=' + this.lastRewardSlotRefreshTime + ', 距上次=' + (now - this.lastRewardSlotRefreshTime) + 'ms');
      if (now - this.lastRewardSlotRefreshTime > 2000) {
        this.lastRewardSlotRefreshTime = now;
        hilog.info(0x0000, 'RewardAd', '【onAppForegroundChange】开始刷新');
        await this.loadRewardSlotStatus();
      } else {
        hilog.info(0x0000, 'RewardAd', '【onAppForegroundChange】防抖跳过');
      }
    }
  }

  async checkLoginStatus() {
    this.isLoggedIn = AuthService.isLogin();
    this.userInfo = AuthService.getCurrentUser();
  }

  async handleLogin() {
    console.info('【登录】开始华为账号登录');
    const result = await AuthService.login();
    if (result.success && result.userInfo) {
      this.isLoggedIn = true;
      this.userInfo = result.userInfo;
      console.info('【登录】成功:', JSON.stringify(result.userInfo));

      // 换取业务token（需要后端配合）
      const tokenResult = await AuthService.exchangeToken(
        result.userInfo.openId,
        result.userInfo.unionId
      );
      if (tokenResult.token) {
        console.info('【登录】业务token:', tokenResult.token);
        // 获取用户资料并更新本地缓存
        this.fetchAndUpdateUserProfile(result.userInfo.openId, tokenResult.token);
        // 上报Push Token到服务端
        this.reportPushTokenAfterLogin(tokenResult.token);
      }
    } else {
      console.error('【登录】失败:', result.error);
    }
  }

  private async reportPushTokenAfterLogin(authToken: string): Promise<void> {
    try {
      const token = await pushService.getToken();
      console.info('【Push Token】获取成功:', token);
      const res = await registerPushToken(token, authToken);
      console.info('【Push Token】上报结果:', JSON.stringify(res));
    } catch (err) {
      const error = err as BusinessError;
      console.error('【Push Token】上报失败:', error.code, error.message);
    }
  }

  private async fetchAndUpdateUserProfile(openid: string, token: string): Promise<void> {
    try {
      const profile = await fetchProfile(openid, token);
      if (profile) {
        console.info('【用户资料】获取成功:', JSON.stringify(profile));
        const user = AuthService.getCurrentUser();
        if (user) {
          user.displayName = profile.nickname;
          user.avatar = profile.avatarUrl;
          console.info('【用户资料】已更新 displayName:', user.displayName, ' avatar:', user.avatar);
        }
      }
    } catch (err) {
      console.error('【用户资料】获取失败:', JSON.stringify(err));
    }
  }

  handleLogout() {
    AuthService.logout();
    this.isLoggedIn = false;
    this.userInfo = null;
    console.info('【登录】已退出');
  }

  async loadBanner(silent: boolean = false) {
    try {
      const config = await fetchConfig();
      const banners = await fetchBanners();

      // 记录刷新前的奖励位状态
      const prevRewardSlotClaimed = this.rewardSlotClaimed;
      const prevRewardSlotUserNickname = this.rewardSlotUser?.nickname || '无';

      // 静默刷新时：比对 config 是否变化
      if (silent && this.configCache) {
        const prevConfig = this.configCache;
        // 只比对关键字段：banner 数量和 topTitle
        const prevBannerCount = (prevConfig.carousel || []).length;
        const newBannerCount = (config.carousel || []).length;
        const prevTitle = prevConfig.defaultTopTitle || '';
        const newTitle = config.defaultTopTitle || '';

        if (prevBannerCount === newBannerCount && prevTitle === newTitle) {
          // banner数量和title无变化，跳过更新
          console.info('【轮播图】silent模式+banner数量title无变化，跳过更新');
          this.bannerLoaded = true;
          return;
        }
        console.info('【轮播图】silent模式+banner数量或title有变化，执行更新');
      }

      // 更新缓存
      this.configCache = config;

      // 解析配置更新UI - 先重置为默认状态
      this.rewardTitle = config.rewardTitle || '呼叫飞手';
      this.rewardSubtitle = config.rewardSubtitle || '打造职业飞手库';
      this.rewardButtonText = config.rewardButtonText || '观看解锁';
      this.marqueeText = config.defaultTopTitle || '呼叫飞手';
      this.marqueeNeedsScroll = this.marqueeText.length > 12;
      this.todayActiveUsers = config.todayActiveUsers ?? 0;
      this.totalPilotCount = config.totalPilotCount ?? 0;
      this.totalEmployerCount = config.totalEmployerCount ?? 0;
      this.totalContactCount = config.totalContactCount ?? 0;

      // 默认不显示奖励位用户名片
      let hasValidRewardSlot = false;

      // 解析carousel中的奖励位数据
      if (config.carousel && config.carousel.length > 0) {
        const rewardSlot = config.carousel.find((item: CarouselItem) => item.slot === 'homepage_carousel_top');
        if (rewardSlot) {
          if (rewardSlot.reward_meta) {
            this.rewardTitle = rewardSlot.reward_meta.title || this.rewardTitle;
            this.rewardSubtitle = rewardSlot.reward_meta.subtitle || this.rewardSubtitle;
            this.rewardButtonText = rewardSlot.reward_meta.cta_text || this.rewardButtonText;
          }
          // 只有当 rewardSlotUser 尚未被 loadRewardSlotStatus 设置时，才从carousel加载
          // 如果 loadRewardSlotStatus 已经设置了 rewardSlotUser（无论是认领还是被他人占用），保持不变
          if (rewardSlot.profile_card && !this.rewardSlotUser) {
            const card = rewardSlot.profile_card;
            this.rewardSlotUser = {
              openid: rewardSlot.publisher_openid || '',
              nickname: card.nickname || '匿名用户',
              avatar: card.avatar_url || DEFAULT_AVATAR,
              city: card.city || '',
              licenseType: card.license_type || '',
              licenseStatus: '已认证',
              droneModel: card.drone_model || '',
              businessScope: card.business_scope?.join(',') || '',
              businessScopeText: card.business_scope?.join(',') || '',
              distanceText: '',
              recentActiveText: '',
              phone: card.phone || '',
              wechatId: card.wechat_id || '',
              douyinId: card.douyin_id || '',
              pilotCode: '',
              company: '',
              position: '',
              likeCount: card.likeCount || card.like_count || 0,
              likedByMe: false,
              isVipSlot: false,
              vipRadiusKm: 0,
              vipLabel: '',
              latitude: 0,
              longitude: 0,
              score: '',
              licenseUrl: '',
              channelsId: '',
              isNew: false,
              licenseStatusClass: '',
              roleLabel: card.user_role === 'pilot' ? '飞手' : (card.user_role === 'employer' ? '雇主' : ''),
              institutionId: '',
              workMu: null,
              workKg: null,
              droneImages: [],
            };
            hasValidRewardSlot = true;
            console.info('【轮播图】rewardSlotUser为空，从carousel加载: nickname=' + this.rewardSlotUser.nickname);
          } else if (this.rewardSlotUser) {
            hasValidRewardSlot = true;
            console.info('【轮播图】rewardSlotUser已存在(来自loadRewardSlotStatus): nickname=' + this.rewardSlotUser.nickname + ', claimed=' + this.rewardSlotClaimed);
          } else {
            console.info('【轮播图】carousel无profile_card，保持rewardSlotUser为空');
          }
        }
      }

      // 根据carousel配置决定是否显示奖励位
      // 注意：最终状态由loadRewardSlotStatus()根据用户是否认领来决定，这里只做记录
      console.info('【轮播图】carousel奖励位状态: hasValidRewardSlot=' + hasValidRewardSlot + ', prevRewardSlotClaimed=' + prevRewardSlotClaimed + ', prevUser=' + prevRewardSlotUserNickname);

      // 不在这里设置rewardSlotClaimed，改为标记hasValidRewardSlot
      // 实际claimed状态由loadRewardSlotStatus()决定
      this.bannerLoaded = true;

      // 更新banner列表
      // 从banners中过滤掉奖励位，只保留普通banner
      const allBanners = banners.length > 0 ? banners : this.getDefaultBanners();
      const baseBanners = allBanners.filter((b: BannerItem) => !b.isRewardSlot);
      const rewardBanner = this.getRewardBanner();
      const newBannerCache = [rewardBanner, ...baseBanners];

      // 比对 rewardBanner 的关键字段，只有真正变化时才更新
      const prevRewardBanner = this.bannerCache[0];
      const isRewardBannerChanged = !prevRewardBanner ||
        prevRewardBanner.title !== rewardBanner.title ||
        prevRewardBanner.subtitle !== rewardBanner.subtitle ||
        prevRewardBanner.actionText !== rewardBanner.actionText;

      // 比对 baseBanners
      const baseBannersChanged = JSON.stringify(baseBanners.map((b: BannerItem) => b.uid)) !==
        JSON.stringify((prevRewardBanner ? this.bannerCache.slice(1) : []).map((b: BannerItem) => b.uid));

      if (isRewardBannerChanged || baseBannersChanged || this.imageList.length === 0) {
        console.info('【轮播图】banner内容变化: reward=' + isRewardBannerChanged + ', base=' + baseBannersChanged + ', empty=' + (this.imageList.length === 0));
        this.bannerCache = newBannerCache;
        this.imageList = this.bannerCache;
      } else {
        console.info('【轮播图】banner内容无变化，跳过更新');
      }
    } catch {
      if (this.imageList.length === 0) {
        const rewardBanner = this.getRewardBanner();
        this.imageList = [rewardBanner, ...this.getDefaultBanners()];
      }
    }
    this.bannerLoaded = true;
    this.startLightAnimations();
  }

  // 启动光晕流动动画
  startLightAnimations() {
    const MIN_DISTANCE = 120;  // 最小间距

    // 检查位置是否与其它光斑重叠
    const isValidPosition = (x: number, y: number, exclude: string): boolean => {
      if (exclude !== 'A' && Math.hypot(x - this.lightAOffsetX, y - this.lightAOffsetY) < MIN_DISTANCE) {
        return false;
      }
      if (exclude !== 'B' && Math.hypot(x - this.lightBOffsetX, y - this.lightBOffsetY) < MIN_DISTANCE) {
        return false;
      }
      if (exclude !== 'C' && Math.hypot(x - this.lightCOffsetX, y - this.lightCOffsetY) < MIN_DISTANCE) {
        return false;
      }
      return true;
    };

    // 生成不重叠的随机位置
    const getRandomPosition = (exclude: string): number[] => {
      let x = 0, y = 0;
      let attempts = 0;
      do {
        x = Math.random() * 280;
        y = Math.random() * 180;
        attempts++;
      } while (!isValidPosition(x, y, exclude) && attempts < 50);
      return [x, y];
    };

    // 光晕 A - 青色 全屏随机移动
    const animateA = () => {
      const pos = getRandomPosition('A');
      animateTo({
        duration: 4200 + Math.random() * 2800,
        curve: Curve.EaseInOut,
      }, () => {
        this.lightAOffsetX = pos[0];
        this.lightAOffsetY = pos[1];
        this.lightAOpacity = 0.6 + Math.random() * 0.4;
        this.lightAScale = 0.8 + Math.random() * 0.4;
      });
      setTimeout(animateA, 4200 + Math.random() * 2800);
    };
    setTimeout(animateA, 0);

    // 光晕 B - 橙色 全屏随机移动
    const animateB = () => {
      const pos = getRandomPosition('B');
      animateTo({
        duration: 5600 + Math.random() * 2800,
        curve: Curve.EaseInOut,
      }, () => {
        this.lightBOffsetX = pos[0];
        this.lightBOffsetY = pos[1];
        this.lightBOpacity = 0.6 + Math.random() * 0.4;
        this.lightBScale = 0.8 + Math.random() * 0.4;
      });
      setTimeout(animateB, 5600 + Math.random() * 2800);
    };
    setTimeout(animateB, 500);

    // 光晕 C - 蓝色 全屏随机移动
    const animateC = () => {
      const pos = getRandomPosition('C');
      animateTo({
        duration: 7000 + Math.random() * 2800,
        curve: Curve.EaseInOut,
      }, () => {
        this.lightCOffsetX = pos[0];
        this.lightCOffsetY = pos[1];
        this.lightCOpacity = 0.6 + Math.random() * 0.4;
        this.lightCScale = 0.8 + Math.random() * 0.4;
      });
      setTimeout(animateC, 7000 + Math.random() * 2800);
    };
    setTimeout(animateC, 1000);
  }

  async loadConfig() {
    try {
      const config = await fetchConfig();
      this.marqueeText = config.defaultTopTitle || '呼叫飞手';
      this.marqueeNeedsScroll = this.marqueeText.length > 12;
      this.todayActiveUsers = config.todayActiveUsers ?? 0;
      this.totalPilotCount = config.totalPilotCount ?? 0;
      this.totalEmployerCount = config.totalEmployerCount ?? 0;
      this.totalContactCount = config.totalContactCount ?? 0;
      this.rewardTitle = config.rewardTitle || '呼叫飞手';
      this.rewardSubtitle = config.rewardSubtitle || '打造职业飞手库';
      this.rewardButtonText = config.rewardButtonText || '观看解锁';
    } catch {
      this.marqueeText = '呼叫飞手';
      this.marqueeNeedsScroll = false;
    }
  }

  // 加载并展示激励视频广告
  async loadRewardedAd(): Promise<void> {
    hilog.info(0x0000, 'RewardAd', 'loadRewardedAd start');

    const context = getContext(this) as common.UIAbilityContext;

    // 广告请求回调监听
    const adLoadListener: advertising.AdLoadListener = {
      onAdLoadFailure: (errorCode: number, errorMsg: string) => {
        hilog.error(0x0000, 'RewardAd', `Failed to load ad. Code is ${errorCode}, message is ${errorMsg}`);
        this.isAdLoading = false;
        promptAction.showToast({ message: '广告加载失败，请重试' });
      },
      onAdLoadSuccess: (ads: Array<advertising.Advertisement>) => {
        hilog.info(0x0000, 'RewardAd', 'Succeeded in loading ad');
        try {
          // 创建激励广告状态处理器并注册监听
          const rewardHandler = new RewardAdStatusHandler();
          rewardHandler.registerPPSReceiver(() => {
            // 激励发放回调 - 调用后端接口领取奖励位
            hilog.info(0x0000, 'RewardAd', 'onAdReward triggered - calling claimRewardSlot');
            this.onRewardClaimed();
          });

          // 广告展示参数
          const adDisplayOptions: advertising.AdDisplayOptions = {
            mute: false
          };

          // 展示广告
          advertising.showAd(ads[0], adDisplayOptions, context);
        } catch (e) {
          hilog.error(0x0000, 'RewardAd', `Failed to show ad. Code is ${(e as BusinessError).code}, message is ${(e as BusinessError).message}`);
          this.isAdLoading = false;
        }
      }
    };

    // 广告请求参数
    const adRequestParams: advertising.AdRequestParams = {
      adId: 'j14rx3xtac',  // 测试广告位ID
      adType: 7,  // 激励广告类型
      oaid: await requestOAID(context)
    };

    // 广告配置参数
    const adOptions: advertising.AdOptions = {};

    // 创建AdLoader广告对象并请求广告
    const adLoader: advertising.AdLoader = new advertising.AdLoader(context);
    try {
      adLoader.loadAd(adRequestParams, adOptions, adLoadListener);
    } catch (e) {
      hilog.error(0x0000, 'RewardAd', `Failed to load ad. Code is ${(e as BusinessError).code}, message is ${(e as BusinessError).message}`);
      this.isAdLoading = false;
      promptAction.showToast({ message: '广告加载失败，请重试' });
    }
  }

  // 激励视频看完后，领取奖励位
  async onRewardClaimed(): Promise<void> {
    try {
      hilog.info(0x0000, 'RewardAd', 'onRewardClaimed called');
      const result = await claimRewardSlot();
      hilog.info(0x0000, 'RewardAd', `claimRewardSlot result: ${JSON.stringify(result)}`);

      if (result.claimed && result.profileCard) {
        hilog.info(0x0000, 'RewardAd', 'Reward slot claimed successfully');
        promptAction.showToast({ message: '奖励位领取成功' });

        // 使用后端返回的 profileCard 数据更新UI
        const card = result.profileCard;
        this.rewardSlotUser = {
          openid: '',
          nickname: card.nickname || '匿名用户',
          avatar: card.avatarUrl || DEFAULT_AVATAR,
          city: card.city || '',
          roleLabel: '',
          licenseType: card.licenseType || '',
          licenseStatus: card.licenseType === '已审核' ? '审核通过' : card.licenseType || '',
          pilotCode: '',
          company: card.company || '',
          position: card.position || '',
          droneModel: card.droneModel || '',
          businessScope: '',
          businessScopeText: (card.businessScope || []).join('、'),
          recentActiveText: '刚刚活跃',
          likeCount: card.likeCount || 0,
          likedByMe: false,
          phone: card.phone || '',
          wechatId: card.wechatId || '',
          douyinId: card.douyinId || '',
          distanceText: '',
          isVipSlot: false,
          vipRadiusKm: 0,
          vipLabel: '',
          latitude: 0,
          longitude: 0,
          score: '',
          licenseUrl: card.licenseUrl || '',
          channelsId: card.channelsId || '',
          isNew: false,
          licenseStatusClass: '',
          institutionId: card.institutionId || '',
          workMu: card.workMu ?? null,
          workKg: card.workKg ?? null,
          droneImages: card.droneImages || [],
        };
        this.rewardSlotClaimed = true;
      } else {
        hilog.info(0x0000, 'RewardAd', 'Reward slot claim failed or already claimed');
        promptAction.showToast({ message: '领取失败或已被领取' });
      }
    } catch (e) {
      hilog.error(0x0000, 'RewardAd', `claimRewardSlot error: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: '领取失败，请重试' });
    }
    this.isAdLoading = false;
  }

  // 检查用户资料是否完整（可以领取奖励位）
  isProfileComplete(): boolean {
    const user = AuthService.getCurrentUser();
    console.info('【isProfileComplete】user: ' + JSON.stringify(user));
    if (!user) {
      console.info('【isProfileComplete】user is null, return false');
      return false;
    }
    // 检查必要字段
    const hasNickname = !!(user.displayName && user.displayName.trim().length > 0);
    const hasAvatar = !!(user.avatar && user.avatar.trim().length > 0);
    const hasPhone = !!(user.phone && user.phone.trim().length > 0);
    console.info('【isProfileComplete】displayName: ' + user.displayName + ', hasNickname: ' + hasNickname + ', avatar: ' + user.avatar + ', hasAvatar: ' + hasAvatar + ', phone: ' + user.phone + ', hasPhone: ' + hasPhone);
    return hasNickname && hasAvatar && hasPhone;
  }

  // 点击奖励位
  onRewardSlotClick(): void {
    console.info('【奖励位点击】rewardSlotClaimed: ' + this.rewardSlotClaimed + ', rewardSlotUser: ' + JSON.stringify(this.rewardSlotUser) + ', isProfileComplete: ' + this.isProfileComplete());
    if (this.rewardSlotClaimed && this.rewardSlotUser) {
      const user: PilotCardData = {
        openid: this.rewardSlotUser.openid,
        nickname: this.rewardSlotUser.nickname,
        avatar: this.rewardSlotUser.avatar,
        city: this.rewardSlotUser.city,
        userRole: '',
        roleLabel: '',
        licenseType: this.rewardSlotUser.licenseType,
        licenseStatus: this.rewardSlotUser.licenseStatus,
        pilotCode: this.rewardSlotUser.pilotCode,
        company: this.rewardSlotUser.company,
        position: this.rewardSlotUser.position,
        droneModel: this.rewardSlotUser.droneModel,
        businessScopeText: this.rewardSlotUser.businessScopeText,
        recentActiveText: this.rewardSlotUser.recentActiveText,
        likeCount: this.rewardSlotUser.likeCount,
        likedByMe: false,
        phone: this.rewardSlotUser.phone,
        wechatId: this.rewardSlotUser.wechatId,
        douyinId: this.rewardSlotUser.douyinId,
        distanceText: this.rewardSlotUser.distanceText,
        isNew: false,
        workMu: this.rewardSlotUser.workMu ?? null,
        workKg: this.rewardSlotUser.workKg ?? null,
        droneImages: this.rewardSlotUser.droneImages || [],
        channelsId: this.rewardSlotUser.channelsId || '',
        institutionId: this.rewardSlotUser.institutionId || '',
        licenseUrl: this.rewardSlotUser.licenseUrl || '',
      };
      // 静默上报查看次数
      const ownerOpenid = this.rewardSlotUser.openid;
      if (ownerOpenid) {
        reportStandbyView(ownerOpenid).catch(() => {});
      }
      this.rewardSlotDialogController = new CustomDialogController({
        builder: StandbyPilotCardDialog({
          user: user,
          onWechatClick: () => {
            if (user.wechatId) {
              promptAction.showToast({ message: '微信号: ' + user.wechatId });
            } else {
              promptAction.showToast({ message: '暂无微信号' });
            }
          },
          onCallClick: () => {
            if (user.phone) {
              call.makeCall(user.phone, (err) => {
                if (err) {
                  promptAction.showToast({ message: '拨打电话失败' });
                }
              });
            }
          },
          onLikeChanged: (likeCount: number, likedByMe: boolean) => {
            if (this.rewardSlotUser) {
              this.rewardSlotUser.likeCount = likeCount;
              this.rewardSlotUser.likedByMe = likedByMe;
            }
          }
        }),
        customStyle: true,
        maskColor: 'rgba(0, 0, 0, 0.7)',
        alignment: DialogAlignment.Center,
      });
      this.rewardSlotDialogController.open();
      return;
    }

    if (!this.isProfileComplete()) {
      promptAction.showToast({ message: '请先完善个人资料' });
      return;
    }

    // 未认领奖励位时，直接调用领取接口（跳过激励视频）
    if (!this.rewardSlotClaimed) {
      this.onRewardClaimed();
    }
  }

  async loadPilots(silent: boolean = false) {
    // 首次或缓存为空时，显示骨架屏
    if (!silent || this.pilots.length === 0) {
      this.pilotsLoading = true;
      this.startSkeletonShimmer();
    }

    // 优先使用缓存（首次加载时缓存已有数据）
    if (this.pilots.length > 0) {
      this.pilotsLoading = false;
    }

    try {
      const context = getContext(this) as Context;
      const location = await LocationService.getCurrentLocation(context);
      this.pilotsLat = location?.latitude ?? 39.9;
      this.pilotsLng = location?.longitude ?? 116.4;
      const result = await fetchNearbyPilots(this.pilotsLat, this.pilotsLng, 1, 50);

      // 静默刷新时：比对列表是否变化
      if (silent && this.pilots.length > 0) {
        const prevIds = this.pilots.map((item: PilotItem) => item.openid).sort().join(',');
        const newIds = result.pilots.map((item: PilotItem) => item.openid).sort().join(',');
        if (prevIds === newIds) {
          // 列表无变化，跳过更新
          console.info('【附近飞手】列表无变化，跳过更新');
          this.pilotsLoading = false;
          this.stopSkeletonShimmer();
          return;
        }
        console.info('【附近飞手】列表有变化，执行更新');
      }

      this.pilotsCache = result.pilots;
      this.pilots = result.pilots;
    } catch {
      if (this.pilots.length === 0) {
        this.pilots = [];
      }
    }
    this.pilotsLoading = false;
    this.stopSkeletonShimmer();
  }

  async loadOrders(silent: boolean = false) {
    // 首次或缓存为空时，显示骨架屏
    if (!silent || this.orders.length === 0) {
      this.ordersLoading = true;
      this.startOrdersSkeletonShimmer();
    }

    // 优先使用缓存
    if (this.orders.length > 0) {
      this.ordersLoading = false;
    }

    try {
      const newOrders = await fetchPublicOrders();

      // 静默刷新时：比对列表是否变化
      if (silent && this.orders.length > 0) {
        const prevIds = this.orders.map((item: OrderItem) => item.orderId).sort().join(',');
        const newIds = newOrders.map((item: OrderItem) => item.orderId).sort().join(',');
        if (prevIds === newIds) {
          // 列表无变化，跳过更新
          console.info('【最新任务】列表无变化，跳过更新');
          this.ordersLoading = false;
          this.stopOrdersSkeletonShimmer();
          return;
        }
        console.info('【最新任务】列表有变化，执行更新');
      }

      this.ordersCache = newOrders;
      this.orders = newOrders;
    } catch {
      if (this.orders.length === 0) {
        this.orders = [];
      }
    }
    this.ordersLoading = false;
    this.stopOrdersSkeletonShimmer();
  }

  async loadStandby(silent: boolean = false) {
    try {
      const result = await fetchStandby();

      // 始终更新列表，确保 viewCount 等实时数据刷新
      this.standbyItems = result.items;
      // 渐显动画
      this.standbyOpacity = 0;
      setTimeout(() => {
        this.standbyOpacity = 1;
      }, 50);
      // 检查当前用户是否在等待列表中
      const currentUser = AuthService.getCurrentUser();
      const myOpenid = currentUser?.openId || '';
      this.standbyIsJoined = this.standbyItems.some(item => item.openid === myOpenid);
      console.info('【今日有空】加载成功，数量:', this.standbyItems.length, '已加入:', this.standbyIsJoined);
    } catch (err) {
      console.error('【今日有空】加载失败:', JSON.stringify(err));
      if (!silent) {
        this.standbyItems = [];
        this.standbyIsJoined = false;
      }
    }
    // 获取屏幕尺寸（转换为vp）
    try {
      const d = display.getDefaultDisplaySync();
      this.screenWidth = px2vp(d.width);
      this.screenHeight = px2vp(d.height);
    } catch (e) {}
  }

  async toggleStandbyJoin() {
    if (this.standbyLoading) return;
    const wasJoined = this.standbyIsJoined;
    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    this.standbyLoading = true;
    try {
      if (wasJoined) {
        await leaveStandby(token);
        this.standbyIsJoined = false;
        promptAction.showToast({ message: '已取消等待' });
      } else {
        await joinStandby(token);
        this.standbyIsJoined = true;
        promptAction.showToast({ message: '已加入等待' });
      }
      // 重新加载列表
      await this.loadStandby();
    } catch (err) {
      console.error('【今日有空】切换失败:', JSON.stringify(err));
      this.standbyIsJoined = wasJoined;
      promptAction.showToast({ message: wasJoined ? '取消失败' : '加入失败' });
    } finally {
      this.standbyLoading = false;
    }
  }

  onStandbyCardTap(item: StandbyItem) {
    const p = item.profile;
    const pilotData: PilotCardData = {
      openid: p.openid,
      nickname: p.nickname,
      avatar: p.avatarUrl || '',
      city: p.city,
      userRole: p.userRole || '',
      roleLabel: p.roleLabel || '',
      licenseType: p.licenseType || '',
      licenseStatus: p.licenseStatus || '',
      pilotCode: p.pilotCode || '',
      company: p.company || '',
      position: p.position || '',
      droneModel: p.droneModel || '',
      businessScopeText: p.businessScopeText || (p.businessScope || []).join(' · ') || '',
      recentActiveText: p.recentActiveText || '',
      likeCount: item.likeCount ?? 0,
      likedByMe: false,
      phone: p.phone || '',
      wechatId: p.wechatId || '',
      douyinId: p.douyinId || '',
      distanceText: '',
      isNew: p.isNew,
      workMu: null,
      workKg: null,
      droneImages: [],
      channelsId: '',
      institutionId: '',
      licenseUrl: '',
    };

    // 静默上报查看次数
    if (p.openid) {
      reportStandbyView(p.openid).then((viewCount) => {
        // 更新列表中对应的 viewCount（创建新数组引用以触发 UI 刷新）
        const idx = this.standbyItems.findIndex((s: StandbyItem) => s.profile.openid === p.openid);
        if (idx >= 0) {
          const item = this.standbyItems[idx];
          const updated: StandbyItem = {
            openid: item.openid,
            joined_at: item.joined_at,
            profile: item.profile,
            likeCount: item.likeCount,
            viewCount: viewCount
          };
          const newItems = this.standbyItems.slice();
          newItems[idx] = updated;
          this.standbyItems = newItems;
        }
      }).catch(() => {});
    }

    this.standbyDialogController = new CustomDialogController({
      builder: StandbyPilotCardDialog({
        user: pilotData,
        onWechatClick: () => {
          console.info('【今日有空弹窗微信点击】pilotData.wechatId:', pilotData.wechatId);
          const wechatId = pilotData.wechatId || '';
          if (wechatId) {
            try {
              const pasteData = pasteboard.createData('text/plain', wechatId);
              const systemPasteboard = pasteboard.getSystemPasteboard();
              systemPasteboard.setData(pasteData);
              promptAction.showToast({ message: '微信号已复制' });
            } catch (e) {
              promptAction.showToast({ message: '微信号: ' + wechatId });
            }
          } else {
            promptAction.showToast({ message: '暂无微信号' });
          }
        },
        onCallClick: () => {
          const phone = pilotData.phone || '';
          if (phone) {
            call.makeCall(phone, (err) => {
              if (err) console.error('拨号失败:', JSON.stringify(err));
            });
          }
        }
      }),
      customStyle: true,
      maskColor: 'rgba(0, 0, 0, 0.7)',
      alignment: DialogAlignment.Center
    });
    this.standbyDialogController?.open();
  }

  closeExpandedStandbyDialog() {
    this.showExpandedStandby = false;
    this.expandedStandbyItem = null;
    this.expandedPilotCardData = null;
    this.showCopySuccess = false;
  }

  @Builder
  buildExpandedPilotCard() {
    if (this.expandedPilotCardData) {
      PilotCard({
        user: this.expandedPilotCardData,
        showDistance: false,
        showRecentActive: false,
        showActions: true,
        onWechatClick: (_openid: string) => {
          const wechatId = this.expandedPilotCardData?.wechatId || '';
          if (wechatId) {
            const pasteData = pasteboard.createData('text/plain', wechatId);
            const systemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData);
            this.showCopySuccess = true;
            setTimeout(() => { this.showCopySuccess = false; }, 1500);
          }
        },
        onCallClick: (_openid: string) => {
          const phone = this.expandedPilotCardData?.phone || '';
          if (phone) {
            call.makeCall(phone, (err) => {
              if (err) {
                console.error('拨号失败:', JSON.stringify(err));
              }
            });
          }
        },
        onLikeChanged: (likeCount: number, likedByMe: boolean) => {
          // 同步更新 standbyItems（需要新数组引用触发 UI 更新）
          const idx = this.standbyItems.findIndex(item => item.openid === this.expandedStandbyItem?.openid);
          if (idx >= 0) {
            const newItems = this.standbyItems.slice();
            const oldItem = newItems[idx];
            newItems[idx] = {
              openid: oldItem.openid,
              joined_at: oldItem.joined_at,
              profile: oldItem.profile,
              likeCount: likeCount,
              viewCount: oldItem.viewCount
            };
            this.standbyItems = newItems;
          }
          // 同步更新 expandedStandbyItem
          if (this.expandedStandbyItem) {
            this.expandedStandbyItem.likeCount = likeCount;
          }
          // 同步更新 expandedPilotCardData（需要新对象引用触发 UI 更新）
          if (this.expandedPilotCardData) {
            const old = this.expandedPilotCardData;
            const updated: PilotCardData = new PilotCardData();
            updated.openid = old.openid;
            updated.nickname = old.nickname;
            updated.avatar = old.avatar;
            updated.city = old.city;
            updated.userRole = old.userRole;
            updated.roleLabel = old.roleLabel;
            updated.licenseType = old.licenseType;
            updated.licenseStatus = old.licenseStatus;
            updated.pilotCode = old.pilotCode;
            updated.company = old.company;
            updated.position = old.position;
            updated.droneModel = old.droneModel;
            updated.businessScopeText = old.businessScopeText;
            updated.recentActiveText = old.recentActiveText;
            updated.likeCount = likeCount;
            updated.likedByMe = likedByMe;
            updated.phone = old.phone;
            updated.wechatId = old.wechatId;
            updated.douyinId = old.douyinId;
            updated.distanceText = old.distanceText;
            updated.isNew = old.isNew;
            updated.workMu = old.workMu;
            updated.workKg = old.workKg;
            updated.droneImages = old.droneImages;
            updated.channelsId = old.channelsId;
            updated.institutionId = old.institutionId;
            updated.licenseUrl = old.licenseUrl;
            this.expandedPilotCardData = updated;
          }
        }
      });
    }
  }

  async copyWechatId(wechatId: string) {
    try {
      const pasteData = pasteboard.createData('text/plain', wechatId);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteData);
      this.showCopySuccess = true;
      setTimeout(() => { this.showCopySuccess = false; }, 1500);
    } catch (err) {
      promptAction.showToast({ message: '微信号: ' + wechatId });
    }
  }

  startSkeletonShimmer() {
    this.skeletonShimmer = false;
    this.skeletonTimer = setInterval(() => {
      this.skeletonShimmer = !this.skeletonShimmer;
    }, 600) as number;
  }

  stopSkeletonShimmer() {
    if (this.skeletonTimer >= 0) {
      clearInterval(this.skeletonTimer);
      this.skeletonTimer = -1;
    }
    this.skeletonShimmer = false;
  }

  startOrdersSkeletonShimmer() {
    this.ordersSkeletonShimmer = false;
    this.ordersSkeletonTimer = setInterval(() => {
      this.ordersSkeletonShimmer = !this.ordersSkeletonShimmer;
    }, 600) as number;
  }

  stopOrdersSkeletonShimmer() {
    if (this.ordersSkeletonTimer >= 0) {
      clearInterval(this.ordersSkeletonTimer);
      this.ordersSkeletonTimer = -1;
    }
    this.ordersSkeletonShimmer = false;
  }

  getDefaultBanners(): BannerItem[] {
    return [
      { uid: '1', src: 'https://wetofly.com/data/banner/banner1.png', isVideoBanner: false, videoUrl: '', clickType: 'none', clickPage: '', clickUrl: '' }
    ];
  }

  getRewardBanner(): BannerItem {
    return {
      uid: 'reward_1',
      src: '',
      isVideoBanner: false,
      videoUrl: '',
      clickType: 'none',
      clickPage: '',
      clickUrl: '',
      isRewardSlot: true,
      title: this.rewardTitle || '呼叫飞手',
      subtitle: this.rewardSubtitle || '打造职业飞手库',
      actionText: this.rewardButtonText || '观看解锁'
    };
  }

  // 保存网络图片到本地相册（使用安全弹窗方式，无需WRITE权限）
  async saveImageToGallery(imageUrl: string): Promise<void> {
    let tempFilePath: string = '';
    try {
      console.info('【保存图片】开始保存: ' + imageUrl);

      // 下载图片到临时目录
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        connectTimeout: 30000,
        readTimeout: 30000
      });

      if (response.responseCode !== 200) {
        console.error('【保存图片】下载失败: ' + response.responseCode);
        promptAction.showToast({ message: '下载图片失败' });
        return;
      }

      const imageData = response.result as ArrayBuffer;

      // 先保存到临时目录
      const tempDir = getContext(this).cacheDir;
      const tempFileName = 'temp_image_' + Date.now() + '.jpg';
      tempFilePath = tempDir + '/' + tempFileName;
      const tempFile = fileIo.openSync(tempFilePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(tempFile.fd, imageData);
      fileIo.closeSync(tempFile.fd);
      console.info('【保存图片】临时文件: ' + tempFilePath);

      // 使用安全弹窗方式保存到相册（不需要WRITE权限）
      const helper = photoAccessHelper.getPhotoAccessHelper(getContext(this));
      const photoCreationConfig: photoAccessHelper.PhotoCreationConfig = {
        title: '轮播图_' + Date.now(),
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE
      };

      const srcFileUri = fileUri.getUriFromPath(tempFilePath);
      const resultUris = await helper.showAssetsCreationDialog(
        [srcFileUri],
        [photoCreationConfig]
      );
      console.info('【保存图片】安全弹窗结果: ' + JSON.stringify(resultUris));

      if (resultUris && resultUris.length > 0) {
        // 弹窗授权后，需要手动复制文件到目标URI
        const srcFile = fileIo.openSync(tempFilePath, fileIo.OpenMode.READ_ONLY);
        const desFile = fileIo.openSync(resultUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
        fileIo.copyFileSync(srcFile.fd, desFile.fd);
        fileIo.closeSync(srcFile);
        fileIo.closeSync(desFile);
        console.info('【保存图片】成功: ' + resultUris[0]);
        promptAction.showToast({ message: '已保存到相册' });
      } else {
        console.info('【保存图片】用户取消保存');
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
      console.error('【保存图片】异常: ' + errMsg);
      promptAction.showToast({ message: '保存失败: ' + errMsg });
    } finally {
      // 删除临时文件
      if (tempFilePath) {
        try {
          fileIo.unlinkSync(tempFilePath);
        } catch (e) {}
      }
    }
  }

  // 判断轮播图是否可点击（是否有有效跳转）
  hasValidClick(item: BannerItem): boolean {
    return !!(item.clickType && item.clickType !== 'none') ||
           !!(item.clickPage && item.clickPage.trim() !== '') ||
           !!(item.clickUrl && item.clickUrl.trim() !== '');
  }

  // 获取联系方式（可能来自本地或远程）
  async getContact(pilot: PilotItem): Promise<PilotContact> {
    let phone = pilot.phone;
    let wechatId = pilot.wechatId;
    if (!phone) {
      const token = AuthService.getAuthToken();
      try {
        const contact = await fetchPilotContact(pilot.openid, token);
        phone = contact.phone;
        wechatId = contact.wechatId;
        console.info('【联系方式】phone:', phone, 'wechatId:', wechatId);
      } catch (err) {
        console.error('【获取联系方式失败】', JSON.stringify(err));
      }
    }
    return { phone, wechatId };
  }

  async onIconCall(pilot: PilotItem) {
    console.info('【拨号】openid:', pilot.openid);
    const contact = await this.getContact(pilot);
    if (contact.phone) {
      try {
        call.makeCall(contact.phone);
      } catch (err) {
        promptAction.showToast({ message: '拨打 ' + contact.phone });
      }
    } else {
      promptAction.showToast({ message: '暂无电话号码' });
    }
  }

  async onIconWechat(pilot: PilotItem) {
    console.info('【微信】openid:', pilot.openid);
    const contact = await this.getContact(pilot);
    if (contact.wechatId) {
      try {
        const pasteData = pasteboard.createData('text/plain', contact.wechatId);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        systemPasteboard.setData(pasteData);
        promptAction.showToast({ message: '微信号已复制' });
      } catch (err) {
        promptAction.showToast({ message: '微信号: ' + contact.wechatId });
      }
    } else {
      promptAction.showToast({ message: '暂无微信号' });
    }
  }

  toggleOrderExpand(orderId: string) {
    const isExpanded = this.expandedOrderIds.includes(orderId);
    if (isExpanded) {
      this.expandedOrderIds = this.expandedOrderIds.filter((id: string) => id !== orderId);
    } else {
      this.expandedOrderIds = [...this.expandedOrderIds, orderId];
    }
  }

  isOrderExpanded(orderId: string): boolean {
    return this.expandedOrderIds.includes(orderId);
  }

  async onOrderCall(order: OrderItem) {
    console.info('【订单拨号】openid:', order.publisherOpenid);
    const token = AuthService.getAuthToken();
    try {
      const contact = await fetchPilotContact(order.publisherOpenid, token);
      if (contact.phone) {
        try {
          call.makeCall(contact.phone);
        } catch (err) {
          promptAction.showToast({ message: '拨打 ' + contact.phone });
        }
      } else {
        promptAction.showToast({ message: '暂无电话号码' });
      }
    } catch (err) {
      console.error('【获取订单联系方式失败】', JSON.stringify(err));
      promptAction.showToast({ message: '暂无电话号码' });
    }
  }

  async onOrderWechat(order: OrderItem) {
    console.info('【订单微信】openid:', order.publisherOpenid);
    const token = AuthService.getAuthToken();
    try {
      const contact = await fetchPilotContact(order.publisherOpenid, token);
      if (contact.wechatId) {
        try {
          const pasteData = pasteboard.createData('text/plain', contact.wechatId);
          const systemPasteboard = pasteboard.getSystemPasteboard();
          systemPasteboard.setData(pasteData);
          promptAction.showToast({ message: '微信号已复制' });
        } catch (err) {
          promptAction.showToast({ message: '微信号: ' + contact.wechatId });
        }
      } else {
        promptAction.showToast({ message: '暂无微信号' });
      }
    } catch (err) {
      console.error('【获取订单联系方式失败】', JSON.stringify(err));
      promptAction.showToast({ message: '暂无微信号' });
    }
  }

  @Builder
  FeatureCard(param: FeatureCardParam) {
    Column() {
      Row() {
        Image(param.iconUrl)
          .width(44)
          .height(37)
          .objectFit(ImageFit.Contain)
        Column() {
          Text(param.title)
            .fontSize(16)
            .fontColor($r('app.color.text_title'))
            .fontWeight(400)
            .fontFamily('DouyinFont')
          Text(param.subtitle)
            .fontSize(12)
            .fontColor($r('app.color.text_body'))
            .fontFamily('DouyinFont')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 14 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .shadow({
        radius: 16,
        color: 'rgba(146, 146, 146, 0.1)',
        offsetX: 0,
        offsetY: 4
      })
    }
    .width('48%')
    .height(72)
    .onClick(() => {
      param.onClick();
    })
  }

  @Builder
  CustomTitleBar() {
    Column() {
      Row() {
        Text('呼叫飞手')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_title'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(56)
    .backgroundEffect({
      radius: 20,
      saturation: 1.0,
      brightness: 1.0,
      color: 'rgba(255, 255, 255, 0.5)'
    })
  }

  @Builder
  StandbyList() {
    if (this.standbyItems.length === 0) {
      Blank()
        .height(12)
    } else {
    Column() {
      // 标题栏 - 在白色容器外
      Row() {
        Text('今日有空')
          .fontSize(17)
          .fontWeight(400)
          .fontColor($r('app.color.text_title'))
          .fontFamily('DouyinFont')
        Blank()
        Text('师徒匹配')
          .fontSize(11)
          .fontFamily('DouyinFont')
          .fontColor('#FFFFFF')
          .backgroundColor('#3B82F6')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(4)
          .onClick(() => {
            router.pushUrl({ url: 'pages/Standby' });
          })
        Text(this.standbyIsJoined ? '取消等待' : '等待任务')
          .fontSize(11)
          .fontFamily('DouyinFont')
          .fontColor('#FFFFFF')
          .backgroundColor(this.standbyIsJoined ? '#EF4444' : '#22C55E')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(4)
          .margin({ left: 10 })
          .onClick(() => this.toggleStandbyJoin())
      }
      .width('100%')
      .padding({ left: 18, right: 18 })
      .margin({ bottom: 12, top: 22 })

      // 白色圆角容器
      Column() {
        // 横向滚动卡片列表（渐显动画）
        List() {
          ForEach(this.standbyItems, (item: StandbyItem) => {
            ListItem() {
              Column() {
                // 头像 + 昵称 + 城市
                Row() {
                  Image(item.profile.avatarUrl || 'https://wetofly.com/data/image/avatar_placeholder.webp')
                    .width(32)
                    .height(32)
                    .borderRadius(18)
                    .backgroundColor($r('app.color.avatar_placeholder'))

                  Column() {
                    Text(item.profile.nickname)
                      .fontSize(13)
                      .fontWeight(700)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.profile.city) {
                      Text(item.profile.city)
                        .fontSize(12)
                        .fontColor($r('app.color.text_caption'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 8 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                // 底部：点赞星 + 浏览次数
                Row() {
                  Row() {
                    Image(item.profile.isNew ? $r('app.media.icon_star2') : $r('app.media.icon_star1'))
                      .width(14)
                      .height(14)
                      .objectFit(ImageFit.Contain)
                    Text(item.likeCount > 0 ? String(item.likeCount) : '')
                      .fontSize(10)
                      .fontColor($r('app.color.text_caption'))
                      .fontWeight(400)
                      .margin({ left: 3 })
                  }
                  .width(36)
                  .justifyContent(FlexAlign.Center)

                  Text(item.viewCount > 0 ? '浏览 ' + item.viewCount + ' 次' : '暂无查看')
                    .fontSize(10)
                    .fontColor($r('app.color.text_caption'))
                    .fontWeight(400)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ top: 6 })
              }
              .width(150)
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ right: 11 })
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor($r('app.color.card_bg_secondary'))
              .borderRadius(9)
              .onClick(() => this.onStandbyCardTap(item))
            }
          })
        }
        .width('100%')
        .height('70')
        .scrollBar(BarState.Off)
        .listDirection(Axis.Horizontal)
        .padding({ left: 10, right: 10 })
        .clip(true)
      }
      .opacity(this.standbyOpacity)
      .animation({ duration: 200, curve: Curve.EaseOut })
      .width('90%')
      .padding({ top: 8, bottom: 8 })
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(9)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  ExpandedStandbyOverlay() {
    if (this.showExpandedStandby && this.expandedStandbyItem) {
      Stack() {
        Column()
          .width(this.screenWidth)
          .height(this.screenHeight)
          .backgroundColor('rgba(0, 0, 0, 0.7)')
          .position({ x: 0, y: 0 })
          .onClick(() => this.closeExpandedStandbyDialog())

        Column() {
          Column() {
            this.buildExpandedPilotCard()
          }
          .width('92%')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)
      }
      .width(this.screenWidth)
      .height(this.screenHeight)
      .clip(false)
      .onClick(() => this.closeExpandedStandbyDialog())
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_label'))
        .fontWeight(FontWeight.Medium)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ top: 9, left: 24, right: 24 })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .expandSafeArea([SafeAreaType.SYSTEM])
        .clip(false)
        .onVisibleAreaChange([0, 1], (isVisible: boolean) => {
          hilog.info(0x0000, 'RewardAd', '【onVisibleAreaChange】isVisible=' + isVisible);
          if (isVisible) {
            // 页面显示时静默刷新数据（比对数据，有变化才更新UI）
            const now = Date.now();
            const hiddenDuration = now - this.pageHideTime;
            hilog.info(0x0000, 'RewardAd', '【onVisibleAreaChange】now=' + now + ', hideTime=' + this.pageHideTime + ', 离开时长=' + hiddenDuration + 'ms');

            // 如果页面离开时间不足3秒，不刷新（快速切换）
            if (hiddenDuration < 3000) {
              hilog.info(0x0000, 'RewardAd', '【onVisibleAreaChange】快速切换，跳过刷新');
              // 但今日有空仍然刷新（viewCount 等实时数据需要更新）
              this.loadStandby(true);
              return;
            }

            // 防抖：距离上次刷新不足2秒则跳过
            if (now - this.lastRewardSlotRefreshTime > 2000) {
              this.lastRewardSlotRefreshTime = now;
              hilog.info(0x0000, 'RewardAd', '【onVisibleAreaChange】开始刷新');
              this.loadRewardSlotStatus();
              this.loadConfig();
              this.loadBanner(true);
              this.loadPilots(true);
              this.loadOrders(true);
              this.loadStandby(true);
            } else {
              hilog.info(0x0000, 'RewardAd', '【onVisibleAreaChange】防抖跳过');
            }
          } else {
            // 页面隐藏，记录时间
            this.pageHideTime = Date.now();
            hilog.info(0x0000, 'RewardAd', '【onVisibleAreaChange】页面隐藏，记录时间=' + this.pageHideTime);
          }
        })

      HdsNavigation() {
        Scroll(this.scroller) {
          Column() {
            // 跑马灯（两侧渐变遮罩）
            Stack() {
              // 背景层
              Column()
                .width('100%')
                .height('100%')
                // .backgroundColor('#E7F8FC')
                .borderRadius(12)

              // 跑马灯容器（限制宽度，两侧留出渐变位置）
              Column() {
                if (this.marqueeNeedsScroll) {
                  // 长文字：滚动播放
                  Marquee({
                    src: this.marqueeText || '呼叫飞手',
                    start: true,
                    fromStart: true,
                    step: 6,
                    loop: -1
                  })
                  .fontSize(18)
                  .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a')
                  .fontWeight(FontWeight.Medium)
                  .fontFamily('DouyinFont')
                  .width('100%')
                } else {
                  // 短文字：居中显示
                  Text(this.marqueeText || '呼叫飞手')
                    .fontSize(18)
                    .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a')
                    .fontWeight(FontWeight.Medium)
                    .fontFamily('DouyinFont')
                    .textAlign(TextAlign.Center)
                    .width('100%')
                }
              }
              .width('100%')
              .constraintSize({ maxWidth: '100%' })
              .padding({ left: 32, right: 32 })

              // 左侧渐变（实色→透明）
              Column()
                .width(48)
                .height('100%')
                .linearGradient({
                  direction: GradientDirection.Right,
                  colors: [[ this.marqueeGradientStart, 0 ], [this.marqueeGradientEnd, 1]]
                })
                .position({ left: 18 })
                .borderRadius({ topLeft: 12, bottomLeft: 12 })

              // 右侧渐变（实色→透明）
              Column()
                .width(48)
                .height('100%')
                .linearGradient({
                  direction: GradientDirection.Left,
                  colors: [[ this.marqueeGradientStart, 0 ], [this.marqueeGradientEnd, 1]]
                })
                .position({ right: 18 })
                .borderRadius({ topRight: 12, bottomRight: 12 })
            }
            .height(30)
            .margin({ top: -40 })

            // 占位，让内容穿过导航栏
            Column().width('100%').height(16)

            // 轮播图（固定高度，防止布局跳动）
            Column() {
              Swiper() {
                ForEach(this.imageList, (item: BannerItem) => {
                  if (item.isRewardSlot) {
                    // 奖励位占位图 - 深色渐变背景 + 彩色光晕
                    Stack() {
                      // 背景层
                      Column()
                        .width('100%')
                        .height('100%')
                        .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#3d3d3d' : '#242325')
                        .onClick(() => { this.onRewardSlotClick(); })

                      // 光斑层 - 圆角矩形包裹
                      Stack() {
                        // 装饰光晕 A - 青色
                        Column()
                          .width(640)
                          .height(640)
                          .borderRadius(320)
                          .backgroundColor('#06b6d4')
                          .opacity(this.lightAOpacity * 0.1)
                          .scale({ x: this.lightAScale * 0.3, y: this.lightAScale * 0.3 })
                          .position({ left: this.lightAOffsetX - 320, top: this.lightAOffsetY - 320 })
                        Column()
                          .width(540)
                          .height(540)
                          .borderRadius(270)
                          .backgroundColor('#06b6d4')
                          .opacity(this.lightAOpacity * 0.15)
                          .scale({ x: this.lightAScale * 0.3, y: this.lightAScale * 0.3 })
                          .position({ left: this.lightAOffsetX - 270, top: this.lightAOffsetY - 270 })
                        Column()
                          .width(440)
                          .height(440)
                          .borderRadius(220)
                          .backgroundColor('#06b6d4')
                          .opacity(this.lightAOpacity * 0.2)
                          .scale({ x: this.lightAScale * 0.3, y: this.lightAScale * 0.3 })
                          .position({ left: this.lightAOffsetX - 220, top: this.lightAOffsetY - 220 })
                        Column()
                          .width(340)
                          .height(340)
                          .borderRadius(170)
                          .backgroundColor('#06b6d4')
                          .opacity(this.lightAOpacity * 0.3)
                          .scale({ x: this.lightAScale * 0.3, y: this.lightAScale * 0.3 })
                          .position({ left: this.lightAOffsetX - 170, top: this.lightAOffsetY - 170 })
                        Column()
                          .width(240)
                          .height(240)
                          .borderRadius(120)
                          .backgroundColor('#06b6d4')
                          .opacity(this.lightAOpacity * 0.4)
                          .scale({ x: this.lightAScale * 0.3, y: this.lightAScale * 0.3 })
                          .position({ left: this.lightAOffsetX - 120, top: this.lightAOffsetY - 120 })
                        Column()
                          .width(140)
                          .height(140)
                          .borderRadius(70)
                          .backgroundColor('#FFFFFF')
                          .opacity(this.lightAOpacity * 0.25)
                          .scale({ x: this.lightAScale * 0.3, y: this.lightAScale * 0.3 })
                          .position({ left: this.lightAOffsetX - 70, top: this.lightAOffsetY - 70 })

                        // 装饰光晕 B - 橙色
                        Column()
                          .width(600)
                          .height(600)
                          .borderRadius(300)
                          .backgroundColor('#f97316')
                          .opacity(this.lightBOpacity * 0.1)
                          .scale({ x: this.lightBScale * 0.3, y: this.lightBScale * 0.3 })
                          .position({ right: this.lightBOffsetX - 300, top: this.lightBOffsetY - 300 })
                        Column()
                          .width(500)
                          .height(500)
                          .borderRadius(250)
                          .backgroundColor('#f97316')
                          .opacity(this.lightBOpacity * 0.15)
                          .scale({ x: this.lightBScale * 0.3, y: this.lightBScale * 0.3 })
                          .position({ right: this.lightBOffsetX - 250, top: this.lightBOffsetY - 250 })
                        Column()
                          .width(400)
                          .height(400)
                          .borderRadius(200)
                          .backgroundColor('#f97316')
                          .opacity(this.lightBOpacity * 0.2)
                          .scale({ x: this.lightBScale * 0.3, y: this.lightBScale * 0.3 })
                          .position({ right: this.lightBOffsetX - 200, top: this.lightBOffsetY - 200 })
                        Column()
                          .width(300)
                          .height(300)
                          .borderRadius(150)
                          .backgroundColor('#f97316')
                          .opacity(this.lightBOpacity * 0.3)
                          .scale({ x: this.lightBScale * 0.3, y: this.lightBScale * 0.3 })
                          .position({ right: this.lightBOffsetX - 150, top: this.lightBOffsetY - 150 })
                        Column()
                          .width(200)
                          .height(200)
                          .borderRadius(100)
                          .backgroundColor('#f97316')
                          .opacity(this.lightBOpacity * 0.4)
                          .scale({ x: this.lightBScale * 0.3, y: this.lightBScale * 0.3 })
                          .position({ right: this.lightBOffsetX - 100, top: this.lightBOffsetY - 100 })
                        Column()
                          .width(120)
                          .height(120)
                          .borderRadius(60)
                          .backgroundColor('#FFFFFF')
                          .opacity(this.lightBOpacity * 0.25)
                          .scale({ x: this.lightBScale * 0.3, y: this.lightBScale * 0.3 })
                          .position({ right: this.lightBOffsetX - 60, top: this.lightBOffsetY - 60 })

                        // 装饰光晕 C - 蓝色
                        Column()
                          .width(720)
                          .height(720)
                          .borderRadius(360)
                          .backgroundColor('#3b82f6')
                          .opacity(this.lightCOpacity * 0.1)
                          .scale({ x: this.lightCScale * 0.25, y: this.lightCScale * 0.25 })
                          .position({ right: this.lightCOffsetX - 360, bottom: this.lightCOffsetY - 360 })
                        Column()
                          .width(600)
                          .height(600)
                          .borderRadius(300)
                          .backgroundColor('#3b82f6')
                          .opacity(this.lightCOpacity * 0.12)
                          .scale({ x: this.lightCScale * 0.25, y: this.lightCScale * 0.25 })
                          .position({ right: this.lightCOffsetX - 300, bottom: this.lightCOffsetY - 300 })
                        Column()
                          .width(480)
                          .height(480)
                          .borderRadius(240)
                          .backgroundColor('#3b82f6')
                          .opacity(this.lightCOpacity * 0.18)
                          .scale({ x: this.lightCScale * 0.25, y: this.lightCScale * 0.25 })
                          .position({ right: this.lightCOffsetX - 240, bottom: this.lightCOffsetY - 240 })
                        Column()
                          .width(360)
                          .height(360)
                          .borderRadius(180)
                          .backgroundColor('#3b82f6')
                          .opacity(this.lightCOpacity * 0.25)
                          .scale({ x: this.lightCScale * 0.25, y: this.lightCScale * 0.25 })
                          .position({ right: this.lightCOffsetX - 180, bottom: this.lightCOffsetY - 180 })
                        Column()
                          .width(240)
                          .height(240)
                          .borderRadius(120)
                          .backgroundColor('#3b82f6')
                          .opacity(this.lightCOpacity * 0.35)
                          .scale({ x: this.lightCScale * 0.25, y: this.lightCScale * 0.25 })
                          .position({ right: this.lightCOffsetX - 120, bottom: this.lightCOffsetY - 120 })
                        Column()
                          .width(140)
                          .height(140)
                          .borderRadius(70)
                          .backgroundColor('#FFFFFF')
                          .opacity(this.lightCOpacity * 0.2)
                          .scale({ x: this.lightCScale * 0.25, y: this.lightCScale * 0.25 })
                          .position({ right: this.lightCOffsetX - 70, bottom: this.lightCOffsetY - 70 })
                      }
                      .width('100%')
                      .height('100%')
                      .borderRadius(12)
                      .clip(true)
                      .blur(50)

                      // 中层蒙版 - 黑色半透明提升文字可读性
                      Column()
                        .width('100%')
                        .height('100%')
                        .backgroundColor('rgba(0, 0, 0, 0.45)')

                      // 内容层
                      Column() {
                        if (this.rewardSlotUser) {
                          // 有用户数据：显示用户名片（无论是否当前用户认领）
                          Column() {
                            // 用户信息行
                            Row() {
                              Image(this.rewardSlotUser.avatar || DEFAULT_AVATAR)
                                .width(56)
                                .height(56)
                                .borderRadius(28)
                              Column() {
                                Text(this.rewardSlotUser.nickname.length > 12 ? this.rewardSlotUser.nickname.substring(0, 12) + '...' : this.rewardSlotUser.nickname || '匿名用户')
                                  .fontSize(18)
                                  .fontWeight(400)
                                  .fontColor('#FFFFFF')
                                  .fontFamily('DouyinFont')
                                  .margin({ bottom: 8 })
                                Row() {
                                  Text(this.rewardSlotUser.city || '')
                                    .fontSize(12)
                                    .fontColor('rgba(255,255,255,0.7)')
                                  if (this.rewardSlotUser.city && this.rewardSlotUser.roleLabel) {
                                    Text(' | ')
                                      .fontSize(12)
                                      .fontColor('rgba(255,255,255,0.4)')
                                  }
                                  Text(this.rewardSlotUser.roleLabel || '')
                                    .fontSize(12)
                                    .fontColor('rgba(255,255,255,0.7)')
                                  // 执照标签
                                  if (this.rewardSlotUser.licenseType === 'CAAC' || this.rewardSlotUser.licenseType === 'caac') {
                                    Text('CAAC')
                                      .fontSize(10)
                                      .fontColor('#FFFFFF')
                                      .backgroundColor('#22c55e')
                                      .borderRadius(4)
                                      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                                      .margin({ left: 6 })
                                  } else if (this.rewardSlotUser.licenseType === 'UTC' || this.rewardSlotUser.licenseType === 'utc') {
                                    Text('UTC')
                                      .fontSize(10)
                                      .fontColor('#FFFFFF')
                                      .backgroundColor('#3b82f6')
                                      .borderRadius(4)
                                      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                                      .margin({ left: 6 })
                                  } else if (this.rewardSlotUser.licenseType && this.rewardSlotUser.licenseType !== '已审核' && this.rewardSlotUser.licenseType !== '审核通过') {
                                    Text(this.rewardSlotUser.licenseType)
                                      .fontSize(10)
                                      .fontColor('#FFFFFF')
                                      .backgroundColor('#f59e0b')
                                      .borderRadius(4)
                                      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                                      .margin({ left: 6 })
                                  }
                                }
                                .justifyContent(FlexAlign.Start)
                              }
                              .alignItems(HorizontalAlign.Start)
                              .margin({ left: 12 })
                            }
                            .width('100%')
                            .alignItems(VerticalAlign.Center)
                            .justifyContent(FlexAlign.Start)

                            // 信息行（限制3行高度）
                            Column() {
                              // 手机
                              if (this.rewardSlotUser.phone) {
                                Row() {
                                  Image($r('app.media.icon_phone'))
                                    .width(14)
                                    .height(14)
                                    .margin({ right: 4 })
                                  Text(this.maskPhone(this.rewardSlotUser.phone))
                                    .fontSize(13)
                                    .fontColor('rgba(255,255,255,0.6)')
                                    .maxLines(1)
                                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                                }
                                .width('100%')
                                .justifyContent(FlexAlign.Start)
                              }

                              // 主营业务
                              if (this.rewardSlotUser.businessScopeText) {
                                Row() {
                                  Image($r('app.media.icon_work'))
                                    .width(14)
                                    .height(14)
                                    .margin({ right: 4 })
                                  Text(this.rewardSlotUser.businessScopeText)
                                    .fontSize(13)
                                    .fontColor('rgba(255,255,255,0.6)')
                                    .maxLines(1)
                                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                                    .layoutWeight(1)
                                }
                                .width('100%')
                                .margin({ top: 6 })
                              }

                              // 机型
                              if (this.rewardSlotUser.droneModel) {
                                Row() {
                                  Image($r('app.media.icon_device'))
                                    .width(14)
                                    .height(14)
                                    .margin({ right: 4 })
                                  Text(this.rewardSlotUser.droneModel)
                                    .fontSize(13)
                                    .fontColor('rgba(255,255,255,0.6)')
                                    .maxLines(1)
                                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                                    .layoutWeight(1)
                                }
                                .width('100%')
                                .margin({ top: 6 })
                              }
                            }
                            .width('100%')
                            .height(90)
                            .clip(true)
                            .backgroundColor('rgba(0,0,0,0.35)')
                            .borderRadius(12)
                            .padding(14)
                            .margin({ top: 12})
                          }
                          .width('95%')
                          .height('92%')
                          .padding(12)
                          .borderRadius(12)
                          .border({ width: 1, color: 'rgba(255,255,255,0.1)' })
                          .alignItems(HorizontalAlign.Start)
                          .onClick(() => { this.onRewardSlotClick(); })
                        } else {
                          // 未领取：显示标题副标题和按钮
                          Column() {
                            Text(item.title || '')
                              .fontSize(28)
                              .fontWeight(500)
                              .fontFamily('DouyinFont')
                              .fontColor('#FFFFFF')
                              .textAlign(TextAlign.Center)
                              .textShadow({
                                radius: 6,
                                color: '#87CEEB',
                                offsetX: 0,
                                offsetY: 0
                              })
                            Text(item.subtitle || '')
                              .fontSize(16)
                              .fontWeight(400)
                              .fontColor('#cffafe')
                              .textAlign(TextAlign.Center)
                              .margin({ top: 10 })
                              .textShadow({
                                radius: 4,
                                color: '#87CEEB',
                                offsetX: 0,
                                offsetY: 0
                              })
                            // 按钮 - 两侧斜切平行四边形
                            // 背景层用 matrix4 skewX 倾斜，文字层同步倾斜
                            Stack({ alignContent: Alignment.Center }) {
                              Row()
                                .width(148)
                                .height(40)
                                .borderRadius(6)
                                .linearGradient({
                                  direction: GradientDirection.Left,
                                  colors: [['#b2e933', 0], ['#4ace39', 1]]
                                })
                                .shadow({
                                  radius: 10,
                                  color: 'rgba(6, 182, 212, 0.35)',
                                  offsetX: 0,
                                  offsetY: 3
                                })
                                .transform(matrix4.identity()
                                  .combine(matrix4.init([
                                    1, 0, 0, 0,
                                    -0.2126, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                  ]))
                                )
                              Text(item.actionText || '观看解锁')
                                .fontSize(15)
                                .fontWeight(500)
                                .fontFamily('DouyinFont')
                                .fontColor('#2c2c2c')
                                .textAlign(TextAlign.Center)
                                .transform(matrix4.identity()
                                  .combine(matrix4.init([
                                    1, 0, 0, 0,
                                    -0.2126, 1, 0, 0,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1
                                  ]))
                                )
                            }
                            .width(160)
                            .height(40)
                            .margin({ top: 10 })
                            .clip(true)
                          }
                          .margin({ bottom: 16 })

                          // 统计数据
                          Row() {
                            if (this.todayActiveUsers > 0) {
                              Text('今日访问 ' + this.todayActiveUsers + ' 人')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                            if (this.todayActiveUsers > 0 && this.totalPilotCount > 0) {
                              Text(' · ')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                            if (this.totalPilotCount > 0) {
                              Text('报道飞手 ' + this.totalPilotCount + ' 人')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                            if ((this.todayActiveUsers > 0 || this.totalPilotCount > 0) && this.totalEmployerCount > 0) {
                              Text(' · ')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                            if (this.totalEmployerCount > 0) {
                              Text('注册雇主 ' + this.totalEmployerCount + ' 人')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                            if ((this.todayActiveUsers > 0 || this.totalPilotCount > 0 || this.totalEmployerCount > 0) && this.totalContactCount > 0) {
                              Text(' · ')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                            if (this.totalContactCount > 0) {
                              Text('联系记录 ' + this.totalContactCount + ' 条')
                                .fontSize(9)
                                .fontColor('#59FFFFFF')
                            }
                          }
                          .margin({ top: 8 })
                        }
                      }
                      .width('100%')
                      .height('100%')
                      .justifyContent(FlexAlign.Center)
                      .alignItems(HorizontalAlign.Center)

                      // 顶部透明点击蒙层（确保点击能传递到背景层）
                      Column()
                        .width('100%')
                        .height('100%')
                        .backgroundColor('rgba(0,0,0,0)')
                        .onClick(() => {
                          console.info('【奖励位蒙层点击】');
                          this.onRewardSlotClick();
                        })
                    }
                    .width('100%')
                    .height('100%')
                    .borderRadius(18)
                    .clip(true)
                  } else {
                    Image(item.src)
                      .width('100%')
                      .height('100%')
                      .objectFit(ImageFit.Cover)
                      .borderRadius(12)
                      .onClick(() => {
                        if (item.clickPage === '/pages/pilot-map/index') {
                          const token = AuthService.getAuthToken() || '';
                          const mapUrl = 'https://wetofly.com/map?token=' + encodeURIComponent(token);
                          console.info('【地图跳转】token: ' + (token ? '有值' : '空') + ', url: ' + mapUrl);
                          router.pushUrl({ url: 'pages/WebView', params: { url: mapUrl, title: '地图' } });
                        } else if (item.clickPage === 'pages/new/index' || item.clickPage === '/pages/new/index') {
                          router.pushUrl({ url: 'pages/CertifiedUsers' });
                        } else if (item.clickPage === 'pages/standby/index' || item.clickPage === '/pages/standby/index') {
                          router.pushUrl({ url: 'pages/Standby' });
                        } else if ((item.clickType === 'h5' || item.clickType === 'url') && item.clickUrl) {
                          router.pushUrl({ url: 'pages/WebView', params: { url: item.clickUrl, title: item.clickPage || '网页' } });
                        } else if (!this.hasValidClick(item)) {
                          // 配置参数为空，保存图片到相册
                          this.saveImageToGallery(item.src);
                        }
                      })
                  }
                })
              }
              .width('100%')
              .height(200)
              .autoPlay(false)
              .interval(8000)
              .loop(true)
              .indicator(false)
              .itemSpace(10)
              .onAnimationStart((index: number, targetIndex: number) => {
                this.currentIndex = targetIndex;
              })
              .onChange((index: number) => {
                this.currentIndex = index;
              })


            }
            .width('100%')
            .height(230)
            .padding({ left: 18, right: 18, top: 0, bottom: 0 })
            .opacity(this.bannerLoaded ? this.bannerOpacity : 0)
            .animation({ duration: 300, curve: Curve.EaseOut })

            // 自定义指示器（带动画）
            Row() {
              ForEach(this.imageList, (_: BannerItem, index: number) => {
                Blank()
                  .width(index === this.currentIndex ? 14 : 5)
                  .height(5)
                  .borderRadius(3)
                  .backgroundColor(index === this.currentIndex ? $r('app.color.indicator_selected') : $r('app.color.indicator_unselected'))
                  .animation({ duration: 200, curve: Curve.EaseOut })
                  .margin({ left: index === 0 ? 0 : 4, right: 4 })
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: -20 })

            // 今日有空
            this.StandbyList()

            // 常用功能标题
            Row() {
              Text('常用功能')
                .fontSize(17)
                .fontWeight(400)
                .fontColor($r('app.color.text_title'))
                .fontFamily('DouyinFont')
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .margin({ top: 16 })

            // 功能卡片行：2x3 网格
            Column() {
              Row() {
                this.FeatureCard({
                  title: '呼叫飞手',
                  subtitle: '发布需求',
                  iconUrl: 'https://wetofly.com/data/image/icon_find.webp',
                  onClick: () => {
                    router.pushUrl({ url: 'pages/PublishTask' });
                  }
                })
                Blank()
                this.FeatureCard({
                  title: '搜索飞手',
                  subtitle: '打造飞手库',
                  iconUrl: 'https://wetofly.com/data/image/icon_my.webp',
                  onClick: () => {
                    router.pushUrl({ url: 'pages/CertifiedUsers' });
                  }
                })
              }
              .width('100%')

              Row() {
                this.FeatureCard({
                  title: '覆盖城市',
                  subtitle: '开通城市',
                  iconUrl: $r('app.media.icon_star'),
                  onClick: () => {
                    router.pushUrl({ url: 'pages/CityCoverage' });
                  }
                })
                Blank()
                this.FeatureCard({
                  title: '共创榜单',
                  subtitle: '邀请排行',
                  iconUrl: 'https://wetofly.com/data/image/icon_my.webp',
                  onClick: () => {
                    router.pushUrl({ url: 'pages/ReferralLeaderboard' });
                  }
                })
              }
              .width('100%')
              .margin({ top: 12 })

              Row() {
                this.FeatureCard({
                  title: '个人中心',
                  subtitle: '管理资料',
                  iconUrl: 'https://wetofly.com/data/image/icon_my.webp',
                  onClick: () => {
                    router.pushUrl({ url: 'pages/Profile' });
                  }
                })
              }
              .width('100%')
              .margin({ top: 12 })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })

            // Tab切换
            Flex({ alignItems: ItemAlign.Center }) {
              Column() {
                Text('附近飞手')
                  .fontSize(17)
                  .fontWeight(400)
                  .fontColor(this.currentTab === 'pilots' ? $r('app.color.text_title') : $r('app.color.text_secondary'))
                  .fontFamily('DouyinFont')
              }
              .height(44)
              .justifyContent(FlexAlign.Center)
              .onClick(() => { this.currentTab = 'pilots'; })

              Column() {
                Text('最新任务')
                  .fontSize(17)
                  .fontWeight(400)
                  .fontColor(this.currentTab === 'orders' ? $r('app.color.text_title') : $r('app.color.text_secondary'))
                  .fontFamily('DouyinFont')
              }
              .height(44)
              .justifyContent(FlexAlign.Center)
              .margin({ left: 12 })
              .onClick(() => { this.currentTab = 'orders'; })

              Blank()

              if (this.currentTab === 'pilots') {
                Image($r('app.media.icon_search'))
                  .width(25)
                  .height(25)
                  .colorFilter(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? WHITE_FILL_MATRIX : null)
                  .margin({ right: 18 })
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/CertifiedUsers' });
                  })
              }
            }
            .width('100%')
            .padding({ left: 18, top: 6, bottom: 6 })

            // 列表内容
            if (this.currentTab === 'pilots') {
              this.PilotsList()
            } else {
              this.OrdersList()
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(false)
        .expandSafeArea([SafeAreaType.SYSTEM])
      }
      .width('100%')
      .height('100%')
      .hideBackButton(true)
      .titleBar({
        enableComponentSafeArea: true,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(20)
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#E7F8FC',
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#40000000' : '#40FFFFFF',
            }
          }
        },
        content: {
          title: { mainTitle: '' },
        }
      })
      .systemBarStyle(
        { statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#E5FFFFFF' : '#E5020202' },
        { statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#E5FFFFFF' : '#E5020202' }
      )
      .titleMode(HdsNavigationTitleMode.MINI)
      .bindToScrollable([this.scroller])
      .expandSafeArea([SafeAreaType.SYSTEM])

      // 复制成功提示
      if (this.showCopySuccess) {
        Column() {
          Text('✓ 已复制')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width(120)
        .height(120)
        .backgroundColor('rgba(0, 0, 0, 0.75)')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .position({ x: this.screenWidth / 2 - 60, y: this.screenHeight / 2 - 60 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  PilotsList() {
    if (this.pilotsLoading) {
      List() {
        ForEach([1, 2, 3], () => {
          ListItem() {
            Column() {
              // 头部：头像 + 昵称
              Row() {
                Row()
                  .width(56)
                  .height(56)
                  .borderRadius(28)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Column() {
                  Row()
                    .width(120)
                    .height(18)
                    .borderRadius(4)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .margin({ top: 4 })
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(80)
                    .height(12)
                    .borderRadius(4)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .margin({ top: 8 })
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                }
                .margin({ left: 14 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Divider()
                .color($r('app.color.divider'))
                .margin({ top: 12, bottom: 12 })

              // 信息行占位
              Row() {
                Row()
                  .width(80)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(60)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: 9 })

              Row() {
                Row()
                  .width(100)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(50)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: 9 })

              Row() {
                Row()
                  .width(70)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(90)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: 9 })

              // 按钮行占位
              Row() {
                Row()
                  .width(50)
                  .height(26)
                  .borderRadius(3)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Blank()
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .margin({ left: 16 })
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .margin({ left: 16 })
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    } else if (this.pilots.length === 0) {
      Column() {
        Text('暂无附近飞手')
          .fontColor($r('app.color.text_secondary'))
          .fontSize(13)
      }
      .width('100%')
      .padding(20)
    } else {
      List() {
        ForEach(this.pilots, (pilot: PilotItem) => {
          ListItem() {
            PilotCard({
              user: {
                openid: pilot.openid,
                nickname: pilot.nickname,
                avatar: pilot.avatar,
                city: pilot.city,
                userRole: '',
                roleLabel: pilot.roleLabel,
                licenseType: pilot.licenseType,
                licenseStatus: pilot.licenseStatus,
                pilotCode: pilot.pilotCode,
                company: pilot.company,
                position: pilot.position,
                droneModel: pilot.droneModel,
                businessScopeText: pilot.businessScopeText,
                recentActiveText: pilot.recentActiveText,
                likeCount: pilot.likeCount,
                likedByMe: pilot.likedByMe,
                phone: pilot.phone,
                wechatId: pilot.wechatId,
                douyinId: pilot.douyinId,
                distanceText: pilot.distanceText,
                isNew: pilot.isNew,
                workMu: pilot.workMu ?? null,
                workKg: pilot.workKg ?? null,
                droneImages: pilot.droneImages || [],
                channelsId: pilot.channelsId || '',
                institutionId: pilot.institutionId || '',
                licenseUrl: pilot.licenseUrl || '',
              },
              showDistance: true,
              showActions: true,
              onWechatClick: () => { this.onIconWechat(pilot); },
              onCallClick: () => { this.onIconCall(pilot); }
            })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    }
  }

  @Builder
  OrdersList() {
    if (this.ordersLoading) {
      List() {
        ForEach([1, 2, 3], () => {
          ListItem() {
            Column() {
              // 头部：头像 + 昵称
              Row() {
                Row()
                  .width(56)
                  .height(56)
                  .borderRadius(28)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Column() {
                  Row()
                    .width(100)
                    .height(18)
                    .borderRadius(4)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .margin({ top: 4 })
                    .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(120)
                    .height(12)
                    .borderRadius(4)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .margin({ top: 8 })
                    .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                }
                .margin({ left: 14 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Divider()
                .color($r('app.color.divider'))
                .margin({ top: 12, bottom: 12 })

              // 信息行占位
              Row() {
                Row()
                  .width(80)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(60)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Row() {
                Row()
                  .width(100)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(70)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: 9 })

              Row() {
                Blank()
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor($r('app.color.skeleton_bg'))
                  .margin({ left: 16 })
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    } else if (this.orders.length === 0) {
      Column() {
        Text('暂无任务')
          .fontColor($r('app.color.text_secondary'))
          .fontSize(13)
      }
      .width('100%')
      .padding(20)
    } else {
      List() {
        ForEach(this.orders, (order: OrderItem) => {
          ListItem() {
            Column() {
              // 头部：头像 + 昵称 + 公司/职位
              Row() {
                Image(order.profile.avatarUrl || 'https://wetofly.com/data/image/avatar_placeholder.webp')
                  .width(45)
                  .height(45)
                  .borderRadius(22.5)
                  .backgroundColor($r('app.color.avatar_placeholder'))

                Column() {
                  Text(order.profile.nickname || '匿名')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_title'))
                    .fontFamily('DouyinFont')
                    .margin({ top: 4 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (order.profile.company || order.profile.position) {
                    Text((order.profile.company || '') + (order.profile.company && order.profile.position ? '｜' : '') + (order.profile.position || ''))
                      .fontSize(12)
                      .fontColor($r('app.color.text_body'))
                      .margin({ top: 4 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  } else {
                    Text('雇主')
                      .fontSize(12)
                      .fontColor($r('app.color.text_body'))
                      .margin({ top: 4 })
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .justifyContent(FlexAlign.Center)
                .height(56)
                .margin({ left: 14 })
                .constraintSize({ maxWidth: 200 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              // 分隔线
              Divider()
                .color($r('app.color.divider'))
                .margin({ top: 12, bottom: 12 })

              // 所在城市
              if (order.city) {
                Row() {
                  Text('所在城市')
                    .fontSize(15)
                    .fontColor($r('app.color.text_label'))
                    .fontWeight(FontWeight.Medium)
                  Text(order.city)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }

              // 任务类型
              Row() {
                Text('任务类型')
                  .fontSize(15)
                  .fontColor($r('app.color.text_label'))
                  .fontWeight(FontWeight.Medium)
                Text(order.taskCategory)
                  .fontSize(15)
                  .fontColor($r('app.color.text_primary'))
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: 9 })

              // 任务预算
              if (order.price) {
                Row() {
                  Text('任务预算')
                    .fontSize(15)
                    .fontColor($r('app.color.text_label'))
                    .fontWeight(FontWeight.Medium)
                  Text(order.price)
                    .fontSize(15)
                    .fontColor($r('app.color.accent_orange'))
                    .fontWeight(FontWeight.Bold)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
                .margin({ top: 9 })
              }

              // 展开内容
              if (this.isOrderExpanded(order.orderId)) {
                // 飞行距离
                if (order.distanceText) {
                  Row() {
                    Text('飞行距离')
                      .fontSize(15)
                      .fontColor($r('app.color.text_label'))
                      .fontWeight(FontWeight.Medium)
                    Text(order.distanceText)
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .fontWeight(FontWeight.Medium)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .margin({ top: 9 })
                }

                // 垂直落差
                if (order.verticalDropLabel) {
                  Row() {
                    Text('垂直落差')
                      .fontSize(15)
                      .fontColor($r('app.color.text_label'))
                      .fontWeight(FontWeight.Medium)
                    Text(order.verticalDropLabel)
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .fontWeight(FontWeight.Medium)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .margin({ top: 9 })
                }

                // 单次载重
                if (order.payloadLabel) {
                  Row() {
                    Text('单次载重')
                      .fontSize(15)
                      .fontColor($r('app.color.text_label'))
                      .fontWeight(FontWeight.Medium)
                    Text(order.payloadLabel)
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .fontWeight(FontWeight.Medium)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .margin({ top: 9 })
                }

                // 订单总量
                if (order.totalOrders > 0) {
                  Row() {
                    Text('订单总量')
                      .fontSize(15)
                      .fontColor($r('app.color.text_label'))
                      .fontWeight(FontWeight.Medium)
                    Text(order.totalOrders.toString() + 'kg')
                      .fontSize(15)
                      .fontColor($r('app.color.text_primary'))
                      .fontWeight(FontWeight.Medium)
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .margin({ top: 9 })
                }

                // 备注
                if (order.notes) {
                  Text(order.notes)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .fontWeight(FontWeight.Medium)
                    .width('100%')
                    .textAlign(TextAlign.Start)
                    .margin({ top: 9 })
                }

                // 评分
                if (order.rating.score > 0) {
                  Row() {
                    Text('评价')
                      .fontSize(15)
                      .fontColor($r('app.color.text_label'))
                      .fontWeight(FontWeight.Medium)
                    Row() {
                      Text(order.rating.score.toFixed(1))
                        .fontSize(15)
                        .fontColor($r('app.color.accent_gold'))
                        .fontWeight(FontWeight.Medium)
                      if (order.rating.comment) {
                        Text(' · ' + order.rating.comment)
                          .fontSize(15)
                          .fontColor($r('app.color.text_body'))
                      }
                    }
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .margin({ top: 9 })
                }
              }

              // 展开/收起按钮
              Row() {
                Blank()
                Text(this.isOrderExpanded(order.orderId) ? '收起' : '展开')
                  .fontSize(13)
                  .fontColor($r('app.color.text_body'))
                  .fontWeight(FontWeight.Medium)
                  .onClick(() => {
                    this.toggleOrderExpand(order.orderId);
                  })
              }
              .width('100%')
              .margin({ top: 12 })

              // 分隔线
              Divider()
                .color($r('app.color.divider'))
                .margin({ top: 12 })

              // 联系图标行
              Row() {
                Blank()
                Column() {
                  Image($r('app.media.iconwechat'))
                    .width(44)
                    .height(44)
                    .onClick(() => {
                      this.onOrderWechat(order);
                    })
                }
                .alignItems(HorizontalAlign.Center)
                Column() {
                  Image($r('app.media.iconcall'))
                    .width(44)
                    .height(44)
                    .onClick(() => {
                      this.onOrderCall(order);
                    })
                }
                .alignItems(HorizontalAlign.Center)
                .margin({ left: 16 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    }
  }
}
