// utils/dataAdapter.js - 数据适配器
/**
 * 工作卡数据适配器
 */
class WorkCardAdapter {
  /**
   * 本地数据转API数据
   */
  static toAPI(localData) {
    return {
      name: localData.name,
      phone: localData.phone,
      avatar: localData.avatarUrl,
      certificates: {
        idCard: localData.certs.idCard,
        healthCard: localData.certs.healthCard,
        nursingCert: localData.certs.nursingCert,
        firstAidCert: localData.certs.firstAidCert
      },
      skills: localData.skills,
      otherRequirements: localData.otherRequirements,
      status: 'draft' // 草稿状态
    };
  }

  /**
   * API数据转本地数据
   */
  static toLocal(apiData) {
    return {
      id: apiData.id,
      avatarUrl: apiData.avatar || '',
      name: apiData.name,
      phone: apiData.phone,
      certs: {
        idCard: apiData.certificates?.idCard || '',
        healthCard: apiData.certificates?.healthCard || '',
        nursingCert: apiData.certificates?.nursingCert || '',
        firstAidCert: apiData.certificates?.firstAidCert || ''
      },
      skills: apiData.skills || [],
      otherRequirements: apiData.otherRequirements || '',
      createTime: apiData.createdAt,
      updateTime: apiData.updatedAt,
      status: apiData.status
    };
  }
}

/**
 * 养老需求数据适配器
 */
class HireRequirementAdapter {
  /**
   * 本地数据转API数据
   */
  static toAPI(localData) {
    const apiData = {
      avatarUrl: localData.avatarUrl,
      gender: localData.gender,
      cert_id_card: localData.certs.idCard,
      cert_health_card: localData.certs.healthCard,
      cert_nursing_cert: localData.certs.nursingCert,
      cert_first_aid_cert: localData.certs.firstAidCert,
      services: localData.services,
      other_requirements: localData.otherRequirements,
      contactName: localData.contactName,
      contactPhone: localData.contactPhone,
      status: 'draft' // 草稿状态
    };
    
    console.log('🔄 HireRequirementAdapter.toAPI 转换数据:');
    console.log('输入数据:', localData);
    console.log('输出数据:', apiData);
    
    return apiData;
  }

  /**
   * API数据转本地数据
   */
  static toLocal(apiData) {
    console.log('🔄 HireRequirementAdapter.toLocal 转换数据:');
    console.log('输入API数据:', apiData);
    console.log('🔍 API数据中的avatarUrl字段:', apiData.avatarUrl);
    console.log('🔍 API数据中的avatar字段:', apiData.avatar);
    console.log('🔍 API数据完整结构:', JSON.stringify(apiData, null, 2));
    
    const localData = {
      id: apiData.id,
      avatarUrl: apiData.avatarUrl || apiData.avatar || '',
      gender: apiData.gender,
      certs: (() => {
        // 处理证件要求数据，支持两种格式
        console.log('🔍 证件要求数据转换:');
        console.log('- apiData.certificates:', apiData.certificates);
        console.log('- apiData.certificates类型:', typeof apiData.certificates);
        
        if (apiData.certificates) {
          // 新格式：certificates 对象
          console.log('🔍 使用certificates对象格式');
          console.log('- certificates.idCard:', apiData.certificates.idCard);
          console.log('- certificates.healthCard:', apiData.certificates.healthCard);
          console.log('- certificates.nursingCert:', apiData.certificates.nursingCert);
          console.log('- certificates.firstAidCert:', apiData.certificates.firstAidCert);
          
          const certs = {
            idCard: apiData.certificates.idCard || false,
            healthCard: apiData.certificates.healthCard || false,
            nursingCert: apiData.certificates.nursingCert || false,
            firstAidCert: apiData.certificates.firstAidCert || false
          };
          
          console.log('🔍 转换后的certs:', certs);
          return certs;
        } else {
          // 旧格式：单独的 cert_ 字段
          console.log('🔍 使用单独字段格式');
          return {
            idCard: apiData.cert_id_card || false,
            healthCard: apiData.cert_health_card || false,
            nursingCert: apiData.cert_nursing_cert || false,
            firstAidCert: apiData.cert_first_aid_cert || false
          };
        }
      })(),
      services: apiData.services || [],
      otherRequirements: apiData.other_requirements || apiData.otherRequirements || '',
      contactName: apiData.contactName,
      contactPhone: apiData.contactPhone,
      createTime: apiData.created_at,
      updateTime: apiData.updated_at,
      status: apiData.status
    };
    
    console.log('输出本地数据:', localData);
    
    return localData;
  }
}

