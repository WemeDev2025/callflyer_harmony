import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import { fetchDisciples, fetchMyDisciples, matchDisciple, removeDisciple, joinDisciple, leaveDisciple, createStandbyRating, fetchPilotContact, DiscipleItem, DiscipleMaster, MyDisciplesResult, PilotContact, RatingInfo } from '../service/ApiService';
import AuthService from '../service/AuthService';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';
const BANNER_URL = 'https://wetofly.com/data/image/pic_thank.webp';

@CustomDialog
struct IntroDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: '' });
  introText: string = '';
  introPrice: string = '';
  onConfirm: (intro: string, price: string) => void = () => {};
  onCancel: () => void = () => {};
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  @State keyboardVisible: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 头部
        Row() {
          Text('自我介绍')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#1d2b3a' : '#e6e9ef')
          Blank()
          Text('×')
            .fontSize(24)
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#8a96a8' : '#6b7a8c')
            .onClick(() => { this.onCancel(); this.controller.close(); })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 10 })

        // 自我介绍输入框
        Column() {
          TextArea({ placeholder: '例如：我是新手，有CAAC证书，会驾驶手动挡皮卡......', text: this.introText })
            .width('100%')
            .height(120)
            .fontSize(15)
            .placeholderFont({ size: 13 })
            .placeholderColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#b0b8c4' : '#9aa4b2')
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#1d2b3a' : '#e6e9ef')
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#f7f9fc' : '#2D2D2D')
            .borderRadius(8)
            .padding(12)
            .maxLength(200)
            .textAlign(TextAlign.Start)
            .onChange((text: string) => { this.introText = text; })
            .onFocus(() => { this.keyboardVisible = true; })
            .onBlur(() => { this.keyboardVisible = false; })
          Text(String(this.introText.length) + '/200')
            .fontSize(12)
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#b0b8c4' : '#9aa4b2')
            .alignSelf(ItemAlign.End)
            .margin({ top: 6 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 12 })

        // 感谢金输入区域
        Column() {
          Text('表达诚意 成功入行后愿意给师傅的感谢金')
            .fontSize(14)
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#374151' : '#c9d1d9')
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 8 })

          Row() {
            Text('¥')
              .fontSize(18)
              .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#374151' : '#c9d1d9')
              .fontWeight(FontWeight.Bold)
            TextInput({ placeholder: '可留空' })
              .width('100%')
              .height(44)
              .fontSize(18)
              .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#374151' : '#c9d1d9')
              .fontWeight(FontWeight.Bold)
              .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#f9fafb' : '#2D2D2D')
              .borderRadius(8)
              .padding({ left: 8, right: 12 })
              .type(InputType.Number)
              .onChange((text: string) => { this.introPrice = text; })
              .onFocus(() => { this.keyboardVisible = true; })
              .onBlur(() => { this.keyboardVisible = false; })
          }
          .width('100%')
          .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#f9fafb' : '#2D2D2D')
          .borderRadius(8)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })

          Text('非平台支付交易 请根据实际情况而定')
            .fontSize(11)
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#9ca3af' : '#6b7a8c')
            .alignSelf(ItemAlign.Start)
            .margin({ top: 6 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 16 })

        // 底部按钮
        Row() {
          Button('取消')
            .width('45%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#6f7c90' : '#a0aec0')
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#f4f6f9' : '#2D2D2D')
            .borderRadius(24)
            .onClick(() => { this.onCancel(); this.controller.close(); })
          Button('发布')
            .width('45%')
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#07c160')
            .borderRadius(24)
            .onClick(() => {
              this.onConfirm(this.introText, this.introPrice);
              this.controller.close();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 34 })
        .justifyContent(FlexAlign.SpaceAround)
        .visibility(this.keyboardVisible ? Visibility.None : Visibility.Visible)
      }
      .width('96%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(22)
      .margin({ bottom: this.keyboardVisible ? 0 : 22 })
    }
    .width('96%')
  }
}

