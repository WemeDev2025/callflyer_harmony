import { ProfileForm, fetchProfile, updateProfile, uploadAvatar } from '../service/ApiService';
import AuthService from '../service/AuthService';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileIo from '@ohos.file.fs';
import inputMethod from '@ohos.inputMethod';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import curves from '@ohos.curves';

const PHONE_REGEX = /^1[3-9]\d{9}$/;
const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';

class RoleOption {
  label: string;
  value: string;
  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

@Entry
@Component
struct Profile {
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State uploadingAvatar: boolean = false;
  @State form: ProfileForm = this.createEmptyForm();
  @State currentDroneModel: string = '';
  @State currentBusinessScope: string = '';
  @State licenseUploadVisible: boolean = false;
  @State showOptionalFields: boolean = false;  // 可选字段折叠状态
  @State uploadingDroneImage: boolean = false;

  // 角色选项
  roleOptions: RoleOption[] = [
    new RoleOption('飞手', 'pilot'),
    new RoleOption('雇主', 'employer')
  ];

  aboutToAppear() {
    this.loadProfile();
  }

  createEmptyForm(): ProfileForm {
    return {
      openid: '',
      nickname: '',
      avatarUrl: '',
      phone: '',
      wechatId: '',
      douyinId: '',
      channelsId: '',
      company: '',
      position: '',
      city: '',
      userRole: 'employer',
      pilotCode: '',
      droneModels: [],
      droneModel: '',
      businessScope: [],
      licenseUrl: '',
      licenseType: '',
      licenseStatus: '',
      licenseVerified: false,
      licenseRejected: false,
      licenseReason: '',
      orgCode: '',
      institutionId: '',
      workMu: null,
      workKg: null,
      droneImages: []
    };
  }

  async ensureLoggedIn(): Promise<boolean> {
    const token = AuthService.getAuthToken();
    const user = AuthService.getCurrentUser();
    if (AuthService.isLogin() && token && user?.openId) {
      return true;
    }
    const result = await AuthService.login();
    if (!result.success || !result.userInfo) {
      promptAction.showToast({ message: '请先登录' });
      return false;
    }
    const tokenResult = await AuthService.exchangeToken(result.userInfo.openId, result.userInfo.unionId);
    if (!tokenResult.token) {
      promptAction.showToast({ message: '登录失败，请重试' });
      return false;
    }
    return true;
  }

  async loadProfile() {
    this.loading = true;
    const loggedIn = await this.ensureLoggedIn();
    if (!loggedIn) {
      this.loading = false;
      return;
    }
    const user = AuthService.getCurrentUser();
    const token = AuthService.getAuthToken();
    if (!user?.openId || !token) {
      this.loading = false;
      return;
    }
    try {
      const profile = await fetchProfile(user.openId, token);
      if (profile) {
        this.form = profile;
      }
    } catch (err) {
      console.error('【获取资料失败】', JSON.stringify(err));
    }
    this.loading = false;
  }

