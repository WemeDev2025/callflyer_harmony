import router from '@ohos.router';
import { BannerItem, PilotItem, OrderItem, PilotContact, fetchBanners, fetchNearbyPilots, fetchPublicOrders, fetchPilotContact, reportVisit, registerPushToken, fetchStandby, StandbyItem } from '../service/ApiService';
import display from '@ohos.display';
import AuthService, { HuaweiUserInfo } from '../service/AuthService';
import LocationService from '../service/LocationService';
import { pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import type { Context } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import call from '@ohos.telephony.call';
import pasteboard from '@ohos.pasteboard';
import curves from '@ohos.curves';
import { imagePreview } from '../components/imagepreview/ImagePreview';
import window from '@ohos.window';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { PilotCard, PilotCardData } from '../components/PilotCard';
import http from '@ohos.net.http';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';

// 防抖标记：确保每次启动只上报一次访问
let visitReported = false;

interface FeatureCardParam {
  title: string;
  subtitle: string;
  iconUrl: string;
  onClick: () => void;
}

interface SystemBarStyleInterface {
  statusBarContentColor?: string;
}

/**
 * 首页 - 轮播图 + 附近飞手 + 最新任务
 */
@Entry
@Component
struct Index {
  // 滚动控制器
  scroller: Scroller = new Scroller();

  // 轮播图
  @State imageList: BannerItem[] = [];
  @State currentIndex: number = 0;
  @State bannerLoaded: boolean = false;
  @State autoplay: boolean = true;

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
  @State expandedStandbyItem: StandbyItem | null = null;
  @State expandedPilotCardData: PilotCardData | null = null;
  @State showExpandedStandby: boolean = false;
  @State showCopySuccess: boolean = false;
  @State screenWidth: number = 360;
  @State screenHeight: number = 780;
  @State navBarHeight: number = 0;

  // 登录状态
  @State isLoggedIn: boolean = false;
  @State userInfo: HuaweiUserInfo | null = null;

  @State statusBarHeight: number = 0;

  aboutToAppear() {
    this.loadBanner();
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
    });

    // 获取状态栏高度
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        this.statusBarHeight = px2vp(avoidArea.topRect.height);
        console.info('状态栏高度:', this.statusBarHeight, 'vp');
        // 状态栏透明 + 黑色文字
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: '#14233a'
        });
      });
    } catch (e) {
      console.info('获取状态栏高度失败', JSON.stringify(e));
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

  handleLogout() {
    AuthService.logout();
    this.isLoggedIn = false;
    this.userInfo = null;
    console.info('【登录】已退出');
  }

  async loadBanner() {
    try {
      const banners = await fetchBanners();
      this.imageList = banners.length > 0 ? banners : this.getDefaultBanners();
    } catch {
      this.imageList = this.getDefaultBanners();
    }
    this.bannerLoaded = true;
  }

  async loadPilots() {
    this.pilotsLoading = true;
    this.startSkeletonShimmer();
    try {
      const context = getContext(this) as Context;
      const location = await LocationService.getCurrentLocation(context);
      this.pilotsLat = location?.latitude ?? 39.9;
      this.pilotsLng = location?.longitude ?? 116.4;
      const result = await fetchNearbyPilots(this.pilotsLat, this.pilotsLng, 1, 50);
      this.pilots = result.pilots;
    } catch {
      this.pilots = [];
    }
    this.pilotsLoading = false;
    this.stopSkeletonShimmer();
  }

  async loadOrders() {
    this.ordersLoading = true;
    this.startOrdersSkeletonShimmer();
    try {
      this.orders = await fetchPublicOrders();
    } catch {
      this.orders = [];
    }
    this.ordersLoading = false;
    this.stopOrdersSkeletonShimmer();
  }

  async loadStandby() {
    try {
      const result = await fetchStandby();
      this.standbyItems = result.items;
      console.info('【今日有空】加载成功，数量:', this.standbyItems.length);
    } catch (err) {
      console.error('【今日有空】加载失败:', JSON.stringify(err));
      this.standbyItems = [];
    }
    // 获取屏幕尺寸（转换为vp）
    try {
      const d = display.getDefaultDisplaySync();
      this.screenWidth = px2vp(d.width);
      this.screenHeight = px2vp(d.height);
    } catch (e) {}
  }

  onStandbyCardTap(item: StandbyItem) {
    this.expandedStandbyItem = item;
    const p = item.profile;
    this.expandedPilotCardData = {
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
      businessScopeText: p.businessScopeText || '',
      recentActiveText: p.recentActiveText || '',
      likeCount: item.likeCount ?? 0,
      likedByMe: false,
      phone: p.phone || '',
      wechatId: p.wechatId || '',
      distanceText: '',
      isNew: p.isNew,
    };
    this.showExpandedStandby = true;
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
          // 同步更新 standbyItems
          const idx = this.standbyItems.findIndex(item => item.openid === this.expandedStandbyItem?.openid);
          if (idx >= 0) {
            this.standbyItems[idx].likeCount = likeCount;
          }
          // 同步更新 expandedStandbyItem
          if (this.expandedStandbyItem) {
            this.expandedStandbyItem.likeCount = likeCount;
          }
          // 同步更新 expandedPilotCardData
          if (this.expandedPilotCardData) {
            this.expandedPilotCardData.likeCount = likeCount;
            this.expandedPilotCardData.likedByMe = likedByMe;
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

  // 保存网络图片到本地相册（使用安全弹窗方式，无需WRITE权限）
  async saveImageToGallery(imageUrl: string): Promise<void> {
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
      const tempFilePath = tempDir + '/' + tempFileName;
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

      const resultUris = await helper.showAssetsCreationDialog(
        [fileUri.getUriFromPath(tempFilePath)],
        [photoCreationConfig]
      );
      console.info('【保存图片】安全弹窗结果: ' + JSON.stringify(resultUris));

      // 删除临时文件
      try {
        fileIo.unlinkSync(tempFilePath);
      } catch (e) {}

      if (resultUris && resultUris.length > 0) {
        console.info('【保存图片】成功: ' + resultUris[0]);
        promptAction.showToast({ message: '已保存到相册' });
      } else {
        console.info('【保存图片】用户取消保存');
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : JSON.stringify(e);
      console.error('【保存图片】异常: ' + errMsg);
      promptAction.showToast({ message: '保存失败: ' + errMsg });
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
            .fontColor('#14233a')
            .fontWeight(FontWeight.Medium)
            .fontFamily('DouyinSansBold')
          Text(param.subtitle)
            .fontSize(12)
            .fontColor('#6f7c90')
            .fontFamily('DouyinSansBold')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 14 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
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
          .fontColor('#14233a')
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
          .fontWeight(FontWeight.Bold)
          .fontColor('#14233a')
          .fontFamily('DouyinSansBold')
      }
      .width('100%')
      .padding({ left: 18 })
      .margin({ bottom: 12, top: 22 })

      // 白色圆角容器
      Column() {
        // 横向滚动卡片列表
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
                    .backgroundColor('#dfe4ec')

                  Column() {
                    Text(item.profile.nickname)
                      .fontSize(14)
                      .fontWeight(700)
                      .fontColor('#1d2b3a')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (item.profile.city) {
                      Text(item.profile.city)
                        .fontSize(12)
                        .fontColor('#8a96a8')
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
                      .fontColor('#b0b8c8')
                      .fontWeight(600)
                      .margin({ left: 3 })
                  }
                  .width(36)
                  .justifyContent(FlexAlign.Center)

                  Text(item.viewCount > 0 ? '浏览 ' + item.viewCount + ' 次' : '暂无查看')
                    .fontSize(10)
                    .fontColor('#b0b8c8')
                    .fontWeight(500)
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
              .backgroundColor('rgba(33, 98, 226, 0.04)')
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
      .width('90%')
      .padding({ top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')
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
        .fontSize(14)
        .fontColor('#455066')
        .fontWeight(FontWeight.Medium)
      Text(value)
        .fontSize(14)
        .fontColor('#1f2a3a')
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
        .backgroundColor('#E7F8FC')
        .expandSafeArea([SafeAreaType.SYSTEM])
        .clip(false)

      HdsNavigation() {
        Scroll(this.scroller) {
          Column() {
            // 占位，让内容穿过导航栏
            Column().width('100%').height(56)

            // 轮播图（固定高度，防止布局跳动）
            Column() {
              Swiper() {
                ForEach(this.imageList, (item: BannerItem) => {
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
                      } else if ((item.clickType === 'h5' || item.clickType === 'url') && item.clickUrl) {
                        router.pushUrl({ url: 'pages/WebView', params: { url: item.clickUrl, title: item.clickPage || '网页' } });
                      } else if (!this.hasValidClick(item)) {
                        // 配置参数为空，保存图片到相册
                        this.saveImageToGallery(item.src);
                      }
                    })
                })
              }
              .width('100%')
              .height(200)
              .autoPlay(this.autoplay)
              .interval(8000)
              .loop(true)
              .indicator(false)
              .itemSpace(10)
              .onChange((index: number) => {
                this.currentIndex = index;
              })
            }
            .width('100%')
            .height(200)
            .padding({ left: 18, right: 18, top: 0, bottom: 0 })
            .margin({ top: -100 })
            .opacity(this.bannerLoaded ? 1 : 0)

            // 今日有空
            this.StandbyList()

            // 常用功能标题
            Row() {
              Text('常用功能')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#14233a')
                .fontFamily('DouyinSansBold')
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .margin({ top: 16 })

            // 功能卡片行：搜索飞手 + 个人中心 + 覆盖城市
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
              this.FeatureCard({
                title: '搜索飞手',
                subtitle: '打造飞手库',
                iconUrl: 'https://wetofly.com/data/image/icon_my.webp',
                onClick: () => {
                  router.pushUrl({ url: 'pages/CertifiedUsers' });
                }
              })

              this.FeatureCard({
                title: '个人中心',
                subtitle: '管理资料',
                iconUrl: 'https://wetofly.com/data/image/icon_my.webp',
                onClick: () => {
                  router.pushUrl({ url: 'pages/Profile' });
                }
              })

              Column() {
                this.FeatureCard({
                  title: '覆盖城市',
                  subtitle: '开通城市',
                  iconUrl: 'https://wetofly.com/data/image/icon_my.webp',
                  onClick: () => {
                    router.pushUrl({ url: 'pages/CityCoverage' });
                  }
                })
              }
              .margin({ top: 12 })
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })

            // Tab切换
            Flex({ alignItems: ItemAlign.Center }) {
              Column() {
                Text('附近飞手')
                  .fontSize(17)
                  .fontWeight(this.currentTab === 'pilots' ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.currentTab === 'pilots' ? '#14233a' : '#999999')
                  .fontFamily('DouyinSansBold')
              }
              .height(44)
              .justifyContent(FlexAlign.Center)
              .onClick(() => { this.currentTab = 'pilots'; })

              Column() {
                Text('最新任务')
                  .fontSize(17)
                  .fontWeight(this.currentTab === 'orders' ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(this.currentTab === 'orders' ? '#14233a' : '#999999')
                  .fontFamily('DouyinSansBold')
              }
              .height(44)
              .justifyContent(FlexAlign.Center)
              .margin({ left: 12 })
              .onClick(() => { this.currentTab = 'orders'; })
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
              backgroundColor: '#000000',
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#40FFFFFF',
            }
          }
        },
        content: {
          title: { mainTitle: '' },
        }
      })
      .systemBarStyle(
        { statusBarContentColor: '#E5020202' },
        { statusBarContentColor: '#E5020202' }
      )
      .titleMode(HdsNavigationTitleMode.MINI)
      .bindToScrollable([this.scroller])
      .expandSafeArea([SafeAreaType.SYSTEM])

      // 今日有空弹窗
      this.ExpandedStandbyOverlay()

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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Column() {
                  Row()
                    .width(120)
                    .height(18)
                    .borderRadius(4)
                    .backgroundColor('#E8E8E8')
                    .margin({ top: 4 })
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(80)
                    .height(12)
                    .borderRadius(4)
                    .backgroundColor('#E8E8E8')
                    .margin({ top: 8 })
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                }
                .margin({ left: 14 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Divider()
                .color('rgba(99, 105, 117, 0.15)')
                .margin({ top: 12, bottom: 12 })

              // 信息行占位
              Row() {
                Row()
                  .width(80)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(60)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(50)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(90)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Blank()
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor('#E8E8E8')
                  .margin({ left: 16 })
                  .opacity(this.skeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor('#E8E8E8')
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
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    } else if (this.pilots.length === 0) {
      Column() {
        Text('暂无附近飞手')
          .fontColor('#999999')
          .fontSize(14)
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
                distanceText: pilot.distanceText,
                isNew: pilot.isNew,
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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Column() {
                  Row()
                    .width(100)
                    .height(18)
                    .borderRadius(4)
                    .backgroundColor('#E8E8E8')
                    .margin({ top: 4 })
                    .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(120)
                    .height(12)
                    .borderRadius(4)
                    .backgroundColor('#E8E8E8')
                    .margin({ top: 8 })
                    .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                }
                .margin({ left: 14 })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)

              Divider()
                .color('rgba(99, 105, 117, 0.15)')
                .margin({ top: 12, bottom: 12 })

              // 信息行占位
              Row() {
                Row()
                  .width(80)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(60)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(70)
                  .height(15)
                  .borderRadius(4)
                  .backgroundColor('#E8E8E8')
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
                  .backgroundColor('#E8E8E8')
                  .opacity(this.ordersSkeletonShimmer ? 1 : 0.4)
                  .animation({ duration: 300 })
                Row()
                  .width(44)
                  .height(44)
                  .borderRadius(22)
                  .backgroundColor('#E8E8E8')
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
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    } else if (this.orders.length === 0) {
      Column() {
        Text('暂无任务')
          .fontColor('#999999')
          .fontSize(14)
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
                  .backgroundColor('#dfe4ec')

                Column() {
                  Text(order.profile.nickname || '匿名')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#14233a')
                    .fontFamily('DouyinSansBold')
                    .margin({ top: 4 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (order.profile.company || order.profile.position) {
                    Text((order.profile.company || '') + (order.profile.company && order.profile.position ? '｜' : '') + (order.profile.position || ''))
                      .fontSize(12)
                      .fontColor('#6f7c90')
                      .margin({ top: 4 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  } else {
                    Text('雇主')
                      .fontSize(12)
                      .fontColor('#6f7c90')
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
                .color('rgba(99, 105, 117, 0.15)')
                .margin({ top: 12, bottom: 12 })

              // 所在城市
              if (order.city) {
                Row() {
                  Text('所在城市')
                    .fontSize(15)
                    .fontColor('#455066')
                    .fontWeight(FontWeight.Medium)
                  Text(order.city)
                    .fontSize(15)
                    .fontColor('#1f2a3a')
                    .fontWeight(FontWeight.Medium)
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }

              // 任务类型
              Row() {
                Text('任务类型')
                  .fontSize(15)
                  .fontColor('#455066')
                  .fontWeight(FontWeight.Medium)
                Text(order.taskCategory)
                  .fontSize(15)
                  .fontColor('#1f2a3a')
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
                    .fontColor('#455066')
                    .fontWeight(FontWeight.Medium)
                  Text(order.price)
                    .fontSize(15)
                    .fontColor('#FF6F4D')
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
                      .fontColor('#455066')
                      .fontWeight(FontWeight.Medium)
                    Text(order.distanceText)
                      .fontSize(15)
                      .fontColor('#1f2a3a')
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
                      .fontColor('#455066')
                      .fontWeight(FontWeight.Medium)
                    Text(order.verticalDropLabel)
                      .fontSize(15)
                      .fontColor('#1f2a3a')
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
                      .fontColor('#455066')
                      .fontWeight(FontWeight.Medium)
                    Text(order.payloadLabel)
                      .fontSize(15)
                      .fontColor('#1f2a3a')
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
                      .fontColor('#455066')
                      .fontWeight(FontWeight.Medium)
                    Text(order.totalOrders.toString() + 'kg')
                      .fontSize(15)
                      .fontColor('#1f2a3a')
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
                    .fontColor('#1f2a3a')
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
                      .fontColor('#455066')
                      .fontWeight(FontWeight.Medium)
                    Row() {
                      Text(order.rating.score.toFixed(1))
                        .fontSize(15)
                        .fontColor('#FFB800')
                        .fontWeight(FontWeight.Medium)
                      if (order.rating.comment) {
                        Text(' · ' + order.rating.comment)
                          .fontSize(15)
                          .fontColor('#6f7c90')
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
                  .fontSize(14)
                  .fontColor('#6f7c90')
                  .fontWeight(FontWeight.Medium)
                  .onClick(() => {
                    this.toggleOrderExpand(order.orderId);
                  })
              }
              .width('100%')
              .margin({ top: 12 })

              // 分隔线
              Divider()
                .color('rgba(99, 105, 117, 0.15)')
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
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
        })
      }
      .padding({ left: 18, right: 18 })
    }
  }
}
