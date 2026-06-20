import router from '@ohos.router';
import { CreateOrderParams, createOrder, QuoteParams, CreateOrderCustomer, BudgetInfo, fetchProfile, ProfileForm } from '../service/ApiService';
import AuthService from '../service/AuthService';
import LocationService from '../service/LocationService';
import promptAction from '@ohos.promptAction';
import window from '@ohos.window';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import vibrator from '@ohos.vibrator';

// 任务类型列表
class TaskCategoryItem {
  label: string;
  value: string;
  description: string;
  constructor(label: string, value: string, description: string) {
    this.label = label;
    this.value = value;
    this.description = description;
  }
}

const TASK_CATEGORY_LIST: TaskCategoryItem[] = [
  new TaskCategoryItem('吊运', 'hoisting', '物料短途转运（人力 / 车辆难直达场景）'),
  new TaskCategoryItem('巡检', 'inspection', '高危 / 大范围排查（电力、管道、桥梁等）'),
  new TaskCategoryItem('测绘', 'mapping', '地理空间数据获取与建模'),
  new TaskCategoryItem('植保', 'plant_protection', '农业作物喷药、病虫害防治'),
  new TaskCategoryItem('应急', 'emergency', '灾害 / 突发事故响应（勘查、救援、补给）'),
  new TaskCategoryItem('物流', 'logistics', '短途 / 特殊场景配送（偏远地区、急救物资）'),
  new TaskCategoryItem('航拍', 'aerial_media', '影视、广告、活动等空中拍摄'),
  new TaskCategoryItem('安防', 'security', '治安巡逻、周界防护、人流监控'),
  new TaskCategoryItem('施工', 'construction', '工程建设辅助（放线、物资吊运、清障）'),
  new TaskCategoryItem('监测', 'monitoring', '环境、气象、水质等数据采集分析'),
  new TaskCategoryItem('教育', 'education', '技能培训、考证教学、科普推广'),
  new TaskCategoryItem('勘探', 'exploration', '矿产、油气、资源分布探测'),
  new TaskCategoryItem('遥感', 'remote_sensing', '作物长势、生态环境等远距离监测'),
  new TaskCategoryItem('娱乐', 'entertainment', '个人航拍、竞速、户外记录等消费场景'),
];

// 以面积为核心参数的任务类型
const AREA_BASED_CATEGORIES: Set<string> = new Set(['plant_protection', 'mapping', 'remote_sensing', 'monitoring']);

// 距离档位
class DistanceBracketItem {
  label: string;
  value: string;
  maxKm: number;
  constructor(label: string, value: string, maxKm: number) {
    this.label = label;
    this.value = value;
    this.maxKm = maxKm;
  }
}

const DISTANCE_BRACKETS: DistanceBracketItem[] = [
  new DistanceBracketItem('<200m', 'lt_200m', 0.2),
  new DistanceBracketItem('200-500m', '200_500m', 0.5),
  new DistanceBracketItem('500-1000m', '500_1000m', 1.0),
  new DistanceBracketItem('1000-4000m', '1_4km', 4.0),
  new DistanceBracketItem('>4000m', 'gt_4km', 5.0),
];

// 垂直落差选项
const VERTICAL_DROP_LABELS: string[] = [
  '<50m',
  '50-150m',
  '>150m',
];

const VERTICAL_DROP_VALUES: string[] = [
  'lt_50m',
  '50_150m',
  'gt_150m',
];

// 任务类型选项文本
const TASK_CATEGORY_LABELS: string[] = TASK_CATEGORY_LIST.map(item => item.label);

