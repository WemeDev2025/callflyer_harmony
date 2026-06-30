import router from '@ohos.router';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import window from '@ohos.window';
import { fetchCityCoverage, CityCoverageSummary, CityItem } from '../service/ApiService';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

interface CityGroup {
  province: string;
  cities: CityItem[];
  litCount: number;
}

@Entry
@Component
struct CityCoverage {
  // 颜色模式监听（跟随系统深浅色）
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  scroller: Scroller = new Scroller();
  @State loading: boolean = true;
  @State error: string = '';
  @State summary: CityCoverageSummary | null = null;
  @State cities: CityItem[] = [];
  @State groups: CityGroup[] = [];
  @State filterMode: string = 'all';
  @State keyword: string = '';

  aboutToAppear() {
    this.loadData();
    // 设置状态栏背景色
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#121212' : '#E7F8FC',
          statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#E5FFFFFF' : '#E5020202'
        });
      });
    } catch (e) {}
  }

  aboutToDisappear() {
    // 恢复状态栏透明
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a'
        });
      });
    } catch (e) {}
  }

  async loadData() {
    this.loading = true;
    this.error = '';
    try {
      const res = await fetchCityCoverage();
      this.summary = res.summary;
      this.cities = res.cities || [];
      this._applyFilter();
    } catch (err) {
      this.error = '加载失败，下拉刷新重试';
    }
    this.loading = false;
  }

  onSearchChange(text: string) {
    this.keyword = text;
    this._applyFilter();
  }

  onFilterChange(mode: string) {
    this.filterMode = mode;
    this._applyFilter();
  }

  _applyFilter() {
    const kw = this.keyword.trim();
    let list = this.cities;
    if (this.filterMode === 'lit') {
      list = list.filter((c: CityItem) => c.lit);
    } else if (this.filterMode === 'unlit') {
      list = list.filter((c: CityItem) => !c.lit);
    }
    if (kw) {
      list = list.filter((c: CityItem) => c.city.includes(kw) || c.province.includes(kw));
    }

    const map: Record<string, CityGroup> = {};
    list.forEach((c: CityItem) => {
      const p = c.province || '其他';
      if (!map[p]) {
        map[p] = { province: p, cities: [], litCount: 0 };
      }
      map[p].cities.push(c);
      if (c.lit) {
        map[p].litCount += 1;
      }
    });

    this.groups = Object.values(map).sort((a: CityGroup, b: CityGroup) => {
      return b.litCount - a.litCount;
    });
  }

  onCityTap(city: string) {
    router.pushUrl({ url: 'pages/new', params: { search: city } });
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))

      HdsNavigation() {
        Scroll(this.scroller) {
          Column() {
            // 占位，撑开搜索栏以下的空间
            Blank().height(8)

            if (this.loading) {
              Column() {
                Text('加载中...')
                  .fontColor($r('app.color.text_caption'))
                  .fontSize(14)
              }
              .width('100%')
              .padding(80)
            } else if (this.error) {
              Column() {
                Text(this.error)
                  .fontColor($r('app.color.text_caption'))
                  .fontSize(14)
              }
              .width('100%')
              .padding(80)
            } else {
              if (this.summary && !this.keyword.trim()) {
                Column() {
                  Row() {
                    Text(String(this.summary.lit_cities))
                      .fontSize(28)
                      .fontWeight(900)
                      .fontColor($r('app.color.badge_green'))
                    Text(' / ')
                      .fontSize(18)
                      .fontColor($r('app.color.text_secondary'))
                    Text(String(this.summary.total_cities))
                      .fontSize(18)
                      .fontWeight(700)
                      .fontColor($r('app.color.text_primary'))
                    Text(' 城市已覆盖')
                      .fontSize(18)
                      .fontColor($r('app.color.text_caption'))
                  }
                  .width('100%')

                  Column() {
                    Row()
                      .width(this.summary.coverage_pct + '%')
                      .height(5)
                      .borderRadius(3)
                      .backgroundColor($r('app.color.badge_green'))
                  }
                  .width('100%')
                  .height(5)
                  .backgroundColor($r('app.color.card_bg_secondary'))
                  .borderRadius(3)
                  .margin({ top: 8 })
                  .alignItems(HorizontalAlign.Start)

                  Text('覆盖率 ' + this.summary.coverage_pct + '%')
                    .fontSize(11)
                    .fontColor($r('app.color.text_caption'))
                    .margin({ top: 8 })
                    .width('100%')
                }
                .width('90%')
                .padding(16)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(12)
              }

              if (!this.keyword.trim()) {
                Row() {
                  Row() {
                    Text('全部 ' + this.cities.length)
                      .fontSize(12)
                      .fontColor(this.filterMode === 'all' ? '#ffffff' : $r('app.color.text_caption'))
                      .fontWeight(this.filterMode === 'all' ? 700 : 400)
                  }
                  .layoutWeight(1)
                  .height(36)
                  .backgroundColor(this.filterMode === 'all' ? $r('app.color.badge_green') : $r('app.color.card_bg'))
                  .borderRadius(6)
                  .alignItems(VerticalAlign.Center)
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => { this.onFilterChange('all'); })

                  Row() {
                    Text('已覆盖 ' + (this.summary?.lit_cities || 0))
                      .fontSize(12)
                      .fontColor(this.filterMode === 'lit' ? '#ffffff' : $r('app.color.text_caption'))
                      .fontWeight(this.filterMode === 'lit' ? 700 : 400)
                  }
                  .layoutWeight(1)
                  .height(36)
                  .backgroundColor(this.filterMode === 'lit' ? $r('app.color.badge_green') : $r('app.color.card_bg'))
                  .borderRadius(6)
                  .alignItems(VerticalAlign.Center)
                  .justifyContent(FlexAlign.Center)
                  .margin({ left: 6 })
                  .onClick(() => { this.onFilterChange('lit'); })

                  Row() {
                    Text('未覆盖 ' + (this.summary?.unlit_cities || 0))
                      .fontSize(12)
                      .fontColor(this.filterMode === 'unlit' ? '#ffffff' : $r('app.color.text_caption'))
                      .fontWeight(this.filterMode === 'unlit' ? 700 : 400)
                  }
                  .layoutWeight(1)
                  .height(36)
                  .backgroundColor(this.filterMode === 'unlit' ? $r('app.color.badge_green') : $r('app.color.card_bg'))
                  .borderRadius(6)
                  .alignItems(VerticalAlign.Center)
                  .justifyContent(FlexAlign.Center)
                  .margin({ left: 6 })
                  .onClick(() => { this.onFilterChange('unlit'); })
                }
                .width('90%')
                .padding({ top: 10, bottom: 10 })
              }

              if (this.groups.length === 0 && this.keyword.trim()) {
                Column() {
                  Text('没有匹配的城市')
                    .fontColor($r('app.color.text_caption'))
                    .fontSize(14)
                }
                .width('100%')
                .padding(80)
              }

              ForEach(this.groups, (group: CityGroup) => {
                Column() {
                  Row() {
                    Text(group.province)
                      .fontSize(14)
                      .fontWeight(700)
                      .fontColor($r('app.color.text_primary'))
                    Blank()
                    Text(group.litCount + ' / ' + group.cities.length)
                      .fontSize(11)
                      .fontColor($r('app.color.text_caption'))
                  }
                  .width('100%')
                  .padding({ bottom: 8 })

                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(group.cities, (city: CityItem) => {
                      Row() {
                        Text(city.city)
                          .fontSize(12)
                          .fontColor(city.lit ? '#ffffff' : $r('app.color.text_caption'))
                        if (city.lit) {
                          Text(' ' + city.pilot_count)
                            .fontSize(10)
                            .fontColor('rgba(255,255,255,0.85)')
                            .fontWeight(700)
                        }
                      }
                      .backgroundColor(city.lit ? $r('app.color.badge_green') : $r('app.color.card_bg_secondary'))
                      .borderRadius(5)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .margin({ right: 6, bottom: 6 })
                      .onClick(() => { this.onCityTap(city.city); })
                    })
                  }
                  .width('100%')
                }
                .width('90%')
                .padding(12)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(10)
                .margin({ bottom: 10 })
              })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 6, bottom: 160 })
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .position({ y: 56 })
      .hideBackButton(true)
      .backgroundColor('#00000000')
      .titleBar({
        enableComponentSafeArea: false,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: false,
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

      // 搜索栏 - 放 Stack 最后确保在最上层，水平居中
      Column() {
        TextInput({ placeholder: '搜索城市或省份', text: this.keyword })
          .width('100%')
          .height(44)
          .backgroundColor($r('app.color.card_bg'))
          .borderRadius(22)
          .placeholderColor($r('app.color.text_caption'))
          .fontSize(14)
          .onChange((text: string) => { this.onSearchChange(text); })
      }
      .width('90%')
      .position({ x: '5%', y: 12 })
      .zIndex(1)
    }
    .width('100%')
    .height('100%')
  }
}
