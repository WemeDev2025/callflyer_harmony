@Entry
@Component
struct PrivacyPolicy {
  @State message: string = '隐私政策'

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
