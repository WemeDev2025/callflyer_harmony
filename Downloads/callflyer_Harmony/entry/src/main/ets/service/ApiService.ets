import http from '@ohos.net.http';
import AuthService from './AuthService';

/**
 * API服务
 */

const BASE_URL = 'https://wetofly.com';

// 通用HTTP响应
export interface HttpResponse<T> {
  code: number;
  data: T;
}

// HTTP请求头
interface HttpHeader {
  key: string;
  value: string;
}

// ============ 轮播图 ============

export interface BannerItem {
  uid: string;
  src: string;
  isVideoBanner: boolean;
  videoUrl: string;
  clickType: string;
  clickPage: string;
  clickUrl: string;
  // 奖励位字段
  isRewardSlot?: boolean;
  title?: string;
  subtitle?: string;
  actionText?: string;
}

interface RawConfig {
  carousel: RawBannerItem[];
  defaultTopTitle?: string;
  todayActiveUsers?: number;
  totalPilotCount?: number;
  totalEmployerCount?: number;
  rewardAdConfig?: RawRewardAdConfig;
}

interface RawRewardAdConfig {
  display_title?: string;
  title?: string;
  cta_text?: string;
  ctaText?: string;
  buttonText?: string;
  display_subtitle?: string;
  subtitle?: string;
  occupied_subtitle?: string;
  occupiedSubtitle?: string;
  enabled?: boolean;
  slot_key?: string;
  slotKey?: string;
  slot_name?: string;
}

interface RawBannerItem {
  image_url: string;
  click_type: string;
  click_page: string;
  click_url: string;
  click_miniprogram: string;
  video_url: string;
  order: number;
  enabled: boolean;
  position: string;
}

