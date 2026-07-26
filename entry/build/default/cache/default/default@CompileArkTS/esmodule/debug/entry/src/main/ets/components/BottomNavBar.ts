if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface BottomNavBar_Params {
    currentIndex?: number;
    language?: string;
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
    }
    aboutToBeDeleted() {
        this.__currentIndex.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
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
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('calc(100% - 40px)');
            Row.height(64);
            Row.padding(6);
            Row.backgroundColor('rgba(248, 249, 250, 0.8)');
            Row.backdropBlur(40);
            Row.borderRadius(Theme.RADIUS_FULL);
            Row.borderWidth(1);
            Row.borderColor('rgba(255, 255, 255, 0.2)');
            Row.shadow({
                radius: 20,
                color: 'rgba(0, 0, 0, 0.06)',
                offsetY: 4
            });
            Row.position({
                bottom: Theme.NAV_BAR_BOTTOM_MARGIN
            });
            Row.alignSelf(ItemAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Cards tab
            Column.create();
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            // Cards tab
            Column.layoutWeight(1);
            // Cards tab
            Column.alignItems(HorizontalAlign.Center);
            // Cards tab
            Column.justifyContent(FlexAlign.Center);
            // Cards tab
            Column.height(48);
            // Cards tab
            Column.borderRadius(Theme.RADIUS_FULL);
            // Cards tab
            Column.backgroundColor(this.currentIndex === 0 ? Theme.PRIMARY : 'transparent');
            globalThis.Context.animation(null);
            // Cards tab
            Column.onClick(() => {
                this.currentIndex = 0;
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([this.currentIndex === 0 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT]);
            globalThis.Context.animation(null);
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '卡片' : 'Cards');
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(this.currentIndex === 0 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
            globalThis.Context.animation(null);
        }, Text);
        Text.pop();
        // Cards tab
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Profile tab
            Column.create();
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            // Profile tab
            Column.layoutWeight(1);
            // Profile tab
            Column.alignItems(HorizontalAlign.Center);
            // Profile tab
            Column.justifyContent(FlexAlign.Center);
            // Profile tab
            Column.height(48);
            // Profile tab
            Column.borderRadius(Theme.RADIUS_FULL);
            // Profile tab
            Column.backgroundColor(this.currentIndex === 1 ? Theme.PRIMARY : 'transparent');
            globalThis.Context.animation(null);
            // Profile tab
            Column.onClick(() => {
                this.currentIndex = 1;
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832135, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([this.currentIndex === 1 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT]);
            globalThis.Context.animation(null);
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '我的' : 'Profile');
            globalThis.Context.animation({
                duration: Theme.ANIMATION_DURATION,
                curve: Curve.EaseInOut
            });
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(this.currentIndex === 1 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
            globalThis.Context.animation(null);
        }, Text);
        Text.pop();
        // Profile tab
        Column.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
