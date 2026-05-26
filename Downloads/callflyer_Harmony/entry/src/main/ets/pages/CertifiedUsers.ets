import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import { fetchCertifiedProfiles, fetchPilotContact, likeProfile, unlikeProfile, CertifiedUser, CertifiedProfilesParams } from '../service/ApiService';
import AuthService from '../service/AuthService';
import { PilotCard, PilotCardData } from '../components/PilotCard';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';
const PAGE_SIZE = 20;

interface UserContact {
  phone: string;
  wechatId: string;
}

@Entry
@Component
struct CertifiedUsers {
  @State users: PilotCardData[] = [];
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = false;
  @State count: number = 0;
  @State searchText: string = '';

  private skip: number = 0;
  private isLoading: boolean = false;

  scroller: Scroller = new Scroller();
  searchController: SearchController = new SearchController();

  aboutToAppear() {
    this.loadCertifiedUsers();
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
    const user = this.users.find(u => u.openid === openid);
    if (!user) return;
    const contact = await this.getContactByOpenid(openid);
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
        .backgroundColor('#F5F8FA')
        .expandSafeArea([SafeAreaType.SYSTEM])

      List() {
        ListItem() {
          Row() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(20)
              .fontColor(['#999999'])
              .margin({ left: 14 })

            TextInput({
              placeholder: '搜索昵称/城市/主营业务...',
              text: this.searchText,
              controller: this.searchController
            })
              .layoutWeight(1)
              .height(44)
              .backgroundColor('#FFFFFF')
              .borderRadius(22)
              .placeholderColor('#999999')
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
                .fontSize(28)
                .fontColor(['#999999'])
                .margin({ right: 12 })
                .onClick(() => {
                  this.searchText = '';
                  this.loadCertifiedUsers();
                })
            }
          }
          .width('100%')
          .height(44)
          .backgroundColor('#FFFFFF')
          .borderRadius(22)
        }
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })

        if (this.loading) {
          ForEach([1, 2, 3], (i: number) => {
            ListItem() {
              Column() {
                Row() {
                  Row()
                    .width(56)
                    .height(56)
                    .borderRadius(28)
                    .backgroundColor('#E8E8E8')
                  Column() {
                    Row().width(120).height(18).borderRadius(4).backgroundColor('#E8E8E8').margin({ top: 4 })
                    Row().width(80).height(12).borderRadius(4).backgroundColor('#E8E8E8').margin({ top: 8 })
                  }
                  .margin({ left: 14 })
                }
                .width('100%')
                Divider().color('rgba(99, 105, 117, 0.15)').margin({ top: 12, bottom: 12 })
                Row() {
                  Row().width(100).height(15).borderRadius(4).backgroundColor('#E8E8E8')
                  Row().width(60).height(15).borderRadius(4).backgroundColor('#E8E8E8')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceBetween)
              }
              .width('100%')
              .padding(24)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .margin({ left: 18, right: 18, bottom: 12 })
            }
          })
        } else if (this.users.length === 0) {
          ListItem() {
            Column() {
              Text(this.searchText && this.searchText.trim() ? '未找到匹配结果' : '暂无认证用户')
                .fontColor('#999999')
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
                LoadingProgress().width(24).height(24).color('#999999')
                Text('加载中...').fontColor('#999999').fontSize(12).margin({ left: 8 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(20)
            }
          } else if (this.hasMore) {
            ListItem() {
              Text('点击加载更多')
                .fontSize(12)
                .fontColor('#999999')
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
    }
    .width('100%')
    .height('100%')
  }
}