export async function fetchBanners(): Promise<BannerItem[]> {
  return new Promise<BannerItem[]>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/config`;
    console.info('【接口请求】url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: [{ 'Content-Type': 'application/json' }],
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchBanners:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchBanners:', data.result as string);
          try {
            const response = JSON.parse(data.result as string) as RawConfig;
            const banners = parseBanners(response);
            resolve(banners);
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve([]);
        }
        httpRequest.destroy();
      }
    );
  });
}

// 判断是否为微信小程序ID（wx开头+数字字母）
function isMiniProgramId(value: string): boolean {
  return /^wx[a-zA-Z0-9]{10,}$/.test(value);
}

function parseBanners(response: RawConfig): BannerItem[] {
  if (!response.carousel || !Array.isArray(response.carousel)) {
    return [];
  }
  const result: BannerItem[] = [];
  const timestamp = Date.now();
  for (let i = 0; i < response.carousel.length; i++) {
    const item = response.carousel[i];
    if (item.enabled && item.position === 'homepage_banner' && item.image_url) {
      // 过滤小程序类型的轮播图
      if (item.click_type === 'miniprogram') {
        continue;
      }
      const clickUrl = item.click_url || '';
      if (isMiniProgramId(clickUrl)) {
        continue;
      }
      result.push({
        uid: `banner_${i}_${timestamp}`,
        src: item.image_url,
        isVideoBanner: !!item.video_url,
        videoUrl: item.video_url || '',
        clickType: item.click_type || 'none',
        clickPage: item.click_page || '',
        clickUrl: clickUrl
      });
    }
  }
  return result;
}

export interface ConfigResult {
  defaultTopTitle: string;
  todayActiveUsers?: number;
  totalPilotCount?: number;
  totalEmployerCount?: number;
  rewardTitle?: string;
  rewardSubtitle?: string;
  rewardButtonText?: string;
  rewardOccupiedSubtitle?: string;
  carousel?: CarouselItem[];
}

export interface CarouselItem {
  slot?: string;
  image_url?: string;
  reward_meta?: RewardMeta;
  profile_card?: ProfileCard;
  publisher_openid?: string;
}

export interface RewardMeta {
  title?: string;
  subtitle?: string;
  cta_text?: string;
}

export interface ProfileCard {
  avatar_url?: string;
  nickname?: string;
  city?: string;
  phone?: string;
  wechat_id?: string;
  douyin_id?: string;
  license_type?: string;
  user_role?: string;
  business_scope?: string[];
  drone_model?: string;
  likeCount?: number;
  like_count?: number;
}

export async function fetchConfig(): Promise<ConfigResult> {
  return new Promise<ConfigResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/config`;
    console.info('【接口请求】fetchConfig url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: [{ 'Content-Type': 'application/json' }],
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchConfig:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchConfig:', data.result as string);
          try {
            const response = JSON.parse(data.result as string) as RawConfig;
            const rewardConfig = response.rewardAdConfig || {};
            resolve({
              defaultTopTitle: response.defaultTopTitle || '',
              todayActiveUsers: response.todayActiveUsers || 0,
              totalPilotCount: response.totalPilotCount || 0,
              totalEmployerCount: response.totalEmployerCount || 0,
              rewardTitle: rewardConfig.display_title || rewardConfig.title || '',
              rewardSubtitle: rewardConfig.display_subtitle || rewardConfig.subtitle || '',
              rewardButtonText: rewardConfig.cta_text || rewardConfig.ctaText || rewardConfig.buttonText || '',
              rewardOccupiedSubtitle: rewardConfig.occupied_subtitle || rewardConfig.occupiedSubtitle || '',
              carousel: response.carousel || []
            });
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve({ defaultTopTitle: '' });
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 附近飞手 ============

export interface NearbyPilotsResult {
  pilots: PilotItem[];
  hasMore: boolean;
}

export interface PilotItem {
  openid: string;
  nickname: string;
  avatar: string;
  city: string;
  licenseType: string;
  licenseStatus: string;
  droneModel: string;
  businessScope: string;
  businessScopeText: string;
  distanceText: string;
  recentActiveText: string;
  phone: string;
  wechatId: string;
  douyinId: string;
  pilotCode: string;
  company: string;
  position: string;
  likeCount: number;
  likedByMe: boolean;
  isVipSlot: boolean;
  vipRadiusKm: number;
  vipLabel: string;
  latitude: number;
  longitude: number;
  score: string;
  licenseUrl: string;
  channelsId: string;
  isNew: boolean;
  licenseStatusClass: string;
  roleLabel: string;
  institutionId: string;
  workMu: number | null;
  workKg: number | null;
  droneImages: string[];
}

interface NearbyPilotsResponse {
  items: RawPilot[];
  total: number;
  has_more?: boolean;
}

interface RawPilotLocation {
  coordinates?: number[];
}

interface RawPilot {
  openid: string;
  openId?: string;
  open_id?: string;
  nickname?: string;
  avatarUrl?: string;
  avatar_url?: string;
  city?: string;
  license_type?: string;
  licenseType?: string;
  license_status?: string;
  licenseStatus?: string;
  drone_model?: string;
  droneModel?: string;
  business_scope?: string[];
  businessScope?: string[];
  distance_meters?: number;
  days_since_update?: number;
  daysSinceUpdate?: number;
  recent_active_days?: number;
  recentActiveDays?: number;
  phone?: string;
  wechat_id?: string;
  wechatId?: string;
  douyin_id?: string;
  douyinId?: string;
  pilot_code?: string;
  pilotCode?: string;
  company?: string;
  position?: string;
  like_count?: number;
  likeCount?: number;
  liked_by_me?: boolean;
  likedByMe?: boolean;
  is_vip_slot?: boolean;
  isNew?: boolean;
  is_new?: boolean;
  vip_radius_km?: number;
  vip_label?: string;
  latitude?: number;
  longitude?: number;
  location?: RawPilotLocation;
  score?: number;
  license_url?: string;
  licenseUrl?: string;
  channels_id?: string;
  channelsId?: string;
  user_role?: string;
  userRole?: string;
  institution_id?: string;
  institutionId?: string;
  work_mu?: number;
  workMu?: number;
  work_kg?: number;
  workKg?: number;
  drone_images?: string[];
  droneImages?: string[];
}

export async function fetchNearbyPilots(lat?: number, lng?: number, page: number = 1, pageSize: number = 50): Promise<NearbyPilotsResult> {
  return new Promise<NearbyPilotsResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    let url = `${BASE_URL}/api/pilots/nearby?page=${page}&page_size=${pageSize}`;
    if (lat !== undefined && lng !== undefined) {
      url = url + `&lat=${lat}&lng=${lng}`;
    }
    console.info('【接口请求】url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: [{ 'Content-Type': 'application/json' }],
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchNearbyPilots:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchNearbyPilots:', data.result as string);
          try {
            const response = JSON.parse(data.result as string) as NearbyPilotsResponse;
            const pilots: PilotItem[] = [];
            if (response.items) {
              for (let i = 0; i < response.items.length; i++) {
                const p = response.items[i];
                const distanceM = p.distance_meters != null ? p.distance_meters : null;
                const distanceText = distanceM != null
                  ? (distanceM < 1000 ? `${Math.round(distanceM)}m` : `${(distanceM / 1000).toFixed(0)}km`)
                  : '';
                const businessScopeArr = p.business_scope || p.businessScope || [];
                const businessScopeText = businessScopeArr.join(' · ');
                const daysSinceUpdateRaw = p.days_since_update != null ? p.days_since_update
                  : p.daysSinceUpdate != null ? p.daysSinceUpdate
                  : p.recent_active_days != null ? p.recent_active_days
                  : p.recentActiveDays;
                const daysSinceUpdate = daysSinceUpdateRaw != null ? `${daysSinceUpdateRaw}` : '';
                let recentActiveText = '--';
                if (daysSinceUpdate !== '') {
                  if (daysSinceUpdate === '0') {
                    recentActiveText = '今天';
                  } else {
                    recentActiveText = `${daysSinceUpdate} 天前`;
                  }
                }
                const userRole = p.user_role || p.userRole || 'pilot';
                const roleLabel = userRole === 'pilot' ? '飞手' : userRole === 'employer' ? '雇主' : '飞手';
                const licenseStatusClass = p.license_status || p.licenseStatus ? 'status-success' : '';
                const scoreRaw = p.score;
                const score = scoreRaw != null ? `${scoreRaw.toFixed(2).replace(/\.?0+$/, '')}%` : '--';
                const locationCoords = p.location?.coordinates || [];
                const longitude = locationCoords[0] || null;
                const latitude = locationCoords[1] || null;
                const item: PilotItem = {
                  openid: p.openid || p.openId || p.open_id || '',
                  nickname: p.nickname || '匿名飞手',
                  avatar: p.avatarUrl || p.avatar_url || 'https://wetofly.com/data/image/avatar_placeholder.webp',
                  city: p.city || '',
                  licenseType: (p.license_type || p.licenseType || '').toLowerCase(),
                  licenseStatus: p.license_status || p.licenseStatus || '',
                  droneModel: p.drone_model || p.droneModel || '--',
                  businessScope: businessScopeArr.join('、'),
                  businessScopeText: businessScopeText,
                  distanceText: distanceText,
                  recentActiveText: recentActiveText,
                  phone: p.phone || '',
                  wechatId: p.wechat_id || p.wechatId || '',
                  douyinId: p.douyin_id || p.douyinId || '',
                  pilotCode: p.pilot_code || p.pilotCode || '',
                  company: p.company || '',
                  position: p.position || '',
                  likeCount: p.like_count || p.likeCount || 0,
                  likedByMe: !!(p.liked_by_me || p.likedByMe),
                  isVipSlot: !!(p.is_vip_slot),
                  vipRadiusKm: p.vip_radius_km || 0,
                  vipLabel: p.vip_label || '',
                  latitude: p.latitude != null ? p.latitude : (latitude != null ? latitude : 0),
                  longitude: p.longitude != null ? p.longitude : (longitude != null ? longitude : 0),
                  score: score,
                  licenseUrl: p.license_url || p.licenseUrl || '',
                  channelsId: p.channels_id || p.channelsId || '',
                  isNew: !!(p.isNew || p.is_new),
                  licenseStatusClass: licenseStatusClass,
                  roleLabel: roleLabel,
                  institutionId: p.institution_id || p.institutionId || '',
                  workMu: p.work_mu ?? p.workMu ?? null,
                  workKg: p.work_kg ?? p.workKg ?? null,
                  droneImages: p.drone_images || p.droneImages || [],
                };
                pilots.push(item);
              }
            }
            const hasMore = !!(response.has_more);
            const result: NearbyPilotsResult = { pilots, hasMore };
            resolve(result);
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          const result: NearbyPilotsResult = { pilots: [], hasMore: false };
          resolve(result);
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 飞手联系方式 ============

export interface PilotContact {
  phone: string;
  wechatId: string;
}

export async function fetchPilotContact(openid: string, token?: string): Promise<PilotContact> {
  return new Promise<PilotContact>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles/${openid}/contact`;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          reject(err);
          return;
        }
        if (data.result) {
          try {
            const response: Record<string, string> = JSON.parse(data.result as string);
            resolve({
              phone: response['phone'] || '',
              wechatId: response['wechat_id'] || response['wechatId'] || ''
            });
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve({ phone: '', wechatId: '' });
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 最新任务 ============

// 任务类型中文映射
const TASK_CATEGORY_MAP: Record<string, string> = {
  'hoisting': '吊运',
  'inspection': '巡检',
  'mapping': '测绘',
  'plant_protection': '植保',
  'emergency': '应急',
  'logistics': '物流',
  'aerial_media': '航拍',
  'security': '安防',
  'construction': '施工',
  'monitoring': '监测',
  'education': '教育',
  'exploration': '勘探',
  'remote_sensing': '遥感',
  'entertainment': '娱乐',
  'lift_pv': '吊运-光伏',
  'lift_material': '吊运-建筑材料',
  'lift_wood': '吊运-木材',
  'inspection_mapping': '巡检/测绘',
  'crop_spraying': '植保喷洒',
  'mountain_transport': '高山运输',
  'others': '其他'
};

function mapTaskCategory(category: string): string {
  return TASK_CATEGORY_MAP[category] || category || '其他';
}

// 距离标签映射
const DISTANCE_LABELS: Record<string, string> = {
  'lt_200m': '<200m',
  '200_500m': '200-500m',
  '500_1000m': '500-1000m',
  '1_4km': '1-4km',
  'gt_4km': '>4km'
};

// 垂直落差标签映射
const VERTICAL_DROP_LABELS: Record<string, string> = {
  'lt_50m': '<50m',
  '50_150m': '50-150m',
  'gt_150m': '>150m'
};

// 载重标签映射
const PAYLOAD_LABELS: Record<string, string> = {
  'lt_100kg': '<100kg',
  '100_300kg': '100-300kg',
  '300_600kg': '300-600kg',
  'gt_600kg': '>600kg'
};

function mapDistanceLabel(label: string): string {
  return DISTANCE_LABELS[label] || label || '';
}

function mapVerticalDropLabel(label: string): string {
  if (!label) return '';
  return VERTICAL_DROP_LABELS[label] || label;
}

function mapPayloadLabel(label: string): string {
  if (!label) return '';
  return PAYLOAD_LABELS[label] || label;
}

export interface OrderItem {
  orderId: string;
  publisherOpenid: string;
  taskCategory: string;
  taskCategoryDisplay: string;
  distanceText: string;
  distanceLabel: string;
  verticalDrop: number;
  verticalDropLabel: string;
  payloadKg: number;
  payloadLabel: string;
  totalOrders: number;
  status: string;
  createdAt: string;
  city: string;
  price: string;
  budgetAmount: number;
  budgetUnit: string;
  notes: string;
  profile: OrderProfile;
  customer: OrderCustomer;
  rating: OrderRating;
  expanded: boolean;
}

export interface OrderProfile {
  openid: string;
  nickname: string;
  avatarUrl: string;
  city: string;
  company: string;
  position: string;
  phone: string;
  wechatId: string;
}

export interface OrderCustomer {
  name: string;
  city: string;
  phone: string;
  company: string;
}

export interface OrderRating {
  score: number;
  comment: string;
}

interface OrdersResponse {
  items: RawOrder[];
  total: number;
}

interface RawOrder {
  order_id: string;
  task_category: string;
  task_category_display?: string;
  distance_km?: number;
  distance_label?: string;
  vertical_drop?: number;
  vertical_drop_label?: string;
  payload_kg?: number;
  payload_kg_label?: string;
  total_orders?: number;
  status: string;
  created_at?: string;
  city?: string;
  city_label?: string;
  per_trip_price?: number;
  total_price?: number;
  notes?: string;
  publisher_openid?: string;
  publisherOpenid?: string;
  profile?: RawOrderProfile;
  customer?: RawOrderCustomer;
  rating?: RawOrderRating;
  budget?: RawBudget;
  quote?: RawQuote;
  quote_params?: RawQuote;
}

interface RawOrderProfile {
  openid?: string;
  openId?: string;
  nickname?: string;
  avatar?: string;
  avatar_url?: string;
  avatarUrl?: string;
  city?: string;
  company?: string;
  position?: string;
  phone?: string;
  wechat_id?: string;
  wechatId?: string;
}

interface RawOrderCustomer {
  name?: string;
  city?: string;
  city_label?: string;
  phone?: string;
  company?: string;
}

interface RawOrderRating {
  score?: number;
  comment?: string;
}

interface RawBudget {
  amount?: number;
  unit?: string;
}

interface RawQuote {
  task_category?: string;
  task_category_display?: string;
  distance_km?: number;
  distance_label?: string;
  vertical_drop?: number;
  vertical_drop_label?: string;
  payload_kg?: number;
  payload_kg_label?: string;
  total_orders?: number;
  total_orders_label?: string;
  city?: string;
  city_label?: string;
  total_price?: number;
  per_trip_price?: number;
}

export async function fetchPublicOrders(): Promise<OrderItem[]> {
  return new Promise<OrderItem[]>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/orders/public`;
    console.info('【接口请求】url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: [{ 'Content-Type': 'application/json' }],
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchPublicOrders:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchPublicOrders:', data.result as string);
          try {
            const response = JSON.parse(data.result as string) as OrdersResponse;
            const orders: OrderItem[] = [];
            if (response.items) {
              for (let i = 0; i < response.items.length; i++) {
                const o = response.items[i];
                // 优先使用 quote_params，其次 quote
                const quote = o.quote_params || o.quote;
                const profile = o.profile;
                const customer = o.customer;
                const rating = o.rating;
                const budget = o.budget;
                // 任务类型显示
                const taskCategoryDisplay = quote?.task_category_display
                  || o.task_category_display
                  || mapTaskCategory(o.task_category);
                // 距离
                const distanceKm = quote?.distance_km ?? o.distance_km;
                const distanceLabelRaw = quote?.distance_label || o.distance_label || '';
                const distanceLabel = mapDistanceLabel(distanceLabelRaw);
                const distanceText = distanceKm ? `${distanceKm}km` : distanceLabel;
                // 垂直落差
                const verticalDrop = quote?.vertical_drop ?? o.vertical_drop ?? 0;
                const verticalDropLabelRaw = quote?.vertical_drop_label || o.vertical_drop_label || '';
                const verticalDropLabel = mapVerticalDropLabel(verticalDropLabelRaw) || (verticalDrop ? `${verticalDrop}m` : '');
                // 单次载重
                const payloadKg = quote?.payload_kg ?? o.payload_kg ?? 0;
                const payloadLabelRaw = quote?.payload_kg_label || o.payload_kg_label || '';
                const payloadLabel = mapPayloadLabel(payloadLabelRaw) || (payloadKg ? `${payloadKg}kg` : '');
                // 总单数
                const totalOrders = quote?.total_orders ?? o.total_orders ?? 0;
                // 预算
                const budgetAmount = budget?.amount ?? quote?.total_price ?? o.total_price ?? 0;
                const budgetUnit = budget?.unit || 'total';
                // 任务预算
                const price = budgetAmount ? `¥${budgetAmount}` : '';
                // 城市
                const city = quote?.city_label || quote?.city || o.city_label || o.city || '';
                const item: OrderItem = {
                  orderId: o.order_id,
                  publisherOpenid: o.publisher_openid || o.publisherOpenid || '',
                  taskCategory: mapTaskCategory(o.task_category),
                  taskCategoryDisplay: taskCategoryDisplay,
                  distanceText: distanceText,
                  distanceLabel: distanceLabel,
                  verticalDrop: verticalDrop,
                  verticalDropLabel: verticalDropLabel,
                  payloadKg: payloadKg,
                  payloadLabel: payloadLabel,
                  totalOrders: totalOrders,
                  status: o.status || 'pending',
                  createdAt: o.created_at || '',
                  city: city,
                  price: price,
                  budgetAmount: budgetAmount,
                  budgetUnit: budgetUnit,
                  notes: o.notes || '',
                  profile: {
                    openid: profile?.openid || profile?.openId || '',
                    nickname: profile?.nickname || '匿名',
                    avatarUrl: profile?.avatar_url || profile?.avatarUrl || profile?.avatar || 'https://wetofly.com/data/image/avatar_placeholder.webp',
                    city: profile?.city || '',
                    company: profile?.company || '',
                    position: profile?.position || '',
                    phone: profile?.phone || '',
                    wechatId: profile?.wechat_id || profile?.wechatId || ''
                  },
                  customer: {
                    name: customer?.name || '',
                    city: customer?.city_label || customer?.city || '',
                    phone: customer?.phone || '',
                    company: customer?.company || ''
                  },
                  rating: {
                    score: rating?.score ?? 0,
                    comment: rating?.comment || ''
                  },
                  expanded: false
                };
                orders.push(item);
              }
            }
            resolve(orders);
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve([]);
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 华为账号Token兑换 ============

export interface HuaweiTokenResponse {
  openid: string;
  token: string;
  expire_at: string;
  unionid: string;
}

export async function exchangeHuaweiToken(openId: string, unionId: string): Promise<HttpResponse<HuaweiTokenResponse>> {
  return new Promise<HttpResponse<HuaweiTokenResponse>>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/huawei/login`;
    console.info('【接口请求】exchangeHuaweiToken url:', url);

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: [{ 'Content-Type': 'application/json' }],
        extraData: { openid: openId, unionid: unionId },
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】exchangeHuaweiToken:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口响应】exchangeHuaweiToken:', JSON.stringify(data.result));
        try {
          const resp = JSON.parse(data.result as string) as HuaweiTokenResponse;
          resolve({ code: data.responseCode, data: resp });
        } catch (parseErr) {
          reject(parseErr);
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 个人资料 ============

export interface ProfileForm {
  openid: string;
  nickname: string;
  avatarUrl: string;
  phone: string;
  wechatId: string;
  douyinId: string;
  channelsId: string;
  company: string;
  position: string;
  city: string;
  userRole: string;
  pilotCode: string;
  droneModels: string[];
  droneModel: string;
  businessScope: string[];
  licenseUrl: string;
  licenseType: string;
  licenseStatus: string;
  licenseVerified: boolean;
  licenseRejected: boolean;
  licenseReason: string;
  orgCode: string;
  institutionId: string;
  workMu: number | null;
  workKg: number | null;
  droneImages: string[];
}

export async function fetchProfile(openid: string, token?: string): Promise<ProfileForm | null> {
  return new Promise<ProfileForm | null>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles/${openid}`;
    console.info('【接口请求】fetchProfile url:', url, ' token:', token ? '有' : '无');
    const reqHeaders: Record<string, string> = token
      ? { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token }
      : { 'Content-Type': 'application/json' };
    console.info('【DEBUG fetchProfile header:', JSON.stringify(reqHeaders));
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: reqHeaders,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchProfile:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchProfile:', data.result as string);
          try {
            const p = JSON.parse(data.result as string) as Record<string, Object>;
            const getStr = (key: string, fallback: string): string => {
              const v = p[key];
              return typeof v === 'string' ? v : fallback;
            };
            const getArr = (key: string): string[] => {
              const v = p[key];
              if (Array.isArray(v)) {
                const arr = v as string[];
                return arr.filter(s => typeof s === 'string') as string[];
              }
              if (typeof v === 'string') return v.split('/').map(s => s.trim()).filter(s => s);
              return [];
            };
            const getNum = (key: string): number | null => {
              const v = p[key];
              return typeof v === 'number' ? v : null;
            };
            const profile: ProfileForm = {
              openid: getStr('openid', getStr('openId', openid)),
              nickname: getStr('nickname', ''),
              avatarUrl: getStr('avatar_url', getStr('avatarUrl', '')),
              phone: getStr('phone', ''),
              wechatId: getStr('wechat_id', getStr('wechatId', '')),
              douyinId: getStr('douyin_id', getStr('douyinId', '')),
              channelsId: getStr('channels_id', getStr('channelsId', '')),
              company: getStr('company', ''),
              position: getStr('position', ''),
              city: getStr('city', ''),
              userRole: getStr('user_role', getStr('userRole', 'employer')),
              pilotCode: getStr('pilotCode', getStr('pilot_code', '')),
              droneModels: getArr('droneModel'),
              droneModel: getArr('droneModel').join('/'),
              businessScope: getArr('businessScope'),
              licenseUrl: getStr('license_url', getStr('licenseUrl', '')),
              licenseType: getStr('license_type', getStr('licenseType', '')),
              licenseStatus: getStr('license_status', getStr('licenseStatus', '')),
              licenseVerified: !!(p['license_verified'] || p['licenseVerified']),
              licenseRejected: isRejected(getStr('license_status', getStr('licenseStatus', ''))),
              licenseReason: getStr('license_reason', getStr('licenseReason', '')),
              orgCode: getStr('institution_id', getStr('institutionId', getStr('org_code', ''))),
              institutionId: getStr('institution_id', getStr('institutionId', getStr('org_code', ''))),
              workMu: getNum('workStatsMu') ?? getNum('work_stats_mu'),
              workKg: getNum('workStatsKg') ?? getNum('work_stats_kg'),
              droneImages: getArr('droneImages'),
            };
            resolve(profile);
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve(null);
        }
        httpRequest.destroy();
      }
    );
  });
}

export async function updateProfile(payload: ProfileForm, token?: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles`;
    console.info('【接口请求】updateProfile url:', url, ' token:', token ? '有' : '无');
    const reqHeaders: Record<string, string> = token
      ? { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token }
      : { 'Content-Type': 'application/json' };
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.PUT,
        header: reqHeaders,
        extraData: payload,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】updateProfile:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】updateProfile:', data.result as string);
        if (data.responseCode === 200 || data.responseCode === 201) {
          resolve();
        } else {
          reject(new Error('更新失败'));
        }
        httpRequest.destroy();
      }
    );
  });
}

export interface UploadAvatarResult {
  url: string;
}

export async function uploadAvatar(buffer: ArrayBuffer, token?: string): Promise<UploadAvatarResult> {
  const authToken = token || '';

  return new Promise<UploadAvatarResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/upload/avatar`;
    const boundary = '----AvatarBoundary' + Date.now();

    const headerParts: string[] = [];
    headerParts.push(`--${boundary}\r\n`);
    headerParts.push('Content-Disposition: form-data; name="file"; filename="avatar.jpg"\r\n');
    headerParts.push('Content-Type: image/jpeg\r\n\r\n');

    const headerStr = headerParts.join('');
    const footerStr = `\r\n--${boundary}--\r\n`;
    const headerBytes = new Uint8Array(headerStr.length);
    for (let i = 0; i < headerStr.length; i++) {
      headerBytes[i] = headerStr.charCodeAt(i);
    }
    const footerBytes = new Uint8Array(footerStr.length);
    for (let i = 0; i < footerStr.length; i++) {
      footerBytes[i] = footerStr.charCodeAt(i);
    }

    const totalSize = headerBytes.length + buffer.byteLength + footerBytes.length;
    const bodyBuffer = new ArrayBuffer(totalSize);
    const bodyView = new Uint8Array(bodyBuffer);
    let offset = 0;
    bodyView.set(headerBytes, offset);
    offset += headerBytes.length;
    const bufferView = new Uint8Array(buffer);
    bodyView.set(bufferView, offset);
    offset += buffer.byteLength;
    bodyView.set(footerBytes, offset);

    const headers: Record<string, string> = {
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Authorization': `Bearer ${authToken}`
    };

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: bodyBuffer,
        connectTimeout: 15000,
        readTimeout: 15000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【头像上传失败】', JSON.stringify(err));
          reject(new Error('上传失败'));
          return;
        }
        console.info('【头像上传响应】', data.result as string);
        try {
          const resultObj = JSON.parse(data.result as string) as Record<string, string>;
          resolve({ url: resultObj.url || '' });
        } catch (parseErr) {
          reject(new Error('解析响应失败'));
        }
        httpRequest.destroy();
      }
    );
  });
}

