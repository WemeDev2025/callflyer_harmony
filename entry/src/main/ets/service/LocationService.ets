import geoLocationManager from '@ohos.geoLocationManager';
import type { Context } from '@kit.AbilityKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import http from '@ohos.net.http';

interface Location {
  latitude: number;
  longitude: number;
}

interface GeocodeCityResponse {
  city?: string;
  province?: string;
  district?: string;
  formatted_address?: string;
}

class LocationService {
  static async getCurrentLocation(context: Context): Promise<Location | null> {
    try {
      // 请求位置权限
      console.info('LocationService: 开始请求位置权限');
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.APPROXIMATELY_LOCATION']);
      console.info('LocationService: 权限请求结果 authResults=' + JSON.stringify(result.authResults));

      if (result.authResults[0] !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        console.info('LocationService: 位置权限被拒绝');
        return null;
      }

      // 检查位置服务是否开启
      let locationEnabled = geoLocationManager.isLocationEnabled();
      console.info('LocationService: 位置服务开启状态=' + locationEnabled);
      if (!locationEnabled) {
        console.info('LocationService: 位置服务未开启');
        return null;
      }

      // 获取位置
      const location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET
      });

      console.info('LocationService: 获取位置成功, lat=' + location.latitude + ', lon=' + location.longitude);

      return {
        latitude: location.latitude,
        longitude: location.longitude
      };
    } catch (error) {
      const err = error as BusinessError;
      console.error('LocationService: 获取位置失败, code=' + err.code + ', message=' + err.message);
      return null;
    }
  }

  static async reverseGeocode(lat: number, lon: number): Promise<string | null> {
    // 调用天翼云后端的天地图逆地理编码接口
    // 注意：天地图 API 参数顺序是 lng, lat
    const url = `https://wetofly.com/api/geocode/city?lat=${lat}&lng=${lon}`;
    console.info('LocationService.reverseGeocode: 请求 url=' + url);

    const timeoutMs = 8000;
    const timeoutPromise = new Promise<'timeout'>((resolve) => {
      setTimeout(() => {
        console.error('LocationService.reverseGeocode: 请求超时');
        resolve('timeout');
      }, timeoutMs);
    });

    const httpRequest = http.createHttp();
    const requestPromise = httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: [{ 'User-Agent': 'CallFlyer-HarmonyOS/1.0' }],
      connectTimeout: 10000,
      readTimeout: 10000
    });

    try {
      const raceResult = await Promise.race([requestPromise, timeoutPromise]);
      if (raceResult === 'timeout') {
        console.error('LocationService.reverseGeocode: 超时未收到响应');
        return null;
      }

      const result = raceResult as http.HttpResponse;
      console.info('LocationService.reverseGeocode: 响应码=' + result.responseCode);

      if (!result.result) {
        console.info('LocationService.reverseGeocode: result为空');
        return null;
      }

      if (typeof result.result !== 'string') {
        console.info('LocationService.reverseGeocode: result非string, type=' + typeof result.result);
        return null;
      }

      const data = JSON.parse(result.result) as GeocodeCityResponse;
      console.info('LocationService.reverseGeocode: 响应=' + JSON.stringify(data));

      // 后端返回格式: { city: "上海·浦东", province: "上海市", district: "浦东新区", formatted_address: "..." }
      const city = data?.city || null;
      console.info('LocationService.reverseGeocode 最终city=', city);
      return city;
    } catch (error) {
      console.error('LocationService.reverseGeocode 异常: error=' + JSON.stringify(error));
      return null;
    }
  }
}

export default LocationService;
