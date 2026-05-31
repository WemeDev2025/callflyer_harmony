// 图片预览页面 - 全模态展开方式
// 从点击位置放大展开，支持双指缩放、双击放大/缩小、滑动切换图片

import router from '@ohos.router';

interface OffsetResult {
  x: number;
  y: number;
}

@Entry
struct ImagePreviewPage {
  @State imageUrls: string[] = [];
  @State currentIndex: number = 0;

  // 缩放状态
  @State zoomLevel: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State lastScale: number = 1;

  // 控制栏显示
  @State showControls: boolean = true;

  // 组件尺寸
  private containerWidth: number = 0;
  private containerHeight: number = 0;

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, Object>;
    if (params) {
      this.imageUrls = params['imageUrls'] as string[] || [];
      this.currentIndex = params['index'] as number || 0;
    }
    console.info('ImagePreviewPage images:', this.imageUrls.length, 'index:', this.currentIndex);
  }

  toggleControls(): void {
    this.showControls = !this.showControls;
  }

  resetZoomState(): void {
    this.zoomLevel = 1;
    this.offsetX = 0;
    this.offsetY = 0;
    this.lastScale = 1;
  }

  toggleZoom(): void {
    if (this.zoomLevel > 1) {
      animateTo({ duration: 200 }, () => {
        this.resetZoomState();
      });
    } else {
      animateTo({ duration: 200 }, () => {
        this.zoomLevel = 2;
        this.lastScale = 2;
      });
    }
  }

  clampOffset(offsetX: number, offsetY: number, scale: number): OffsetResult {
    const scaledWidth = this.containerWidth * scale;
    const scaledHeight = this.containerHeight * scale;

    let clampedX = offsetX;
    let clampedY = offsetY;

    if (scaledWidth > this.containerWidth) {
      const maxX = (scaledWidth - this.containerWidth) / 2;
      clampedX = Math.max(-maxX, Math.min(maxX, offsetX));
    } else {
      clampedX = 0;
    }

    if (scaledHeight > this.containerHeight) {
      const maxY = (scaledHeight - this.containerHeight) / 2;
      clampedY = Math.max(-maxY, Math.min(maxY, offsetY));
    } else {
      clampedY = 0;
    }

    return { x: clampedX, y: clampedY };
  }

  build() {
    Stack() {
      // 黑色背景
      Row() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .onClick(() => {
        this.toggleControls();
      })

      Column() {
        // 顶部栏
        if (this.showControls) {
          Row() {
            if (this.imageUrls.length > 1) {
              Text(`${this.currentIndex + 1} / ${this.imageUrls.length}`)
                .fontSize(16)
                .fontColor('#FFFFFF')
            }
            Blank()
            Text('✕')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .onClick(() => {
                router.back();
              })
          }
          .width('100%')
          .padding(16)
        }

        // 图片滑动区域
        Swiper() {
          ForEach(this.imageUrls, (url: string, index: number) => {
            Image(url)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale({ x: this.zoomLevel, y: this.zoomLevel })
              .translate({ x: this.offsetX, y: this.offsetY })
              .gesture(
                TapGesture({ count: 2 })
                  .onAction(() => {
                    this.toggleZoom();
                  })
              )
              .gesture(
                PinchGesture()
                  .onActionUpdate((event) => {
                    let newScale = this.lastScale * event.scale;
                    newScale = Math.max(0.5, Math.min(4, newScale));

                    if (newScale >= 1) {
                      this.zoomLevel = newScale;
                    } else {
                      this.zoomLevel = newScale;
                      if (newScale < 1) {
                        animateTo({ duration: 100 }, () => {
                          this.offsetX = 0;
                          this.offsetY = 0;
                        });
                      }
                    }
                  })
                  .onActionEnd(() => {
                    this.lastScale = this.zoomLevel;
                    if (this.zoomLevel < 1) {
                      animateTo({ duration: 200 }, () => {
                        this.zoomLevel = 1;
                        this.offsetX = 0;
                        this.offsetY = 0;
                        this.lastScale = 1;
                      });
                    }
                  })
              )
          })
        }
        .index(this.currentIndex)
        .indicator(false)
        .loop(false)
        .duration(300)
        .onChange((index: number) => {
          this.currentIndex = index;
          this.resetZoomState();
        })
        .width('100%')
        .layoutWeight(1)

        // 底部指示器
        if (this.showControls && this.imageUrls.length > 1) {
          Row() {
            ForEach(this.imageUrls, (imgUrl: string, index: number) => {
              Circle({ width: 8, height: 8 })
                .fill(index === this.currentIndex ? '#FFFFFF' : 'rgba(255,255,255,0.4)')
                .margin({ left: 4, right: 4 })
            })
          }
          .margin({ bottom: 40 })
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