function parseArrayField(value: string | string[] | undefined): string[] {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  return value.split('/').map(s => s.trim()).filter(s => s);
}

// ============ 认证用户列表 ============

export interface CertifiedUser {
  openid: string;
  nickname: string;
  avatar: string;
  city: string;
  userRole: string;
  roleLabel: string;
  licenseType: string;
  licenseStatus: string;
  licenseStatusClass: string;
  pilotCode: string;
  company: string;
  position: string;
  droneModel: string;
  businessScope: string[];
  businessScopeText: string;
  recentActiveText: string;
  likeCount: number;
  likedByMe: boolean;
  phone: string;
  wechatId: string;
  latitude: number;
  longitude: number;
  channelsId: string;
  workMu: number | null;
  workKg: number | null;
  droneImages: string[];
  isVipSlot: boolean;
  vipLabel: string;
  isNew: boolean;
}

export interface TagCounts {
  all: number;
  pilot: number;
  employer: number;
  company: number;
  position: number;
  drone_model: number;
  caac: number;
  utc: number;
  business_植保: number;
  business_飞防: number;
  business_吊运: number;
  business_巡检: number;
  business_测绘: number;
  business_教学: number;
  business_应急: number;
  liked_by_me: number;
}

export interface CertifiedProfilesResult {
  items: CertifiedUser[];
  count: number;
  hasMore: boolean;
  tag_counts?: TagCounts;
}

