import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import { fetchDisciples, fetchMyDisciples, matchDisciple, removeDisciple, joinDisciple, leaveDisciple, createStandbyRating, DiscipleItem, DiscipleMaster, MyDisciplesResult } from '../service/ApiService';
import AuthService from '../service/AuthService';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

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

@Entry
@Component
struct Standby {
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  @State pilotList: DiscipleItem[] = [];
  @State filteredList: DiscipleItem[] = [];
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
    this.loadData();
  }

  async loadData() {
    this.loading = true;
    try {
      const discipleRes = await fetchDisciples();
      const token = AuthService.getAuthToken();
      const myDiscipleRes = token ? await fetchMyDisciples(token) : { items: [] } as MyDisciplesResult;

      const items = discipleRes.items || [];
      const myDisciples = myDiscipleRes.items || [];

      this.pilotList = items;
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
      this.filteredList = this.pilotList.filter((p: DiscipleItem) => (p.city || '').toLowerCase().includes(key));
    }
  }

  onSearchChange(value: string) {
    this.searchKey = value;
    this.applyFilter();
  }

  async onMatchTap(item: DiscipleItem) {
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

  async onCancelMatch(item: DiscipleItem) {
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

  async onContactDisciple(item: DiscipleItem) {
    // TODO: 获取联系方式
    promptAction.showToast({ message: '暂无联系方式' });
  }

  async onContactMaster(item: DiscipleItem) {
    // TODO: 获取联系方式
    promptAction.showToast({ message: '暂无联系方式' });
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
      // 背景模糊层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))

      Column() {
        // 顶部区域 - 动态模糊背景
        Column() {
          // 标题
          Text('师徒匹配')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('DouyinSansBold')
            .margin({ top: 40, bottom: 16 })

          // 副标题
          Text('找师傅带入门，找徒弟传承技术')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.8)')
            .margin({ bottom: 20 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18 })
        .backgroundImage(BANNER_URL)
        .backgroundImagePosition(Alignment.Center)
        .backgroundImageSize(ImageSize.Cover)
        .width('100%')
        .height(160)

        // 搜索框
        Search({ placeholder: '搜索城市' })
          .width('90%')
          .margin({ top: -20 })
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
            ForEach(this.filteredList, (item: DiscipleItem, index: number) => {
              ListItem() {
                this.DiscipleCard(item, index)
              }
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')

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
      .padding({ bottom: 30 })
      .alignItems(HorizontalAlign.Center)
      .position({ y: '88%' })

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

  @Builder
  DiscipleCard(item: DiscipleItem, index: number) {
    Column() {
      // 顶部区域：入行感谢金标签+金额badge
      Row() {
        // 入行感谢金标签 - 左边，黑色粗体
        Text('入行感谢金')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        // 感谢金金额badge - 右边，圆角矩形
        if (item.price > 0) {
          Text('¥' + item.price)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#07c160')
            .borderRadius(3)
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 主信息区
      Row() {
        // 左侧：徒弟信息 - 带背景，水平排列
        Row() {
          Image(item.avatar || DEFAULT_AVATAR)
            .width(50)
            .height(50)
            .borderRadius(25)

          Column() {
            Text(item.name || '匿名飞手')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            Text(item.city || '')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .width('60%')
        }
        .alignItems(VerticalAlign.Center)
        .width('42%')
        .height('100%')
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(10)

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
        Column() {
          if (item.masters && item.masters.length > 0) {
            Image(item.masters[0].avatar || DEFAULT_AVATAR)
              .width(50)
              .height(50)
              .borderRadius(25)
            Text(item.masters[0].nickname || '师傅')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 4 })
            Text('已收徒 ' + item.masterCount + ' 人')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => { this.onCancelMatch(item); })
          } else {
            Row() {
              // 图标 - 绿色原始图标
              Image($r('app.media.icon_gan'))
                .width(32)
                .height(32)

              // 文字
              Text('我收了')
                .fontSize(13)
                .fontColor('#6f7c90')
                .fontWeight(FontWeight.Medium)
                .margin({ left: 8 })
            }
            .alignItems(VerticalAlign.Center)
            .onClick(() => { this.onMatchTap(item); })
          }
        }
        .alignItems(HorizontalAlign.Center)
        .width('42%')
        .height('100%')
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(10)
      }
      .width('100%')
      .height(90)

      // 自我介绍
      if (item.intro) {
        Column() {
          Text(item.intro)
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
        if (item.rating) {
          Text('师傅对徒弟: ' + '★'.repeat(item.rating))
            .fontSize(11)
            .fontColor('#FFD700')
        }
        if (item.masterRating) {
          Text('  徒弟对师傅: ' + '★'.repeat(item.masterRating))
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
          .onClick(() => { this.onContactDisciple(item); })
        Button('联系师傅')
          .fontSize(12)
          .height(28)
          .fontColor('#07c160')
          .backgroundColor('#E8F7ED')
          .borderRadius(14)
          .margin({ left: 10 })
          .onClick(() => { this.onContactMaster(item); })
        if (item.masters && item.masters.length > 0) {
          Button('去评价')
            .fontSize(12)
            .height(28)
            .fontColor('#FF9500')
            .backgroundColor('#FFF5E6')
            .borderRadius(14)
            .margin({ left: 10 })
            .onClick(() => { this.showRatingDialog(item.isMine ? 'disciple' : 'master', index); })
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
