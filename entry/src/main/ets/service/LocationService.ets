import geoLocationManager from '@ohos.geoLocationManager';
import type { Context } from '@kit.AbilityKit';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

interface Location {
  latitude: number;
  longitude: number;
}

class LocationService {
  static async getCurrentLocation(context: Context): Promise<Location | null> {
    try {
      // 请求位置权限
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.APPROXIMATELY_LOCATION']);

      if (result.authResults[0] !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        console.info('LocationService: 位置权限被拒绝');
        return null;
      }

      // 检查位置服务是否开启
      let locationEnabled = geoLocationManager.isLocationEnabled();
      if (!locationEnabled) {
        console.info('LocationService: 位置服务未开启');
        return null;
      }

      // 获取位置
      const location = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET
      });

      console.info('LocationService: 获取位置成功', JSON.stringify(location));

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
}

export default LocationService;