export interface CertifiedProfilesParams {
  limit: number;
  skip: number;
  search?: string;
  liked_by_me?: boolean;
  role?: string;
  tag?: string;
}

interface RawCertifiedLocation {
  coordinates?: number[];
}

interface RawCertifiedProfile {
  openid?: string;
  openId?: string;
  open_id?: string;
  nickname?: string;
  avatarUrl?: string;
  avatar_url?: string;
  city?: string;
  userRole?: string;
  user_role?: string;
  licenseType?: string;
  license_type?: string;
  licenseStatus?: string;
  license_status?: string;
  pilotCode?: string;
  pilot_code?: string;
  company?: string;
  position?: string;
  droneModel?: string;
  drone_model?: string;
  businessScope?: string[];
  business_scope?: string[];
  likeCount?: number;
  like_count?: number;
  likedByMe?: boolean;
  liked_by_me?: boolean;
  phone?: string;
  wechatId?: string;
  wechat_id?: string;
  latitude?: number;
  longitude?: number;
  location?: RawCertifiedLocation;
  channelsId?: string;
  channels_id?: string;
  workMu?: number;
  work_mu?: number;
  workKg?: number;
  work_kg?: number;
  droneImages?: string[];
  drone_images?: string[];
  isVipSlot?: boolean;
  is_vip_slot?: boolean;
  vipLabel?: string;
  vip_label?: string;
  isNew?: boolean;
  is_new?: boolean;
  daysSinceUpdate?: string;
  days_since_update?: string;
  recentActiveDays?: string;
  recent_active_days?: string;
}

