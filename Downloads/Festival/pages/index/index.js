// pages/index/index.js
const TARGET = new Date(2026, 1, 17, 0, 0, 0); // 2026-02-17 00:00:00 (month is 0-based)

Page({
  data: {
    days: '0',
    hours: '00',
    minutes: '00',
    seconds: '00',
    sparkleArray: [],
    typewriterText: ''
  },
  onLoad() {
    this.setData({ showSparks: false });
    setTimeout(() => { this.setData({ showSparks: true }); }, 600);

    this.update();
    this.timer = setInterval(() => this.update(), 1000);
    
    // 打字机效果初始化
    this.startTypewriter();
  },
  onUnload() {
    clearInterval(this.timer);
    if (this.typewriterTimer) clearInterval(this.typewriterTimer);
  },
  // 打字机效果
  startTypewriter() {
    const fullText = '新年快乐！恭迎丙午（马）年';
    let index = 0;
    this.typewriterTimer = setInterval(() => {
      if (index < fullText.length) {
        this.setData({
          typewriterText: fullText.substring(0, index + 1)
        });
        index++;
      } else {
        clearInterval(this.typewriterTimer);
      }
    }, 150);
  },
  update() {
    const now = new Date();
    let diff = TARGET.getTime() - now.getTime();
    if (diff < 0) diff = 0;

    const s = Math.floor(diff / 1000);
    const days = Math.floor(s / (24*3600));
    const hours = Math.floor((s % (24*3600)) / 3600);
    const minutes = Math.floor((s % 3600) / 60);
    const seconds = s % 60;

    this.setData({
      days: String(days),
      hours: hours.toString().padStart(2,'0'),
      minutes: minutes.toString().padStart(2,'0'),
      seconds: seconds.toString().padStart(2,'0')
    });
  }
})
