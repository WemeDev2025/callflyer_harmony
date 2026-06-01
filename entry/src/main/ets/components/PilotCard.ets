import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import vibrator from '@ohos.vibrator';
import window from '@ohos.window';
import { matrix4 } from '@kit.ArkUI';
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

// ─── 图片预览器状态管理（@Observed）────────────────────────────────────────────
@Observed
class ImagePreviewModel {
  // 当前缩放值
  curScale: number = 1;
  // 当前偏移 X
  curOffsetX: number = 0;
  // 当前偏移 Y
  curOffsetY: number = 0;
  // 上次缩放值（手势结束时固化）
  lastScale: number = 1;
  // 上次偏移 X
  lastOffsetX: number = 0;
  // 上次偏移 Y
  lastOffsetY: number = 0;
  // 最小缩放
  minScale: number = 0.5;
  // 最大缩放
  maxScale: number = 3;
  // 默认缩放（fit to screen）
  defaultScale: number = 1;
  // 缩放中心百分比 X（相对于图片内容）
  centerX: number = 0.5;
  // 缩放中心百分比 Y
  centerY: number = 0.5;
  // 屏幕宽度
  screenWidth: number = 360;
  // 屏幕高度
  screenHeight: number = 780;
  // 当前图片显示宽度（fit 之后）
  imageWidth: number = 300;
  // 当前图片显示高度
  imageHeight: number = 200;
  // 是否禁用 Swiper 切换
  isDisableSwipe: boolean = false;
  // 是否到达边界
  isArriveBoundary: boolean = false;

  // 偏移范围
  maxOffsetX: number = 0;
  minOffsetX: number = 0;
  maxOffsetY: number = 0;
  minOffsetY: number = 0;

  // 手势结束，固化当前状态
  gestureEnd(): void {
    this.lastScale = this.curScale;
    this.lastOffsetX = this.curOffsetX;
    this.lastOffsetY = this.curOffsetY;
  }

  // 重置偏移
  offsetReset(): void {
    this.curOffsetX = 0;
    this.curOffsetY = 0;
    this.lastOffsetX = 0;
    this.lastOffsetY = 0;
  }

  // 重置图片（切图时调用）
  imageReset(): void {
    this.curScale = this.defaultScale;
    this.lastScale = this.defaultScale;
    this.offsetReset();
    this.isDisableSwipe = false;
  }

  // 计算偏移范围（根据当前 scale + 图片尺寸 + 屏幕尺寸）
  evaluateOffsetRange(): void {
    let scaledImageWidth = this.imageWidth * this.curScale;
    let scaledImageHeight = this.imageHeight * this.curScale;

    // X 轴边界
    if (scaledImageWidth > this.screenWidth) {
      let maxX = (scaledImageWidth - this.screenWidth) / 2;
      this.maxOffsetX = maxX;
      this.minOffsetX = -maxX;
    } else {
      this.maxOffsetX = 0;
      this.minOffsetX = 0;
    }

    // Y 轴边界
    if (scaledImageHeight > this.screenHeight) {
      let maxY = (scaledImageHeight - this.screenHeight) / 2;
      this.maxOffsetY = maxY;
      this.minOffsetY = -maxY;
    } else {
      this.maxOffsetY = 0;
      this.minOffsetY = 0;
    }
  }

  // 计算缩放中心相对于图片的百分比位置
  // pinchCenterX/Y 是相对于屏幕左上角的绝对坐标
  evaluateCenter(pinchCenterX: number, pinchCenterY: number): [number, number] {
    let scaledW = this.imageWidth * this.lastScale;
    let scaledH = this.imageHeight * this.lastScale;
    // 图片左上角在屏幕中的位置（考虑居中 + 当前偏移）
    let imgX = (this.screenWidth - scaledW) / 2 + this.lastOffsetX;
    let imgY = (this.screenHeight - scaledH) / 2 + this.lastOffsetY;
    // 触摸点相对于图片的百分比（0~1）
    let cX = Math.max((pinchCenterX - imgX) / scaledW, 0);
    let cY = Math.max((pinchCenterY - imgY) / scaledH, 0);
    return [cX, cY];
  }

  // 捏合手势开始：记录缩放中心点
  pinchGestureStart(pinchCenterX: number, pinchCenterY: number): void {
    let center = this.evaluateCenter(pinchCenterX, pinchCenterY);
    // centerX/Y = 1 - center[0/1]，用于偏移补偿公式
    this.centerX = 1 - center[0];
    this.centerY = 1 - center[1];
  }

