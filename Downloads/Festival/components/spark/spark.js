Component({
  properties: {},
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
      const count = 18;
      const sparks = [];
      for (let i = 0; i < count; i++) {
        const x = Math.floor(Math.random() * 700); // rpx space; it's fine for demo
        const y = Math.floor(Math.random() * 500) + 200;
        const d = (Math.random() * 2 + 1).toFixed(2);
        const o = (Math.random() * 0.5 + 0.6).toFixed(2);
        sparks.push({ x, y, d, o });
      }
      this.setData({ sparks });
    }
  }
});
