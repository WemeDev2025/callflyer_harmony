# SSL证书问题诊断

## 🚨 问题描述

**错误信息**: `net::ERR_SSL_VERSION_OR_CIPHER_MISMATCH`
**错误代码**: `-113`
**影响范围**: 真机调试时API请求失败

## 🔍 问题分析

### 错误原因
1. **SSL证书配置问题**
   - 证书链不完整
   - 证书已过期或无效
   - 证书域名不匹配

2. **TLS配置问题**
   - 不支持的TLS版本
   - 不安全的密码套件
   - SSL协议配置错误

3. **微信小程序环境限制**
   - 真机环境对SSL要求更严格
   - 不支持某些旧的SSL配置

## 🛠️ 后端需要修复的问题

### 1. SSL证书配置
```bash
# 检查证书有效性
openssl x509 -in certificate.crt -text -noout

# 检查证书链
openssl verify -CAfile ca-bundle.crt certificate.crt

# 检查证书域名
openssl x509 -in certificate.crt -text -noout | grep -A 1 "Subject Alternative Name"
```

### 2. TLS配置优化
**Nginx配置示例**:
```nginx
server {
    listen 443 ssl http2;
    server_name wemedev.com;
    
    # SSL证书配置
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    # 现代TLS配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    
    # 安全头配置
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
}
```

### 3. 服务器配置检查
```bash
# 测试SSL配置
openssl s_client -connect wemedev.com:443 -servername wemedev.com

# 检查支持的TLS版本
nmap --script ssl-enum-ciphers -p 443 wemedev.com

# 在线SSL测试
# 访问: https://www.ssllabs.com/ssltest/analyze.html?d=wemedev.com
```

## 🔧 临时解决方案

### 1. 开发环境配置
在微信开发者工具中：
- **设置** → **项目设置** → **不校验合法域名、web-view（业务域名）、TLS 版本以及 HTTPS 证书**

### 2. 小程序端错误处理
已添加SSL错误检测和处理：
```javascript
// 检测SSL错误
if (err.errMsg && (err.errMsg.includes('SSL') || err.errMsg.includes('TLS') || err.errMsg.includes('cipher'))) {
  console.log('🔒 检测到SSL/TLS错误，尝试降级处理...');
  this.handleSSLError(err, reject);
  return;
}
```

## 📋 检查清单

### 后端检查项
- [ ] SSL证书有效性
- [ ] 证书链完整性
- [ ] 域名匹配性
- [ ] TLS版本支持（1.2+）
- [ ] 密码套件安全性
- [ ] HTTP/2支持
- [ ] 安全头配置

### 测试工具
- [ ] SSL Labs测试: https://www.ssllabs.com/ssltest/
- [ ] 在线证书检查: https://www.sslshopper.com/ssl-checker.html
- [ ] 命令行测试: `openssl s_client`

## 🎯 预期结果

修复后应该看到：
- ✅ 真机调试API请求成功
- ✅ SSL握手正常
- ✅ 证书验证通过
- ✅ TLS连接建立

## 📞 联系支持

如果问题持续存在，请提供：
1. SSL证书详情
2. 服务器配置信息
3. 完整的错误日志
4. SSL测试报告
