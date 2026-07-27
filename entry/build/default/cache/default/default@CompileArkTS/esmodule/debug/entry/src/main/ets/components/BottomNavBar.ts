if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface BottomNavBar_Params {
    currentIndex?: number;
    language?: string;
    showScanPage?: boolean;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class BottomNavBar extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__currentIndex = new SynchedPropertySimpleTwoWayPU(params.currentIndex, this, "currentIndex");
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__showScanPage = new SynchedPropertySimpleTwoWayPU(params.showScanPage, this, "showScanPage");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: BottomNavBar_Params) {
    }
    updateStateVars(params: BottomNavBar_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__currentIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showScanPage.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__currentIndex.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__showScanPage.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __currentIndex: SynchedPropertySimpleTwoWayPU<number>;
    get currentIndex() {
        return this.__currentIndex.get();
    }
    set currentIndex(newValue: number) {
        this.__currentIndex.set(newValue);
    }
    private __language: SynchedPropertySimpleTwoWayPU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    private __showScanPage: SynchedPropertySimpleTwoWayPU<boolean>;
    get showScanPage() {
        return this.__showScanPage.get();
    }
    set showScanPage(newValue: boolean) {
        this.__showScanPage.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Bottom });
            Stack.width('calc(100% - 40px)');
            Stack.height(78);
            Stack.position({ bottom: Theme.NAV_BAR_BOTTOM_MARGIN });
            Stack.alignSelf(ItemAlign.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.create();
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.width(72);
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.height(72);
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.fill('rgba(238, 240, 255, 0.9)');
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.backdropBlur(40);
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.borderWidth(1);
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.borderColor('rgba(70, 72, 212, 0.16)');
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.shadow({
                radius: 18,
                color: 'rgba(70, 72, 212, 0.12)',
                offsetY: 3
            });
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.position({ x: '50%', y: 0 });
            // The center dome and the bar share one glass material so Scan reads as a tab extension.
            Circle.translate({ x: -36 });
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.height(64);
            Row.backgroundColor('rgba(248, 249, 250, 0.86)');
            Row.backdropBlur(40);
            Row.borderRadius(Theme.RADIUS_FULL);
            Row.borderWidth(1);
            Row.borderColor('rgba(255, 255, 255, 0.72)');
            Row.shadow({
                radius: 20,
                color: 'rgba(30, 34, 78, 0.08)',
                offsetY: 5
            });
            Row.position({ x: 0, y: 14 });
        }, Row);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.height(78);
            Row.padding({ left: 6, right: 6, bottom: 6 });
            Row.alignItems(VerticalAlign.Bottom);
        }, Row);
        this.StandardTab.bind(this)(0, { "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" }, this.language === 'zh' ? '卡片' : 'Cards');
        this.ScanTab.bind(this)();
        this.StandardTab.bind(this)(1, { "id": 125832135, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" }, this.language === 'zh' ? '我的' : 'Profile');
        Row.pop();
        Stack.pop();
    }
    StandardTab(index: number, icon: Resource, label: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            Column.layoutWeight(1);
            Column.height(50);
            Column.justifyContent(FlexAlign.Center);
            Column.alignItems(HorizontalAlign.Center);
            Column.borderRadius(Theme.RADIUS_FULL);
            Column.backgroundColor(this.isTabSelected(index) ? 'rgba(70, 72, 212, 0.11)' : 'transparent');
            globalThis.Context.animation(null);
            Column.onClick(() => {
                this.currentIndex = index;
                this.showScanPage = false;
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create(icon);
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([this.isTabSelected(index) ? Theme.PRIMARY : Theme.ON_SURFACE_VARIANT]);
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(this.isTabSelected(index) ?
                Theme.FONT_WEIGHT_SEMIBOLD : Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(this.isTabSelected(index) ? Theme.PRIMARY : Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        Column.pop();
    }
    ScanTab(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            Column.width(72);
            Column.height(72);
            Column.justifyContent(FlexAlign.Center);
            Column.alignItems(HorizontalAlign.Center);
            Column.scale({
                x: this.showScanPage ? 1.03 : 1,
                y: this.showScanPage ? 1.03 : 1
            });
            globalThis.Context.animation(null);
            Column.onClick(() => {
                this.showScanPage = true;
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(44);
            Stack.height(44);
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(42);
            Circle.height(42);
            Circle.fill(this.showScanPage ? 'rgba(70, 72, 212, 0.17)' : 'rgba(70, 72, 212, 0.08)');
            Circle.borderWidth(1);
            Circle.borderColor(this.showScanPage ?
                'rgba(70, 72, 212, 0.28)' : 'rgba(255, 255, 255, 0.52)');
        }, Circle);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832421, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '扫描' : 'Scan');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.PRIMARY);
        }, Text);
        Text.pop();
        Column.pop();
    }
    private isTabSelected(index: number): boolean {
        return !this.showScanPage && this.currentIndex === index;
    }
    rerender() {
        this.updateDirtyElements();
    }
}
