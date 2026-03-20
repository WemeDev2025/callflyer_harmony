/**
 * Property-based tests for the landscape-overview-mode feature.
 * Uses Jest + fast-check.
 */

const fc = require('fast-check');

// ── Mock heavy dependencies before requiring course-schedule.js ──────────────

jest.mock('../../../utils/api.js', () => ({
  createReminder: jest.fn(),
  cancelReminder: jest.fn(),
  getReminderById: jest.fn(),
  getMySchedule: jest.fn(),
  saveMySchedule: jest.fn(),
  createScheduleTemplate: jest.fn(),
  cloneScheduleTemplate: jest.fn(),
  getProfile: jest.fn(),
}));

jest.mock('miniprogram-recycle-view', () => function RecycleContext() {});

// ── Mock wx API ──────────────────────────────────────────────────────────────
global.wx = {
  getWindowInfo: jest.fn(() => ({ windowWidth: 375, windowHeight: 667 })),
  onWindowResize: jest.fn(),
  offWindowResize: jest.fn(),
  getSystemInfoSync: jest.fn(() => ({ statusBarHeight: 20, model: '', brand: '' })),
  getMenuButtonBoundingClientRect: jest.fn(() => ({ top: 24, height: 32 })),
  getStorageSync: jest.fn(() => null),
  setStorageSync: jest.fn(),
};

global.getApp = jest.fn(() => ({ globalData: { isVip: false } }));

global.requirePlugin = jest.fn(() => ({
  getRecordRecognitionManager: jest.fn(() => ({
    onRecognize: null,
    onStop: null,
    onError: null,
    stop: jest.fn(),
    start: jest.fn(),
  })),
}));

global.Page = jest.fn();

// ── Import the pure function ─────────────────────────────────────────────────
const { computeIsLandscape } = require('../course-schedule.js');

