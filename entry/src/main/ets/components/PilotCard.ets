import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import vibrator from '@ohos.vibrator';
import window from '@ohos.window';
import { likeProfile, unlikeProfile } from '../service/ApiService';
import AuthService from '../service/AuthService';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';

export class PilotCardData {
  openid: string = '';
  nickname: string = '';
  avatar: string = '';
  city: string = '';
  userRole: string = '';
  roleLabel: string = '';
  licenseType: string = '';
  licenseStatus: string = '';
  pilotCode: string = '';
  company: string = '';
  position: string = '';
  droneModel: string = '';
  businessScopeText: string = '';
  recentActiveText: string = '';
  likeCount: number = 0;
  likedByMe: boolean = false;
  phone: string = '';
  wechatId: string = '';
  douyinId: string = '';
  distanceText: string = '';
  isNew: boolean = false;
  // 作业数据
  workMu: number | null = null;
  workKg: number | null = null;
  // 机型图片
  droneImages: string[] = [];
  // 视频号
  channelsId: string = '';
  // 机构认证
  institutionId: string = '';
  licenseUrl: string = '';
}

// ─── 图片预览弹窗参数 ─────────────────────────────────────────────────────────
// （已移除，改用 CustomDialogController 方案）

// ─── 全屏图片预览内容 ─────────────────────────────────────────────────────────
@CustomDialog
struct ImagePreviewDialog {
  imageUrls: string[] = [];
  startIndex: number = 0;
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });

  @State currentIndex: number = 0;
  @State zoomLevel: number = 1;
  @State lastScale: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State showUI: boolean = true;
  @State isScaling: boolean = false;
  @State isDragging: boolean = false;
  @State isDisableSwipe: boolean = false; // 控制 Swiper 是否禁用滑动
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  aboutToAppear() {
    this.currentIndex = this.startIndex;
    // 设置状态栏字体为白色
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarContentColor: '#FFFFFF'
        });
      });
    } catch (e) {}
  }

  aboutToDisappear() {
    // 退出时恢复状态栏字体颜色
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        const isDark = this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        win.setWindowSystemBarProperties({
          statusBarContentColor: isDark ? '#FFFFFF' : '#14233a'
        });
      });
    } catch (e) {}
  }

  resetZoom() {
    animateTo({ duration: 200 }, () => {
      this.zoomLevel = 1;
      this.lastScale = 1;
      this.offsetX = 0;
      this.offsetY = 0;
    });
  }

  toggleZoom() {
    if (this.zoomLevel > 1) {
      this.resetZoom();
    } else {
      animateTo({ duration: 200 }, () => {
        this.zoomLevel = 2;
        this.lastScale = 2;
      });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {

      // 图片 Swiper
      Swiper() {
        ForEach(this.imageUrls, (url: string) => {
          Image(url)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.zoomLevel, y: this.zoomLevel })
            .translate({ x: this.offsetX, y: this.offsetY })
            .gesture(GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 })
                .onAction(() => { this.toggleZoom(); }),
              PinchGesture()
                .onActionStart(() => {
                  this.isScaling = true;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.zoomLevel = Math.max(0.5, Math.min(4, this.lastScale * event.scale));
                  this.isDisableSwipe = this.zoomLevel > 1;
                })
                .onActionEnd(() => {
                  this.lastScale = this.zoomLevel;
                  this.isScaling = false;
                  this.isDisableSwipe = this.zoomLevel > 1;
                  if (this.zoomLevel < 1) { this.resetZoom(); }
                }),
              PanGesture({ fingers: 1, distance: this.isDisableSwipe ? 3 : 50 })
                .onActionStart(() => {
                  this.isDragging = true;
                })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.zoomLevel > 1) {
                    // 放大状态：拖动图片，按比例计算偏移
                    let maxOffsetX = (this.zoomLevel - 1) * 200;
                    let maxOffsetY = (this.zoomLevel - 1) * 200;
                    this.offsetX = Math.max(-maxOffsetX, Math.min(maxOffsetX, this.offsetX + event.offsetX));
                    this.offsetY = Math.max(-maxOffsetY, Math.min(maxOffsetY, this.offsetY + event.offsetY));
                  }
                })
                .onActionEnd(() => {
                  this.isDragging = false;
                })
            ))
        })
      }
      .index(this.currentIndex)
      .indicator(false)
      .loop(false)
      .duration(300)
      .disableSwipe(this.isDisableSwipe)
      .onClick(() => { this.showUI = !this.showUI; })
      .onChange((index: number) => {
        this.currentIndex = index;
        this.zoomLevel = 1; this.lastScale = 1;
        this.offsetX = 0; this.offsetY = 0;
        this.isDisableSwipe = false;
      })
      .width('100%')
      .height('100%')

      // 顶部栏
      if (this.showUI) {
        Row() {
          if (this.imageUrls.length > 1) {
            Text(`${this.currentIndex + 1} / ${this.imageUrls.length}`)
              .fontSize(16)
              .fontColor('#FFFFFF')
          }
          Blank()
          Text('✕')
            .fontSize(26)
            .fontColor('#FFFFFF')
            .padding(8)
            .onClick(() => { this.controller.close(); })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 48, bottom: 12 })
      }

      // 底部指示点
      if (this.showUI && this.imageUrls.length > 1) {
        Row() {
          ForEach(this.imageUrls, (_url: string, idx: number) => {
            Circle({ width: 7, height: 7 })
              .fill(idx === this.currentIndex ? '#FFFFFF' : 'rgba(255,255,255,0.4)')
              .margin({ left: 4, right: 4 })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 40 })
        .alignSelf(ItemAlign.End)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0)')
    .expandSafeArea([SafeAreaType.SYSTEM])
  }
}