/**
 * 用户数据适配器
 */
class UserAdapter {
  /**
   * API数据转本地数据
   */
  static toLocal(apiData) {
    return {
      id: apiData.id,
      openid: apiData.openid,
      nickname: apiData.nickname,
      avatar: apiData.avatar,
      phone: apiData.phone,
      gender: apiData.gender,
      city: apiData.city,
      province: apiData.province,
      country: apiData.country,
      createdAt: apiData.createdAt
    };
  }
}

/**
 * 响应数据适配器
 */
class ResponseAdapter {
  /**
   * 统一处理API响应
   */
  static handleResponse(response) {
    // 检查是否是微信登录的特殊响应格式（直接格式）
    if (response.access_token && response.user_info) {
      console.log('🔄 检测到微信登录响应格式（直接），进行数据转换...');
      return {
        success: true,
        data: {
          user: response.user_info,
          token: response.access_token
        },
        message: '登录成功'
      };
    }
    
    // 检查是否是微信登录的嵌套响应格式
    if (response.success && response.data && response.data.access_token && response.data.user_info) {
      console.log('🔄 检测到微信登录响应格式（嵌套），进行数据转换...');
      return {
        success: true,
        data: {
          user: response.data.user_info,
          token: response.data.access_token
        },
        message: response.message || '登录成功'
      };
    }
    
    // 检查是否是用户信息接口的模拟数据格式
    if (response.id && response.openid && response.nickname) {
      console.log('🔄 检测到用户信息响应格式（模拟数据），进行数据转换...');
      return {
        success: true,
        data: response,
        message: '获取用户信息成功'
      };
    }
    
    // 标准响应格式处理
    if (response.code === 0 || response.success) {
      return {
        success: true,
        data: response.data,
        message: response.message || '操作成功'
      };
    } else {
      return {
        success: false,
        data: null,
        message: response.message || '操作失败'
      };
    }
  }

  /**
   * 处理分页数据
   */
  static handlePageResponse(response) {
    console.log('🔄 处理分页响应:', response);
    
    // 后端已统一格式，直接处理标准响应
    if (response.success && Array.isArray(response.data)) {
      console.log('✅ 标准分页格式，直接返回');
      return {
        success: true,
        data: response.data,
        total: response.total || response.data.length,
        page: response.page || 1,
        pageSize: response.pageSize || 10,
        message: response.message || '操作成功'
      };
    }
    
    // 兼容旧格式（如果还有的话）
    const result = this.handleResponse(response);
    if (result.success) {
      let data = [];
      let total = 0;
      
      if (response.caregivers) {
        data = response.caregivers;
        total = response.total || data.length;
      } else if (response.employers) {
        data = response.employers;
        total = response.total || data.length;
      } else if (response.data) {
        data = response.data.list || response.data.items || response.data;
        total = response.data.total || response.total || data.length;
      }
      
      return {
        success: true,
        data: data,
        total: total,
        page: response.page || 1,
        pageSize: response.pageSize || 10,
        message: result.message
      };
    }
    
    return result;
  }
}

module.exports = {
  WorkCardAdapter,
  HireRequirementAdapter,
  UserAdapter,
  ResponseAdapter
};
