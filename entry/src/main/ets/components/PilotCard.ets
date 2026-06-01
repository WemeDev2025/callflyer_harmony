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

// 官方 runWithAnimation 实现（对齐 CommonModel.ets）
const uiContext: UIContext | undefined = AppStorage.get('uiContext');
function runWithAnimation(fn: Function, duration: number = 300, curve: Curve = Curve.Smooth): void {
  if (uiContext) {
    uiContext.animateTo({ duration: duration, curve: curve }, () => {
      fn();
    });
  } else {
    fn();
  }
}

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
  // 视频号（鸿蒙无法跳转，保留字段但不在UI显示）
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
  // 变换矩阵（官方实现使用 matrix 控制缩放）
  matrix: matrix4.Matrix4Transit = matrix4.identity().copy();
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
  // 缩放中心（官方实现）
  center: number[] = [0.5, 0.5];
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

  // 增量计算基准（捏合手势中）
  private prevPinchOffsetX: number = 0;
  private prevPinchOffsetY: number = 0;

  // 手势结束，固化当前状态
  // 注意：参考代码中 gestureEnd 不调用 pictureBoundaryRestriction
  // 边界处理只在手势进行中实时应用，不在结束时修改 lastOffset
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

  // 重置图片（切图时调用）- 官方版本带延迟
  imageReset(): void {
    setTimeout(() => {
      this.matrix = matrix4.identity().scale({
        x: this.defaultScale,
      }).copy();
      this.lastScale = this.defaultScale;
      this.offsetReset();
    }, 200);
    AppStorage.setOrCreate('isImgDefaultSize', true);
  }

  // 官方 pictureScaling 方法：更新变换矩阵
  pictureScaling(scale: number): void {
    this.matrix = matrix4.identity().scale({
      x: scale,
      y: scale
    }).copy();
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

  // 计算缩放中心相对于图片的百分比位置（官方版本）
  evaluateCenter(centerX: number, centerY: number): [number, number] {
    let imgDisplayWidth = this.imageWidth * this.lastScale;
    let imgDisplayHeight = this.imageHeight * this.lastScale;
    let imgX = (this.screenWidth - imgDisplayWidth) / 2 + this.lastOffsetX;
    let imgY = (this.screenHeight - imgDisplayHeight) / 2 + this.lastOffsetY;
    let cX = Math.max((centerX - imgX) / imgDisplayWidth, 0);
    let cY = Math.max((centerY - imgY) / imgDisplayHeight, 0);
    return [cX, cY];
  }

  // 官方 onScale 方法：核心缩放计算（从 pinchGestureUpdate 提取）
  onScale(scale: number, offX: number, offY: number): void {
    // 边界限制
    if (this.lastScale * scale > this.maxScale) {
      this.curScale = this.maxScale;
    } else if (this.lastScale * scale < this.minScale) {
      this.curScale = this.minScale;
    } else {
      this.curScale = this.lastScale * scale;
    }
    // 防止刚好等于 maxScale 时出现边界问题（官方精度处理）
    if (this.lastScale * scale === this.maxScale) {
      this.curScale -= 0.001;
    }
    this.evaluateOffsetRange();

    // 核心偏移公式（跟手原理）
    if (this.curScale < this.maxScale) {
      this.curOffsetY =
        (this.lastOffsetY + offY) + (0.5 - this.centerY) * this.imageHeight * (1 - scale) * this.lastScale;
      this.curOffsetX =
        (this.lastOffsetX + offX) + (0.5 - this.centerX) * this.imageWidth * (1 - scale) * this.lastScale;
    }

    // 移动中未到达边界
    this.isArriveBoundary = false;
    // 未到达边界时禁止 Swiper 切换
    if (!this.isArriveBoundary) {
      this.isDisableSwipe = true;
    }
  }

  // 捏合手势开始：记录缩放中心点
  pinchGestureStart(pinchCenterX: number, pinchCenterY: number): void {
    this.center = this.evaluateCenter(pinchCenterX, pinchCenterY);
    this.centerX = 1 - this.center[0];
    this.centerY = 1 - this.center[1];
    // 重置增量计算基准
    this.prevPinchOffsetX = 0;
    this.prevPinchOffsetY = 0;
    AppStorage.setOrCreate('isImgDefaultSize', false);
  }

  // 捏合手势移动中：更新 scale + offset（官方版本）
  pinchGestureUpdate(scale: number, offX: number, offY: number): boolean {
    // 计算每帧增量（累积值 - 上次累积值）
    let deltaX = offX - this.prevPinchOffsetX;
    let deltaY = offY - this.prevPinchOffsetY;
    this.prevPinchOffsetX = offX;
    this.prevPinchOffsetY = offY;

    // 调用官方 onScale 方法
    this.onScale(scale, deltaX, deltaY);

    // 更新 matrix（官方实现）
    this.pictureScaling(this.curScale);

    // 放大时禁止 Swiper 切换
    if (this.curScale > this.defaultScale) {
      this.isDisableSwipe = true;
    }

    // 边界限制
    this.pictureBoundaryRestriction();
    return this.isDisableSwipe;
  }

  // 捏合手势结束（官方版本带动画回弹）
  pinchGestureEnd(): void {
    runWithAnimation(() => {
      // 小于默认尺寸则回弹到 1
      if (this.curScale <= this.defaultScale) {
        this.pictureScaling(this.defaultScale);
        this.imageReset();
      } else if (this.curScale >= this.maxScale) {
        this.curScale -= 0.1;
        this.pictureScaling(this.curScale);
      }
      this.gestureEnd();
    });
  }

  // 单指滑动更新（官方版本调用 onScale）
  panGestureUpdate(offX: number, offY: number): boolean {
    // 官方版本直接调用 onScale，但 scale=1 不改变缩放
    this.onScale(1, offX, offY);
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

  // 双击切换缩放（官方版本带动画）
  doubleTapGesture(tapX: number, tapY: number, tapScale: number): boolean {
    let curRatio: number = 1;
    let center = this.evaluateCenter(tapX, tapY);
    this.centerX = 1 - center[0];
    this.centerY = 1 - center[1];

    if (this.lastScale > this.defaultScale) {
      // 恢复默认尺寸
      runWithAnimation(() => {
        this.pictureScaling(this.defaultScale);
        this.offsetReset();
      });
      curRatio = this.defaultScale;
      this.isDisableSwipe = false;
      AppStorage.setOrCreate('isImgDefaultSize', true);
    } else {
      // 放大到 maxScale
      runWithAnimation(() => {
        this.onScale(tapScale, 0, 0);
        this.pictureScaling(this.maxScale);
        this.offsetReset();
      });
      curRatio = this.maxScale;
      this.isDisableSwipe = true;
      AppStorage.setOrCreate('isImgDefaultSize', false);
    }
    this.lastScale = curRatio;
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
            .transform(this.previewModels[index]?.matrix ?? matrix4.identity().copy())
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
            .parallelGesture(
              GestureGroup(
                GestureMode.Exclusive,
                // 单指拖动（放大状态平移）
                PanGesture({ fingers: 1, distance: this.previewModels[index]?.isDisableSwipe ? 3 : 50 })
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
                  })
              ), GestureMask.Normal
            )
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
  // 主营业务长文本标记（超过15字符切换为标签样式）
  @State businessScopeLong: boolean = false;
  // 常用机型长文本标记（超过12字符切换为标签样式）
  @State droneModelLong: boolean = false;

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
    // 计算长文本标记（主营业务>15字符，常用机型>12字符）
    const businessText = this.user.businessScopeText || '';
    const droneText = this.user.droneModel || '';
    this.businessScopeLong = businessText.length > 15;
    this.droneModelLong = droneText.length > 12;
  }

  aboutToReuse(params: Record<string, Object>) {
    const userParam = params['user'] as PilotCardData;
    if (userParam) {
      this.internalLikeCount = userParam.likeCount ?? 0;
      this.internalLikedByMe = userParam.likedByMe ?? false;
      // 计算长文本标记（主营业务>15字符，常用机型>12字符）
      const businessText = userParam.businessScopeText || '';
      const droneText = userParam.droneModel || '';
      this.businessScopeLong = businessText.length > 15;
      this.droneModelLong = droneText.length > 12;
    }
  }

  isSquareTag(): boolean {
    const t = this.user.licenseType?.toLowerCase() || '';
    return t === '已审核' || t === 'cac' || t === 'utc';
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
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_title'))
            .fontFamily('DouyinSansBold')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          if (this.user.userRole !== 'employer' && this.user.pilotCode || this.user.company || this.user.position) {
            Column() {
              if (this.user.userRole !== 'employer' && this.user.pilotCode) {
                Row() {
                  Image($r('app.media.icon_banner'))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                    .margin({ right: 4 })
                  Text(this.user.pilotCode)
                    .fontSize(12)
                    .fontColor($r('app.color.text_body'))
                }
                .alignItems(VerticalAlign.Center)
              } else {
                if (this.user.company) {
                  Text(this.user.company)
                    .fontSize(12)
                    .fontColor($r('app.color.text_body'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 3 })
                }
              }
              if (this.user.position) {
                Text(this.user.position)
                  .fontSize(12)
                  .fontColor($r('app.color.text_body'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 3 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: -4 })
            .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 14, bottom:1})
        .layoutWeight(1)

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
        .padding({ left: 12 })
        .margin({ left: 14, right: -2 })
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
      if (this.user.licenseType || this.user.licenseStatus) {
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
                .borderRadius(this.isSquareTag() ? 0 : 2)
                .padding({ top: 4, bottom: 4, left: 8, right: 8 })
                .margin({ right: 8 })
            }
            if (this.user.licenseStatus) {
              Text(this.user.licenseStatus)
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

      // 主营业务（长文本时切换为标签样式）
      if (this.user.businessScopeText) {
        if (this.businessScopeLong) {
          // 长文本模式：列布局 + 背景标签
          Column() {
            Text('主营业务')
              .fontSize(14)
              .fontColor($r('app.color.text_label'))
              .fontWeight(FontWeight.Medium)
            Text(this.user.businessScopeText)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.tag_bg'))
              .borderRadius(8)
              .padding({ left: 11, right: 11, top: 9, bottom: 9 })
              .width('100%')
              .textAlign(TextAlign.JUSTIFY)
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 9 })
        } else {
          // 短文本模式：普通行布局
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
      }

      // 常用机型（长文本时切换为标签样式）
      if (this.user.droneModel && this.user.droneModel !== '--' && this.user.userRole !== 'employer') {
        if (this.droneModelLong) {
          // 长文本模式：列布局 + 背景标签
          Column() {
            Text('常用机型')
              .fontSize(14)
              .fontColor($r('app.color.text_label'))
              .fontWeight(FontWeight.Medium)
            Text(this.user.droneModel)
              .fontSize(14)
              .fontColor($r('app.color.text_primary'))
              .backgroundColor($r('app.color.tag_bg'))
              .borderRadius(8)
              .padding({ left: 10, right: 10, top: 9, bottom: 9 })
              .width('100%')
              .margin({ top: 8 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 9 })
        } else {
          // 短文本模式：普通行布局
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