interface RawCertifiedResponse {
  items?: RawCertifiedProfile[];
  count?: number;
  has_more?: boolean;
}

function getRawStr(value: string | undefined, fallback: string): string {
  return value !== undefined ? value : fallback;
}

function getRawNum(value: number | undefined): number | null {
  return value !== undefined ? value : null;
}

export async function fetchCertifiedProfiles(params: CertifiedProfilesParams, token?: string): Promise<CertifiedProfilesResult> {
  return new Promise<CertifiedProfilesResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const queryParts: string[] = [];
    if (params.limit !== undefined) queryParts.push(`limit=${params.limit}`);
    if (params.skip !== undefined) queryParts.push(`skip=${params.skip}`);
    if (params.search) queryParts.push(`search=${encodeURIComponent(params.search)}`);
    if (params.liked_by_me) queryParts.push('liked_by_me=true');
    if (params.role && params.role !== 'all') queryParts.push(`role=${params.role}`);
    if (params.tag) queryParts.push(`tag=${encodeURIComponent(params.tag)}`);
    const query = queryParts.length > 0 ? '?' + queryParts.join('&') : '';
    const url = `${BASE_URL}/api/profiles/certified${query}`;
    console.info('【接口请求】fetchCertifiedProfiles url:', url);
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchCertifiedProfiles:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchCertifiedProfiles:', data.result as string);
          try {
            const res = JSON.parse(data.result as string) as RawCertifiedResponse;
            const items: CertifiedUser[] = [];
            if (res.items) {
              for (let i = 0; i < res.items.length; i++) {
                const p = res.items[i];
                const userRole = getRawStr(p.userRole || p.user_role, 'pilot');
                const roleLabel = userRole === 'pilot' ? '飞手' : userRole === 'employer' ? '雇主' : '';
                const licenseType = (getRawStr(p.licenseType || p.license_type, '')).toLowerCase();
                const licenseStatus = getRawStr(p.licenseStatus || p.license_status, 'PASS');
                const businessScopeArr: string[] = [];
                const bsRaw = p.businessScope || p.business_scope;
                if (bsRaw) {
                  for (let j = 0; j < bsRaw.length; j++) {
                    const s = bsRaw[j];
                    if (s !== undefined) {
                      businessScopeArr.push(s);
                    }
                  }
                }
                const recentActiveDaysRaw = getRawStr(p.daysSinceUpdate || p.days_since_update, '');
                let recentActiveText = '';
                if (recentActiveDaysRaw !== '') {
                  const days = parseInt(recentActiveDaysRaw, 10);
                  if (!isNaN(days)) {
                    recentActiveText = days === 0 ? '今日' : `${days} 天前`;
                  }
                }
                const droneModelRaw = getRawStr(p.droneModel || p.drone_model, '');
                const coords = p.location?.coordinates || [];
                const avatarStr = getRawStr(p.avatarUrl || p.avatar_url, 'https://wetofly.com/data/image/avatar_placeholder.webp');
                const droneImagesRaw = p.droneImages || p.drone_images;
                const droneImagesArr: string[] = [];
                if (droneImagesRaw) {
                  for (let j = 0; j < droneImagesRaw.length; j++) {
                    const img = droneImagesRaw[j];
                    if (img !== undefined) {
                      droneImagesArr.push(img);
                    }
                  }
                }
                items.push({
                  openid: getRawStr(p.openid || p.openId || p.open_id, ''),
                  nickname: getRawStr(p.nickname, '匿名飞手'),
                  avatar: avatarStr,
                  city: getRawStr(p.city, ''),
                  userRole: userRole,
                  roleLabel: roleLabel,
                  licenseType: licenseType,
                  licenseStatus: licenseStatus,
                  licenseStatusClass: licenseStatus === 'PASS' ? 'status-success' : '',
                  pilotCode: getRawStr(p.pilotCode || p.pilot_code, ''),
                  company: getRawStr(p.company, ''),
                  position: getRawStr(p.position, ''),
                  droneModel: droneModelRaw || '--',
                  businessScope: businessScopeArr,
                  businessScopeText: businessScopeArr.join(' · '),
                  recentActiveText: recentActiveText,
                  likeCount: getRawNum(p.likeCount || p.like_count) || 0,
                  likedByMe: !!(p.likedByMe || p.liked_by_me),
                  phone: getRawStr(p.phone, ''),
                  wechatId: getRawStr(p.wechatId || p.wechat_id, ''),
                  latitude: coords[1] || getRawNum(p.latitude) || 0,
                  longitude: coords[0] || getRawNum(p.longitude) || 0,
                  channelsId: getRawStr(p.channelsId || p.channels_id, ''),
                  workMu: getRawNum(p.workMu || p.work_mu),
                  workKg: getRawNum(p.workKg || p.work_kg),
                  droneImages: droneImagesArr,
                  isVipSlot: !!(p.isVipSlot || p.is_vip_slot),
                  vipLabel: getRawStr(p.vipLabel || p.vip_label, ''),
                  isNew: !!(p.isNew || p.is_new)
                });
              }
            }
            resolve({
              items,
              count: res.count || 0,
              hasMore: !!(res.has_more)
            });
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve({ items: [], count: 0, hasMore: false });
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 认证用户标签 ============

export interface CertifiedTag {
  key: string;
  label: string;
  count: number | null;
}

export interface CertifiedTagsResult {
  tags: CertifiedTag[];
}

export async function fetchCertifiedTags(token?: string): Promise<CertifiedTagsResult> {
  return new Promise<CertifiedTagsResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles/certified/tags`;
    console.info('【接口请求】fetchCertifiedTags url:', url);
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchCertifiedTags:', JSON.stringify(err));
          reject(err);
          return;
        }
        if (data.result) {
          console.info('【接口返回】fetchCertifiedTags:', data.result as string);
          try {
            const res: CertifiedTagsResult = JSON.parse(data.result as string);
            resolve({
              tags: res.tags || []
            });
          } catch (parseErr) {
            reject(parseErr);
          }
        } else {
          resolve({ tags: [] });
        }
        httpRequest.destroy();
      }
    );
  });
}

// ============ 访问上报 ============

export async function reportVisit(code: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/wx/visit`;
    console.info('【接口请求】reportVisit url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: [{ 'Content-Type': 'application/json' }],
        extraData: { openid: code },
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】reportVisit:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】reportVisit:', data.result as string);
        httpRequest.destroy();
        resolve();
      }
    );
  });
}

