import router from '@ohos.router';
import { fetchCityCoverage, CityCoverageSummary, CityItem } from '../service/ApiService';

interface CityGroup {
  province: string;
  cities: CityItem[];
  litCount: number;
}

@Entry
@Component
struct CityCoverage {
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
    Column() {
      // 搜索栏
      TextInput({ placeholder: '搜索城市或省份', text: this.keyword })
        .width('100%')
        .height(44)
        .backgroundColor('#ffffff')
        .borderRadius(22)
        .placeholderColor('#9aa4b2')
        .fontSize(14)
        .onChange((text: string) => { this.onSearchChange(text); })

      Scroll(this.scroller) {
        Column() {
          if (this.loading) {
            Column() {
              Text('加载中...')
                .fontColor('#9aa4b2')
                .fontSize(14)
            }
            .width('100%')
            .padding(80)
          } else if (this.error) {
            Column() {
              Text(this.error)
                .fontColor('#9aa4b2')
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
                    .fontColor('#07C160')
                  Text(' / ')
                    .fontSize(18)
                    .fontColor('#d0d8e4')
                  Text(String(this.summary.total_cities))
                    .fontSize(18)
                    .fontWeight(700)
                    .fontColor('#1d2b3a')
                  Text(' 城市已覆盖')
                    .fontSize(18)
                    .fontColor('#8a96a8')
                }
                .width('100%')

                Column() {
                  Row()
                    .width(this.summary.coverage_pct + '%')
                    .height(5)
                    .borderRadius(3)
                    .backgroundColor('#07C160')
                }
                .width('100%')
                .height(5)
                .backgroundColor('#f0f2f5')
                .borderRadius(3)
                .margin({ top: 8 })

                Text('覆盖率 ' + this.summary.coverage_pct + '%')
                  .fontSize(11)
                  .fontColor('#9aa4b2')
                  .margin({ top: 8 })
                  .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#ffffff')
              .borderRadius(12)
            }

            if (!this.keyword.trim()) {
              Row() {
                Row() {
                  Text('全部 ' + this.cities.length)
                    .fontSize(12)
                    .fontColor(this.filterMode === 'all' ? '#ffffff' : '#8a96a8')
                    .fontWeight(this.filterMode === 'all' ? 700 : 400)
                }
                .layoutWeight(1)
                .height(36)
                .backgroundColor(this.filterMode === 'all' ? '#07C160' : '#ffffff')
                .borderRadius(6)
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .onClick(() => { this.onFilterChange('all'); })

                Row() {
                  Text('已覆盖 ' + (this.summary?.lit_cities || 0))
                    .fontSize(12)
                    .fontColor(this.filterMode === 'lit' ? '#ffffff' : '#8a96a8')
                    .fontWeight(this.filterMode === 'lit' ? 700 : 400)
                }
                .layoutWeight(1)
                .height(36)
                .backgroundColor(this.filterMode === 'lit' ? '#07C160' : '#ffffff')
                .borderRadius(6)
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .margin({ left: 6 })
                .onClick(() => { this.onFilterChange('lit'); })

                Row() {
                  Text('未覆盖 ' + (this.summary?.unlit_cities || 0))
                    .fontSize(12)
                    .fontColor(this.filterMode === 'unlit' ? '#ffffff' : '#8a96a8')
                    .fontWeight(this.filterMode === 'unlit' ? 700 : 400)
                }
                .layoutWeight(1)
                .height(36)
                .backgroundColor(this.filterMode === 'unlit' ? '#07C160' : '#ffffff')
                .borderRadius(6)
                .alignItems(VerticalAlign.Center)
                .justifyContent(FlexAlign.Center)
                .margin({ left: 6 })
                .onClick(() => { this.onFilterChange('unlit'); })
              }
              .width('100%')
              .padding({ top: 10, bottom: 4 })
            }

            if (this.groups.length === 0) {
              Column() {
                Text('没有匹配的城市')
                  .fontColor('#9aa4b2')
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
                    .fontColor('#1d2b3a')
                  Blank()
                  Text(group.litCount + ' / ' + group.cities.length)
                    .fontSize(11)
                    .fontColor('#9aa4b2')
                }
                .width('100%')
                .padding({ bottom: 8 })

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(group.cities, (city: CityItem) => {
                    Row() {
                      Text(city.city)
                        .fontSize(12)
                        .fontColor(city.lit ? '#ffffff' : '#b0b8c8')
                      if (city.lit) {
                        Text(' ' + city.pilot_count)
                          .fontSize(10)
                          .fontColor('rgba(255,255,255,0.85)')
                          .fontWeight(700)
                      }
                    }
                    .backgroundColor(city.lit ? '#07C160' : '#f5f6f8')
                    .borderRadius(5)
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .margin({ right: 6, bottom: 6 })
                    .onClick(() => { this.onCityTap(city.city); })
                  })
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#ffffff')
              .borderRadius(10)
              .margin({ left: 14, right: 14, bottom: 10 })
            })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Start)
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
    .padding({ left: 14, right: 14 })
    .backgroundColor('#E7F8FC')
  }
}
