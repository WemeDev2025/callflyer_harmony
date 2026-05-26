import router from '@ohos.router';
import { BannerItem, PilotItem, OrderItem, PilotContact, fetchBanners, fetchNearbyPilots, fetchPublicOrders, fetchPilotContact, reportVisit } from '../service/ApiService';
import AuthService, { HuaweiUserInfo } from '../service/AuthService';
import LocationService from '../service/LocationService';
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
      }
    } else {
      console.error('【登录】失败:', result.error);
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

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#E7F8FC')
        .expandSafeArea([SafeAreaType.SYSTEM])

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

            // 功能卡片行：职业飞手库 + 个人中心
            Row() {
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
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 16 })
            .justifyContent(FlexAlign.SpaceBetween)

            // Tab切换
            Row() {
              Text('附近飞手')
                .fontSize(17)
                .fontWeight(this.currentTab === 'pilots' ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.currentTab === 'pilots' ? '#14233a' : '#999999')
                .fontFamily('DouyinSansBold')
                .onClick(() => { this.currentTab = 'pilots'; })
                .margin({ right: 16 })

              Text('最新任务')
                .fontSize(17)
                .fontWeight(this.currentTab === 'orders' ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.currentTab === 'orders' ? '#14233a' : '#999999')
                .fontFamily('DouyinSansBold')
                .onClick(() => { this.currentTab = 'orders'; })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .padding({ left: 18, top: 6, bottom: 22 })

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
                  .width(56)
                  .height(56)
                  .borderRadius(28)
                  .backgroundColor('#dfe4ec')

                Column() {
                  Text(order.profile.nickname || '匿名')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#14233a')
                    .fontFamily('DouyinSansBold')
                    .margin({ top: 4 })
                  if (order.profile.company || order.profile.position) {
                    Text((order.profile.company || '') + (order.profile.company && order.profile.position ? '｜' : '') + (order.profile.position || ''))
                      .fontSize(12)
                      .fontColor('#6f7c90')
                      .margin({ top: 4 })
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