function isRejected(status: string): boolean {
  return status.includes('未通过') || status.includes('不通过');
}

// ============ 点赞功能 ============

export interface LikeResult {
  like_count: number;
  liked_by_me: boolean;
}

export async function likeProfile(openid: string, token: string): Promise<LikeResult> {
  return new Promise<LikeResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles/${openid}/like`;
    console.info('【接口请求】likeProfile url:', url);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    };
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】likeProfile:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】likeProfile:', data.result as string);
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res: Record<string, Object> = JSON.parse(data.result as string);
            const likeCountVal = res['like_count'];
            const finalCount = typeof likeCountVal === 'number' ? likeCountVal : (typeof likeCountVal === 'string' ? parseInt(likeCountVal as string, 10) : 0);
            resolve({
              like_count: finalCount,
              liked_by_me: true
            });
          } catch (e) {
            console.error('【likeProfile解析失败】', JSON.stringify(e));
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

// ============ 今日有空（Standby）===========

export interface StandbyProfile {
  openid: string;
  nickname: string;
  avatarUrl: string;
  city: string;
  isNew: boolean;
  phone?: string;
  wechatId?: string;
  douyinId?: string;
  company?: string;
  position?: string;
  droneModel?: string;
  businessScopeText?: string;
  recentActiveText?: string;
  licenseType?: string;
  licenseStatus?: string;
  pilotCode?: string;
  userRole?: string;
  roleLabel?: string;
}

export interface StandbyItem {
  openid: string;
  joined_at: string;
  profile: StandbyProfile;
  likeCount: number;
  viewCount: number;
}

export interface StandbyResult {
  items: StandbyItem[];
  count: number;
  is_joined: boolean;
}

export async function fetchStandby(): Promise<StandbyResult> {
  return new Promise<StandbyResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/standby`;
    console.info('【接口请求】fetchStandby url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchStandby:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】fetchStandby:', data.result as string);
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res: Record<string, Object> = JSON.parse(data.result as string);
            const rawItems: Record<string, Object>[] = (res['items'] as Record<string, Object>[]) || [];
            const items: StandbyItem[] = rawItems.map((item: Record<string, Object>) => {
              const profileRaw: Record<string, Object> = (item['profile'] as Record<string, Object>) || {};
              // 优先用API返回的recentActiveText，否则从updated_at计算
              let recentActiveText = (profileRaw['recentActiveText'] as string) || (profileRaw['recent_active_text'] as string) || '';
              if (!recentActiveText) {
                const updatedAt = (profileRaw['updated_at'] as string) || (profileRaw['updatedAt'] as string) || '';
                if (updatedAt) {
                  const updatedMs = new Date(updatedAt).getTime();
                  if (!isNaN(updatedMs)) {
                    const nowMs = Date.now();
                    const diffMs = nowMs - updatedMs;
                    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
                    recentActiveText = diffDays === 0 ? '今天' : `${diffDays} 天前`;
                  }
                }
              }
              const p: StandbyProfile = {
                openid: (profileRaw['openid'] as string) || '',
                nickname: (profileRaw['nickname'] as string) || '',
                avatarUrl: (profileRaw['avatarUrl'] as string) || (profileRaw['avatar_url'] as string) || '',
                city: (profileRaw['city'] as string) || '',
                isNew: (profileRaw['isNew'] as boolean) || (profileRaw['is_new'] as boolean) || false,
                phone: (profileRaw['phone'] as string) || '',
                wechatId: (profileRaw['wechatId'] as string) || (profileRaw['wechat_id'] as string) || '',
                company: (profileRaw['company'] as string) || '',
                position: (profileRaw['position'] as string) || '',
                droneModel: (profileRaw['droneModel'] as string) || (profileRaw['drone_model'] as string) || '',
                businessScopeText: (profileRaw['businessScopeText'] as string) || (profileRaw['business_scope_text'] as string) || '',
                recentActiveText: recentActiveText || '--',
                licenseType: (profileRaw['licenseType'] as string) || (profileRaw['license_type'] as string) || '',
                licenseStatus: (profileRaw['licenseStatus'] as string) || (profileRaw['license_status'] as string) || '',
                pilotCode: (profileRaw['pilotCode'] as string) || (profileRaw['pilot_code'] as string) || '',
                userRole: (profileRaw['userRole'] as string) || (profileRaw['user_role'] as string) || '',
                roleLabel: (profileRaw['roleLabel'] as string) || ''
              };
              const si: StandbyItem = {
                openid: (item['openid'] as string) || '',
                joined_at: (item['joined_at'] as string) || '',
                profile: p,
                likeCount: (item['likeCount'] as number) || (item['like_count'] as number) || 0,
                viewCount: (item['viewCount'] as number) || (item['view_count'] as number) || 0
              };
              return si;
            });
            resolve({
              items: items,
              count: (res['count'] as number) || 0,
              is_joined: (res['is_joined'] as boolean) || false
            });
          } catch (e) {
            console.error('【fetchStandby解析失败】', JSON.stringify(e));
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

export async function joinStandby(token: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/standby`;
    console.info('【接口请求】joinStandby url:', url);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    };
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】joinStandby:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】joinStandby:', data.result as string);
        if (data.responseCode === 200 || data.responseCode === 201) {
          resolve();
        } else {
          reject(new Error('加入等待失败'));
        }
        httpRequest.destroy();
      }
    );
  });
}

export async function leaveStandby(token: string): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/standby`;
    console.info('【接口请求】leaveStandby url:', url);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    };
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.DELETE,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】leaveStandby:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】leaveStandby:', data.result as string);
        if (data.responseCode === 200 || data.responseCode === 204) {
          resolve();
        } else {
          reject(new Error('取消等待失败'));
        }
        httpRequest.destroy();
      }
    );
  });
}

