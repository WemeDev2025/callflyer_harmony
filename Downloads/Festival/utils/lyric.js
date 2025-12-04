// utils/lyric.js
// LRC歌词解析工具

/**
 * 解析LRC格式歌词
 * @param {string} lrcText - LRC格式的歌词文本
 * @returns {Array} 解析后的歌词数组，格式: [{time: 秒数, text: '歌词内容'}, ...]
 */
function parseLRC(lrcText) {
  if (!lrcText) return [];
  
  const lines = lrcText.split('\n');
  const lyrics = [];
  
  // 匹配时间标签的正则表达式: [mm:ss.xx] 或 [mm:ss]
  const timeRegex = /\[(\d{2}):(\d{2})\.?(\d{2})?\]/g;
  
  lines.forEach(line => {
    line = line.trim();
    if (!line) return;
    
    // 匹配所有时间标签
    const timeMatches = [];
    let match;
    while ((match = timeRegex.exec(line)) !== null) {
      const minutes = parseInt(match[1], 10);
      const seconds = parseInt(match[2], 10);
      const centiseconds = match[3] ? parseInt(match[3], 10) : 0;
      const time = minutes * 60 + seconds + centiseconds / 100;
      timeMatches.push(time);
    }
    
    // 获取歌词文本（移除所有时间标签）
    const text = line.replace(timeRegex, '').trim();
    
    // 如果有时间标签和歌词文本，添加到数组
    if (timeMatches.length > 0 && text) {
      timeMatches.forEach(time => {
        lyrics.push({
          time: time,
          text: text
        });
      });
    }
  });
  
  // 按时间排序
  lyrics.sort((a, b) => a.time - b.time);
  
  return lyrics;
}

/**
 * 根据当前播放时间获取当前歌词索引
 * @param {Array} lyrics - 解析后的歌词数组
 * @param {number} currentTime - 当前播放时间（秒）
 * @param {number} delayOffset - 延迟偏移量（秒），用于补偿时间差异，默认0.1秒（减小以适配真机）
 * @returns {number} 当前歌词索引，-1表示没有匹配的歌词
 */
function getCurrentLyricIndex(lyrics, currentTime, delayOffset = 0.1) {
  if (!lyrics || lyrics.length === 0) return -1;
  
  // 如果当前时间为0或很小，不显示歌词（可能还未开始播放）
  if (currentTime < 0.1) {
    return -1;
  }
  
  // 应用延迟偏移量，让歌词稍微延迟显示，避免提前出现
  // 但偏移量要小，避免真机上匹配不到
  const adjustedTime = currentTime - delayOffset;
  
  // 如果调整后的时间小于0，不显示任何歌词
  if (adjustedTime < 0) {
    return -1;
  }
  
  // 从后往前查找，找到最后一个时间小于等于调整后时间的歌词
  for (let i = lyrics.length - 1; i >= 0; i--) {
    if (lyrics[i].time <= adjustedTime) {
      return i;
    }
  }
  
  return -1;
}

/**
 * 从服务器加载歌词文件
 * @param {string} url - 歌词文件URL
 * @returns {Promise<string>} 返回歌词文本
 */
function loadLyric(url) {
  return new Promise((resolve, reject) => {
    wx.request({
      url: url,
      method: 'GET',
      success: (res) => {
        if (res.statusCode === 200) {
          resolve(res.data);
        } else {
          reject(new Error(`加载歌词失败: ${res.statusCode}`));
        }
      },
      fail: (err) => {
        reject(err);
      }
    });
  });
}

module.exports = {
  parseLRC,
  getCurrentLyricIndex,
  loadLyric
};