// ─── PilotCard ───────────────────────────────────────────────────────────────
@Component
export struct PilotCard {
  // 颜色模式监听（跟随系统深浅色）
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  // 用户数据
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
  // 是否显示距离标签（附近飞手用）
  showDistance: boolean = false;
  // 是否显示操作按钮（拨号/微信）
  showActions: boolean = false;
  // 是否显示最近活跃
  showRecentActive: boolean = true;
  // 点赞状态（内部管理）
  @State internalLikeCount: number = 0;
  @State internalLikedByMe: boolean = false;

  // 微信点击回调
  onWechatClick?: (openid: string) => void;
  // 电话点击回调
  onCallClick?: (openid: string) => void;
  // 点赞状态变化回调
  onLikeChanged?: (likeCount: number, likedByMe: boolean) => void;
  // 在「我赞过」标签下点击取消时直接移除的回调
  onUnlikeInLikedTab?: () => void;

  // 图片预览 controller（在组件实例内声明，绑定到当前 UI 上下文）
  private previewUrls: string[] = [];
  private previewStartIndex: number = 0;
  private previewController: CustomDialogController = new CustomDialogController({
    builder: ImagePreviewDialog({
      imageUrls: this.previewUrls,
      startIndex: this.previewStartIndex,
    }),
    customStyle: true,
    maskColor: '#000000',
    backgroundColor: '#000000',
    alignment: DialogAlignment.Center,
    offset: { dx: 0, dy: 0 }
  });

  openPreview(urls: string[], index: number) {
    // 关闭旧的再重建，确保数据更新
    try { this.previewController.close(); } catch (_) {}
    this.previewUrls = urls;
    this.previewStartIndex = index;
    this.previewController = new CustomDialogController({
      builder: ImagePreviewDialog({
        imageUrls: urls,
        startIndex: index,
      }),
      customStyle: true,
      maskColor: '#000000',
      backgroundColor: '#000000',
      alignment: DialogAlignment.Center,
      offset: { dx: 0, dy: 0 }
    });
    this.previewController.open();
  }

  aboutToAppear() {
    this.internalLikeCount = this.user.likeCount ?? 0;
    this.internalLikedByMe = this.user.likedByMe ?? false;
  }

