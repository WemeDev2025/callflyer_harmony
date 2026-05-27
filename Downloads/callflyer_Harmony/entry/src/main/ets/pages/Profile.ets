import { ProfileForm, fetchProfile, updateProfile, uploadAvatar } from '../service/ApiService';
import AuthService from '../service/AuthService';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import fileIo from '@ohos.file.fs';
import inputMethod from '@ohos.inputMethod';

const PHONE_REGEX = /^1[3-9]\d{9}$/;
const DEFAULT_AVATAR = 'https://wetofly.com/data/image/avatar_placeholder.webp';

@Entry
@Component
struct Profile {
  @State loading: boolean = true;
  @State submitting: boolean = false;
  @State uploadingAvatar: boolean = false;
  @State form: ProfileForm = this.createEmptyForm();
  @State currentDroneModel: string = '';
  @State currentBusinessScope: string = '';
  @State licenseUploadVisible: boolean = false;

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
      businessScope: [],
      licenseUrl: '',
      licenseStatus: '',
      licenseVerified: false,
      licenseRejected: false,
      licenseReason: '',
      orgCode: '',
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
      businessScope: this.form.businessScope,
      licenseUrl: this.form.licenseUrl,
      licenseStatus: this.form.licenseStatus,
      licenseVerified: this.form.licenseVerified,
      licenseRejected: this.form.licenseRejected,
      licenseReason: this.form.licenseReason,
      orgCode: this.form.orgCode,
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
          // 编辑卡片区域（占据上半部分）
          Scroll() {
            Column() {
              Column() {
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
                .margin({ top: 24, bottom: 20 })

                TextInput({ placeholder: '输入昵称', text: this.form.nickname })
                  .width('100%')
                  .height(44)
                  .backgroundColor($r('app.color.card_bg_secondary'))
                  .borderRadius(12)
                  .fontSize(16)
                  .padding({ left: 12, right: 12 })
                  .margin({ bottom: 12 })
                  .onChange((value: string) => {
                    this.form.nickname = value;
                  })

                TextInput({ placeholder: '手机号码', text: this.form.phone })
                  .width('100%')
                  .height(44)
                  .backgroundColor($r('app.color.card_bg_secondary'))
                  .borderRadius(12)
                  .fontSize(16)
                  .type(InputType.PhoneNumber)
                  .padding({ left: 12, right: 12 })
                  .margin({ bottom: 12 })
                  .onChange((value: string) => {
                    this.form.phone = value;
                    if (PHONE_REGEX.test(value)) {
                      inputMethod.getController().hideSoftKeyboard();
                    }
                  })

                if (this.form.userRole === 'pilot' && this.form.pilotCode) {
                  Row() {
                    Image($r('app.media.icon_banner'))
                      .width(22)
                      .height(22)
                      .objectFit(ImageFit.Contain)
                    Text(this.form.pilotCode)
                      .fontSize(12)
                      .fontColor($r('app.color.text_body'))
                      .margin({ left: 4 })
                  }
                  .margin({ bottom: 8 })
                }
              }
              .width('100%')
              .backgroundColor($r('app.color.card_bg'))
              .borderRadius(22)
              .padding(20)
              .shadow({
                radius: 16,
                color: 'rgba(146, 146, 146, 0.1)',
                offsetX: 0,
                offsetY: 4
              })
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          // 底部区域：保存按钮和协议
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
            .margin({ top: 24 })

            Row() {
              Text('《用户协议》')
                .fontSize(13)
                .fontColor($r('app.color.accent_green'))
                .onClick(() => {
                  router.push({ url: 'pages/UserAgreement' });
                })
              Text('和')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 8, right: 8 })
              Text('《隐私政策》')
                .fontSize(13)
                .fontColor($r('app.color.accent_green'))
                .onClick(() => {
                  router.push({ url: 'pages/PrivacyPolicy' });
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 16, bottom: 40 })
          }
          .width('100%')
          .padding({ left: 18, right: 18 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM])
  }
}