  async handleSave() {
    if (this.submitting) return;

    const loggedIn = await this.ensureLoggedIn();
    if (!loggedIn) return;

    const nickname = this.form.nickname.trim();
    const phone = this.form.phone.trim();

    if (!nickname) {
      promptAction.showToast({ message: '请填写昵称' });
      return;
    }
    if (!phone) {
      promptAction.showToast({ message: '请填写手机号' });
      return;
    }
    if (!PHONE_REGEX.test(phone)) {
      promptAction.showToast({ message: '手机号格式不正确' });
      return;
    }

    this.submitting = true;
    const token = AuthService.getAuthToken();
    const payload: ProfileForm = {
      openid: AuthService.getCurrentUser()?.openId || '',
      nickname: nickname,
      avatarUrl: this.form.avatarUrl || DEFAULT_AVATAR,
      phone: phone,
      wechatId: this.form.wechatId,
      douyinId: this.form.douyinId,
      channelsId: this.form.channelsId,
      company: this.form.company,
      position: this.form.position,
      city: this.form.city,
      userRole: this.form.userRole,
      pilotCode: this.form.pilotCode,
      droneModels: this.form.droneModels,
      droneModel: this.form.droneModels.join('/'),
      businessScope: this.form.businessScope,
      licenseUrl: this.form.licenseUrl,
      licenseType: this.form.licenseType,
      licenseStatus: this.form.licenseStatus,
      licenseVerified: this.form.licenseVerified,
      licenseRejected: this.form.licenseRejected,
      licenseReason: this.form.licenseReason,
      orgCode: this.form.orgCode,
      institutionId: this.form.orgCode,
      workMu: this.form.workMu,
      workKg: this.form.workKg,
      droneImages: this.form.droneImages
    };

    try {
      await updateProfile(payload, token);
      promptAction.showToast({ message: '保存成功' });
    } catch (err) {
      console.error('【保存失败】', JSON.stringify(err));
      promptAction.showToast({ message: '保存失败' });
    }
    this.submitting = false;
  }

  handleAddDroneModel() {
    const model = this.currentDroneModel.trim();
    if (!model) return;
    if (this.form.droneModels.includes(model)) {
      promptAction.showToast({ message: '机型已存在' });
      return;
    }
    this.form.droneModels = [...this.form.droneModels, model];
    this.currentDroneModel = '';
  }

  handleRemoveDroneModel(index: number) {
    const models = [...this.form.droneModels];
    models.splice(index, 1);
    this.form.droneModels = models;
  }

  async handleAddDroneImage() {
    if (this.uploadingDroneImage) return;
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 9 - this.form.droneImages.length;
      const result = await photoPicker.select(options);
      const uris = result.photoUris;
      if (!uris || uris.length === 0) return;

      this.uploadingDroneImage = true;
      const token = AuthService.getAuthToken();
      const newImages: string[] = [];

      for (const uri of uris) {
        const fileStat = fileIo.statSync(uri);
        const buffer = new ArrayBuffer(fileStat.size);
        const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
        fileIo.readSync(file.fd, buffer);
        fileIo.closeSync(file.fd);
        const uploadResult = await uploadAvatar(buffer, token);
        if (uploadResult.url) {
          newImages.push(uploadResult.url);
        }
      }

      if (newImages.length > 0) {
        this.form.droneImages = [...this.form.droneImages, ...newImages];
        promptAction.showToast({ message: `已上传${newImages.length}张图片` });
      }
    } catch (e) {
      console.error('【上传机型图片失败】', JSON.stringify(e));
      promptAction.showToast({ message: '上传失败' });
    } finally {
      this.uploadingDroneImage = false;
    }
  }

  handleRemoveDroneImage(index: number) {
    const images = [...this.form.droneImages];
    images.splice(index, 1);
    this.form.droneImages = images;
  }

  handleAddBusinessScope() {
    const scope = this.currentBusinessScope.trim();
    if (!scope) return;
    if (this.form.businessScope.includes(scope)) {
      promptAction.showToast({ message: '已存在' });
      return;
    }
    this.form.businessScope = [...this.form.businessScope, scope];
    this.currentBusinessScope = '';
  }

  handleRemoveBusinessScope(index: number) {
    const scopes = [...this.form.businessScope];
    scopes.splice(index, 1);
    this.form.businessScope = scopes;
  }

  handleRoleChange(value: string) {
    this.form.userRole = value;
  }