  // 捏合手势移动中：更新 scale + offset
  // scale: 相对于手势开始的相对缩放比（event.scale from PinchGesture）
  pinchGestureUpdate(scale: number, offX: number, offY: number): boolean {
    // 限制 scale 范围
    let newScale = this.lastScale * scale;
    if (newScale > this.maxScale) {
      this.curScale = this.maxScale;
    } else if (newScale < this.minScale) {
      this.curScale = this.minScale;
    } else {
      this.curScale = newScale;
    }

    // 到达边界时略微回退，防止抖动
    if (newScale >= this.maxScale) {
      this.curScale -= 0.001;
    }

    this.evaluateOffsetRange();

    // 核心偏移公式（跟手原理）：
    // curOffset = (上次偏移 + 手指带来的偏移) + (缩放中心偏移补偿)
    // 补偿 = (0.5 - centerX) * imageSize * (1 - scale) * lastScale
    if (this.curScale < this.maxScale) {
      this.curOffsetY = (this.lastOffsetY + offY) + (0.5 - this.centerY) * this.imageHeight * (1 - scale) * this.lastScale;
      this.curOffsetX = (this.lastOffsetX + offX) + (0.5 - this.centerX) * this.imageWidth * (1 - scale) * this.lastScale;
    }

    this.isArriveBoundary = false;
    // 未到达边界时禁止 Swiper 切换
    if (!this.isArriveBoundary && this.curScale > this.defaultScale) {
      this.isDisableSwipe = true;
    }

    // 边界限制
    this.pictureBoundaryRestriction();
    return this.isDisableSwipe;
  }

  // 捏合手势结束
  pinchGestureEnd(): void {
    // 小于默认尺寸则回弹到 1
    if (this.curScale <= this.defaultScale) {
      this.curScale = this.defaultScale;
      this.imageReset();
    } else if (this.curScale >= this.maxScale) {
      this.curScale -= 0.1;
    }
    this.gestureEnd();
  }

  // 单指滑动更新（用于平移拖动）
  // offX/offY 是 PanGesture 的增量（单帧delta，非累积值）
  panGestureUpdate(offX: number, offY: number): boolean {
    if (this.curScale > this.defaultScale) {
      this.curOffsetX = this.lastOffsetX + offX;
      this.curOffsetY = this.lastOffsetY + offY;
      this.isDisableSwipe = true;
    }
    this.pictureBoundaryRestriction();
    return this.isDisableSwipe;
  }

  // 边界限制（完全对齐参考代码 CommonModel.ets）
  pictureBoundaryRestriction(): void {
    // 先处理边界超出（X轴）
    if (this.curOffsetX > this.maxOffsetX) {
      this.curOffsetX = this.maxOffsetX;
      this.isDisableSwipe = false;
      this.isArriveBoundary = true;
    } else if (this.curOffsetX < this.minOffsetX) {
      this.curOffsetX = this.minOffsetX;
      this.isDisableSwipe = false;
      this.isArriveBoundary = true;
    }
    // 先处理边界超出（Y轴）
    if (this.curOffsetY > this.maxOffsetY) {
      this.curOffsetY = this.maxOffsetY;
    } else if (this.curOffsetY < this.minOffsetY) {
      this.curOffsetY = this.minOffsetY;
    }
    // 图片小于屏幕时，强制居中（居中逻辑写在边界处理之后）
    let scaledW = this.imageWidth * this.curScale;
    let scaledH = this.imageHeight * this.curScale;
    if (scaledW <= this.screenWidth) {
      this.curOffsetX = 0;
    }
    if (scaledH <= this.screenHeight) {
      this.curOffsetY = 0;
    }
  }

  // 双击切换缩放（默认 ↔ 最大）
  doubleTapGesture(tapX: number, tapY: number, tapScale: number): boolean {
    if (this.lastScale > this.defaultScale) {
      // 恢复默认尺寸
      this.curScale = this.defaultScale;
      this.offsetReset();
      this.gestureEnd();
      this.isDisableSwipe = false;
    } else {
      // 放大到 maxScale，中心点在双击位置
      let center = this.evaluateCenter(tapX, tapY);
      this.centerX = 1 - center[0];
      this.centerY = 1 - center[1];
      this.curScale = this.maxScale;
      this.offsetReset();
      this.lastScale = this.maxScale;
      this.isDisableSwipe = true;
    }
    return this.isDisableSwipe;
  }
}