export async function unlikeProfile(openid: string, token: string): Promise<LikeResult> {
  return new Promise<LikeResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles/${openid}/like`;
    console.info('【接口请求】unlikeProfile url:', url);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    };
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.DELETE,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        console.info('【unlikeProfile响应码】', data.responseCode);
        if (err) {
          console.error('【接口错误】unlikeProfile:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】unlikeProfile:', data.result as string);
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res: Record<string, Object> = JSON.parse(data.result as string);
            const likeCountVal = res['like_count'];
            const finalCount = typeof likeCountVal === 'number' ? likeCountVal : (typeof likeCountVal === 'string' ? parseInt(likeCountVal as string, 10) : 0);
            resolve({
              like_count: finalCount,
              liked_by_me: false
            });
          } catch (e) {
            console.error('【unlikeProfile解析失败】', JSON.stringify(e));
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

// ============ Push Token 注册 ============

export interface PushTokenResponse {
  success: boolean;
  message: string;
}

export async function registerPushToken(pushToken: string, token?: string): Promise<PushTokenResponse> {
  return new Promise<PushTokenResponse>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/push/token`;
    console.info('【接口请求】registerPushToken:', url, ' token:', token ? '有' : '无');

    const headers: Record<string, string> = token
      ? { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token }
      : { 'Content-Type': 'application/json' };
    console.info('【DEBUG registerPushToken header:', JSON.stringify(headers));

    const body = JSON.stringify({ push_token: pushToken });

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】registerPushToken:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】registerPushToken:', data.result as string);
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string') {
          try {
            const res = JSON.parse(data.result as string) as PushTokenResponse;
            resolve(res);
          } catch (e) {
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

export async function unregisterPushToken(token?: string): Promise<PushTokenResponse> {
  return new Promise<PushTokenResponse>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/push/token`;
    console.info('【接口请求】unregisterPushToken:', url);

    const header: HttpHeader[] = [{ key: 'Content-Type', value: 'application/json' }];
    if (token) {
      header.push({ key: 'Authorization', value: `Bearer ${token}` });
    }

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.DELETE,
        header: header,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】unregisterPushToken:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】unregisterPushToken:', data.result as string);
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string') {
          try {
            const res = JSON.parse(data.result as string) as PushTokenResponse;
            resolve(res);
          } catch (e) {
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

// ============ 城市覆盖 ============

export interface CityCoverageSummary {
  total_cities: number;
  lit_cities: number;
  unlit_cities: number;
  coverage_pct: number;
}

export interface CityItem {
  city: string;
  province: string;
  lit: boolean;
  pilot_count: number;
}

export interface CityCoverageResponse {
  summary: CityCoverageSummary;
  cities: CityItem[];
}

export interface ReferralLeaderboardItem {
  openid: string;
  nickname: string;
  avatar_url: string;
  referral_count: number;
}

export interface ReferralLeaderboardResult {
  leaderboard: ReferralLeaderboardItem[];
  my_rank: number;
  my_count: number;
}

export async function fetchCityCoverage(): Promise<CityCoverageResponse> {
  return new Promise<CityCoverageResponse>((resolve, reject) => {
    const httpRequest = http.createHttp();
    httpRequest.request(
      `${BASE_URL}/api/cities/pilot-coverage`,
      {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchCityCoverage:', JSON.stringify(err));
          reject(err);
          return;
        }
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string') {
          try {
            const res = JSON.parse(data.result as string) as CityCoverageResponse;
            resolve(res);
          } catch (e) {
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

export async function fetchReferralLeaderboard(limit: number = 50): Promise<ReferralLeaderboardResult> {
  const token = AuthService.getAuthToken();
  return new Promise<ReferralLeaderboardResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/referral/leaderboard?limit=${limit}`;
    console.info('【接口请求】fetchReferralLeaderboard url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchReferralLeaderboard:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】fetchReferralLeaderboard:', data.result as string);
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res = JSON.parse(data.result as string) as Record<string, Object>;
            const list: ReferralLeaderboardItem[] = (res['leaderboard'] as ReferralLeaderboardItem[]) || (res['list'] as ReferralLeaderboardItem[]) || [];
            const myRank = (res['my_rank'] as number) || 0;
            const myCount = (res['my_count'] as number) || 0;
            resolve({ leaderboard: list, my_rank: myRank, my_count: myCount });
          } catch (e) {
            reject(err);
          }
        } else {
          reject(err);
        }
      }
    );
  });
}

