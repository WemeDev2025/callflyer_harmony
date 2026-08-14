import { pushService } from '@kit.PushKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import dataPreferences from '@ohos.data.preferences';
import http from '@ohos.net.http';
import AuthService from './AuthService';

const TAG = 'PushService';
const DOMAIN = 0xFF00;
const PREFS_NAME = 'callflyer_prefs';
const KEY_DEVICE_ID = 'device_id';

export class PushService {
  private static instance: PushService;
  private pushToken: string = '';
  private deviceId: string = '';
  private context: Context | null = null;

  private constructor(context: Context) {
    this.context = context;
    this.loadDeviceId();
  }

  static getInstance(context?: Context): PushService {
    if (!PushService.instance) {
      if (!context) {
        hilog.error(DOMAIN, TAG, '【PushService】getInstance called without context, not initialized');
        return PushService.instance;
      }
      hilog.info(DOMAIN, TAG, '【PushService】创建单例实例');
      PushService.instance = new PushService(context);
    }
    return PushService.instance;
  }

  private async loadDeviceId(): Promise<void> {
    try {
      const prefs = dataPreferences.getPreferencesSync(this.context!, { name: PREFS_NAME });
      let deviceId = prefs.getSync(KEY_DEVICE_ID, '') as string;
      if (!deviceId) {
        deviceId = 'device_' + Date.now() + '_' + Math.floor(Math.random() * 10000).toString();
        prefs.putSync(KEY_DEVICE_ID, deviceId);
        prefs.flushSync();
        hilog.info(DOMAIN, TAG, '【PushService】生成新 deviceId: %{public}s', deviceId);
      }
      this.deviceId = deviceId;
      hilog.info(DOMAIN, TAG, '【PushService】加载 deviceId: %{public}s', this.deviceId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, '【PushService】加载 deviceId 失败: %{public}s', JSON.stringify(e));
    }
  }

  async getAndRegisterPushToken(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, '【PushService】开始获取并注册 Push Token');

      // 获取 push token
      let pushToken = '';
      try {
        pushToken = await pushService.getToken();
        hilog.info(DOMAIN, TAG, '【PushService】获取 Token 成功: %{public}s', pushToken);
        this.pushToken = pushToken;
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(DOMAIN, TAG, '【PushService】获取 Push Token 失败，继续注册: %{public}d %{public}s', err.code, err.message);
      }

      // 优先使用 AuthService 中的 openId，其次使用 deviceId
      const openId = AuthService.getCurrentOpenId();
      const identifier = openId || this.deviceId;

      hilog.info(DOMAIN, TAG, '【PushService】注册到服务器, identifier: %{public}s, openId: %{public}s, deviceId: %{public}s',
        identifier, openId || 'N/A', this.deviceId || 'N/A');

      // 调用注册接口（无需 auth）
      const result = await this.registerPushToken(pushToken, identifier);
      hilog.info(DOMAIN, TAG, '【PushService】注册结果: %{public}s', result ? '成功' : '失败');
    } catch (e) {
      hilog.error(DOMAIN, TAG, '【PushService】注册 Push Token 异常: %{public}s', JSON.stringify(e));
    }
  }

  private registerPushToken(pushToken: string, identifier: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      const req = http.createHttp();
      req.request(
        'https://wetofly.com/api/push/token',
        {
          method: http.RequestMethod.POST,
          header: [{ 'Content-Type': 'application/json' }],
          extraData: JSON.stringify({
            push_token: pushToken || '',
            openid: identifier
          }),
          connectTimeout: 15000,
          readTimeout: 15000
        },
        (err, data) => {
          if (!err && data.responseCode === 200) {
            hilog.info(DOMAIN, TAG, '【PushService】注册成功');
            resolve(true);
          } else {
            hilog.error(DOMAIN, TAG, '【PushService】注册失败: %{public}s %{public}d', JSON.stringify(err), data.responseCode);
            resolve(false);
          }
          req.destroy();
        }
      );
    });
  }
}

export default PushService;
