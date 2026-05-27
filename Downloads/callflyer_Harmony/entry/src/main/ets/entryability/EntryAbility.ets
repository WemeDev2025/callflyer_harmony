import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG = 'EntryAbility';
const DOMAIN = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: object) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onCreate');
  }

  onDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageCreate');

    // 请求通知授权
    notificationManager.requestEnableNotification(this.context).then(() => {
      hilog.info(DOMAIN, TAG, '[ANS] requestEnableNotification success');
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, '[ANS] requestEnableNotification failed, code is %{public}d, message is %{public}s', err.code, err.message);
    });

    windowStage.loadContent('pages/Index', (err: Error, data: void) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data));
    });

    // 设置窗口背景色与页面背景一致
    windowStage.getMainWindow().then((win: window.Window) => {
      win.setWindowBackgroundColor('#E7F8FC');
      // 设置状态栏背景透明
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#14233a'
      });
    });
  }

  onWindowStageDestroy() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onWindowStageDestroy');
  }

  onForeground() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onForeground');
  }

  onBackground() {
    hilog.info(DOMAIN, TAG, 'EntryAbility onBackground');
  }
}
