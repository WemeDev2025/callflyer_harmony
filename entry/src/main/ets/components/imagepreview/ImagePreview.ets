interface ImagePreviewOptions {
  showIndex?: boolean;
}

export class imagePreview {
  static show(imageUrls: string[], options?: ImagePreviewOptions): void {
    console.info('imagePreview.show called with images:', imageUrls.length);
  }
}