@CustomDialog
struct RatingDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: '' });
  ratingScore: number = 5;
  ratingComment: string = '';
  onSubmit: (score: number, comment: string) => void = () => {};
  onCancel: () => void = () => {};

  build() {
    Column() {
      Text('给徒弟评星')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })

      // 星级选择
      Row() {
        ForEach([1, 2, 3, 4, 5], (star: number) => {
          Text(star <= this.ratingScore ? '★' : '☆')
            .fontSize(36)
            .fontColor('#FFD700')
            .onClick(() => { this.ratingScore = star; })
        })
      }
      .margin({ bottom: 20 })

      // 评价输入
      TextInput({ placeholder: '说点什么...', text: this.ratingComment })
        .width('90%')
        .height(80)
        .margin({ bottom: 20 })
        .onChange((text: string) => { this.ratingComment = text; })

      // 按钮
      Row() {
        Button('取消')
          .width('40%')
          .height(40)
          .fontColor('#07c160')
          .backgroundColor('#FFFFFF')
          .borderColor('#07c160')
          .borderWidth(1)
          .borderRadius(20)
          .onClick(() => { this.onCancel(); this.controller.close(); })
        Button('提交')
          .width('40%')
          .height(40)
          .fontColor('#FFFFFF')
          .backgroundColor('#07c160')
          .borderRadius(20)
          .onClick(() => {
            this.onSubmit(this.ratingScore, this.ratingComment);
            this.controller.close();
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceAround)
    }
    .width('85%')
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
  }
}

// 缓存数据结构
interface StandbyCache {
  items: DiscipleItem[];
  isJoined: boolean;
  fetchedAt: number;
}

// 缓存读取结果
class StandbyCacheResult {
  items: DiscipleItem[] = [];
  isJoined: boolean = false;
}

// 可观察的徒弟项，用于精准更新UI
@Observed
class ObservedDiscipleItem {
  openid: string = '';
  order_id: string = '';
  out_trade_no: string = '';
  name: string = '';
  city: string = '';
  avatar: string = '';
  intro: string = '';
  price: number = 0;
  paid_at: string = '';
  finished_at: string = '';
  masters: DiscipleMaster[] = [];
  masterCount: number = 0;
  hasMatchedMe: boolean = false;
  isMine: boolean = false;
  transfer_status: string = '';
  rating: RatingInfo | null = null;
  masterRating: RatingInfo | null = null;

  constructor(item?: DiscipleItem) {
    if (item) {
      this.openid = item.openid;
      this.order_id = item.order_id;
      this.out_trade_no = item.out_trade_no;
      this.name = item.name;
      this.city = item.city;
      this.avatar = item.avatar;
      this.intro = item.intro;
      this.price = item.price;
      this.paid_at = item.paid_at;
      this.finished_at = item.finished_at;
      this.masters = item.masters ? [...item.masters] : [];
      this.masterCount = item.masterCount;
      this.hasMatchedMe = item.hasMatchedMe;
      this.isMine = item.isMine;
      this.transfer_status = item.transfer_status;
      this.rating = item.rating;
      this.masterRating = item.masterRating;
    }
  }
}

// 徒弟卡片组件 - 使用@ObjectLink实现精准UI更新
@Component
struct DiscipleCard {
  @ObjectLink item: ObservedDiscipleItem;
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  onMatch: (item: ObservedDiscipleItem) => void = () => {};
  onCancelMatch: (item: ObservedDiscipleItem) => void = () => {};
  onContactDisciple: (item: ObservedDiscipleItem) => void = () => {};
  onContactMaster: (item: ObservedDiscipleItem) => void = () => {};
  onRating: (item: ObservedDiscipleItem, role: string) => void = () => {};