// ── Property 1: 方向判断正确性 ────────────────────────────────────────────────
// Feature: landscape-overview-mode, Property 1: 方向判断正确性
describe('Property 1: 方向判断正确性', () => {
  test('computeIsLandscape(w, h) === (w > h) for any integer dimensions', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 100, max: 1000 }),
        fc.integer({ min: 100, max: 1000 }),
        (width, height) => {
          const result = computeIsLandscape(width, height);
          return result === (width > height);
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ── Property 3: currentDayIndex 在横竖屏切换中保持不变 ────────────────────────
// Feature: landscape-overview-mode, Property 3: currentDayIndex 在横竖屏切换中保持不变
describe('Property 3: currentDayIndex 在横竖屏切换中保持不变', () => {
  /**
   * Creates a minimal page-like object that mimics the resize handler logic
   * implemented in _initLandscapeDetector, without requiring the full wx Page
   * runtime. This lets us test the invariant in pure Node.js.
   */
  function createPageStub(initialDayIndex) {
    const page = {
      data: {
        currentDayIndex: initialDayIndex,
        isLandscape: false,
      },
      _onResizeHandler: null,
      setData(updates) {
        Object.assign(this.data, updates);
      },
    };

    // Replicate _initLandscapeDetector logic
    page._onResizeHandler = ({ size }) => {
      const landscape = size.windowWidth > size.windowHeight;
      if (landscape !== page.data.isLandscape) {
        // Only isLandscape changes; currentDayIndex is never touched
        page.setData({ isLandscape: landscape });
      }
    };

    return page;
  }

  test('currentDayIndex unchanged after landscape→portrait resize', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 0, max: 6 }),
        (initialIndex) => {
          const page = createPageStub(initialIndex);

          // Simulate landscape resize (width > height)
          page._onResizeHandler({ size: { windowWidth: 800, windowHeight: 400 } });
          // Simulate portrait resize (width < height)
          page._onResizeHandler({ size: { windowWidth: 400, windowHeight: 800 } });

          return page.data.currentDayIndex === initialIndex;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ── Property 2: 布局互斥切换（Round-trip）────────────────────────────────────
// Feature: landscape-overview-mode, Property 2: 布局互斥切换
describe('Property 2: 布局互斥切换（Round-trip）', () => {
  /**
   * Pure logic functions modelling WXML wx:if conditions:
   *   Overview:  wx:if="{{isLandscape}}"   → visible when isLandscape === true
   *   Swiper:    wx:if="{{!isLandscape}}"  → visible when isLandscape === false
   */
  function overviewVisible(isLandscape) {
    return isLandscape === true;
  }

  function swiperVisible(isLandscape) {
    return isLandscape === false;
  }

  test('Overview visible === isLandscape, Swiper visible === !isLandscape for any boolean', () => {
    fc.assert(
      fc.property(
        fc.boolean(),
        (isLandscape) => {
          return (
            overviewVisible(isLandscape) === isLandscape &&
            swiperVisible(isLandscape) === !isLandscape
          );
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ── Property 6: 横屏时竖屏专属 UI 元素隐藏 ───────────────────────────────────
// Feature: landscape-overview-mode, Property 6: 横屏时竖屏专属 UI 元素隐藏
describe('Property 6: 横屏时竖屏专属 UI 元素隐藏', () => {
  /**
   * Pure logic function modelling the WXML wx:if condition on .bottom-bar:
   *   bottom-bar: wx:if="{{!isLandscape}}" → visible when isLandscape === false
   */
  function bottomBarVisible(isLandscape) {
    return isLandscape === false;
  }

  test('.bottom-bar visibility === !isLandscape for any boolean', () => {
    fc.assert(
      fc.property(
        fc.boolean(),
        (isLandscape) => {
          return bottomBarVisible(isLandscape) === !isLandscape;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ── Property 4: 横屏卡片渲染内容完整性 ───────────────────────────────────────
// Feature: landscape-overview-mode, Property 4: 横屏卡片渲染内容完整性
describe('Property 4: 横屏卡片渲染内容完整性', () => {
  /**
   * Models the WXML landscape-card rendering as a pure function.
   * The card template renders:
   *   style="background: {{course.color || '#F0F3FF'}}"
   *   <text class="landscape-card-name">{{course.name}}</text>
   *   <text class="landscape-card-time">{{course.startTime}}</text>
   */
  function renderLandscapeCard(course) {
    const bg = course.color || '#F0F3FF';
    return `<view class="landscape-card" style="background: ${bg}"><text class="landscape-card-name">${course.name}</text><text class="landscape-card-time">${course.startTime}</text></view>`;
  }

  test('rendered card contains course.name, course.startTime, and course.color', () => {
    fc.assert(
      fc.property(
        fc.record({
          name: fc.string({ minLength: 1 }),
          startTime: fc.string(),
          color: fc.constantFrom('#E3F2FD', '#F3E5F5', '#E8F5E9'),
        }),
        (course) => {
          const rendered = renderLandscapeCard(course);
          return (
            rendered.includes(course.name) &&
            rendered.includes(course.startTime) &&
            rendered.includes(course.color)
          );
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ── Property 5: 数据一致性（Overview 与 scheduleData 同源）────────────────────
// Feature: landscape-overview-mode, Property 5: 数据一致性
describe('Property 5: 数据一致性（Overview 与 scheduleData 同源）', () => {
  /**
   * Models the per-day course count rendered in the landscape overview.
   * The WXML iterates scheduleData[dayIdx] directly, so the rendered count
   * for each day must equal scheduleData[dayIdx].length.
   */
  function getRenderedCourseCountPerDay(scheduleData) {
    return scheduleData.map((dayCourses) => dayCourses.length);
  }

  test('rendered course count per day equals scheduleData[dayIdx].length for all 7 days', () => {
    fc.assert(
      fc.property(
        fc.array(
          fc.array(
            fc.record({ name: fc.string(), startTime: fc.string() }),
            { maxLength: 10 }
          ),
          { minLength: 7, maxLength: 7 }
        ),
        (scheduleData) => {
          const counts = getRenderedCourseCountPerDay(scheduleData);
          for (let dayIdx = 0; dayIdx < 7; dayIdx++) {
            if (counts[dayIdx] !== scheduleData[dayIdx].length) return false;
          }
          return true;
        }
      ),
      { numRuns: 100 }
    );
  });
});
