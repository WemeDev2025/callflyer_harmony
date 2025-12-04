/**
 * 图片缓存工具
 * 用于下载和缓存服务器图片到本地，提升加载速度
 */

const CACHE_KEY_PREFIX = 'ad_image_cache_';
const CACHE_KEY_VERSION = 'ad_image_version';

/**
 * 获取广告图片本地缓存路径
 * @param {string} imageUrl 图片URL
 * @returns {string} 缓存key
 */
function getCacheKey(imageUrl) {
  // 使用URL的hash作为缓存key
  const urlHash = imageUrl.split('/').pop().replace(/[^a-zA-Z0-9]/g, '_');
  return `${CACHE_KEY_PREFIX}${urlHash}`;
}

/**
 * 获取缓存版本key（用于检测图片是否更新）
 * @param {string} imageUrl 图片URL
 * @returns {string} 版本key
 */
function getVersionKey(imageUrl) {
  return `${CACHE_KEY_VERSION}_${getCacheKey(imageUrl)}`;
}

/**
 * 检查本地是否已有缓存的图片
 * @param {string} imageUrl 图片URL
 * @returns {Promise<string|null>} 返回本地缓存路径，如果没有则返回null
 */
function getCachedImagePath(imageUrl) {
  return new Promise((resolve) => {
    if (!imageUrl) {
      resolve(null);
      return;
    }

    // 使用存储中的路径记录，而不是文件系统
    const versionKey = getVersionKey(imageUrl);
    const cachedVersion = wx.getStorageSync(versionKey);
    const cachedPath = wx.getStorageSync(getCacheKey(imageUrl));
    const currentVersion = imageUrl; // 使用URL作为版本标识

    if (cachedVersion === currentVersion && cachedPath) {
      // 版本匹配，检查文件是否存在
      const fs = wx.getFileSystemManager();
      try {
        fs.accessSync(cachedPath);
        // 文件存在，返回缓存路径
        resolve(cachedPath);
      } catch (e) {
        // 文件不存在，清除记录
        wx.removeStorageSync(versionKey);
        wx.removeStorageSync(getCacheKey(imageUrl));
        resolve(null);
      }
    } else {
      resolve(null);
    }
  });
}

/**
 * 下载并缓存图片
 * @param {string} imageUrl 图片URL
 * @returns {Promise<string>} 返回本地缓存路径
 */
function downloadAndCacheImage(imageUrl) {
  return new Promise((resolve, reject) => {
    if (!imageUrl) {
      reject(new Error('图片URL为空'));
      return;
    }

    const cacheKey = getCacheKey(imageUrl);
    const versionKey = getVersionKey(imageUrl);

    // 先检查是否已有缓存
    getCachedImagePath(imageUrl).then(cachedPath => {
      if (cachedPath) {
        console.log('使用缓存的图片', cachedPath);
        resolve(cachedPath);
        return;
      }

      // 下载图片
      console.log('开始下载图片', imageUrl);
      wx.downloadFile({
        url: imageUrl,
        success: (res) => {
          if (res.statusCode === 200) {
            // 保存到本地文件系统
            const fs = wx.getFileSystemManager();
            fs.saveFile({
              tempFilePath: res.tempFilePath,
              success: (saveRes) => {
                const savedFilePath = saveRes.savedFilePath;
                // 保存版本信息和文件路径
                wx.setStorageSync(versionKey, imageUrl);
                wx.setStorageSync(cacheKey, savedFilePath);
                console.log('图片缓存成功', savedFilePath);
                resolve(savedFilePath);
              },
              fail: (err) => {
                console.error('保存图片失败', err);
                // 即使保存失败，也可以使用临时文件
                resolve(res.tempFilePath);
              }
            });
          } else {
            reject(new Error(`下载失败，状态码: ${res.statusCode}`));
          }
        },
        fail: (err) => {
          console.error('下载图片失败', err);
          reject(err);
        }
      });
    });
  });
}

/**
 * 清除所有广告图缓存
 */
function clearImageCache() {
  try {
    const fs = wx.getFileSystemManager();
    
    // 清除存储记录，并删除对应的文件
    try {
      const storageInfo = wx.getStorageInfoSync();
      storageInfo.keys.forEach(key => {
        if (key.startsWith(CACHE_KEY_VERSION) || key.startsWith(CACHE_KEY_PREFIX)) {
          // 如果是文件路径记录，尝试删除文件
          if (key.startsWith(CACHE_KEY_PREFIX) && !key.includes(CACHE_KEY_VERSION)) {
            const filePath = wx.getStorageSync(key);
            if (filePath) {
              try {
                fs.unlinkSync(filePath);
              } catch (e) {
                // 忽略删除失败
              }
            }
          }
          // 清除存储记录
          wx.removeStorageSync(key);
        }
      });
    } catch (e) {
      console.warn('清除存储缓存失败', e);
    }

    console.log('广告图缓存已清除');
  } catch (e) {
    console.error('清除缓存失败', e);
  }
}

module.exports = {
  getCachedImagePath,
  downloadAndCacheImage,
  clearImageCache
};