  build() {
    Column() {
      // 顶部区域：入行感谢金标签+金额badge（仅价格>0时显示）
      if (this.item.price > 0) {
        Row() {
          // 入行感谢金标签 - 左边，黑色粗体
          Text('入行感谢金')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Blank()

          // 感谢金金额badge - 右边，圆角矩形
          Text('¥' + this.item.price)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#07c160')
            .borderRadius(3)
        }
        .width('100%')
        .margin({ bottom: 12 })
      }

      // 主信息区
      Row() {
        // 左侧：徒弟信息 - 带背景，水平排列
        Row() {
          Image(this.item.avatar || DEFAULT_AVATAR)
            .width(35)
            .height(35)
            .borderRadius(17.5)

          Column() {
            Text(this.item.name || '匿名飞手')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(this.item.city || '')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 8 })
          .width('60%')
        }
        .alignItems(VerticalAlign.Center)
        .width('42%')
        .height('100%')
        .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#F5F5F5' : '#2A2A2A')
        .borderRadius(8)
        .padding({ top: 6, bottom: 6, left: 8, right: 8 })

        // 中间连接线 - 短横线
        Column() {
          Column()
            .width(30)
            .height(2)
            .backgroundColor(this.item.masterCount > 0 ? '#07c160' : $r('app.color.divider'))
        }
        .width('16%')
        .height('100%')
        .justifyContent(FlexAlign.Center)

        // 右侧：师傅信息 - 带背景
        Row() {
          if (this.item.masterCount > 0) {
            // 已收徒状态 - 显示师傅头像
            Row() {
              Image(this.item.masters && this.item.masters[0] ? this.item.masters[0].avatar || DEFAULT_AVATAR : DEFAULT_AVATAR)
                .width(35)
                .height(35)
                .borderRadius(17.5)
                .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))

              Column() {
                Text(this.item.masters && this.item.masters[0] ? this.item.masters[0].nickname || '师傅' : '师傅')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text('已收徒 ' + this.item.masterCount + ' 人')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 8 })
              .width('60%')
              .onClick(() => { this.onCancelMatch(this.item); })
            }
            .alignItems(VerticalAlign.Center)
          } else {
            // 未收徒状态 - 显示"我收了"图标
            Row() {
              Column() {
                Image($r('app.media.icon_gan'))
                  .width(35)
                  .height(35)
              }
              .width(35)
              .height(35)
              .backgroundColor('#07c160')
              .borderRadius(17.5)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)

              Text('我收了')
                .fontSize(13)
                .fontColor('#6f7c90')
                .fontWeight(FontWeight.Medium)
                .margin({ left: 8 })
            }
            .alignItems(VerticalAlign.Center)
            .onClick(() => { this.onMatch(this.item); })
          }
        }
        .alignItems(VerticalAlign.Center)
        .width('42%')
        .height('100%')
        .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#F5F5F5' : '#2A2A2A')
        .borderRadius(8)
        .padding({ top: 6, bottom: 6, left: 8, right: 8 })
      }
      .width('100%')
      .height(70)

      // 自我介绍
      if (this.item.intro) {
        Column() {
          Text(this.item.intro)
            .fontSize(13)
            .fontColor($r('app.color.text_body'))
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#F5F5F5' : '#2A2A2A')
        .borderRadius(8)
        .margin({ top: 10 })
      }

      // 评星区域
      if (this.item.rating || this.item.masterRating) {
        Column() {
          Divider()
            .color($r('app.color.divider'))
            .margin({ top: 12, bottom: 12 })

          // 师傅对徒弟的评价
          if (this.item.rating) {
            Column() {
              Row() {
                Text('评价徒弟')
                  .fontSize(12)
                  .fontColor($r('app.color.text_label'))
                  .fontWeight(FontWeight.Medium)
                Row() {
                  ForEach([1, 2, 3, 4, 5], (star: number) => {
                    Text(star <= (this.item.rating?.score ?? 0) ? '★' : '☆')
                      .fontSize(14)
                      .fontColor('#FFD700')
                  })
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              if (this.item.rating?.comment) {
                Text('"' + this.item.rating.comment + '"')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 4 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
          }

          // 徒弟对师傅的评价
          if (this.item.masterRating) {
            Column() {
              Row() {
                Text('评价师傅')
                  .fontSize(12)
                  .fontColor($r('app.color.text_label'))
                  .fontWeight(FontWeight.Medium)
                Row() {
                  ForEach([1, 2, 3, 4, 5], (star: number) => {
                    Text(star <= (this.item.masterRating?.score ?? 0) ? '★' : '☆')
                      .fontSize(14)
                      .fontColor('#FFD700')
                  })
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .margin({ top: this.item.rating ? 10 : 0 })

              if (this.item.masterRating?.comment) {
                Text('"' + this.item.masterRating.comment + '"')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 4 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
          }
        }
        .width('100%')
      }

      // 操作按钮 - 微信风格
      Row() {
        Button('联系徒弟')
          .fontSize(12)
          .height(28)
          .fontColor('#07c160')
          .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#E8F7ED' : '#1A3D2A')
          .borderRadius(14)
          .onClick(() => { this.onContactDisciple(this.item); })
        if (this.item.masterCount > 0) {
          Button('联系师傅')
            .fontSize(12)
            .height(28)
            .fontColor('#07c160')
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#E8F7ED' : '#1A3D2A')
            .borderRadius(14)
            .margin({ left: 10 })
            .onClick(() => { this.onContactMaster(this.item); })
        }
        if (this.item.isMine || (this.item.masterCount > 0 && this.item.masters && this.item.masters.length > 0 && this.item.masters[0].openid === AuthService.getCurrentOpenId())) {
          Button('去评价')
            .fontSize(12)
            .height(28)
            .fontColor('#FF9500')
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? '#FFF5E6' : '#3D3520')
            .borderRadius(14)
            .margin({ left: 10 })
            .onClick(() => { this.onRating(this.item, this.item.isMine ? 'disciple' : 'master'); })
        }
      }
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
  }
}

@Entry
@Component
struct Standby {
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  scroller: Scroller = new Scroller();

  @State pilotList: ObservedDiscipleItem[] = [];
  @State filteredList: ObservedDiscipleItem[] = [];
  @State loading: boolean = true;
  @State skeletonShimmer: boolean = false;
  private skeletonTimer: number = -1;
  @StorageLink('standbyIsJoined') isJoined: boolean = false;
  @State searchKey: string = '';
  @State showIntroPopup: boolean = false;
  @State introText: string = '';
  @State introPrice: string = '';
  @State showRatingPopup: boolean = false;
  @State ratingRole: string = 'master';
  @State ratingIndex: number = -1;

  private ratingDialogController: CustomDialogController | null = null;
  private introDialogController: CustomDialogController | null = null;

  // 缓存 key
  private cacheKey: string = 'standby_page_data';
  private cacheTTL: number = 3 * 60 * 1000; // 3分钟缓存

  aboutToAppear() {
    this.loadData(true);
  }

  // 读取缓存
  private readCache(): StandbyCacheResult | null {
    try {
      const raw = AppStorage.get<string>(this.cacheKey);
      if (raw) {
        const cache: StandbyCache = JSON.parse(raw) as StandbyCache;
        if (cache && cache.fetchedAt && Date.now() - cache.fetchedAt < this.cacheTTL && cache.items) {
          const result = new StandbyCacheResult();
          result.items = cache.items;
          result.isJoined = cache.isJoined;
          return result;
        }
      }
    } catch (e) {}
    return null;
  }

  // 写入缓存
  private writeCache(items: DiscipleItem[], isJoined: boolean) {
    try {
      const data = JSON.stringify({ items, isJoined, fetchedAt: Date.now() });
      AppStorage.setOrCreate(this.cacheKey, data);
    } catch (e) {}
  }

  async loadData(showLoading: boolean = false, silentRefresh: boolean = false) {
    console.info('【loadData】 START showLoading:', showLoading, 'silentRefresh:', silentRefresh, 'isJoined:', this.isJoined);
    // 如果是静默刷新，只更新数据不修改 UI
    if (silentRefresh) {
      try {
        const discipleRes = await fetchDisciples();
        const token = AuthService.getAuthToken();
        const myDiscipleRes = token ? await fetchMyDisciples(token) : { items: [] } as MyDisciplesResult;
        const items = discipleRes.items || [];
        this.pilotList = items.map((item: DiscipleItem) => new ObservedDiscipleItem(item));
        this.applyFilter();
        // 计算 isJoined：当前用户是否在列表中（与小程序逻辑一致）
        const myOpenid = AuthService.getCurrentOpenId();
        const apiJoined = items.some((item: DiscipleItem) => item.openid === myOpenid);
        // 不覆盖已加入状态
        if (!this.isJoined) {
          this.isJoined = apiJoined;
        }
        this.writeCache(items, this.isJoined);
      } catch (err) {
        console.error('【师徒匹配静默刷新失败】', JSON.stringify(err));
      }
      return;
    }

    // 优先读取缓存
    const cachedData = this.readCache();
    if (cachedData) {
      this.pilotList = cachedData.items.map((item: DiscipleItem) => new ObservedDiscipleItem(item));
      this.applyFilter();
      // 不覆盖已加入状态
      if (!this.isJoined) {
        this.isJoined = cachedData.isJoined;
      }
      if (!showLoading) {
        this.loading = false;
      }
    } else if (showLoading) {
      this.loading = true;
      this.startSkeletonShimmer();
    }

    // 后台静默刷新
    try {
      const discipleRes = await fetchDisciples();
      const token = AuthService.getAuthToken();
      const myDiscipleRes = token ? await fetchMyDisciples(token) : { items: [] } as MyDisciplesResult;

      const items = discipleRes.items || [];
      const myDisciples = myDiscipleRes.items || [];

      this.pilotList = items.map((item: DiscipleItem) => new ObservedDiscipleItem(item));
      this.applyFilter();
      // 计算 isJoined：当前用户是否在列表中（与小程序逻辑一致）
      const myOpenid = AuthService.getCurrentOpenId();
      const apiJoined = items.some((item: DiscipleItem) => item.openid === myOpenid);
      console.info('【loadData】 myOpenid:', myOpenid, 'apiJoined:', apiJoined, 'items count:', items.length);
      // 不覆盖已加入状态
      if (!this.isJoined) {
        this.isJoined = apiJoined;
      }
      console.info('【loadData】 final isJoined:', this.isJoined);

      // 更新缓存
      this.writeCache(items, this.isJoined);
    } catch (err) {
      console.error('【师徒匹配加载失败】', JSON.stringify(err));
      if (!cachedData) {
        promptAction.showToast({ message: '加载失败' });
      }
    }
    this.loading = false;
    this.stopSkeletonShimmer();
  }

  startSkeletonShimmer() {
    this.skeletonShimmer = false;
    this.skeletonTimer = setInterval(() => {
      this.skeletonShimmer = !this.skeletonShimmer;
    }, 500);
  }

  stopSkeletonShimmer() {
    if (this.skeletonTimer >= 0) {
      clearInterval(this.skeletonTimer);
      this.skeletonTimer = -1;
    }
    this.skeletonShimmer = false;
  }

  applyFilter() {
    if (!this.searchKey) {
      this.filteredList = this.pilotList;
    } else {
      const key = this.searchKey.toLowerCase();
      this.filteredList = this.pilotList.filter((p: ObservedDiscipleItem) => (p.city || '').toLowerCase().includes(key));
    }
  }

  onSearchChange(value: string) {
    this.searchKey = value;
    this.applyFilter();
  }

  async onMatchTap(item: ObservedDiscipleItem) {
    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '登录后才能收徒' });
      return;
    }

    // 校验个人资料完整性，先刷新获取最新数据
    await AuthService.refreshCurrentUser();
    const currentUser = AuthService.getCurrentUser();
    if (!currentUser) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    const missing: string[] = [];
    if (!currentUser.avatar) missing.push('头像');
    if (!currentUser.displayName) missing.push('昵称');
    if (!currentUser.phone) missing.push('电话');
    if (missing.length > 0) {
      const dialogRes = await promptAction.showDialog({
        title: '无法收徒',
        message: '请先完善个人资料（' + missing.join('、') + '）',
        buttons: [
          { text: '取消', color: '#999999' },
          { text: '去完善', color: '#07C160' }
        ]
      });
      if (dialogRes.index === 1) {
        router.push({ url: 'pages/Profile' });
      }
      return;
    }

    try {
      await matchDisciple(item.openid, token);
      promptAction.showToast({ message: '收徒成功' });

      // 本地更新 UI（不重建列表）
      const currentOpenId = AuthService.getCurrentOpenId();
      item.isMine = true;
      item.masterCount = (item.masterCount || 0) + 1;
      if (currentOpenId && currentUser) {
        const newMaster: DiscipleMaster = {
          openid: currentOpenId,
          nickname: currentUser.displayName || currentUser.openId || '师傅',
          avatar: currentUser.avatar || ''
        };
        item.masters = [...item.masters, newMaster];
      }

      // 后台静默刷新数据
      this.loadData(false, true);
    } catch (err) {
      promptAction.showToast({ message: '操作失败' });
    }
  }

  async onCancelMatch(item: ObservedDiscipleItem) {
    const token = AuthService.getAuthToken();
    if (!token) return;

    // 确认弹窗
    const dialogRes = await promptAction.showDialog({
      title: '缘分已尽',
      message: '请确认解除师徒关系',
      buttons: [
        { text: '取消', color: '#999999' },
        { text: '确认', color: '#fa5151' }
      ]
    });

    if (dialogRes.index !== 1) {
      return;
    }

    try {
      await removeDisciple(item.openid, token);
      promptAction.showToast({ message: '已取消' });

      // 本地更新 UI（不重建列表）
      const currentOpenId = AuthService.getCurrentOpenId();
      item.isMine = false;
      item.masterCount = Math.max(0, (item.masterCount || 0) - 1);
      if (currentOpenId) {
        item.masters = item.masters.filter((m: DiscipleMaster) => m.openid !== currentOpenId);
      }

      // 后台静默刷新数据
      this.loadData(false, true);
    } catch (err) {
      promptAction.showToast({ message: '操作失败' });
    }
  }

  async onContactDisciple(item: ObservedDiscipleItem) {
    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    // 校验个人资料完整性，先刷新获取最新数据
    await AuthService.refreshCurrentUser();
    const currentUser = AuthService.getCurrentUser();
    if (!currentUser) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    const missing: string[] = [];
    if (!currentUser.avatar) missing.push('头像');
    if (!currentUser.displayName) missing.push('昵称');
    if (!currentUser.phone) missing.push('电话');
    if (missing.length > 0) {
      const dialogRes = await promptAction.showDialog({
        title: '无法联系',
        message: '请先完善个人资料（' + missing.join('、') + '）',
        buttons: [
          { text: '取消', color: '#999999' },
          { text: '去完善', color: '#07C160' }
        ]
      });
      if (dialogRes.index === 1) {
        router.push({ url: 'pages/Profile' });
      }
      return;
    }

    try {
      const contact: PilotContact = await fetchPilotContact(item.openid, token);
      const phone = contact.phone;
      const wechatId = contact.wechatId;
      if (!phone && !wechatId) {
        promptAction.showToast({ message: '暂无联系方式' });
        return;
      }

      const hasPhone = !!phone;
      const hasWechat = !!wechatId;

      if (hasPhone && hasWechat) {
        promptAction.showActionMenu({
          title: '联系方式',
          buttons: [{ text: '拨打电话', color: '#07c160' }, { text: '复制微信', color: '#07c160' }]
        }).then((response) => {
          const index = response.index;
          if (index === 0) {
            call.makeCall(phone);
          } else if (index === 1) {
            const pasteData = pasteboard.createData('text/plain', wechatId);
            const systemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData);
            promptAction.showToast({ message: '微信已复制' });
          }
        }).catch(() => {});
      } else if (hasPhone) {
        call.makeCall(phone);
      } else if (hasWechat) {
        const pasteData = pasteboard.createData('text/plain', wechatId);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        systemPasteboard.setData(pasteData);
        promptAction.showToast({ message: '微信已复制' });
      }
    } catch (err) {
      promptAction.showToast({ message: '获取联系方式失败' });
    }
  }

  async onContactMaster(item: ObservedDiscipleItem) {
    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    // 校验个人资料完整性，先刷新获取最新数据
    await AuthService.refreshCurrentUser();
    const currentUser = AuthService.getCurrentUser();
    if (!currentUser) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    const missing: string[] = [];
    if (!currentUser.avatar) missing.push('头像');
    if (!currentUser.displayName) missing.push('昵称');
    if (!currentUser.phone) missing.push('电话');
    if (missing.length > 0) {
      const dialogRes = await promptAction.showDialog({
        title: '无法联系',
        message: '请先完善个人资料（' + missing.join('、') + '）',
        buttons: [
          { text: '取消', color: '#999999' },
          { text: '去完善', color: '#07C160' }
        ]
      });
      if (dialogRes.index === 1) {
        router.push({ url: 'pages/Profile' });
      }
      return;
    }

    if (!item.masters || item.masters.length === 0) {
      promptAction.showToast({ message: '暂无师傅信息' });
      return;
    }

    try {
      const master = item.masters[0];
      const contact: PilotContact = await fetchPilotContact(master.openid, token);
      const phone = contact.phone;
      const wechatId = contact.wechatId;
      if (!phone && !wechatId) {
        promptAction.showToast({ message: '暂无联系方式' });
        return;
      }

      const hasPhone = !!phone;
      const hasWechat = !!wechatId;

      if (hasPhone && hasWechat) {
        promptAction.showActionMenu({
          title: '联系方式',
          buttons: [{ text: '拨打电话', color: '#07c160' }, { text: '复制微信', color: '#07c160' }]
        }).then((response) => {
          const index = response.index;
          if (index === 0) {
            call.makeCall(phone);
          } else if (index === 1) {
            const pasteData = pasteboard.createData('text/plain', wechatId);
            const systemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData);
            promptAction.showToast({ message: '微信已复制' });
          }
        }).catch(() => {});
      } else if (hasPhone) {
        call.makeCall(phone);
      } else if (hasWechat) {
        const pasteData = pasteboard.createData('text/plain', wechatId);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        systemPasteboard.setData(pasteData);
        promptAction.showToast({ message: '微信已复制' });
      }
    } catch (err) {
      promptAction.showToast({ message: '获取联系方式失败' });
    }
  }

  showRatingDialog(role: string, index: number) {
    this.ratingRole = role;
    this.ratingIndex = index;
    this.ratingDialogController = new CustomDialogController({
      builder: RatingDialog({
        ratingScore: 5,
        ratingComment: '',
        onSubmit: (score, comment) => {
          this.submitRating(score, comment);
        },
        onCancel: () => {}
      }),
      customStyle: true,
      alignment: DialogAlignment.Center
    });
    this.ratingDialogController.open();
  }

  async submitRating(score: number, comment: string) {
    const item = this.filteredList[this.ratingIndex];
    if (!item) {
      console.error('【submitRating】item not found, ratingIndex:', this.ratingIndex, 'filteredList length:', this.filteredList.length);
      return;
    }

    const token = AuthService.getAuthToken();
    if (!token) {
      console.error('【submitRating】no token');
      return;
    }

    console.info('【submitRating】disciple_openid:', item.openid, 'role:', this.ratingRole, 'score:', score, 'comment:', comment);
    console.info('【submitRating】token:', token.substring(0, 20) + '...');

    try {
      const res = await createStandbyRating({
        disciple_openid: item.openid,
        role: this.ratingRole,
        score: score,
        comment: comment
      }, token);
      console.info('【submitRating】success:', JSON.stringify(res));
      promptAction.showToast({ message: '评价已提交' });
      this.loadData();
    } catch (err) {
      console.error('【submitRating】error:', JSON.stringify(err));
      promptAction.showToast({ message: '提交失败' });
    }
  }

  showIntroDialog() {
    this.introText = '';
    this.introPrice = '';
    this.introDialogController = new CustomDialogController({
      builder: IntroDialog({
        introText: '',
        introPrice: '',
        onConfirm: (intro: string, price: string) => {
          this.onConfirmIntroWithParams(intro, price);
        },
        onCancel: () => {
          this.hideIntroDialog();
        }
      }),
      customStyle: true,
      maskColor: 'rgba(0, 0, 0, 0.7)',
      alignment: DialogAlignment.Bottom,
    });
    this.introDialogController.open();
  }

  hideIntroDialog() {
    // dialog 由 controller 管理关闭
  }

  async onConfirmIntroWithParams(text: string, priceStr: string) {
    const trimmedText = text.trim();
    if (!trimmedText) {
      promptAction.showToast({ message: '请输入自我介绍' });
      return;
    }

    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    try {
      const price = parseFloat(priceStr) || 0;
      console.info('【onConfirmIntroWithParams】before joinDisciple, isJoined:', this.isJoined, 'text:', trimmedText, 'price:', price);
      await joinDisciple(trimmedText, price, token);
      console.info('【onConfirmIntro】after joinDisciple, isJoined:', this.isJoined);
      promptAction.showToast({ message: '发布成功' });
      this.showIntroPopup = false;
      // 立即设置 isJoined = true（用户已在列表中）
      this.isJoined = true;
      console.info('【onConfirmIntro】after set isJoined=true, isJoined:', this.isJoined);
      // 更新缓存（使用当前列表数据，保持 isJoined=true）
      const cacheItems: DiscipleItem[] = this.pilotList.map((item: ObservedDiscipleItem): DiscipleItem => {
        return {
          openid: item.openid,
          order_id: item.order_id,
          out_trade_no: item.out_trade_no,
          name: item.name,
          city: item.city,
          avatar: item.avatar,
          intro: item.intro,
          price: item.price,
          paid_at: item.paid_at,
          finished_at: item.finished_at,
          masters: item.masters,
          masterCount: item.masterCount,
          hasMatchedMe: item.hasMatchedMe,
          isMine: item.isMine,
          transfer_status: item.transfer_status,
          rating: item.rating,
          masterRating: item.masterRating
        };
      });
      this.writeCache(cacheItems, true);
      // 静默刷新获取最新列表（确保 isJoined 状态与列表一致）
      this.loadData(false, true);
      console.info('【onConfirmIntro】after loadData, isJoined:', this.isJoined);
    } catch (err) {
      console.error('【onConfirmIntro】error:', JSON.stringify(err));
      promptAction.showToast({ message: '发布失败' });
    }
  }

  async onLeaveStandby() {
    const token = AuthService.getAuthToken();
    if (!token) return;

    try {
      await leaveDisciple(token);
      promptAction.showToast({ message: '已退出' });
      // 乐观更新：立即显示"加入匹配"按钮
      this.isJoined = false;
      // 更新缓存中的 isJoined 状态
      const cached = this.readCache();
      if (cached) {
        this.writeCache(cached.items, false);
      }
      // 静默刷新获取最新列表
      this.loadData(false, true);
    } catch (err) {
      promptAction.showToast({ message: '退出失败' });
    }
  }


  build() {
    Stack() {
      // 背景层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .expandSafeArea([SafeAreaType.SYSTEM])

      // 主内容区 - 可滚动
      HdsNavigation() {
        Scroll(this.scroller) {
          Column() {
            // 顶部区域 - 横幅图片
            Column() {
              Image(BANNER_URL)
                .width('100%')
                .borderRadius(16)
                .objectFit(ImageFit.Cover)
            }
            .width('90%')
            .margin({ top: -50 })
            .alignItems(HorizontalAlign.Center)

            // 搜索框
            Search({ placeholder: '搜索城市' })
              .width('90%')
              .margin({ top: 16 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(20)
              .onChange((value: string) => { this.onSearchChange(value); })

            // 加载状态
            if (this.loading && this.filteredList.length === 0) {
              List() {
                ForEach([1, 2, 3], () => {
                  ListItem() {
                    Column() {
                      // 头像 + 昵称
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

                      // 信息行
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
                          .margin({ left: 20 })
                          .opacity(this.skeletonShimmer ? 1 : 0.4)
                          .animation({ duration: 300 })
                      }
                      .width('100%')
                      .justifyContent(FlexAlign.SpaceBetween)
                    }
                    .width('100%')
                    .padding(24)
                    .backgroundColor($r('app.color.card_bg'))
                    .borderRadius(14)
                  }
                  .padding({ left: 18, right: 18, top: 8, bottom: 8 })
                })
              }
              .width('100%')
            } else if (this.filteredList.length === 0) {
              // 空状态
              Column() {
                Text('暂无徒弟信息')
                  .fontSize(16)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 40 })
              }
            } else {
              // 徒弟列表
              List() {
                ForEach(this.filteredList, (item: ObservedDiscipleItem) => {
                  ListItem() {
                    DiscipleCard({
                      item: item,
                      onMatch: (i: ObservedDiscipleItem) => { this.onMatchTap(i); },
                      onCancelMatch: (i: ObservedDiscipleItem) => { this.onCancelMatch(i); },
                      onContactDisciple: (i: ObservedDiscipleItem) => { this.onContactDisciple(i); },
                      onContactMaster: (i: ObservedDiscipleItem) => { this.onContactMaster(i); },
                      onRating: (i: ObservedDiscipleItem, role: string) => {
                        const idx = this.filteredList.findIndex((p: ObservedDiscipleItem) => p.openid === i.openid);
                        this.showRatingDialog(role, idx);
                      }
                    })
                  }
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                })
              }
              .width('100%')
              .padding({ bottom: 100 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
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

      // 底部悬浮按钮
      Column() {
        if (this.isJoined) {
          Button('不找了')
            .width('60%')
            .height(44)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#EF4444')
            .borderRadius(22)
            .onClick(() => { this.onLeaveStandby(); })
        } else {
          Button('加入匹配')
            .width('60%')
            .height(44)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#07c160')
            .borderRadius(22)
            .onClick(() => { this.showIntroDialog(); })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .position({ y: '95%' })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
  }
}
