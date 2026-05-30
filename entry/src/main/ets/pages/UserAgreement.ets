@Entry
@Component
struct UserAgreement {
  @State message: string = '用户协议'

  build() {
    Column() {
      Text(this.message)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
    }
    .width('100%')
    .height('100%')
  }
}