  async handleChooseAvatar() {
    if (this.uploadingAvatar) {
      return;
    }
    const loggedIn = await this.ensureLoggedIn();
    if (!loggedIn) return;
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      const uri = result.photoUris[0];
      if (!uri) {
        promptAction.showToast({ message: '未选择图片' });
        return;
      }
      this.uploadingAvatar = true;
      const fileStat = fileIo.statSync(uri);
      const buffer = new ArrayBuffer(fileStat.size);
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file.fd);
      const token = AuthService.getAuthToken();
      const uploadResult = await uploadAvatar(buffer, token);
      if (uploadResult.url) {
        this.form.avatarUrl = uploadResult.url;
        promptAction.showToast({ message: '头像已更新' });
      } else {
        promptAction.showToast({ message: '上传失败' });
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : JSON.stringify(err);
      console.error('【选择头像失败】', errorMsg);
      promptAction.showToast({ message: '选择失败' });
    } finally {
      this.uploadingAvatar = false;
    }
  }

  async handleUploadLicense() {
    if (this.uploadingAvatar) return;
    try {
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      const uri = result.photoUris[0];
      if (!uri) {
        return;
      }
      this.uploadingAvatar = true;
      const fileStat = fileIo.statSync(uri);
      const buffer = new ArrayBuffer(fileStat.size);
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file.fd);
      const token = AuthService.getAuthToken();
      const uploadResult = await uploadAvatar(buffer, token);
      if (uploadResult.url) {
        this.form.licenseUrl = uploadResult.url;
        this.form.licenseStatus = '待审核';
        this.form.licenseVerified = false;
        this.form.licenseRejected = false;
        this.form.licenseReason = '';
        promptAction.showToast({ message: '执照上传成功' });
      } else {
        promptAction.showToast({ message: '上传失败' });
      }
    } catch (e) {
      console.error('【上传执照失败】', JSON.stringify(e));
      promptAction.showToast({ message: '上传失败' });
    } finally {
      this.uploadingAvatar = false;
    }
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.page_bg'))

      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.primary_color'))
          Text('加载中...')
            .fontColor($r('app.color.text_secondary'))
            .fontSize(14)
            .margin({ top: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Scroll() {
            Column() {
              // 基础信息卡片
              Column({ space: 16 }) {
                // 头像区域
                Column() {
                  Image(this.form.avatarUrl || DEFAULT_AVATAR)
                    .width(84)
                    .height(84)
                    .borderRadius(42)
                    .backgroundColor($r('app.color.avatar_placeholder'))
                    .onClick(() => this.handleChooseAvatar())
                  if (this.uploadingAvatar) {
                    LoadingProgress()
                      .width(84)
                      .height(84)
                      .borderRadius(42)
                      .color($r('app.color.primary_color'))
                      .backgroundColor('rgba(0,0,0,0.3)')
                      .position({ x: 0, y: 0 })
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .margin({ top: 12, bottom: 12 })

                // 飞手码显示
                if (this.form.userRole === 'pilot' && this.form.pilotCode) {
                  Row() {
                    Image($r('app.media.icon_banner'))
                      .width(18)
                      .height(18)
                      .objectFit(ImageFit.Contain)
                    Text(this.form.pilotCode)
                      .fontSize(13)
                      .fontColor($r('app.color.primary_color'))
                      .margin({ left: 4 })
                  }
                }

                this.buildInputItem('昵称', this.form.nickname, '')
                this.buildInputItem('手机号码', this.form.phone, '', InputType.PhoneNumber)
                this.buildInputItem('微信号', this.form.wechatId, '')
                if (this.showOptionalFields) {
                  this.buildInputItem('抖音号', this.form.douyinId, '')
                  this.buildInputItem('视频号ID', this.form.channelsId, '')
                  this.buildInputItem('公司简称', this.form.company, '')
                  this.buildInputItem('职位', this.form.position, '')
                  this.buildInputItem('城市', this.form.city, '')
                }
                // 展开/收起按钮
                Row() {
                  Blank()
                  Text(this.showOptionalFields ? '收起' : '展开')
                    .fontSize(14)
                    .fontColor('#999999')
                    .onClick(() => {
                      animateTo({
                        duration: 300,
                        curve: Curve.EaseInOut
                      }, () => {
                        this.showOptionalFields = !this.showOptionalFields;
                      })
                    })
                }
                .width('100%')
                // 身份选择
                Row() {
                  Text('身份选择')
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                  Blank()
                  ForEach(this.roleOptions, (item: RoleOption) => {
                    Row() {
                      Stack() {
                        Circle()
                          .width(20)
                          .height(20)
                          .fill(this.form.userRole === item.value ? '#00C853' : '#FFFFFF')
                          .stroke(this.form.userRole === item.value ? '#00C853' : '#CCCCCC')
                          .strokeWidth(1)
                        if (this.form.userRole === item.value) {
                          Text('✓')
                            .fontSize(12)
                            .fontColor('#FFFFFF')
                        }
                      }
                      .width(20)
                      .height(20)
                      Text(item.label)
                        .fontSize(15)
                        .fontColor($r('app.color.text_primary'))
                        .margin({ left: 6 })
                    }
                    .margin({ left: 20 })
                    .onClick(() => {
                      animateTo({
                        duration: 300,
                        curve: Curve.EaseInOut
                      }, () => {
                        this.form.userRole = item.value;
                      })
                    })
                  })
                }
                .width('100%')
                .padding(14)
                .backgroundColor($r('app.color.card_bg_secondary'))
                .borderRadius(10)
                // 图片认证
                Row() {
                  Text(this.form.userRole === 'pilot' ? '执照认证' : '图片认证')
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                  if (this.form.licenseVerified) {
                    Text(this.form.licenseType || '已认证')
                      .fontSize(13)
                      .backgroundColor('#00C85333')
                      .fontColor('#00C853')
                      .borderRadius(4)
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .margin({ left: 8 })
                  } else if (this.form.licenseUrl) {
                    Text('已上传')
                      .fontSize(13)
                      .backgroundColor('#FF980033')
                      .fontColor('#FF9800')
                      .borderRadius(4)
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .margin({ left: 8 })
                  }
                  Blank()
                  Text(this.form.licenseUrl ? '重新上传' : '点击上传')
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .onClick(() => this.handleUploadLicense())
                }
                .width('100%')
                .padding(14)
                .backgroundColor($r('app.color.card_bg_secondary'))
                .borderRadius(10)
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 22, bottom: 22 })
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(18)
              .margin({ top: 44 })

              // 飞手专属字段
              Column({ space: 12 }) {
                // 主营业务
                Column() {
                  Row() {
                    TextInput({ placeholder: '主营业务', text: this.currentBusinessScope })
                      .width('100%')
                      .height(44)
                      .fontSize(12)
                      .fontColor($r('app.color.text_primary'))
                      .placeholderFont({ size: 14 })
                      .placeholderColor($r('app.color.text_secondary'))
                      .borderRadius(8)
                      .padding({ left: 10, right: 10 })
                      .onChange((v: string) => this.currentBusinessScope = v)
                      .onSubmit(() => this.handleAddBusinessScope())
                  }
                  if (this.form.businessScope.length > 0) {
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.form.businessScope, (scope: string, index: number) => {
                        Row() {
                          Text(scope + '  ×')
                            .fontSize(12)
                            .backgroundColor('#F5F5F5')
                            .fontColor($r('app.color.text_primary'))
                            .borderRadius(4)
                            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                            .onClick(() => this.handleRemoveBusinessScope(index))
                        }
                        .margin({ right: 8, top: 8 })
                      })
                    }
                    .margin({ top: 8 })
                  }
                }
                .width('88%')
                // 常用机型
                Column() {
                  Row() {
                    TextInput({ placeholder: '常用机型', text: this.currentDroneModel })
                      .width('100%')
                      .height(44)
                      .fontSize(12)
                      .fontColor($r('app.color.text_primary'))
                      .placeholderFont({ size: 14 })
                      .placeholderColor($r('app.color.text_secondary'))
                      .borderRadius(8)
                      .padding({ left: 10, right: 10 })
                      .onChange((v: string) => this.currentDroneModel = v)
                      .onSubmit(() => this.handleAddDroneModel())
                  }
                  if (this.form.droneModels.length > 0) {
                    Flex({ wrap: FlexWrap.Wrap }) {
                      ForEach(this.form.droneModels, (model: string, index: number) => {
                        Row() {
                          Text(model + '  ×')
                            .fontSize(12)
                            .backgroundColor('#F5F5F5')
                            .fontColor($r('app.color.text_primary'))
                            .borderRadius(4)
                            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                            .onClick(() => this.handleRemoveDroneModel(index))
                        }
                        .margin({ right: 8, top: 8 })
                      })
                    }
                    .margin({ top: 8 })
                  }
                }
                .width('88%')

                // 机型贴图上传
                if (this.form.droneModels.length > 0) {
                  Column() {
                    Text('机型贴图')
                      .fontSize(14)
                      .fontColor($r('app.color.text_secondary'))
                      .width('88%')
                      .padding({ left: 12, right: 12, top: 12, bottom: 8 })

                    List() {
                      ForEach(this.form.droneImages, (imgUrl: string, index: number) => {
                        ListItem() {
                          Stack() {
                            Image(imgUrl)
                              .width(80)
                              .height(80)
                              .borderRadius(8)
                              .objectFit(ImageFit.Cover)
                            Circle()
                              .width(20)
                              .height(20)
                              .fill('rgba(0,0,0,0.5)')
                              .position({ x: 58, y: 2 })
                            Text('×')
                              .fontSize(12)
                              .fontColor('#FFFFFF')
                              .textAlign(TextAlign.Center)
                              .width(20)
                              .height(20)
                              .position({ x: 58, y: 2 })
                              .onClick(() => this.handleRemoveDroneImage(index))
                          }
                          .width(80)
                          .height(80)
                          .alignContent(Alignment.TopEnd)
                        }
                        .margin({ right: 8 })
                      })
                      if (this.form.droneImages.length < 9) {
                        ListItem() {
                          Column() {
                            Text('+')
                              .fontSize(24)
                              .fontColor($r('app.color.text_secondary'))
                          }
                          .width(80)
                          .height(80)
                          .backgroundColor($r('app.color.card_bg_secondary'))
                          .borderRadius(8)
                          .justifyContent(FlexAlign.Center)
                          .onClick(() => this.handleAddDroneImage())
                        }
                      }
                    }
                    .width('88%')
                    .listDirection(Axis.Horizontal)
                    .scrollBar(BarState.Off)
                    .padding({ left: 12, right: 12, bottom: 12 })
                  }
                  .width('100%')
                  .padding({ top: 12 })
                }

                // 机构码
                Column() {
                  Row() {
                    Text('我的机构码')
                      .fontSize(14)
                      .fontColor($r('app.color.text_primary'))
                    Text(this.form.orgCode || '输入6位机构码')
                      .fontSize(14)
                      .fontColor(this.form.orgCode ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
                      .layoutWeight(1)
                      .textAlign(TextAlign.End)
                  }
                  .alignItems(VerticalAlign.Center)
                  .padding(14)
                  .onClick(() => this.handleOrgCodeTap())
                }
                .width('88%')
                .backgroundColor($r('app.color.card_bg_secondary'))
                .borderRadius(10)
              }
              .width('100%')
              .padding({ top: 16, bottom: 16 })
              .opacity(this.form.userRole === 'pilot' ? 1 : 0)
              .clip(true)
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(16)
              .margin({ top: 12 })

              // 底部间距
              Column().height(80)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          // 保存按钮和协议
          Column() {
            Row() {
              Button('保存')
                .width('80%')
                .height(48)
                .borderRadius(24)
                .fontSize(16)
                .fontColor($r('app.color.text_on_dark_background'))
                .backgroundColor($r('app.color.badge_green'))
                .onClick(() => this.handleSave())
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 16 })

            Row() {
              Text('《用户协议》')
                .fontSize(13)
                .fontColor($r('app.color.accent_green'))
                .onClick(() => router.push({ url: 'pages/UserAgreement' }))
              Text('和')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 8, right: 8 })
              Text('《隐私政策》')
                .fontSize(13)
                .fontColor($r('app.color.accent_green'))
                .onClick(() => router.push({ url: 'pages/PrivacyPolicy' }))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 12, bottom: 32 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .backgroundColor($r('app.color.page_bg'))
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM])
  }

  // 构建输入项
  @Builder
  buildInputItem(label: string, value: string, placeholder: string, inputType: InputType = InputType.Normal) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
        .width(76)
      TextInput({ placeholder: placeholder, text: value })
        .layoutWeight(1)
        .height(48)
        .backgroundColor('transparent')
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .type(inputType)
        .padding(0)
        .onChange((v: string) => {
          if (label === '昵称') this.form.nickname = v;
          else if (label === '手机号码') this.form.phone = v;
          else if (label === '微信号') this.form.wechatId = v;
          else if (label === '抖音号') this.form.douyinId = v;
          else if (label === '视频号ID') this.form.channelsId = v;
          else if (label === '公司简称') this.form.company = v;
          else if (label === '职位') this.form.position = v;
          else if (label === '城市') this.form.city = v;
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
    .backgroundColor($r('app.color.card_bg_secondary'))
    .borderRadius(10)
  }

  // 构建分割线
  @Builder
  buildDivider() {
    Divider()
      .width('100%')
      .height(0.5)
      .color($r('app.color.divider'))
  }

  // 机构码弹窗
  @State orgCodeInput: string = '';
  @State orgCodeError: string = '';
  dialogController: CustomDialogController = new CustomDialogController({
    builder: OrgCodeDialog({
      orgCodeInput: $orgCodeInput,
      orgCodeError: $orgCodeError,
      onConfirm: this.handleOrgCodeConfirm.bind(this),
      onCancel: this.handleOrgCodeCancel.bind(this)
    }),
    alignment: DialogAlignment.Center,
    backgroundColor: Color.Transparent
  });

  handleOrgCodeTap() {
    this.orgCodeInput = this.form.orgCode || '';
    this.orgCodeError = '';
    this.dialogController.open();
  }

  handleOrgCodeConfirm() {
    if (this.orgCodeInput.length !== 6) {
      this.orgCodeError = '机构码必须为6位';
      return;
    }
    this.form.orgCode = this.orgCodeInput;
    this.dialogController.close();
  }

  handleOrgCodeCancel() {
    this.dialogController.close();
  }
}

