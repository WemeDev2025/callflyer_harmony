@Entry
@Component
struct BlurTest {
  @State message: string = '模糊测试'

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
