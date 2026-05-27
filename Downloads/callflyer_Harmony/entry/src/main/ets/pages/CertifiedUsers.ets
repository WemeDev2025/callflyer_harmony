import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
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
        .backgroundColor('rgba(0, 0, 0, 0.7)')
        .onClick(() => {
          this.controller?.close();
        })

      Column() {
        Image(this.imagePath)
          .width('80%')
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
        title: '呼叫飞手 - 无人机服务调度平台',
        description: '专业飞手调度平台，找飞手、发任务一键搞定'
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

  aboutToAppear() {
    this.loadTags();
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
      } else {
        console.info('【加载标签】tags为空或格式异常');
        this.roleOptions = [];
      }
      this.loadCertifiedUsers();
    } catch (err) {
      console.error('【加载标签失败】', JSON.stringify(err));
      this.roleOptions = [];
      this.loadCertifiedUsers();
    }
  }

  async loadCertifiedUsers(searchQuery?: string) {
    if (this.isLoading) {
      return;
    }
    this.isLoading = true;
    this.loading = true;

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
        params.tag = this.currentRole;
      }
      console.info('【认证用户】currentRole:', this.currentRole, 'params:', JSON.stringify(params));
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
  }

  onSearch(value: string) {
    this.searchText = value;
    this.loadCertifiedUsers(value);
  }

  handleRoleChange(role: string) {
    this.currentRole = role;
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
      const result = await fetchCertifiedProfiles({
        limit: PAGE_SIZE,
        skip: this.skip
      }, token || undefined);

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

  async onCopyWechatByOpenid(openid: string) {
    console.info('【复制微信】openid:', openid);
    const user = this.users.find(u => u.openid === openid);
    console.info('【复制微信】user:', user ? 'found' : 'not found', 'wechatId:', user?.wechatId);
    if (!user) return;
    const contact = await this.getContactByOpenid(openid);
    console.info('【复制微信】contact:', JSON.stringify(contact));
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

  async onCallPhoneByOpenid(openid: string) {
    const user = this.users.find(u => u.openid === openid);
    if (!user) return;
    const contact = await this.getContactByOpenid(openid);
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
    return data;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .expandSafeArea([SafeAreaType.SYSTEM])

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
              }
              .padding({ left: 4, right: 4, top: 10, bottom: 10 })
            }
            .width('100%')
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
          }
          .width('100%')
        }
        .padding({ left: 18, right: 18, top: 12 })

        if (this.loading) {
          ForEach([1, 2, 3], (i: number) => {
            ListItem() {
              Column() {
                Row() {
                  Row()
                    .width(56)
                    .height(56)
                    .borderRadius(28)
                    .backgroundColor($r('app.color.skeleton_bg'))
                  Column() {
                    Row().width(120).height(18).borderRadius(4).backgroundColor($r('app.color.skeleton_bg')).margin({ top: 4 })
                    Row().width(80).height(12).borderRadius(4).backgroundColor($r('app.color.skeleton_bg')).margin({ top: 8 })
                  }
                  .margin({ left: 14 })
                }
                .width('100%')
                Divider().color($r('app.color.divider')).margin({ top: 12, bottom: 12 })
                Row() {
                  Row().width(100).height(15).borderRadius(4).backgroundColor($r('app.color.skeleton_bg'))
                  Row().width(60).height(15).borderRadius(4).backgroundColor($r('app.color.skeleton_bg'))
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .width('100%')
              .padding(24)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(14)
              .margin({ left: 18, right: 18, bottom: 12 })
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
              PilotCard({
                user: user,
                showActions: true,
                onWechatClick: (openid: string): void => { this.onCopyWechatByOpenid(openid); },
                onCallClick: (openid: string): void => { this.onCallPhoneByOpenid(openid); },
              })
            }
            .padding({ left: 18, right: 18 })
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
      .sticky(0)
      .onReachEnd(() => {
        this.loadMore()
      })
      .onScrollIndex((firstIndex: number) => {
        // 根据索引估算滚动位置，每个卡片约250vp
        const estimatedScrollTop = firstIndex * 250;
        this.onScrollIndex(estimatedScrollTop);
      })
    }
    .width('100%')
    .height('100%')
  }
}