  aboutToReuse(params: Record<string, Object>) {
    const userParam = params['user'] as PilotCardData;
    if (userParam) {
      this.internalLikeCount = userParam.likeCount ?? 0;
      this.internalLikedByMe = userParam.likedByMe ?? false;
    }
  }

  async handleLikeClick() {
    // 同步 internal 状态与 user prop
    if (this.internalLikedByMe !== this.user.likedByMe || this.internalLikeCount !== this.user.likeCount) {
      this.internalLikedByMe = this.user.likedByMe ?? false;
      this.internalLikeCount = this.user.likeCount ?? 0;
    }

    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: 'touch' });
    } catch (e) {}

    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    const currentUser = AuthService.getCurrentUser();
    if (currentUser && currentUser.openId === this.user.openid) {
      promptAction.showToast({ message: '不能给自己点赞' });
      return;
    }

    const prevLiked = this.internalLikedByMe;
    const prevCount = this.internalLikeCount;
    const nextLiked = !prevLiked;
    const optimisticCount = Math.max(0, (prevCount ?? 0) + (nextLiked ? 1 : -1));

    this.internalLikedByMe = nextLiked;
    this.internalLikeCount = optimisticCount;

    if (!nextLiked && this.onUnlikeInLikedTab) {
      this.onUnlikeInLikedTab();
    }

    try {
      const res = nextLiked
        ? await likeProfile(this.user.openid, token)
        : await unlikeProfile(this.user.openid, token);

      this.internalLikedByMe = res.liked_by_me;
      if (!nextLiked && res.liked_by_me === false && res.like_count === prevCount) {
        this.internalLikeCount = optimisticCount;
      } else {
        this.internalLikeCount = res.like_count;
      }
      this.user.likeCount = this.internalLikeCount;
      this.user.likedByMe = res.liked_by_me;
      this.onLikeChanged?.(res.like_count, res.liked_by_me);
    } catch (err) {
      this.internalLikedByMe = prevLiked;
      this.internalLikeCount = prevCount;
      console.error('【点赞失败】', JSON.stringify(err));
      promptAction.showToast({ message: '操作失败' });
    }
  }

  build() {
    Column() {
      // 头部：头像 + 昵称 + 星星
      Row() {
        Image(this.user.avatar || DEFAULT_AVATAR)
          .width(45)
          .height(45)
          .borderRadius(22.5)
          .backgroundColor($r('app.color.avatar_placeholder'))
          .onClick(() => {
            this.openPreview([this.user.avatar || DEFAULT_AVATAR], 0);
          })

        Column() {
          Text(this.user.nickname.length > 12 ? this.user.nickname.substring(0, 12) + '...' : this.user.nickname)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_title'))
            .fontFamily('DouyinSansBold')
            .margin({ top: 4 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.user.pilotCode) {
            Row() {
              Image($r('app.media.icon_banner'))
                .width(22)
                .height(22)
                .objectFit(ImageFit.Contain)
              Text(this.user.pilotCode)
                .fontSize(12)
                .fontColor($r('app.color.text_body'))
                .margin({ left: 4 })
            }
            .margin({ top: 4 })
          } else if (this.user.company) {
            Text(this.user.company + (this.user.position ? ' ' + this.user.position : ''))
              .fontSize(12)
              .fontColor($r('app.color.text_body'))
              .margin({ top: 4 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else if (this.user.roleLabel) {
            Text(this.user.roleLabel)
              .fontSize(12)
              .fontColor($r('app.color.text_body'))
              .margin({ top: 4 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
        .height(56)
        .margin({ left: 14 })
        .constraintSize({ maxWidth: 200 })

        Blank().layoutWeight(1)

        Column() {
          Image(this.user.isNew ? $r('app.media.icon_star2') : $r('app.media.icon_star1'))
            .width(20)
            .height(20)
          Text(String(this.internalLikeCount))
            .fontSize(12)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Bold)
            .margin({ top: 8 })
            .visibility(this.internalLikeCount > 0 ? Visibility.Visible : Visibility.None)
        }
        .alignItems(HorizontalAlign.Center)
        .height(44)
        .padding({ left: 12, right: -14 })
        .margin({ left: 14 })
        .onClick(() => this.handleLikeClick())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Divider()
        .color($r('app.color.divider'))
        .margin({ top: 12, bottom: 12 })

      // 最近活跃
      if (this.showRecentActive) {
        Row() {
          Text('最近活跃')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Text(this.user.recentActiveText || '--')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 认证状态
      Row() {
        Text('认证状态')
          .fontSize(14)
          .fontColor($r('app.color.text_label'))
          .fontWeight(FontWeight.Medium)
        Row() {
          if (this.user.licenseType) {
            Text(this.user.licenseType.toUpperCase())
              .fontSize(10)
              .fontColor('#FFFFFF')
              .backgroundColor(this.user.licenseType.toLowerCase() === 'utc' ? $r('app.color.primary_color') : $r('app.color.accent_green'))
              .borderRadius(3)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ right: 12 })
          }
          Text(this.user.licenseStatus)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 9 })

      // 所在城市
      if (this.user.city) {
        Row() {
          Text('所在城市')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Text(this.user.city)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 主营业务
      if (this.user.businessScopeText) {
        Row() {
          Text('主营业务')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Text(this.user.businessScopeText)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 常用机型
      if (this.user.droneModel && this.user.droneModel !== '--' && this.user.userRole !== 'employer') {
        Row() {
          Text('常用机型')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Text(this.user.droneModel)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 作业数据（亩/千克）
      if (this.user.workMu != null || this.user.workKg != null) {
        Row() {
          Text('任务进度')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Row() {
            if (this.user.workMu != null) {
              Text(this.user.workMu + '亩')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Medium)
            }
            if (this.user.workMu != null && this.user.workKg != null) {
              Text(' / ')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
            }
            if (this.user.workKg != null) {
              Text(this.user.workKg + '千克')
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .fontWeight(FontWeight.Medium)
            }
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 机构认证
      if (this.user.institutionId) {
        Row() {
          Text('机构认证')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Text('已认证')
            .fontSize(14)
            .fontColor($r('app.color.accent_green'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 视频号
      if (this.user.channelsId) {
        Row() {
          Text('视频号')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
          Text(this.user.channelsId)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 9 })
      }

      // 机型图片横滑
      if (this.user.droneImages && this.user.droneImages.length > 0) {
        Column() {
          Text('机型图片')
            .fontSize(14)
            .fontColor($r('app.color.text_label'))
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 9 })
          Scroll() {
            Row() {
              ForEach(this.user.droneImages, (img: string, index: number) => {
                Image(img)
                  .width(80)
                  .height(60)
                  .borderRadius(4)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.openPreview(this.user.droneImages, index);
                  })
              })
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      // 底部操作区域
      if (this.showActions || this.showDistance) {
        Divider()
          .color($r('app.color.divider'))
          .margin({ top: 12 })

        Row() {
          Row() {
            if (this.showDistance && this.user.distanceText) {
              Text(this.user.distanceText)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#07c160' : 'rgba(0, 0, 0, 0.1)')
                .borderRadius(3)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            }
            Blank()
            if (this.showActions) {
              Column() {
                Image($r('app.media.iconwechat'))
                  .width(44)
                  .height(44)
                  .onClick(() => {
                    this.onWechatClick?.(this.user.openid);
                  })
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ left: 12 })

              Column() {
                Image($r('app.media.iconcall'))
                  .width(44)
                  .height(44)
                  .onClick(() => this.onCallClick?.(this.user.openid))
              }
              .alignItems(HorizontalAlign.Center)
              .margin({ left: 16 })
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.card_bg_secondary'))
          .borderRadius(11)
          .padding({ left: 16, right: 16, top: 11, bottom: 11 })
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(22)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ bottom: 12 })
  }
}
