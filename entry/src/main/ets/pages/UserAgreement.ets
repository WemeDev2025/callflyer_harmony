import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';

@Entry
@Component
struct UserAgreement {
  @State content: string = ''
  @StorageLink('colorMode') colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT

  aboutToAppear() {
    this.content = `用户协议

生效日期：2025年1月1日

欢迎您使用 CallFlyer 服务！

请您在使用 CallFlyer 服务前，仔细阅读本协议的全部内容。如果您不同意本协议的任何内容，请不要注册、登录或使用本服务。您通过网络页面点击确认或以其他方式选择接受本协议，即表示您与 CallFlyer 已达成协议，同意接受本协议的全部约定内容。

一、服务内容

1.1 CallFlyer 是由上海微幂网络科技有限公司（以下简称"本公司"）向用户提供的无人机任务信息对接平台服务，旨在连接无人机飞手与有拍摄需求的雇主，具体服务内容以您实际使用为准。

1.2 本公司保留随时变更、中断或终止部分或全部服务的权利。

二、用户注册与账户

2.1 您在使用本服务前需要注册成为 CallFlyer 用户。注册时，您应提供真实、准确、完整的个人信息和有效的联系方式。

2.2 您应当妥善保管账户信息，因个人保管不善造成的损失，由您自行承担。

2.3 您同意遵守法律法规及社会主义核心价值观，不利用本平台从事违法违规活动。

三、服务使用规范

3.1 CallFlyer 平台上有两类用户角色：
    - 飞手：提供无人机飞行服务的人员
    - 雇主：需要无人机拍摄服务的人员

3.2 您理解并承诺，在使用本服务时遵守以下规范：
    - 不发布虚假任务信息或进行欺诈行为
    - 不侵犯他人合法权益
    - 不干扰本服务的正常运行
    - 不实施任何危害系统安全的行为
    - 遵守国家关于无人机飞行的相关法规

3.3 飞手用户应确保具备相应的无人机飞行资质，保险齐全；雇主用户应确保拍摄任务合法合规，不涉及禁飞区域。

3.4 平台用户之间的线下服务交易行为，由用户自行负责，本公司不对此承担任何责任。

四、免责声明

4.1 本公司不对用户发布的任务信息真实性、合法性承担任何责任。

4.2 因不可抗力、意外事件、系统故障等原因导致的服务中断，本公司不承担责任。

4.3 用户因违反本协议或因无人机飞行活动导致的任何法律责任，由用户自行承担。

4.4 本公司不对无人机飞行安全、设备安全承担任何责任。

五、协议修改

5.1 本公司有权随时修改本协议的任何条款，修改后的协议一经公布即生效。

5.2 如果您不同意修改后的协议，有权停止使用本服务。

六、联系方式

如您对本协议有任何疑问，请通过以下方式联系我们：
- 邮箱：jing1834@gmail.com
- 微信：task1834

公司名称：上海微幂网络科技有限公司
`
  }

  build() {
    Column() {
      Scroll() {
        Text(this.content)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .padding(20)
          .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
