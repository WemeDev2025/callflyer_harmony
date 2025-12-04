Component({
  properties: {
    startTop: {
      type: Number,
      value: 0 // 粒子起始位置（rpx），默认从顶部开始
    }
  },
  data: {
    sparks: []
  },
  lifetimes: {
    attached() {
      this.initSparks();
    }
  },
  methods: {
    initSparks() {
      const count = 20; // 增加粒子数量，让效果更丰富
      const sparks = [];
      const startTop = this.properties.startTop || 0;
      
      for (let i = 0; i < count; i++) {
        // X轴位置：在卡片宽度范围内随机分布（考虑padding，约700rpx）
        const x = Math.floor(Math.random() * 700);
        
        // Y轴位置：从起始位置开始，在200rpx范围内随机分布
        // 这样粒子会从底部外面开始，逐渐向上穿过卡片
        const y = Math.floor(Math.random() * 200);
        
        // 速度：统一7秒，确保所有粒子在7秒后消失
        const d = 7;
        
        // 透明度：0.5-1.0，让粒子有明暗变化
        const o = (Math.random() * 0.5 + 0.5).toFixed(2);
        
        // 延迟：0-1秒，让粒子错开出现，但确保在7秒内完成
        const delay = (Math.random() * 1).toFixed(2);
        
        sparks.push({ x, y, d, o, delay });
      }
      this.setData({ 
        sparks: sparks,
        startTop: startTop
      });
    }
  }
});
