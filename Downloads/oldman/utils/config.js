// utils/config.js - 配置文件
module.exports = {
  // 开发环境配置
  DEV: {
    USE_MOCK_DATA: false, // 是否使用模拟数据（强制使用真实API）
    MOCK_API_DELAY: 500  // 模拟API延迟（毫秒）
  },

  // API配置
  API: {
    BASE_URL: 'https://wemedev.com', // API基础URL
    TIMEOUT: 10000,
    VERSION: 'v1'
  },

  // 文件上传配置
  UPLOAD: {
    MAX_SIZE: 5 * 1024 * 1024, // 5MB
    ALLOWED_TYPES: ['image/jpeg', 'image/png', 'image/jpg'],
    UPLOAD_URL: 'https://wemedev.com/api/upload'
  },

  // 缓存配置
  CACHE: {
    TIMEOUT: 5 * 60 * 1000, // 5分钟
    MAX_SIZE: 50 // 最大缓存条目数
  },

  // 分页配置
  PAGINATION: {
    DEFAULT_PAGE_SIZE: 10,
    MAX_PAGE_SIZE: 50
  },

  // 错误重试配置
  RETRY: {
    MAX_ATTEMPTS: 3,
    DELAY: 1000 // 1秒
  },

  // 业务配置
  BUSINESS: {
    // 技能选项
    SKILLS: [
      '失智照护',
      '失能照护', 
      '术后/康复照护',
      '慢性病照护',
      '安宁疗养'
    ],
    
    // 证件类型
    CERTIFICATES: [
      { key: 'idCard', name: '身份证' },
      { key: 'healthCard', name: '健康证' },
      { key: 'nursingCert', name: '护理证' },
      { key: 'firstAidCert', name: '急救证' }
    ],

    // 性别选项
    GENDER_OPTIONS: [
      { key: 'male', name: '男' },
      { key: 'female', name: '女' },
      { key: 'any', name: '不限' }
    ]
  }
};
