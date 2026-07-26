if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface MockSettingsPage_Params {
    language?: string;
    showMockSettingsPage?: boolean;
    showVerificationDialog?: boolean;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class MockSettingsPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__showMockSettingsPage = new SynchedPropertySimpleTwoWayPU(params.showMockSettingsPage, this, "showMockSettingsPage");
        this.__showVerificationDialog = new SynchedPropertySimpleTwoWayPU(params.showVerificationDialog, this, "showVerificationDialog");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: MockSettingsPage_Params) {
    }
    updateStateVars(params: MockSettingsPage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showMockSettingsPage.purgeDependencyOnElmtId(rmElmtId);
        this.__showVerificationDialog.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__language.aboutToBeDeleted();
        this.__showMockSettingsPage.aboutToBeDeleted();
        this.__showVerificationDialog.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __language: SynchedPropertySimpleTwoWayPU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    private __showMockSettingsPage: SynchedPropertySimpleTwoWayPU<boolean>;
    get showMockSettingsPage() {
        return this.__showMockSettingsPage.get();
    }
    set showMockSettingsPage(newValue: boolean) {
        this.__showMockSettingsPage.set(newValue);
    }
    private __showVerificationDialog: SynchedPropertySimpleTwoWayPU<boolean>;
    get showVerificationDialog() {
        return this.__showVerificationDialog.get();
    }
    set showVerificationDialog(newValue: boolean) {
        this.__showVerificationDialog.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(Theme.BACKGROUND);
            Column.padding({ top: Theme.STATUS_BAR_PADDING });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.height(56);
            Row.padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN });
            Row.backgroundColor('rgba(248, 249, 250, 0.8)');
            Row.backdropBlur(40);
            Row.borderWidth({ bottom: 1 });
            Row.borderColor('rgba(199, 196, 215, 0.3)');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width(40);
            Row.height(40);
            Row.borderRadius(Theme.RADIUS_FULL);
            Row.justifyContent(FlexAlign.Center);
            Row.alignItems(VerticalAlign.Center);
            Row.backgroundColor('rgba(70, 72, 212, 0.05)');
            Row.onClick(() => {
                this.showMockSettingsPage = false;
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832663, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(20);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? 'MOCK 测试' : 'MOCK Testing');
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.margin({ left: Theme.SPACING_MD });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN });
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '开发测试入口' : 'DEVELOPER TESTS');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.alignSelf(ItemAlign.Start);
            Text.margin({ left: Theme.SPACING_SM, bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(Theme.SPACING_LG);
            Row.alignItems(VerticalAlign.Center);
            Row.backgroundColor('rgba(255, 255, 255, 0.82)');
            Row.borderRadius(Theme.RADIUS_LG);
            Row.borderWidth(1);
            Row.borderColor('rgba(255, 255, 255, 0.6)');
            Row.shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 });
            Row.onClick(() => {
                this.showVerificationDialog = true;
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(44);
            Stack.height(44);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor(Theme.PRIMARY);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832274, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.ON_PRIMARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
            Column.margin({ left: Theme.SPACING_MD });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '* 二次验证弹窗' : '* Secondary Verification');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '模拟收到 SLE 验证请求' : 'Simulate an incoming SLE verification request');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832664, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_MD);
            SymbolGlyph.fontColor([Theme.OUTLINE_VARIANT]);
        }, SymbolGlyph);
        Row.pop();
        Column.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
