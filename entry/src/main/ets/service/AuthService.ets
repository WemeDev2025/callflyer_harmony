import { authentication } from '@kit.AccountKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { exchangeHuaweiToken, fetchProfile } from './ApiService';

/**
 * 华为账号登录服务 - 使用Account Kit
 */
const TAG = 'AuthService';
const DOMAIN = 0xFF00;

// 用户信息类
export class HuaweiUserInfo {
  openId: string = '';
  unionId: string = '';
  displayName: string = '';
  email: string = '';
  phone: string = '';
  avatar: string = '';
  authorizationCode: string = '';
}

// 登录结果类
export class LoginResult {
  success: boolean = false;
  userInfo: HuaweiUserInfo | undefined;
  error: string | undefined;
}

// Token兑换结果类
export class TokenResult {
  token: string | undefined;
  error: string | undefined;
}

// 华为账号信息类
class NativeAuthInfo {
  hasAccount: boolean = false;
  openId: string = '';
  unionId: string = '';
}

class AuthService {
  private static instance: AuthService;
  private currentUser: HuaweiUserInfo | null = null;
  private isLoggedIn: boolean = false;
  private authToken: string = '';

  private constructor() {}

  static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  /**
   * 华为一键登录（静默登录）
   * 如果用户已登录华为账号且已授权，可直接获取OpenID
   */
  async login(): Promise<LoginResult> {
    hilog.info(DOMAIN, TAG, 'Starting Huawei quick login');

    const result = new LoginResult();

    try {
      // 创建授权请求
      const authRequest = new authentication.HuaweiIDProvider().createAuthorizationWithHuaweiIDRequest();

      // 一键登录场景该参数必须设置为false
      authRequest.forceAuthorization = false;

      // 用于防跨站点请求伪造
      authRequest.state = util.generateRandomUUID();

      // 获取UnionID、OpenID需要传递的scope
      authRequest.scopes = ['quickLoginAnonymousPhone'];
      // 获取code需要传递的permission
      authRequest.permissions = ['serviceauthcode'];

      // 执行授权请求
      const controller = new authentication.AuthenticationController();
      const response = await controller.executeRequest(authRequest) as authentication.AuthorizationWithHuaweiIDResponse;

      hilog.info(DOMAIN, TAG, 'Login response: %{public}s', JSON.stringify(response));

      if (response.data) {
        const userInfo = new HuaweiUserInfo();
        userInfo.openId = response.data.openID ?? '';
        userInfo.unionId = response.data.unionID ?? '';
        userInfo.authorizationCode = response.data.authorizationCode ?? '';
        // 从extraInfo获取匿名手机号
        const extraInfo = response.data.extraInfo as Record<string, string>;
        userInfo.phone = extraInfo?.['quickLoginAnonymousPhone'] ?? '';

        this.currentUser = userInfo;
        this.isLoggedIn = true;

        hilog.info(DOMAIN, TAG, 'Login success, openId: %{public}s', userInfo.openId);
        result.success = true;
        result.userInfo = userInfo;
        return result;
      } else {
        hilog.warn(DOMAIN, TAG, 'Login failed: no data in response');
        result.success = false;
        result.error = '登录失败：无返回数据';
        return result;
      }
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Login failed, errCode: %{public}d, errMessage: %{public}s',
        error.code, error.message);

      // 常见错误码处理
      let errorMsg = '登录失败';
      switch (error.code) {
        case 12300101: // 用户取消
          errorMsg = '用户取消登录';
          break;
        case 12300201: // 无华为账号
          errorMsg = '请先登录华为账号';
          break;
        case 12300103: // 授权被拒绝
          errorMsg = '授权被拒绝';
          break;
        default:
          errorMsg = '登录失败: ' + error.message;
      }

      result.success = false;
      result.error = errorMsg;
      return result;
    }
  }

  /**
   * 获取当前登录用户信息
   */
  getCurrentUser(): HuaweiUserInfo | null {
    return this.currentUser;
  }

  /**
   * 判断是否已登录
   */
  isLogin(): boolean {
    return this.isLoggedIn;
  }

  /**
   * 获取认证Token
   */
  getAuthToken(): string {
    if (this.authToken) {
      return this.authToken;
    }
    // 尝试从 AppStorage 获取
    const storedToken = AppStorage.get<string>('authToken');
    if (storedToken) {
      this.authToken = storedToken;
    }
    return this.authToken;
  }

  /**
   * 获取当前用户OpenID
   */
  getCurrentOpenId(): string {
    return this.currentUser?.openId ?? '';
  }

  /**
   * 刷新当前用户资料（从服务器获取最新数据）
   * 用于解决登录后用户完善资料但本地缓存未更新的问题
   */
  async refreshCurrentUser(): Promise<boolean> {
    if (!this.currentUser?.openId) {
      hilog.warn(DOMAIN, TAG, 'refreshCurrentUser: no openId, skip');
      return false;
    }
    const token = this.getAuthToken();
    if (!token) {
      hilog.warn(DOMAIN, TAG, 'refreshCurrentUser: no token, skip');
      return false;
    }
    try {
      const profile = await fetchProfile(this.currentUser.openId, token);
      if (profile) {
        this.currentUser.displayName = profile.nickname;
        this.currentUser.avatar = profile.avatarUrl;
        this.currentUser.phone = profile.phone;
        this.currentUser.email = profile.wechatId; // wechatId 暂存在 email 字段
        hilog.info(DOMAIN, TAG, 'refreshCurrentUser: updated successfully');
        return true;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'refreshCurrentUser failed: %{public}s', JSON.stringify(err));
    }
    return false;
  }

  /**
   * 退出登录
   */
  async logout(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Logging out');
    this.currentUser = null;
    this.isLoggedIn = false;
    this.authToken = '';
    AppStorage.setOrCreate('authToken', '');
  }

  /**
   * 将华为OpenID转换为业务Token
   */
  async exchangeToken(openId: string, unionId: string): Promise<TokenResult> {
    hilog.info(DOMAIN, TAG, 'Exchanging token for openId: %{public}s', openId);

    const result = new TokenResult();

    try {
      const resp = await exchangeHuaweiToken(openId, unionId);
      hilog.info(DOMAIN, TAG, 'Token exchange response code: %{public}d', resp.code);

      if (resp.code === 200 && resp.data && resp.data.token) {
        result.token = resp.data.token;
        this.authToken = resp.data.token;
        AppStorage.setOrCreate('authToken', resp.data.token);
        hilog.info(DOMAIN, TAG, 'Token exchange success, stored authToken: %{public}s', this.authToken);
      } else {
        result.error = 'Token兑换失败';
        hilog.error(DOMAIN, TAG, 'Token exchange failed: %{public}s', JSON.stringify(resp));
      }
    } catch (err) {
      const error = err as BusinessError;
      result.error = 'Token兑换失败: ' + error.message;
      hilog.error(DOMAIN, TAG, 'Token exchange error: %{public}d, %{public}s', error.code, error.message);
    }

    return result;
  }
}

export default AuthService.getInstance();
