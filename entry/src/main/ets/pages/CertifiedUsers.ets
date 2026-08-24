import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import router from '@ohos.router';
import window from '@ohos.window';
import { fetchCertifiedProfiles, fetchPilotContact, likeProfile, unlikeProfile, CertifiedUser, CertifiedProfilesParams, fetchCertifiedTags, CertifiedTag } from '../service/ApiService';
import AuthService from '../service/AuthService';
import { PilotCard, PilotCardData } from '../components/PilotCard';
import systemShare from '@hms.collaboration.systemShare';
import common from '@ohos.app.ability.common';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';
const PAGE_SIZE = 20;

interface UserContact {
  phone: string;
  wechatId: string;
}

interface RoleOption {
  label: string;
  value: string;
  count?: number;
}

// 分享引导弹窗（定义在文件级别，避免 ArkTS strict mode 下 this 引用问题）
@CustomDialog
struct ShareGuideDialog {
  imagePath: string = '';
  onConfirm: () => void = () => {};
  controller: CustomDialogController;

  build() {
    Stack() {
      // 点击蒙层空白关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.05)')
        .onClick(() => {
          this.controller?.close();
        })

      Column() {
        Image(this.imagePath)
          .width('90%')
          .objectFit(ImageFit.Contain)
      }
      .width('80%')
      .borderRadius(16)
      .clip(true)
      .onClick(() => {
        this.onConfirm();
        this.controller?.close();
      })
    }
    .width('100%')
    .height('100%')
  }
}

@Entry
@Component
struct CertifiedUsers {
  // 颜色模式监听（跟随系统深浅色）
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  @State users: PilotCardData[] = [];
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State count: number = 0;
  @State searchText: string = '';
  @State currentRole: string = 'all';

  // 分享引导弹窗
  @State shareGuideImagePath: string = 'https://wetofly.com/data/image/pic_comeon.webp';
  private shareDialogController: CustomDialogController | null = null;
  private browseScrollTriggered: boolean = false;

  private skip: number = 0;
  private isLoading: boolean = false;
  private skeletonTimer: number = -1;

  @State skeletonShimmer: boolean = false;
  @State roleOptions: RoleOption[] = [];

  scroller: Scroller = new Scroller();
  searchController: SearchController = new SearchController();

  // 分享引导 CustomDialog
  private shareGuideDialogController: CustomDialogController = new CustomDialogController({
    builder: ShareGuideDialog({
      imagePath: this.shareGuideImagePath,
      onConfirm: this.confirmShare.bind(this)
    }),
    customStyle: true,
    maskColor: 'rgba(0, 0, 0, 0.7)',
    alignment: DialogAlignment.Center
  });

  // 滚动监听，滑过约10张卡片后触发分享引导
  onScrollIndex(scrollTop: number) {
    if (!this.browseScrollTriggered && scrollTop > 2500) {
      this.browseScrollTriggered = true;
      this.shareGuideDialogController?.open();
    }
  }