// ─── 全屏图片预览内容 ─────────────────────────────────────────────────────────
@CustomDialog
struct ImagePreviewDialog {
  imageUrls: string[] = [];
  startIndex: number = 0;
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });

  @State currentIndex: number = 0;
  @State showUI: boolean = true;
  // 每个图片独立的预览模型（用数组对应多图）
  @State previewModels: ImagePreviewModel[] = [];
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  aboutToAppear() {
    this.currentIndex = this.startIndex;
    this.initModels();
    // 设置状态栏字体为白色
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({ statusBarContentColor: '#FFFFFF' });
      });
    } catch (e) {}
  }

  aboutToDisappear() {
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        const isDark = this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
        win.setWindowSystemBarProperties({
          statusBarContentColor: isDark ? '#FFFFFF' : '#14233a'
        });
      });
    } catch (e) {}
  }

  // 初始化每个图片的预览模型
  initModels(): void {
    // 同步获取屏幕尺寸（getLastWindow 同步调用有时可用）
    let screenW = 360;
    let screenH = 780;
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        const rect = win.getWindowProperties().windowRect;
        screenW = px2vp(rect.width);
        screenH = px2vp(rect.height);
        // 立即同步到已有模型
        this.previewModels.forEach(model => {
          model.screenWidth = screenW;
          model.screenHeight = screenH;
        });
      });
    } catch (_) {}

    // 创建模型：imageHeight 设为 screenH（按屏幕高度预估，足以触发 Y 轴边界计算）
    this.previewModels = this.imageUrls.map(() => {
      const model = new ImagePreviewModel();
      model.imageWidth = screenW;   // 宽占满屏幕
      model.imageHeight = screenH;  // 高按屏幕高度（过度估计，确保能计算 maxOffsetY）
      model.screenWidth = screenW;
      model.screenHeight = screenH;
      return model;
    });
  }

  // 切换图片时重置目标图片的状态
  onSwiperChange(index: number): void {
    this.currentIndex = index;
    // 确保新索引有模型
    while (this.previewModels.length <= index) {
      this.previewModels.push(new ImagePreviewModel());
    }
    this.previewModels[index].imageReset();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {

      // 图片 Swiper
      Swiper() {
        ForEach(this.imageUrls, (url: string, index: number) => {
          Image(url)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .transform(
              matrix4.identity()
                .scale({ x: this.previewModels[index]?.curScale ?? 1, y: this.previewModels[index]?.curScale ?? 1 })
                .copy()
            )
            .translate({
              x: this.previewModels[index]?.curOffsetX ?? 0,
              y: this.previewModels[index]?.curOffsetY ?? 0
            })
            .onComplete((event) => {
              // 图片加载完成后，用真实尺寸更新 model
              if (event && event.width > 0 && event.height > 0 && this.previewModels[index]) {
                const model = this.previewModels[index];
                const w = event.width;
                const h = event.height;
                // 计算 fit 到屏幕后的尺寸（与 initModels 逻辑一致）
                const widthRatio = model.screenWidth / w;
                const heightRatio = model.screenHeight / h;
                const scaleRatio = Math.min(widthRatio, heightRatio);
                model.imageWidth = w * scaleRatio;
                model.imageHeight = h * scaleRatio;
                // 动态计算 maxScale：能放大到屏幕的 2.5 倍（更大的拖动范围）
                const widthRatio2 = (model.screenWidth * 2.5) / model.imageWidth;
                const heightRatio2 = (model.screenHeight * 2.5) / model.imageHeight;
                model.maxScale = Math.min(widthRatio2, heightRatio2, 5);
                this.previewModels = [...this.previewModels];
              }
            })
            .gesture(GestureGroup(GestureMode.Exclusive,
              // 双击：切换默认 ↔ 最大缩放
              TapGesture({ count: 2 })
                .onAction((event: GestureEvent) => {
                  if (this.previewModels[index]) {
                    let isDisable = this.previewModels[index].doubleTapGesture(
                      event.fingerList[0].displayX,
                      event.fingerList[0].displayY,
                      event.scale
                    );
                    // 触发响应式更新（创建新数组引用）
                    this.previewModels = [...this.previewModels];
                  }
                }),
              // 双指捏合缩放
              PinchGesture({ fingers: 2, distance: 1 })
                .onActionStart((event: GestureEvent) => {
                  if (this.previewModels[index]) {
                    this.previewModels[index].pinchGestureStart(event.pinchCenterX, event.pinchCenterY);
                  }
                })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.previewModels[index]) {
                    this.previewModels[index].pinchGestureUpdate(event.scale, event.offsetX, event.offsetY);
                    this.previewModels = [...this.previewModels];
                  }
                })
                .onActionEnd(() => {
                  if (this.previewModels[index]) {
                    this.previewModels[index].pinchGestureEnd();
                    this.previewModels = [...this.previewModels];
                  }
                }),
              // 单指拖动（放大状态平移）
              PanGesture({ fingers: 1, distance: 5 })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.previewModels[index]) {
                    let isDisable = this.previewModels[index].panGestureUpdate(event.offsetX, event.offsetY);
                    this.previewModels = [...this.previewModels];
                  }
                })
                .onActionEnd(() => {
                  if (this.previewModels[index]) {
                    this.previewModels[index].gestureEnd();
                    this.previewModels = [...this.previewModels];
                  }
                })
            ))
        })
      }
      .index(this.currentIndex)
      .indicator(false)
      .loop(false)
      .duration(300)
      .disableSwipe(this.previewModels[this.currentIndex]?.isDisableSwipe ?? false)
      .onClick(() => { this.showUI = !this.showUI; })
      .onChange((index: number) => this.onSwiperChange(index))
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
    .backgroundColor('#000000')
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
                Image($r('app.media.icon_callu'))
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