// 今日日期字符串
function getTodayDate(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

@Entry
@Component
struct PublishTask {
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  @State submitting: boolean = false;

  // 表单数据
  @State city: string = '';
  @State locationLoading: boolean = false;
  @State locationFailed: boolean = false;
  @State taskCategoryIndex: number = -1;  // -1 表示未选择
  @State pickerSelectedCategoryIndex: number = 0;  // picker 内部选择
  @State taskCategoryDetail: string = '';
  @State distanceBrackets: string[] = [];
  @State distanceSelectedIndex: number = 0;
  @State payloadKg: string = '';
  @State totalOrders: string = '';
  @State verticalDropIndex: number = -1;
  @State pickerSelectedVerticalDropIndex: number = 0;  // picker 内部选择
  @State budgetAmount: string = '';
  @State expiresAt: string = '';
  @State notes: string = '';

  // 弹窗显示状态
  @State showDistancePicker: boolean = false;
  @State showDatePicker: boolean = false;

  // 判断是否为面积类任务
  get isAreaBased(): boolean {
    if (this.taskCategoryIndex < 0) {
      return false;
    }
    const category = TASK_CATEGORY_LIST[this.taskCategoryIndex];
    return category ? AREA_BASED_CATEGORIES.has(category.value) : false;
  }

  aboutToAppear() {
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#121212' : '#E7F8FC',
          statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#E5FFFFFF' : '#E5020202'
        });
      });
    } catch (e) {}

    // 自动获取当前位置并填充城市
    this.locationLoading = true;
    this.locationFailed = false;
    const context = getContext(this);
    LocationService.getCurrentLocation(context).then((location) => {
      console.info('【PublishTask】getCurrentLocation result:', JSON.stringify(location));
      this.locationLoading = false;
      if (location) {
        LocationService.reverseGeocode(location.latitude, location.longitude).then((city) => {
          console.info('【PublishTask】reverseGeocode result:', city);
          this.locationLoading = false;
          if (city) {
            this.city = city;
            this.locationFailed = false;
          } else {
            this.locationFailed = true;
          }
        }).catch((err: Error) => {
          console.error('【PublishTask】reverseGeocode error:', err.message);
          this.locationLoading = false;
          this.locationFailed = true;
        });
      } else {
        this.locationFailed = true;
      }
    }).catch((err: Error) => {
      console.error('【PublishTask】getCurrentLocation error:', err.message);
      this.locationLoading = false;
      this.locationFailed = true;
    });
  }

  retryLocation() {
    this.locationLoading = true;
    this.locationFailed = false;
    const context = getContext(this);
    LocationService.getCurrentLocation(context).then((location) => {
      this.locationLoading = false;
      if (location) {
        LocationService.reverseGeocode(location.latitude, location.longitude).then((city) => {
          this.locationLoading = false;
          if (city) {
            this.city = city;
            this.locationFailed = false;
          } else {
            this.locationFailed = true;
          }
        }).catch(() => {
          this.locationLoading = false;
          this.locationFailed = true;
        });
      } else {
        this.locationFailed = true;
      }
    }).catch(() => {
      this.locationLoading = false;
      this.locationFailed = true;
    });
  }

  aboutToDisappear() {
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#FFFFFF' : '#14233a'
        });
      });
    } catch (e) {}
  }

  getTaskCategoryLabel(): string {
    if (this.taskCategoryIndex < 0) {
      return '未选择';
    }
    return TASK_CATEGORY_LIST[this.taskCategoryIndex]?.label || '未选择';
  }

  getTaskCategoryDescription(): string {
    if (this.taskCategoryIndex < 0) {
      return '请输入具体内容';
    }
    return TASK_CATEGORY_LIST[this.taskCategoryIndex]?.description || '请输入具体内容';
  }

  getDistanceDisplay(): string {
    if (this.distanceBrackets.length === 0) {
      return '未选择';
    }
    const labels = this.distanceBrackets
      .map(v => DISTANCE_BRACKETS.find(d => d.value === v)?.label || v)
      .join('、');
    return labels;
  }

  getVerticalDropLabel(): string {
    if (this.verticalDropIndex < 0) {
      return '未选择';
    }
    return VERTICAL_DROP_LABELS[this.verticalDropIndex] || '未选择';
  }

  toggleDistanceBracket(value: string) {
    const index = this.distanceBrackets.indexOf(value);
    if (index >= 0) {
      this.distanceBrackets = this.distanceBrackets.filter(v => v !== value);
    } else {
      this.distanceBrackets = [...this.distanceBrackets, value];
    }
  }

  validateForm(): boolean {
    if (!this.city.trim()) {
      promptAction.showToast({ message: '请输入所在城市' });
      return false;
    }

    if (this.taskCategoryIndex < 0) {
      promptAction.showToast({ message: '请选择任务类型' });
      return false;
    }

    const payloadKg = Number(this.payloadKg);
    if (!this.payloadKg || isNaN(payloadKg) || payloadKg <= 0) {
      promptAction.showToast({ message: '请填写有效的单次载重' });
      return false;
    }

    const total = Number(this.totalOrders);
    if (!this.totalOrders || isNaN(total) || total <= 0) {
      promptAction.showToast({ message: '请填写有效的订单总量' });
      return false;
    }

    if (!this.isAreaBased) {
      if (this.distanceBrackets.length === 0) {
        promptAction.showToast({ message: '请选择运输距离' });
        return false;
      }
    }

    return true;
  }

  buildQuoteParams(): QuoteParams | null {
    const category = TASK_CATEGORY_LIST[this.taskCategoryIndex];
    if (!category) return null;

    const payloadKg = Math.round(Number(this.payloadKg));
    const totalOrders = Math.round(Number(this.totalOrders));

    if (this.isAreaBased) {
      return {
        task_category: category.value,
        payload_kg: payloadKg,
        total_orders: totalOrders,
        area_mu: totalOrders,
        task_category_detail: this.taskCategoryDetail.trim() || undefined,
      };
    } else {
      if (this.distanceBrackets.length === 0) return null;

      const lastDistance = this.distanceBrackets[this.distanceBrackets.length - 1];
      const distanceInfo = DISTANCE_BRACKETS.find(d => d.value === lastDistance);
      const distanceKm = distanceInfo?.maxKm || 0;

      return {
        task_category: category.value,
        distance_km: distanceKm,
        vertical_drop: VERTICAL_DROP_VALUES[this.verticalDropIndex],
        payload_kg: payloadKg,
        total_orders: totalOrders,
        task_category_detail: this.taskCategoryDetail.trim() || undefined,
      };
    }
  }

  async handleSubmit() {
    if (this.submitting) return;

    if (!this.validateForm()) return;

    const loggedIn = await this.ensureLoggedIn();
    if (!loggedIn) return;

    // 获取用户Profile检查联系方式
    const user = AuthService.getCurrentUser();
    const token = AuthService.getAuthToken();
    if (!user?.openId || !token) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    let profile: ProfileForm | null = null;
    try {
      profile = await fetchProfile(user.openId, token);
    } catch (e) {
      console.error('【获取Profile失败】', JSON.stringify(e));
    }

    if (!profile || !profile.phone || !/^1[3-9]\d{9}$/.test(profile.phone.trim())) {
      promptAction.showToast({ message: '请先完善个人信息（手机号）' });
      setTimeout(() => {
        router.pushUrl({ url: 'pages/Profile' });
      }, 1500);
      return;
    }

    const quoteParams = this.buildQuoteParams();
    if (!quoteParams) {
      promptAction.showToast({ message: '请完善任务信息' });
      return;
    }

    const category = TASK_CATEGORY_LIST[this.taskCategoryIndex];
    const categoryDetail = this.taskCategoryDetail.trim();
    const categoryDisplay = categoryDetail ? `${category.label}-${categoryDetail}` : category.label;

    const payload: CreateOrderParams = {
      quote_params: quoteParams,
      task_category: category.value,
      task_category_label: category.label,
      task_category_detail: categoryDetail || undefined,
      task_category_display: categoryDisplay,
      customer: {
        name: profile.nickname?.trim() || undefined,
        phone: profile.phone.trim(),
        city: profile.city?.trim() || this.city.trim(),
      } as CreateOrderCustomer,
      budget: this.budgetAmount ? {
        amount: Number(this.budgetAmount),
      } as BudgetInfo : undefined,
      notes: this.notes.trim() || undefined,
      expires_at: this.expiresAt || undefined,
    };

    console.info('【发布任务】payload:', JSON.stringify(payload));

    this.submitting = true;
    try {
      const result = await createOrder(payload);
      console.info('【发布任务成功】result:', JSON.stringify(result));
      promptAction.showToast({ message: '任务已发布' });

      setTimeout(() => {
        router.back();
      }, 1500);
    } catch (err) {
      console.error('【发布任务失败】', JSON.stringify(err));
      promptAction.showToast({ message: '发布失败，请重试' });
    } finally {
      this.submitting = false;
    }
  }

  async ensureLoggedIn(): Promise<boolean> {
    if (AuthService.isLogin() && AuthService.getAuthToken()) {
      return true;
    }
    promptAction.showToast({ message: '请先登录' });
    try {
      const result = await AuthService.login();
      if (!result.success) {
        return false;
      }
      const tokenResult = await AuthService.exchangeToken(result.userInfo!.openId, result.userInfo!.unionId);
      return !!tokenResult.token;
    } catch (e) {
      return false;
    }
  }

  // 任务类型选择弹窗
  @Builder
  TaskCategorySheet() {
    Column() {
      TextPicker({ range: TASK_CATEGORY_LABELS, selected: this.pickerSelectedCategoryIndex })
        .width('100%')
        .height(200)
        .canLoop(false)
        .selectedTextStyle({ color: '#1A1A1A', font: { size: 20, weight: FontWeight.Medium } })
        .textStyle({ color: '#999999', font: { size: 16 } })
        .disappearTextStyle({ color: '#999999', font: { size: 14 } })
        .onChange((value: string | string[], index: number | number[]) => {
          if (typeof index === 'number') {
            this.pickerSelectedCategoryIndex = index;
            vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' });
          }
        })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor('#1A1A1A')
          .backgroundColor('#F0F0F0')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .onClick(() => { this.showTaskCategoryPicker = false; })
        Text('确定')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#07C160')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .margin({ left: 24 })
          .onClick(() => {
            if (this.pickerSelectedCategoryIndex < 0) {
              this.pickerSelectedCategoryIndex = 0;
            }
            this.taskCategoryIndex = this.pickerSelectedCategoryIndex;
            this.showTaskCategoryPicker = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 48 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
    .borderRadius({ topLeft: 22, topRight: 22 })
    .padding({ bottom: 20 })
  }

  // 垂直落差选择弹窗
  @Builder
  VerticalDropSheet() {
    Column() {
      TextPicker({ range: VERTICAL_DROP_LABELS, selected: this.pickerSelectedVerticalDropIndex })
        .width('100%')
        .height(200)
        .canLoop(false)
        .selectedTextStyle({ color: '#1A1A1A', font: { size: 20, weight: FontWeight.Medium } })
        .textStyle({ color: '#999999', font: { size: 16 } })
        .disappearTextStyle({ color: '#999999', font: { size: 14 } })
        .onChange((value: string | string[], index: number | number[]) => {
          if (typeof index === 'number') {
            this.pickerSelectedVerticalDropIndex = index;
            vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' });
          }
        })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor('#1A1A1A')
          .backgroundColor('#F0F0F0')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .onClick(() => { this.showVerticalDropPicker = false; })
        Text('确定')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#07C160')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .margin({ left: 24 })
          .onClick(() => {
            this.verticalDropIndex = this.pickerSelectedVerticalDropIndex;
            this.showVerticalDropPicker = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 48 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
    .borderRadius({ topLeft: 22, topRight: 22 })
    .padding({ bottom: 34 })
  }

  // 距离选择弹窗
  @Builder
  DistanceSheet() {
    Column() {
      TextPicker({ range: DISTANCE_BRACKETS.map(item => item.label), selected: this.distanceSelectedIndex })
        .width('100%')
        .height(200)
        .canLoop(false)
        .selectedTextStyle({ color: '#1A1A1A', font: { size: 20, weight: FontWeight.Medium } })
        .textStyle({ color: '#999999', font: { size: 16 } })
        .disappearTextStyle({ color: '#999999', font: { size: 14 } })
        .onChange((value: string | string[], index: number | number[]) => {
          if (typeof index === 'number') {
            this.distanceSelectedIndex = index;
            vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' });
          }
        })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor('#1A1A1A')
          .backgroundColor('#F0F0F0')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .onClick(() => { this.showDistancePicker = false; })
        Text('确定')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#07C160')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .margin({ left: 24 })
          .onClick(() => {
            this.distanceBrackets = [DISTANCE_BRACKETS[this.distanceSelectedIndex].value];
            this.showDistancePicker = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 48 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
    .borderRadius({ topLeft: 22, topRight: 22 })
    .padding({ bottom: 20 })
  }

  // 日期选择弹窗
  @Builder
  DateSheet() {
    Column() {
      Column() {
        DatePicker({
          start: new Date(getTodayDate()),
          end: new Date('2030-12-31')
        })
          .width('100%')
          .height(200)
          .textStyle({ color: '#999999', font: { size: 16 } })
          .selectedTextStyle({ color: '#1A1A1A', font: { size: 20, weight: FontWeight.Medium } })
          .disappearTextStyle({ color: '#999999', font: { size: 14 } })
          .onDateChange((value: Date) => {
            this.expiresAt = `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
          })
      }
      .width('100%')
      .padding({ top: 20 })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor('#1A1A1A')
          .backgroundColor('#F0F0F0')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .onClick(() => { this.showDatePicker = false; })
        Text('确定')
          .fontSize(15)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#07C160')
          .borderRadius(8)
          .padding({ left: 36, right: 36, top: 10, bottom: 10 })
          .margin({ left: 24 })
          .onClick(() => {
            this.showDatePicker = false;
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 48 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
    .borderRadius({ topLeft: 22, topRight: 22 })
    .padding({ bottom: 20 })
  }

  @State showTaskCategoryPicker: boolean = false;
  @State showVerticalDropPicker: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#0F1216' : '#E7F8FC')
        .expandSafeArea([SafeAreaType.SYSTEM])

      Scroll() {
        Column() {
          // 顶部导航栏
          Row() {
            Image($r('app.media.icon_back'))
              .width(24)
              .height(24)
              .onClick(() => { router.back(); })
            Blank()
            Text('发布任务')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Blank()
            Blank()
              .width(24)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })

          // 所在城市
          Column() {
            Column() {
              Row() {
                Text('所在城市')
                  .fontSize(15)
                  .fontColor('#666666')
                  .flexShrink(0)
                TextInput({ placeholder: '请输入城市', text: this.city })
                  .height(40)
                  .fontSize(15)
                  .fontColor('#1A1A1A')
                  .placeholderColor('#999999')
                  .placeholderFont({ size: 15 })
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .layoutWeight(1)
                  .margin({ left: 12 })
                  .textAlign(TextAlign.End)
                  .onChange((value: string) => { this.city = value; })
                if (this.locationFailed) {
                  Text('定位失败')
                    .fontSize(12)
                    .fontColor('#FF6B6B')
                    .flexShrink(0)
                    .onClick(() => { this.retryLocation(); })
                }
              }
              .width('100%')
              .height(40)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 0 })

          // 任务类型 - 点击弹出
          Column() {
            Column() {
              Row() {
                Text('任务类型')
                  .fontSize(15)
                  .fontColor('#666666')
                  .flexGrow(1)
                Text(this.getTaskCategoryLabel())
                  .fontSize(15)
                  .fontColor(this.taskCategoryIndex >= 0 ? '#1A1A1A' : '#999999')
                  .textAlign(TextAlign.End)
                  .margin({ right: 12 })
              }
              .width('100%')
              .height(40)
              .alignItems(VerticalAlign.Center)
              .onClick(() => {
                if (this.taskCategoryIndex >= 0) {
                  this.pickerSelectedCategoryIndex = this.taskCategoryIndex;
                } else {
                  this.pickerSelectedCategoryIndex = 0;
                }
                this.showTaskCategoryPicker = true;
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 0 })
          .bindSheet($$this.showTaskCategoryPicker, this.TaskCategorySheet(), {
            height: 360,
            dragBar: true,
            showClose: false,
            backgroundColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF',
            radius: { topLeft: 22, topRight: 22 }
          })

          if (this.taskCategoryIndex >= 0) {
            Column() {
              Column() {
                TextInput({ placeholder: this.getTaskCategoryDescription(), text: this.taskCategoryDetail })
                  .fontSize(14)
                  .fontColor('#1A1A1A')
                  .placeholderColor('#999999')
                  .placeholderFont({ size: 15 })
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .borderRadius(8)
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .onChange((value: string) => { this.taskCategoryDetail = value; })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
              .borderRadius(14)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 0 })
          }

          // 运输距离（非面积类任务显示）
          if (!this.isAreaBased) {
            Column() {
              Column() {
                Row() {
                  Text('运输距离')
                    .fontSize(15)
                    .fontColor('#666666')
                    .flexGrow(1)
                  Text(this.getDistanceDisplay())
                    .fontSize(15)
                    .fontColor(this.distanceBrackets.length > 0 ? '#1A1A1A' : '#999999')
                    .textAlign(TextAlign.End)
                    .margin({ right: 12 })
                }
                .width('100%')
                .height(40)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  if (this.distanceBrackets.length > 0) {
                    const idx = DISTANCE_BRACKETS.findIndex(d => d.value === this.distanceBrackets[0]);
                    this.distanceSelectedIndex = idx >= 0 ? idx : 0;
                  } else {
                    this.distanceSelectedIndex = 0;
                  }
                  this.showDistancePicker = true;
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
              .borderRadius(14)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 0 })
            .bindSheet($$this.showDistancePicker, this.DistanceSheet(), {
              height: 360,
              dragBar: true,
              showClose: false,
              backgroundColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF',
              radius: { topLeft: 22, topRight: 22 }
            })
          }

          // 作业面积（面积类任务显示）
          if (this.isAreaBased) {
            Column() {
              Column() {
                Row() {
                  Text('作业面积（亩）')
                    .fontSize(15)
                    .fontColor('#666666')
                    .flexShrink(0)
                    .alignSelf(ItemAlign.Center)
                  TextInput({ placeholder: '请输入作业面积', text: this.totalOrders })
                    .fontSize(15)
                    .fontColor('#1A1A1A')
                    .placeholderColor('#999999')
                  .placeholderFont({ size: 15 })
                    .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                    .layoutWeight(1)
                    .height(40)
                    .margin({ left: 12 })
                    .textAlign(TextAlign.End)
                    .onChange((value: string) => { this.totalOrders = value; })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
              .borderRadius(14)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 0 })
          }

          // 垂直落差（非面积类任务显示）
          if (!this.isAreaBased) {
            Column() {
              Column() {
                Row() {
                  Text('垂直落差')
                    .fontSize(15)
                    .fontColor('#666666')
                    .flexGrow(1)
                  Text(this.getVerticalDropLabel())
                    .fontSize(15)
                    .fontColor(this.verticalDropIndex >= 0 ? '#1A1A1A' : '#999999')
                    .textAlign(TextAlign.End)
                    .margin({ right: 12 })
                }
                .width('100%')
                .height(40)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  if (this.verticalDropIndex >= 0) {
                    this.pickerSelectedVerticalDropIndex = this.verticalDropIndex;
                  } else {
                    this.pickerSelectedVerticalDropIndex = 0;
                  }
                  this.showVerticalDropPicker = true;
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
              .borderRadius(14)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 0 })
            .bindSheet($$this.showVerticalDropPicker, this.VerticalDropSheet(), {
              height: 360,
              dragBar: true,
              showClose: false,
              backgroundColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF',
              radius: { topLeft: 22, topRight: 22 }
            })
          }

          // 单次载重
          Column() {
            Column() {
              Row() {
                Text('单次载重（kg）')
                  .fontSize(15)
                  .fontColor('#666666')
                  .flexShrink(0)
                  .alignSelf(ItemAlign.Center)
                TextInput({ placeholder: '请输入', text: this.payloadKg })
                  .fontSize(15)
                  .fontColor('#1A1A1A')
                  .placeholderColor('#999999')
                  .placeholderFont({ size: 15 })
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .layoutWeight(1)
                  .height(40)
                  .margin({ left: 12 })
                  .textAlign(TextAlign.End)
                  .onChange((value: string) => { this.payloadKg = value; })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 0 })

          // 订单总量（非面积类任务）
          if (!this.isAreaBased) {
            Column() {
              Column() {
                Row() {
                  Text('订单总量（kg）')
                    .fontSize(15)
                    .fontColor('#666666')
                    .flexShrink(0)
                    .alignSelf(ItemAlign.Center)
                  TextInput({ placeholder: '请输入', text: this.totalOrders })
                    .fontSize(15)
                    .fontColor('#1A1A1A')
                    .placeholderColor('#999999')
                  .placeholderFont({ size: 15 })
                    .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                    .layoutWeight(1)
                    .height(40)
                    .margin({ left: 12 })
                    .textAlign(TextAlign.End)
                    .onChange((value: string) => { this.totalOrders = value; })
                }
                .width('100%')
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
              .borderRadius(14)
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 12, bottom: 0 })
          }

          // 项目预算
          Column() {
            Column() {
              Row() {
                Text('项目预算（元）')
                  .fontSize(15)
                  .fontColor('#666666')
                  .flexShrink(0)
                  .alignSelf(ItemAlign.Center)
                TextInput({ placeholder: '请输入', text: this.budgetAmount })
                  .fontSize(15)
                  .fontColor('#1A1A1A')
                  .placeholderColor('#999999')
                  .placeholderFont({ size: 15 })
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .layoutWeight(1)
                  .height(40)
                  .margin({ left: 12 })
                  .textAlign(TextAlign.End)
                  .onChange((value: string) => { this.budgetAmount = value; })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 0 })

          // 任务截止日期
          Column() {
            Column() {
              Row() {
                Text('任务截止日期')
                  .fontSize(15)
                  .fontColor('#666666')
                  .flexGrow(1)
                Text(this.expiresAt || '请选择')
                  .fontSize(15)
                  .fontColor(this.expiresAt ? '#1A1A1A' : '#999999')
                  .textAlign(TextAlign.End)
                  .margin({ right: 12 })
              }
              .width('100%')
              .height(40)
              .alignItems(VerticalAlign.Center)
              .onClick(() => { this.showDatePicker = true; })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 0 })
          .bindSheet($$this.showDatePicker, this.DateSheet(), {
            height: 360,
            dragBar: true,
            showClose: false,
            backgroundColor: this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF',
            radius: { topLeft: 22, topRight: 22 }
          })

          // 备注区域
          Column() {
            Column() {
              Text('备注信息')
                .fontSize(15)
                .fontColor('#666666')
                .width('100%')
                .margin({ bottom: 10 })

              TextArea({ placeholder: '请输入', text: this.notes })
                .fontSize(15)
                .fontColor('#1A1A1A')
                .placeholderColor('#CCCCCC')
                .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                .borderRadius(10)
                .padding(12)
                .height(100)
                .onChange((value: string) => { this.notes = value; })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#1C2130' : '#FFFFFF')
            .borderRadius(14)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 12, bottom: 120 })
        }
        .width('100%')
        .padding({ bottom: 40 })
      }
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部发布按钮
      Column() {
        Button('发布')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#07C160')
          .borderRadius(24)
          .width(200)
          .height(48)
          .enabled(!this.submitting)
          .onClick(() => { this.handleSubmit(); })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