export async function fetchPublicProfile(openid: string): Promise<Record<string, Object>> {
  const token = AuthService.getAuthToken();
  return new Promise<Record<string, Object>>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/profiles/${openid}/public`;
    console.info('【接口请求】fetchPublicProfile url:', url);
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchPublicProfile:', JSON.stringify(err));
          reject(err);
          return;
        }
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res = JSON.parse(data.result as string) as Record<string, Object>;
            console.info('【fetchPublicProfile返回】', JSON.stringify(res));
            resolve(res as Record<string, Object>);
          } catch (e) {
            console.error('【fetchPublicProfile解析失败】', JSON.stringify(e));
            reject(err);
          }
        } else {
          console.error('【fetchPublicProfile无数据】');
          reject(err);
        }
      }
    );
  });
}

// ============ 联系记录 ============

export interface ContactLogActor {
  openid?: string;
  nickname?: string;
  avatar?: string;
}

export interface ContactLogItem {
  openid?: string;
  actor?: ContactLogActor;
  target?: ContactLogActor;
  action_label?: string;
  created_at?: string;
}

export interface ContactLogResult {
  items: ContactLogItem[];
  count: number;
}

export interface ContactLogParams {
  limit?: number;
  skip?: number;
}

export async function fetchContactLogFeed(params: ContactLogParams): Promise<ContactLogResult> {
  const limit = params.limit ?? 30;
  const skip = params.skip ?? 0;
  const token = AuthService.getAuthToken();
  return new Promise<ContactLogResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/contact-log/feed?limit=${limit}&skip=${skip}`;
    console.info('【接口请求】fetchContactLogFeed url:', url);
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchContactLogFeed:', JSON.stringify(err));
          reject(err);
          return;
        }
        httpRequest.destroy();
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res = JSON.parse(data.result as string) as ContactLogResult;
            console.info('【接口返回】fetchContactLogFeed:', JSON.stringify(res));
            resolve(res);
          } catch (e) {
            console.error('【fetchContactLogFeed解析失败】', JSON.stringify(e));
            reject(err);
          }
        } else {
          console.error('【fetchContactLogFeed无数据】');
          reject(err);
        }
      }
    );
  });
}

// 奖励位资料卡片
export interface RewardProfileCard {
  avatarUrl: string;
  nickname: string;
  phone?: string;
  wechatId?: string;
  douyinId?: string;
  city?: string;
  company?: string;
  position?: string;
  droneModel?: string;
  licenseType?: string;
  userRole?: string;
  businessScope?: string[];
  viewCount?: number;
  likeCount?: number;
  channelsId?: string;
  institutionId?: string;
  licenseUrl?: string;
  workMu?: number;
  workKg?: number;
  droneImages?: string[];
}

// 奖励位认领结果（匹配后端 RewardClaimResponse）
export interface RewardSlotClaimResult {
  claimed: boolean;
  expiresAt?: string;
  remainingSeconds: number;
  slotKey?: string;
  slot: string;
  profileCard?: RewardProfileCard;
}

// 领取奖励位（激励视频看完后调用）
export async function claimRewardSlot(): Promise<RewardSlotClaimResult> {
  return new Promise<RewardSlotClaimResult>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/carousel/reward/claim`;
    const token = AuthService.getAuthToken();

    console.info('【接口请求】claimRewardSlot url:', url);

    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.POST,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】claimRewardSlot:', JSON.stringify(err));
          reject(err);
          return;
        }
        httpRequest.destroy();
        console.info('【claimRewardSlot】responseCode=' + data.responseCode + ', result=' + JSON.stringify(data.result));
        if (data.result && typeof data.result === 'string' && data.result.length > 0) {
          try {
            const res = JSON.parse(data.result as string) as RewardSlotClaimResult;
            console.info('【接口返回】claimRewardSlot:', JSON.stringify(res));
            resolve(res);
          } catch (e) {
            console.error('【claimRewardSlot解析失败】', JSON.stringify(e));
            reject(err);
          }
        } else {
          console.error('【claimRewardSlot无数据】');
          reject(err);
        }
      }
    );
  });
}

// 获取奖励位状态（检查用户是否已认领）
export async function fetchRewardSlotStatus(): Promise<RewardSlotClaimResult | null> {
  return new Promise<RewardSlotClaimResult | null>((resolve, reject) => {
    const httpRequest = http.createHttp();
    const url = `${BASE_URL}/api/carousel/reward/status`;
    const token = AuthService.getAuthToken();

    console.info('【接口请求】fetchRewardSlotStatus url:', url);

    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    httpRequest.request(
      url,
      {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      },
      (err: Error, data: http.HttpResponse) => {
        if (err) {
          console.error('【接口错误】fetchRewardSlotStatus:', JSON.stringify(err));
          reject(err);
          return;
        }
        console.info('【接口返回】fetchRewardSlotStatus:', data.result as string);
        if (data.responseCode === 200 || data.responseCode === 201) {
          try {
            const res = JSON.parse(data.result as string) as RewardSlotClaimResult;
            resolve(res);
          } catch (e) {
            console.error('【fetchRewardSlotStatus解析失败】', JSON.stringify(e));
            resolve(null);
          }
        } else {
          resolve(null);
        }
        httpRequest.destroy();
      }
    );
  });
}
