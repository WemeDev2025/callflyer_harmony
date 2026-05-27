import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import call from '@ohos.telephony.call';
import vibrator from '@ohos.vibrator';
import { imagePreview } from './imagepreview/ImagePreview';
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
  distanceText: string = '';
  isNew: boolean = false;
}

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
    distanceText: '',
    isNew: false,
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

  aboutToAppear() {
    this.internalLikeCount = this.user.likeCount ?? 0;
    this.internalLikedByMe = this.user.likedByMe ?? false;
  }

  async handleLikeClick() {
    // 震动反馈
    try {
      vibrator.startVibration({ type: 'time', duration: 30 }, { usage: 'touch' });
    } catch (e) {}

    const token = AuthService.getAuthToken();
    if (!token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    // 保存当前状态用于回滚
    const prevLiked = this.internalLikedByMe;
    const prevCount = this.internalLikeCount;
    const nextLiked = !prevLiked;
    const optimisticCount = Math.max(0, (prevCount ?? 0) + (nextLiked ? 1 : -1));

    // 乐观更新
    this.internalLikedByMe = nextLiked;
    this.internalLikeCount = optimisticCount;

    try {
      const res = nextLiked
        ? await likeProfile(this.user.openid, token)
        : await unlikeProfile(this.user.openid, token);

      // 更新最终状态
      this.internalLikedByMe = res.liked_by_me;
      this.internalLikeCount = res.like_count;
      // 强制触发UI更新
      this.user.likedByMe = res.liked_by_me;
      this.onLikeChanged?.(res.like_count, res.liked_by_me);
    } catch (err) {
      // 失败回滚
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
            imagePreview.show([this.user.avatar || DEFAULT_AVATAR], {
              showIndex: false
            });
          })

        Column() {
          Text(this.user.nickname)
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

      // 电话
      // if (this.user.phone) {
      //   Row() {
      //     Text('电话')
      //       .fontSize(14)
      //       .fontColor('#455066')
      //       .fontWeight(FontWeight.Medium)
      //     Text(this.user.phone)
      //       .fontSize(14)
      //       .fontColor('#1f2a3a')
      //       .fontWeight(FontWeight.Medium)
      //   }
      //   .width('100%')
      //   .justifyContent(FlexAlign.SpaceBetween)
      //   .margin({ top: 9 })
      // }

      // 微信
      // if (this.user.wechatId) {
      //   Row() {
      //     Text('微信')
      //       .fontSize(14)
      //       .fontColor('#455066')
      //       .fontWeight(FontWeight.Medium)
      //     Text(this.user.wechatId)
      //       .fontSize(14)
      //       .fontColor('#1f2a3a')
      //       .fontWeight(FontWeight.Medium)
      //   }
      //   .width('100%')
      //   .justifyContent(FlexAlign.SpaceBetween)
      //   .margin({ top: 9 })
      // }

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
                .backgroundColor($r('app.color.badge_green'))
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
    .padding(28)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ bottom: 12 })
  }
}
