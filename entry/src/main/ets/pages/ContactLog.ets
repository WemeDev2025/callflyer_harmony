import promptAction from '@ohos.promptAction';
import { fetchContactLogFeed, ContactLogItem, ContactLogActor } from '../service/ApiService';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';
const PAGE_SIZE = 30;

function formatTimeLabel(isoStr: string | undefined): string {
  if (!isoStr) return '';
  const d = new Date(isoStr);
  const now = new Date();
  const diffMs = now.getTime() - d.getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return '刚刚';
  if (diffMin < 60) return `${diffMin} 分钟前`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `${diffH} 小时前`;
  const diffD = Math.floor(diffH / 24);
  if (diffD < 30) return `${diffD} 天前`;
  return `${d.getMonth() + 1}/${d.getDate()}`;
}

class ContactLogItemEx {
  openid?: string;
  actor?: ContactLogActor;
  target?: ContactLogActor;
  action_label?: string;
  created_at?: string;
  timeLabel?: string;
}

@Entry
@Component
struct ContactLog {
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  @State items: ContactLogItemEx[] = [];
  @State loading: boolean = false;
  @State loadingMore: boolean = false;
  @State hasMore: boolean = false;

  private skip: number = 0;
  private isLoading: boolean = false;

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    if (this.isLoading) return;
    this.isLoading = true;
    this.loading = true;

    try {
      const result = await fetchContactLogFeed({ limit: PAGE_SIZE, skip: 0 });
      console.info('【ContactLog】loadData result - items:', result.items?.length, 'count:', result.count);
      this.items = result.items || [];
      for (let i = 0; i < this.items.length; i++) {
        this.items[i].timeLabel = formatTimeLabel(this.items[i].created_at);
      }
      this.skip = result.items?.length || 0;
      // 如果返回的数量等于请求的 limit，说明可能还有更多数据
      this.hasMore = this.skip === PAGE_SIZE;
      console.info('【ContactLog】loadData after - skip:', this.skip, 'hasMore:', this.hasMore);
    } catch (err) {
      console.error('【加载联系记录失败】', JSON.stringify(err));
      promptAction.showToast({ message: '加载失败' });
    }

    this.loading = false;
    this.isLoading = false;
  }

  async loadMore() {
    if (this.isLoading || !this.hasMore) return;
    this.isLoading = true;
    this.loadingMore = true;

    try {
      const result = await fetchContactLogFeed({ limit: PAGE_SIZE, skip: this.skip });
      const newItems: ContactLogItemEx[] = result.items || [];
      for (let i = 0; i < newItems.length; i++) {
        newItems[i].timeLabel = formatTimeLabel(newItems[i].created_at);
      }
      this.items = this.items.concat(newItems);
      this.skip = this.skip + newItems.length;
      this.hasMore = newItems.length === PAGE_SIZE;
    } catch (err) {
      console.error('【加载更多失败】', JSON.stringify(err));
      promptAction.showToast({ message: '加载更多失败' });
    }

    this.loadingMore = false;
    this.isLoading = false;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .clip(false)

      if (this.loading) {
        Column() {
          LoadingProgress().width(48).height(48).color($r('app.color.primary_color'))
          Text('加载中...').fontColor($r('app.color.text_secondary')).fontSize(14).margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column() {
          Text('暂无联系记录')
            .fontColor($r('app.color.text_secondary'))
            .fontSize(14)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.items, (item: ContactLogItemEx, index: number) => {
            ListItem() {
              this.ContactLogItem(item)
            }
          }, (item: ContactLogItemEx, index: number) => `${item.openid}-${index}`)

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
        .width('100%')
        .height('100%')
        .sticky(0)
        .onReachEnd(() => {
          console.info('【ContactLog】onReachEnd triggered, hasMore:', this.hasMore, 'isLoading:', this.isLoading);
          this.loadMore()
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ContactLogItem(item: ContactLogItemEx) {
    Row() {
      Column() {
        Image(item.actor?.avatar || DEFAULT_AVATAR)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.avatar_placeholder'))
        Text(item.actor?.nickname || '匿名')
          .fontSize(12)
          .fontColor($r('app.color.text_body'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Center)
      .width(70)

      Column() {
        Text(item.action_label || '联系')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        Text(item.timeLabel || '')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)

      Column() {
        Image(item.target?.avatar || DEFAULT_AVATAR)
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.avatar_placeholder'))
        Text(item.target?.nickname || '匿名')
          .fontSize(12)
          .fontColor($r('app.color.text_body'))
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Center)
      .width(70)
    }
    .width('90%')
    .padding({ top: 16, bottom: 16, left: 20, right: 20 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ left: '5%', right: '5%', top: 8 })
  }
}
