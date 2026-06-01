// 图片预览组件

interface ImagePreviewConfig {
  imageUrls: string[];
  index?: number;
}

@CustomDialog
export struct ImagePreviewDialog {
  @Prop imageUrls: string[] = [];
  @Prop currentIndex: number = 0;
  @State zoomLevel: number = 1;
  @State lastScale: number = 1;
  controller?: CustomDialogController;

  aboutToAppear(): void {
    console.info('【ImagePreviewDialog aboutToAppear】 urls:', this.imageUrls.length, 'index:', this.currentIndex);
  }

  resetZoomState(): void {
    this.zoomLevel = 1;
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

  closePreview(): void {
    console.info('【ImagePreviewDialog closePreview】');
    if (this.controller) {
      this.controller.close();
    }
  }

  build() {
    Column() {
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
            this.closePreview();
          })
      }
      .width('100%')
      .padding(16)

      Swiper() {
        ForEach(this.imageUrls, (url: string, index: number) => {
          Image(url)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.zoomLevel, y: this.zoomLevel })
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
                  this.zoomLevel = newScale;
                })
                .onActionEnd(() => {
                  this.lastScale = this.zoomLevel;
                  if (this.zoomLevel < 1) {
                    animateTo({ duration: 200 }, () => {
                      this.zoomLevel = 1;
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

      if (this.imageUrls.length > 1) {
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
    .backgroundColor('#000000')
    .onClick(() => {
      this.closePreview();
    })
  }
}

export class imagePreview {
  private static controller: CustomDialogController | null = null;

  static show(config: ImagePreviewConfig): void {
    console.info('【imagePreview.show】 START, urls:', config.imageUrls?.length, 'index:', config.index);

    if (imagePreview.controller) {
      console.info('【imagePreview.show】 closing existing controller');
      imagePreview.controller.close();
      imagePreview.controller = null;
    }

    const imageUrls = config.imageUrls || [];
    const index = config.index ?? 0;

    console.info('【imagePreview.show】 creating dialog');

    imagePreview.controller = new CustomDialogController({
      builder: ImagePreviewDialog({
        imageUrls: imageUrls,
        currentIndex: index
      }),
      customStyle: false,
      backgroundColor: '#000000',
      alignment: DialogAlignment.Center
    });

    console.info('【imagePreview.show】 calling open()');
    imagePreview.controller.open();
    console.info('【imagePreview.show】 open() called');
  }
}