// 机构码输入弹窗
@CustomDialog
struct OrgCodeDialog {
  @Link orgCodeInput: string;
  @Link orgCodeError: string;
  onConfirm: () => void = () => {};
  onCancel: () => void = () => {};
  controller: CustomDialogController = new CustomDialogController({ builder: () => {} });

  build() {
    Column({ space: 16 }) {
      Text('输入机构码')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      TextInput({ text: this.orgCodeInput, placeholder: '请输入6位机构码' })
        .width('100%')
        .height(48)
        .fontSize(16)
        .placeholderColor($r('app.color.text_secondary'))
        .type(InputType.Number)
        .maxLength(6)
        .onChange((v: string) => {
          this.orgCodeInput = v;
          this.orgCodeError = '';
        })

      if (this.orgCodeError) {
        Text(this.orgCodeError)
          .fontSize(12)
          .fontColor($r('app.color.accent_orange'))
      }

      Row() {
        Button('取消')
          .width('45%')
          .height(40)
          .backgroundColor($r('app.color.card_bg_secondary'))
          .fontColor($r('app.color.text_secondary'))
          .borderRadius(8)
          .onClick(() => this.onCancel())

        Button('确定')
          .width('45%')
          .height(40)
          .backgroundColor($r('app.color.badge_green'))
          .fontColor($r('app.color.text_on_dark_background'))
          .borderRadius(8)
          .onClick(() => this.onConfirm())
      }
    }
    .width('85%')
    .padding(16)
  }
}
