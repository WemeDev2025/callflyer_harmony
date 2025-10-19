# API测试命令

## 1. 获取用户信息
```bash
curl -X GET "https://wemedev.com/user/info" \
  -H "Authorization: eyJ0eXAiOiJKV1QiLCJh..." \
  -H "Content-Type: application/json"
```

## 2. 获取我的养老需求
```bash
curl -X GET "https://wemedev.com/hire-requirement/my" \
  -H "Authorization: eyJ0eXAiOiJKV1QiLCJh..." \
  -H "Content-Type: application/json"
```

## 3. 保存养老需求（测试数据）
```bash
curl -X POST "https://wemedev.com/hire-requirement" \
  -H "Authorization: eyJ0eXAiOiJKV1QiLCJh..." \
  -H "Content-Type: application/json" \
  -d '{
    "gender": "female",
    "cert_id_card": true,
    "cert_health_card": true,
    "cert_nursing_cert": false,
    "cert_first_aid_cert": true,
    "services": ["慢性病照护", "失智照护", "失能照护"],
    "other_requirements": "测试其他要求",
    "contactName": "测试用户",
    "contactPhone": "13800138000"
  }'
```

## 4. 发布养老需求
```bash
curl -X POST "https://wemedev.com/hire-requirement/{ID}/publish" \
  -H "Authorization: eyJ0eXAiOiJKV1QiLCJh..." \
  -H "Content-Type: application/json"
```

## 5. 获取Token（如果需要重新获取）
```bash
curl -X POST "https://wemedev.com/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "code": "微信登录code",
    "encryptedData": "加密数据",
    "iv": "初始向量"
  }'
```

## 测试步骤

1. 首先运行命令2，查看当前API返回的数据格式
2. 运行命令3，保存新的测试数据
3. 再次运行命令2，查看保存后的数据格式
4. 对比保存前后的数据格式是否一致

## 预期结果

如果API实现正确，应该看到：
- 保存时：`cert_id_card: true, cert_health_card: true, cert_nursing_cert: false, cert_first_aid_cert: true`
- 获取时：`certificates: {idCard: true, healthCard: true, nursingCert: false, firstAidCert: true}`

如果API有问题，会看到：
- 保存时：`cert_id_card: true, cert_health_card: true, cert_nursing_cert: false, cert_first_aid_cert: true`
- 获取时：`certificates: {idCard: false, healthCard: false, nursingCert: false, firstAidCert: false}`