  // 确认分享
  async confirmShare() {
    try {
      const context = getContext(this) as common.UIAbilityContext;

      // 创建分享记录（使用超链接类型，content 为图片 URL）
      const record: systemShare.SharedRecord = {
        utd: 'general.hyperlink',
        content: 'https://wetofly.com/data/pic_h5Share.png',
        title: '呼叫飞手-找飞手 找雇主 都在这了',
        description: '打造 10W+ 职业飞手库'
      };
      // 创建分享数据
      const sharedData = new systemShare.SharedData(record);
      // 创建分享控制器
      const controller = new systemShare.ShareController(sharedData);
      // 显示系统分享面板
      await controller.show(context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT
      });
    } catch (e) {
      console.info('【分享失败】', JSON.stringify(e));
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

  aboutToAppear() {
    // 设置状态栏背景色
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#121212' : '#E7F8FC',
          statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#E5FFFFFF' : '#E5020202'
        });
      });
    } catch (e) {}

    // 并行加载标签和用户列表（无依赖关系）
    this.loadTags();
    this.loadCertifiedUsers();
  }

  async loadTags() {
    try {
      const token = AuthService.getAuthToken();
      const res = await fetchCertifiedTags(token || undefined);
      console.info('【加载标签】res:', JSON.stringify(res));
      if (res && res.tags && res.tags.length > 0) {
        this.roleOptions = res.tags.map(tag => ({
          label: tag.label,
          value: tag.key,
          count: tag.count ?? 0
        } as RoleOption));
        console.info('【加载标签】roleOptions:', JSON.stringify(this.roleOptions));
        console.info('【加载标签】巡检的value:', JSON.stringify(this.roleOptions.find(t => t.label === '巡检')));
      } else {
        console.info('【加载标签】tags为空或格式异常');
        this.roleOptions = [];
      }
    } catch (err) {
      console.error('【加载标签失败】', JSON.stringify(err));
      this.roleOptions = [];
    }
  }

  async loadCertifiedUsers(searchQuery?: string) {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.loading = true;
    this.startSkeletonShimmer();

    try {
      const token = AuthService.getAuthToken();
      const params: CertifiedProfilesParams = {
        limit: PAGE_SIZE,
        skip: 0
      };
      if (searchQuery && searchQuery.trim()) {
        params.search = searchQuery.trim();
      }
      if (this.currentRole && this.currentRole !== 'all') {
        if (this.currentRole === 'liked_by_me') {
          params.liked_by_me = true;
        } else if (this.currentRole === 'pilot' || this.currentRole === 'employer') {
          // 飞手/雇主是用户角色，用 role 参数过滤
          params.role = this.currentRole;
        } else {
          // 其他标签（business_xxx、caac、utc 等）用 tag 参数
          params.tag = this.currentRole;
        }
      }
      console.info('【认证用户】currentRole:', this.currentRole, 'params:', JSON.stringify(params));
      console.info('【认证用户】searchText:', this.searchText);
      const result = await fetchCertifiedProfiles(params, token || undefined);

      const newUsers = (result.items || []).map(item => this.toPilotCardData(item));
      this.users = newUsers;

      this.count = result.count || 0;
      this.skip = result.items?.length || 0;
      this.hasMore = this.skip < this.count;
    } catch (err) {
      console.error('【加载认证用户失败】', JSON.stringify(err));
      promptAction.showToast({ message: '加载失败' });
    }

    this.loading = false;
    this.isLoading = false;
    this.stopSkeletonShimmer();
  }

  onSearch(value: string) {
    this.searchText = value;
    this.loadCertifiedUsers(value);
  }

  handleRoleChange(role: string) {
    this.currentRole = role;
    this.searchText = '';
    console.info('【handleRoleChange】role:', role, 'searchText cleared');
    if (role === 'liked_by_me') {
      const token = AuthService.getAuthToken();
      if (!token) {
        promptAction.showToast({ message: '登录后即可查看我赞过的用户' });
        return;
      }
    }
    this.loadCertifiedUsers();
  }

  async loadMore() {
    if (this.isLoading || !this.hasMore) {
      return;
    }
    this.isLoading = true;
    this.loadingMore = true;

    try {
      const token = AuthService.getAuthToken();
      const params: CertifiedProfilesParams = {
        limit: PAGE_SIZE,
        skip: this.skip
      };
      if (this.currentRole && this.currentRole !== 'all') {
        if (this.currentRole === 'liked_by_me') {
          params.liked_by_me = true;
        } else if (this.currentRole === 'pilot' || this.currentRole === 'employer') {
          // 飞手/雇主是用户角色，用 role 参数过滤
          params.role = this.currentRole;
        } else {
          // 其他标签（business_xxx、caac、utc 等）用 tag 参数
          params.tag = this.currentRole;
        }
      }
      const result = await fetchCertifiedProfiles(params, token || undefined);

      const newUsers = (result.items || []).map(item => this.toPilotCardData(item));
      this.users = [...this.users, ...newUsers];

      this.skip = this.skip + newUsers.length;
      this.hasMore = this.skip < (result.count || 0);
    } catch (err) {
      console.error('【加载更多失败】', JSON.stringify(err));
      promptAction.showToast({ message: '加载更多失败' });
    }

    this.loadingMore = false;
    this.isLoading = false;
  }

  async getContactByOpenid(openid: string): Promise<UserContact> {
    const user = this.users.find(u => u.openid === openid);
    if (!user) return { phone: '', wechatId: '' };
    let phone = user.phone;
    let wechatId = user.wechatId;
    if (!phone || !wechatId) {
      const token = AuthService.getAuthToken();
      try {
        const contact = await fetchPilotContact(openid, token);
        phone = phone || contact.phone;
        wechatId = wechatId || contact.wechatId;
      } catch (err) {
        console.error('【获取联系方式失败】', JSON.stringify(err));
      }
    }
    return { phone, wechatId };
  }

  // 将CertifiedUser转换为PilotCardData类实例
  toPilotCardData(user: CertifiedUser): PilotCardData {
    const data = new PilotCardData();
    data.openid = user.openid;
    data.nickname = user.nickname;
    data.avatar = user.avatar;
    data.city = user.city;
    data.userRole = user.userRole;
    data.roleLabel = user.roleLabel;
    data.licenseType = user.licenseType;
    data.licenseStatus = user.licenseStatus;
    data.pilotCode = user.pilotCode;
    data.company = user.company;
    data.position = user.position;
    data.droneModel = user.droneModel;
    data.businessScopeText = user.businessScopeText;
    data.recentActiveText = user.recentActiveText;
    data.likeCount = user.likeCount ?? 0;
    data.likedByMe = user.likedByMe;
    data.phone = user.phone;
    data.wechatId = user.wechatId;
    data.distanceText = '';
    data.isNew = user.isNew;
    data.workMu = user.workMu ?? null;
    data.workKg = user.workKg ?? null;
    data.droneImages = user.droneImages || [];
    data.channelsId = user.channelsId || '';
    data.institutionId = '';
    data.licenseUrl = '';
    return data;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .clip(false)

      List() {
        ListItem() {
          Column() {
            Row() {
              SymbolGlyph($r('sys.symbol.magnifyingglass'))
                .fontSize(20)
                .fontColor([$r('app.color.text_secondary')])
                .margin({ left: 14 })

              TextInput({
                placeholder: '搜索昵称/城市/主营业务...',
                text: this.searchText,
                controller: this.searchController
              })
                .layoutWeight(1)
                .height(44)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(22)
                .placeholderColor($r('app.color.text_secondary'))
                .fontSize(15)
                .margin({ left: 8 })
                .onChange((value: string) => {
                  this.searchText = value;
                })
                .onSubmit((enterKey: EnterKeyType) => {
                  this.loadCertifiedUsers(this.searchText);
                })

              if (this.searchText && this.searchText.trim() !== '') {
                SymbolGlyph($r('sys.symbol.xmark'))
                  .fontSize(20)
                  .fontColor([$r('app.color.text_secondary')])
                  .margin({ right: 12 })
                  .onClick(() => {
                    this.searchText = '';
                    this.loadCertifiedUsers();
                  })
              }
            }
            .width('100%')
            .height(44)
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(22)

            // 标签行
            Scroll() {
              Row() {
                ForEach(this.roleOptions, (option: RoleOption) => {
                  Text(option.label + (option.count !== undefined ? '(' + option.count + ')' : ''))
                    .fontSize(13)
                    .fontColor(this.currentRole === option.value ? '#FFFFFF' : $r('app.color.text_title'))
                    .fontWeight(FontWeight.Medium)
                    .backgroundColor(this.currentRole === option.value ? $r('app.color.badge_green') : $r('app.color.card_bg'))
                    .borderRadius(16)
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .margin({ right: 8 })
                    .onClick(() => {
                      this.handleRoleChange(option.value);
                    })
                })

                // 记录按钮
                Text('记录')
                  .fontSize(13)
                  .fontColor($r('app.color.text_title'))
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor($r('app.color.card_bg'))
                  .borderRadius(16)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .margin({ right: 8 })
                  .onClick(() => {
                    router.pushUrl({ url: 'pages/ContactLog' });
                  })
              }
              .padding({ left: 4, right: 4, top: 10, bottom: 10 })
            }
            .width('100%')
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
          }
          .width('100%')
          .padding({ top: 12, bottom: 0 })
        }

        if (this.loading) {
          ForEach([1, 2, 3, 4, 5], (i: number) => {
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
                      .width(100)
                      .height(18)
                      .borderRadius(4)
                      .backgroundColor($r('app.color.skeleton_bg'))
                      .margin({ top: 4 })
                      .opacity(this.skeletonShimmer ? 1 : 0.4)
                      .animation({ duration: 300 })
                    Row()
                      .width(60)
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

                Column()
                  .width('100%')
                  .border({
                    width: { top: 0, right: 0, bottom: 1, left: 0 },
                    color: $r('app.color.divider'),
                    style: BorderStyle.Dashed
                  })
                  .margin({ top: 12, bottom: 12 })

                // 信息行占位（3行，匹配 PilotCard 字段数）
                Row() {
                  Row()
                    .width(60)
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
                    .width(80)
                    .height(15)
                    .borderRadius(4)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(40)
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
                    .width(55)
                    .height(15)
                    .borderRadius(4)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(70)
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
                    .width(40)
                    .height(26)
                    .borderRadius(3)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Blank()
                  Row()
                    .width(40)
                    .height(40)
                    .borderRadius(20)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .margin({ left: 12 })
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                  Row()
                    .width(40)
                    .height(40)
                    .borderRadius(20)
                    .backgroundColor($r('app.color.skeleton_bg'))
                    .margin({ left: 12 })
                    .opacity(this.skeletonShimmer ? 1 : 0.4)
                    .animation({ duration: 300 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .margin({ top: 12 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(14)
              .margin({ bottom: 12 })
            }
          })
        } else if (this.users.length === 0) {
          ListItem() {
            Column() {
              Text(this.searchText && this.searchText.trim() ? '未找到匹配结果' : '暂无认证用户')
                .fontColor($r('app.color.text_secondary'))
                .fontSize(14)
            }
            .width('100%')
            .padding(40)
            .justifyContent(FlexAlign.Center)
          }
        } else {
          ForEach(this.users, (user: PilotCardData) => {
            ListItem() {
              this.PilotCardItem(user)
            }
          }, (user: PilotCardData) => user.openid)

          if (this.loadingMore) {
            ListItem() {
              Row() {
                LoadingProgress().width(24).height(24).color($r('app.color.text_secondary'))
                Text('加载中...').fontColor($r('app.color.text_secondary')).fontSize(12).margin({ left: 8 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(20)
            }
          } else if (this.hasMore) {
            ListItem() {
              Text('点击加载更多')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(20)
                .onClick(() => this.loadMore())
            }
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18 })
      .sticky(0)
      .onReachEnd(() => {
        this.loadMore()
      })
      .onScrollIndex((firstIndex: number) => {
        // 根据索引估算滚动位置，每个卡片约250vp
        const estimatedScrollTop = firstIndex * 250;
        this.onScrollIndex(estimatedScrollTop);
      })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  PilotCardItem(user: PilotCardData) {
    PilotCard({
      user: user,
      showActions: true,
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

        console.info('### Builder PilotCardItem wechat click, user:', user.openid);
        let wechatId = user.wechatId || '';
        let phone = user.phone || '';
        // 如果本地没有wechatId，尝试获取
        if (!wechatId || !phone) {
          try {
            const token = AuthService.getAuthToken();
            const contact = await fetchPilotContact(user.openid, token);
            wechatId = wechatId || contact.wechatId || '';
            phone = phone || contact.phone || '';
          } catch (e) {
            console.info('### 获取联系方式失败:', JSON.stringify(e));
          }
        }
        console.info('### wechatId:', wechatId, 'phone:', phone);
        if (wechatId) {
          try {
            const pasteData = pasteboard.createData('text/plain', wechatId);
            const systemPasteboard = pasteboard.getSystemPasteboard();
            systemPasteboard.setData(pasteData);
            promptAction.showToast({ message: '微信号已复制' });
          } catch (err) {
            promptAction.showToast({ message: '微信号: ' + wechatId });
          }
        } else {
          promptAction.showToast({ message: '暂无微信号' });
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

        console.info('### Builder PilotCardItem call click, user:', user.openid);
        let phone = user.phone || '';
        // 如果本地没有phone，尝试获取
        if (!phone) {
          try {
            const token = AuthService.getAuthToken();
            const contact = await fetchPilotContact(user.openid, token);
            phone = phone || contact.phone || '';
          } catch (e) {
            console.info('### 获取联系方式失败:', JSON.stringify(e));
          }
        }
        console.info('### phone:', phone);
        if (phone) {
          try {
            call.makeCall(phone);
          } catch (err) {
            promptAction.showToast({ message: '拨打 ' + phone });
          }
        } else {
          promptAction.showToast({ message: '暂无电话号码' });
        }
      },
      onLikeChanged: (likeCount: number, likedByMe: boolean) => {
        // 在「我赞过」标签下，取消点赞后自动从列表移除
        if (this.currentRole === 'liked_by_me' && !likedByMe) {
          const index = this.users.findIndex(u => u.openid === user.openid);
          if (index > -1) {
            this.users.splice(index, 1);
            this.count = Math.max(0, this.count - 1);
            console.info('【我赞过】已移除用户:', user.openid, '剩余:', this.count);
          }
        }
      },
      onUnlikeInLikedTab: () => {
        // 在「我赞过」标签下，点击即移除（不等 API 返回）
        if (this.currentRole === 'liked_by_me') {
          const index = this.users.findIndex(u => u.openid === user.openid);
          if (index > -1) {
            this.users.splice(index, 1);
            this.count = Math.max(0, this.count - 1);
            console.info('【我赞过】点击即移除用户:', user.openid, '剩余:', this.count);
          }
        }
      }
    })
  }
}
