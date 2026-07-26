import window from "@ohos:window";
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
/**
 * Immersive Light Effect - 沉浸式光感效果工具类
 * 实现状态栏透明和系统栏样式配置
 */
export class ImmersiveLightEffect {
    private static instance: ImmersiveLightEffect;
    private windowStage: window.WindowStage | null = null;
    private constructor() { }
    static getInstance(): ImmersiveLightEffect {
        if (!ImmersiveLightEffect.instance) {
            ImmersiveLightEffect.instance = new ImmersiveLightEffect();
        }
        return ImmersiveLightEffect.instance;
    }
    /**
     * 初始化沉浸式效果
     */
    async init(windowStage: window.WindowStage): Promise<void> {
        this.windowStage = windowStage;
        await this.enableImmersiveMode();
    }
    /**
     * 启用沉浸式模式
     */
    async enableImmersiveMode(): Promise<void> {
        if (!this.windowStage)
            return;
        try {
            const win = await this.windowStage.getMainWindow();
            // 设置状态栏和导航栏为透明
            const systemBarProps: window.SystemBarProperties = {
                statusBarColor: 'transparent',
                navigationBarColor: 'transparent',
                statusBarContentColor: Theme.ON_SURFACE,
                navigationBarContentColor: Theme.ON_SURFACE
            };
            await win.setWindowSystemBarProperties(systemBarProps);
            // 启用全屏布局
            await win.setWindowLayoutFullScreen(true);
            // 设置状态栏内容为深色（适合浅色背景）
            await this.setStatusBarContentDark(true);
        }
        catch (err) {
            console.error('Failed to enable immersive mode:', err);
        }
    }
    /**
     * 设置状态栏内容颜色
     * @param isDark 是否使用深色内容
     */
    async setStatusBarContentDark(isDark: boolean): Promise<void> {
        if (!this.windowStage)
            return;
        try {
            const win = await this.windowStage.getMainWindow();
            const systemBarProps: window.SystemBarProperties = {
                statusBarContentColor: isDark ? Theme.ON_SURFACE : '#FFFFFF'
            };
            await win.setWindowSystemBarProperties(systemBarProps);
        }
        catch (err) {
            console.error('Failed to set status bar content color:', err);
        }
    }
    /**
     * 获取状态栏高度
     */
    async getStatusBarHeight(): Promise<number> {
        if (!this.windowStage)
            return Theme.STATUS_BAR_PADDING;
        try {
            const win = await this.windowStage.getMainWindow();
            const properties = await win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
            return properties.topRect.height;
        }
        catch (err) {
            console.error('Failed to get status bar height:', err);
            return Theme.STATUS_BAR_PADDING;
        }
    }
    /**
     * 获取导航栏高度
     */
    async getNavigationBarHeight(): Promise<number> {
        if (!this.windowStage)
            return 0;
        try {
            const win = await this.windowStage.getMainWindow();
            const properties = await win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
            return properties.bottomRect.height;
        }
        catch (err) {
            console.error('Failed to get navigation bar height:', err);
            return 0;
        }
    }
    /**
     * 应用光感效果 - 根据背景自动调整状态栏
     * @param isLightBackground 是否为浅色背景
     */
    async applyLightEffect(isLightBackground: boolean): Promise<void> {
        await this.setStatusBarContentDark(isLightBackground);
    }
}
/**
 * 创建光感阴影效果
 * 模拟设计中的"Soft Elevation"
 */
export function createAmbientShadow(radius: number = 20, color: string = 'rgba(0, 0, 0, 0.04)', offsetY: number = 4): ShadowOptions {
    return {
        radius: radius,
        color: color,
        offsetX: 0,
        offsetY: offsetY
    };
}
/**
 * 创建主色调阴影
 * 活跃元素使用主色调阴影
 */
export function createPrimaryShadow(radius: number = 20, opacity: number = 0.02, offsetY: number = 4): ShadowOptions {
    return {
        radius: radius,
        color: `rgba(70, 72, 212, ${opacity})`,
        offsetX: 0,
        offsetY: offsetY
    };
}
/**
 * 创建毛玻璃效果背景
 */
export function createGlassBackground(opacity: number = 0.8, blur: number = 20): GlassEffect {
    return {
        opacity: opacity,
        blur: blur,
        borderColor: `rgba(255, 255, 255, ${Theme.GLASS_BORDER_OPACITY})`
    };
}
interface ShadowOptions {
    radius: number;
    color: string;
    offsetX: number;
    offsetY: number;
}
interface GlassEffect {
    opacity: number;
    blur: number;
    borderColor: string;
}
