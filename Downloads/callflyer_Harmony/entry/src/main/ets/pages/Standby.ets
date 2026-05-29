import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import { fetchDisciples, fetchMyDisciples, matchDisciple, removeDisciple, joinDisciple, leaveDisciple, createStandbyRating, fetchPilotContact, DiscipleItem, DiscipleMaster, MyDisciplesResult, PilotContact } from '../service/ApiService';
import AuthService from '../service/AuthService';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';
const BANNER_URL = 'https://wetofly.com/data/image/pic_thank.webp';

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
          .onClick(() => { this.onCancel(); this.controller.close(); })
        Button('提交')
          .width('40%')
          .type(ButtonType.Normal)
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
  rating: number | null = null;
  masterRating: number | null = null;

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
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding({ top: 6, bottom: 6, left: 8, right: 8 })

        // 中间连接线 - 短横线
        Column() {
          Column()
            .width(30)
            .height(2)
            .backgroundColor($r('app.color.divider'))
        }
        .width('16%')
        .height('100%')
        .justifyContent(FlexAlign.Center)

        // 右侧：师傅信息 - 带背景
        Row() {
          if (this.item.masterCount > 0) {
            Row() {
              Image(this.item.masters && this.item.masters[0] ? this.item.masters[0].avatar || DEFAULT_AVATAR : DEFAULT_AVATAR)
                .width(35)
                .height(35)
                .borderRadius(17.5)

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
            Row() {
              // 绿色圆形背景包裹图标
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

              // 文字
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
        .backgroundColor('#F5F5F5')
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
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .margin({ top: 10 })
      }

      // 评星
      Row() {
        if (this.item.rating) {
          Text('师傅对徒弟: ' + '★'.repeat(this.item.rating))
            .fontSize(11)
            .fontColor('#FFD700')
        }
        if (this.item.masterRating) {
          Text('  徒弟对师傅: ' + '★'.repeat(this.item.masterRating))
            .fontSize(11)
            .fontColor('#FFD700')
        }
      }
      .margin({ top: 6 })

      // 操作按钮 - 微信风格
      Row() {
        Button('联系徒弟')
          .fontSize(12)
          .height(28)
          .fontColor('#07c160')
          .backgroundColor('#E8F7ED')
          .borderRadius(14)
          .onClick(() => { this.onContactDisciple(this.item); })
        if (this.item.masterCount > 0) {
          Button('联系师傅')
            .fontSize(12)
            .height(28)
            .fontColor('#07c160')
            .backgroundColor('#E8F7ED')
            .borderRadius(14)
            .margin({ left: 10 })
            .onClick(() => { this.onContactMaster(this.item); })
        }
        if (this.item.isMine || (this.item.masterCount > 0 && this.item.masters && this.item.masters.length > 0 && this.item.masters[0].openid === AuthService.getCurrentOpenId())) {
          Button('去评价')
            .fontSize(12)
            .height(28)
            .fontColor('#FF9500')
            .backgroundColor('#FFF5E6')
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
  @State isJoined: boolean = false;
  @State searchKey: string = '';
  @State showIntroPopup: boolean = false;
  @State introText: string = '';
  @State introPrice: string = '';
  @State showRatingPopup: boolean = false;
  @State ratingRole: string = 'master';
  @State ratingIndex: number = -1;

  private ratingDialogController: CustomDialogController | null = null;

  aboutToAppear() {
    this.loadData(true);
  }

  async loadData(showLoading: boolean = false) {
    if (showLoading) {
      this.loading = true;
    }
    try {
      const discipleRes = await fetchDisciples();
      const token = AuthService.getAuthToken();
      const myDiscipleRes = token ? await fetchMyDisciples(token) : { items: [] } as MyDisciplesResult;

      const items = discipleRes.items || [];
      const myDisciples = myDiscipleRes.items || [];

      this.pilotList = items.map((item: DiscipleItem) => new ObservedDiscipleItem(item));
      this.applyFilter();
      this.isJoined = items.some((p: DiscipleItem) => p.isMine);
    } catch (err) {
      console.error('【师徒匹配加载失败】', JSON.stringify(err));
      promptAction.showToast({ message: '加载失败' });
    }
    this.loading = false;
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

    try {
      await matchDisciple(item.openid, token);
      promptAction.showToast({ message: '收徒成功' });
      this.loadData();
    } catch (err) {
      promptAction.showToast({ message: '操作失败' });
    }
  }

  async onCancelMatch(item: ObservedDiscipleItem) {
    const token = AuthService.getAuthToken();
    if (!token) return;

    try {
      await removeDisciple(item.openid, token);
      promptAction.showToast({ message: '已取消' });
      this.loadData();
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
    if (!item) return;

    const token = AuthService.getAuthToken();
    if (!token) return;

    try {
      await createStandbyRating({
        disciple_openid: item.openid,
        role: this.ratingRole,
        score: score,
        comment: comment
      }, token);
      promptAction.showToast({ message: '评价已提交' });
      this.loadData();
    } catch (err) {
      promptAction.showToast({ message: '提交失败' });
    }
  }

  showIntroDialog() {
    this.introText = '';
    this.introPrice = '';
    this.showIntroPopup = true;
  }

  hideIntroDialog() {
    this.showIntroPopup = false;
  }

  async onConfirmIntro() {
    const text = this.introText.trim();
    if (!text) {
      promptAction.showToast({ message: '请输入自我介绍' });
      return;
    }

    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    try {
      const price = parseFloat(this.introPrice) || 0;
      await joinDisciple(text, price, token);
      promptAction.showToast({ message: '发布成功' });
      this.showIntroPopup = false;
      this.loadData();
    } catch (err) {
      promptAction.showToast({ message: '发布失败' });
    }
  }

  async onLeaveStandby() {
    const token = AuthService.getAuthToken();
    if (!token) return;

    try {
      await leaveDisciple(token);
      promptAction.showToast({ message: '已退出' });
      this.loadData();
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
            if (this.loading) {
              LoadingProgress()
                .width(40)
                .height(40)
                .margin({ top: 40 })
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

      // 自我介绍弹窗
      if (this.showIntroPopup) {
        Stack() {
          // 蒙层
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => { this.hideIntroDialog(); })

          // 弹窗内容
          Column() {
            Text('发布加入匹配')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 20 })

            TextInput({ placeholder: '自我介绍' })
              .width('90%')
              .height(100)
              .margin({ bottom: 16 })
              .onChange((text: string) => { this.introText = text; })

            TextInput({ placeholder: '感谢金（选填）' })
              .width('90%')
              .margin({ bottom: 20 })
              .onChange((text: string) => { this.introPrice = text; })

            Row() {
              Button('取消')
                .width('40%')
                .height(40)
                .fontColor('#666666')
                .backgroundColor('#EEEEEE')
                .borderRadius(20)
                .onClick(() => { this.hideIntroDialog(); })
              Button('发布')
                .width('40%')
                .height(40)
                .fontColor('#FFFFFF')
                .backgroundColor('#07c160')
                .borderRadius(20)
                .onClick(() => { this.onConfirmIntro(); })
            }
            .width('90%')
            .justifyContent(FlexAlign.SpaceAround)
          }
          .width('85%')
          .padding(24)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
