import { ReferralLeaderboardItem, fetchReferralLeaderboard, fetchPublicProfile, fetchPilotContact } from '../service/ApiService';
import { PilotCard, PilotCardData } from '../components/PilotCard';
import AuthService from '../service/AuthService';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import call from '@ohos.telephony.call';
import pasteboard from '@ohos.pasteboard';
import display from '@ohos.display';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import window from '@ohos.window';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';

@Component
struct ReferralLeaderboardItemView {
  item: ReferralLeaderboardItem = {
    openid: '',
    nickname: '',
    avatar_url: '',
    referral_count: 0
  };
  rank: number = 0;
  onAvatarClick: (openid: string) => void = () => {};

  build() {
    Row() {
      if (this.rank === 1) {
        Text('🥇').fontSize(28).width(40).textAlign(TextAlign.Center)
      } else if (this.rank === 2) {
        Text('🥈').fontSize(28).width(40).textAlign(TextAlign.Center)
      } else if (this.rank === 3) {
        Text('🥉').fontSize(28).width(40).textAlign(TextAlign.Center)
      } else {
        Text(String(this.rank))
          .fontSize(16).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_secondary'))
          .width(40).textAlign(TextAlign.Center)
      }

      Image(this.item.avatar_url || DEFAULT_AVATAR)
        .width(48).height(48).borderRadius(24).backgroundColor($r('app.color.avatar_placeholder'))
        .onClick(() => this.onAvatarClick(this.item.openid))

      Column() {
        Text(this.item.nickname || '未知用户')
          .fontSize(16).fontColor($r('app.color.text_primary')).fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.rank <= 3) {
          Text('TOP ' + this.rank)
            .fontSize(12).fontWeight(FontWeight.Bold)
            .fontColor(this.rank === 1 ? '#b45309' : this.rank === 2 ? '#475569' : '#c2410c')
            .backgroundColor(this.rank === 1 ? '#fef3c7' : this.rank === 2 ? '#f1f5f9' : '#fef2e8')
            .borderRadius(12).padding({ left: 8, right: 8, top: 2, bottom: 2 }).margin({ top: 4 })
        } else {
          Text('TOP ' + this.rank)
            .fontSize(12).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.card_bg_secondary')).borderRadius(12)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 }).margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })

      Row() {
        Text(String(this.item.referral_count))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.badge_green'))
        Text('人').fontSize(14).fontColor($r('app.color.text_secondary')).margin({ left: 2 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .alignItems(VerticalAlign.Center)
  }
}

@CustomDialog
struct PilotCardDialog {
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

  build() {
    Stack() {
      // 点击蒙层空白关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.01)')
        .onClick(() => { this.controller?.close(); })

      Column() {
        PilotCard({
          user: this.user,
          showDistance: false,
          showRecentActive: false,
          showActions: true,
          onWechatClick: () => { this.onWechatClick(); },
          onCallClick: () => { this.onCallClick(); }
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
struct ReferralLeaderboard {
  // 颜色模式监听（跟随系统深浅色）
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  @State leaderboard: ReferralLeaderboardItem[] = [];
  @State loading: boolean = true;
  @State myRank: number = 0;
  @State myCount: number = 0;
  @State expandedPilotCardData: PilotCardData | null = null;
  @State showCopySuccess: boolean = false;

  dialogController: CustomDialogController | null = null;

  aboutToAppear() {
    this.loadLeaderboard();
    // 设置状态栏透明，让顶部图片延伸上去
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000'
        });
      });
    } catch (e) {}
  }

  async loadLeaderboard() {
    this.loading = true;
    try {
      const res = await fetchReferralLeaderboard(50);
      this.leaderboard = res.leaderboard;
      this.myRank = res.my_rank;
      this.myCount = res.my_count;
    } catch (err) {
      console.error('【共创榜单】加载失败:', JSON.stringify(err));
      promptAction.showToast({ message: '加载失败' });
    }
    this.loading = false;
  }

  onAvatarClick(openid: string) {
    fetchPublicProfile(openid)
      .then(async (res) => {
        const p = res as Record<string, Object>;
        if (!p) return;
        const businessScopeArr: string[] = Array.isArray(p['businessScope']) ? p['businessScope'] as string[]
          : Array.isArray(p['business_scope']) ? p['business_scope'] as string[] : [];
        const licenseType = ((p['licenseType'] as string) || (p['license_type'] as string) || '').toLowerCase();

        let phone = '';
        let wechatId = '';
        try {
          const token = AuthService.getAuthToken();
          const contact = await fetchPilotContact(openid, token);
          phone = contact.phone;
          wechatId = contact.wechatId;
        } catch (e) {}

        this.expandedPilotCardData = {
          openid: openid,
          nickname: (p['nickname'] as string) || '用户',
          avatar: (p['avatarUrl'] as string) || (p['avatar_url'] as string) || DEFAULT_AVATAR,
          city: (p['city'] as string) || '',
          userRole: (p['userRole'] as string) || (p['user_role'] as string) || 'pilot',
          roleLabel: (p['userRole'] === 'employer' || p['user_role'] === 'employer') ? '雇主' : '飞手',
          licenseType: licenseType,
          licenseStatus: (p['licenseStatus'] as string) || (p['license_status'] as string) || '',
          pilotCode: (p['pilotCode'] as string) || (p['pilot_code'] as string) || '',
          company: (p['company'] as string) || '',
          position: (p['position'] as string) || '',
          droneModel: ((p['droneModel'] as string) || (p['drone_model'] as string) || '').split('/').filter(Boolean).join(' · '),
          businessScopeText: businessScopeArr.join(' · '),
          recentActiveText: '',
          likeCount: (p['likeCount'] as number) || (p['like_count'] as number) || 0,
          likedByMe: (p['likedByMe'] as boolean) || (p['liked_by_me'] as boolean) || false,
          phone: phone,
          wechatId: wechatId,
          douyinId: (p['douyinId'] as string) || (p['douyin_id'] as string) || '',
          distanceText: '',
          isNew: false,
          workMu: (p['workMu'] as number) || (p['work_mu'] as number) || null,
          workKg: (p['workKg'] as number) || (p['work_kg'] as number) || null,
          droneImages: (p['droneImages'] as string[]) || [],
          channelsId: (p['channelsId'] as string) || (p['channels_id'] as string) || '',
          institutionId: (p['institutionId'] as string) || (p['institution_id'] as string) || '',
          licenseUrl: (p['licenseUrl'] as string) || (p['license_url'] as string) || '',
        };

        this.dialogController = new CustomDialogController({
          builder: PilotCardDialog({
            user: this.expandedPilotCardData,
            onWechatClick: async () => {
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
                  title: '无法复制',
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
              const wechatId = this.expandedPilotCardData?.wechatId || '';
              if (wechatId) {
                const pasteData = pasteboard.createData('text/plain', wechatId);
                const systemPasteboard = pasteboard.getSystemPasteboard();
                systemPasteboard.setData(pasteData);
                this.showCopySuccess = true;
                setTimeout(() => { this.showCopySuccess = false; }, 1500);
              }
            },
            onCallClick: async () => {
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
                  title: '无法拨打电话',
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
              const phone = this.expandedPilotCardData?.phone || '';
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
        this.dialogController.open();
      })
      .catch(() => {
        promptAction.showToast({ message: '加载失败' });
      });
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          // 顶部 banner
          Column()
            .width('100%')
            .height(200)
            .backgroundImage('https://wetofly.com/data/image/pic_top.webp')
            .backgroundImageSize(ImageSize.Cover)

          // 榜单卡片容器
          Column() {
            if (this.loading) {
              Text('加载中...')
                .fontSize(16).fontColor($r('app.color.text_secondary')).width('100%')
                .textAlign(TextAlign.Center).padding({ top: 100, bottom: 100 })
            } else if (this.leaderboard.length === 0) {
              Text('暂无榜单数据')
                .fontSize(16).fontColor($r('app.color.text_secondary')).width('100%')
                .textAlign(TextAlign.Center).padding({ top: 100, bottom: 100 })
            } else {
              ForEach(this.leaderboard, (item: ReferralLeaderboardItem, index: number) => {
                Column() {
                  ReferralLeaderboardItemView({
                    item: item,
                    rank: index + 1,
                    onAvatarClick: (openid: string): void => { this.onAvatarClick(openid); }
                  })
                  Divider().color($r('app.color.divider')).margin({ left: 76 })
                }
              })

              if (this.myRank > 0) {
                Column() {
                  Text('我的排名：第 ' + this.myRank + ' 名（邀请 ' + this.myCount + ' 人）')
                    .fontSize(14).fontColor($r('app.color.badge_green')).fontWeight(FontWeight.Medium)
                }
                .width('100%').padding(16)
                .backgroundColor('rgba(22, 163, 74, 0.06)')
                .borderRadius(12).margin({ top: 8 })
              }
            }
          }
          .width('100%')
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(24)
          .margin({ left: 12, right: 12, top: -20 })
          .padding({ bottom: 34 })
        }
        .width('100%')
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      if (this.showCopySuccess) {
        Column() {
          Text('✓ 已复制')
            .fontSize(16).fontColor($r('app.color.text_on_dark_background')).fontWeight(FontWeight.Bold)
        }
        .width(120).height(120)
        .backgroundColor('rgba(0, 0, 0, 0.75)')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
