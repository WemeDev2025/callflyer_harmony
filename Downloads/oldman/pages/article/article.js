// pages/article/article.js
Page({
  data: {
    articleInfo: {
      title: '妈妈眼中长不大的孩子',
      publishTime: '2024年1月15日',
      readCount: '10,000+'
    }
  },

  onLoad(options) {
    // 页面加载时的初始化
    console.log('文章页面加载');
  },

  onShareAppMessage() {
    return {
      title: '妈妈眼中长不大的孩子',
      path: '/pages/article/article',
      imageUrl: ''
    };
  },

  onShareTimeline() {
    return {
      title: '妈妈眼中长不大的孩子 - 一个关于母爱的感人故事',
      imageUrl: ''
    };
  }
})




