if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface LanguagePage_Params {
    language?: string;
    showLanguagePage?: boolean;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class LanguagePage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__showLanguagePage = new SynchedPropertySimpleTwoWayPU(params.showLanguagePage, this, "showLanguagePage");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: LanguagePage_Params) {
    }
    updateStateVars(params: LanguagePage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showLanguagePage.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__language.aboutToBeDeleted();
        this.__showLanguagePage.aboutToBeDeleted();
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
    private __showLanguagePage: SynchedPropertySimpleTwoWayPU<boolean>;
    get showLanguagePage() {
        return this.__showLanguagePage.get();
    }
    set showLanguagePage(newValue: boolean) {
        this.__showLanguagePage.set(newValue);
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
                this.showLanguagePage = false;
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832663, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(20);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '语言' : 'Language');
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
            Text.create(this.language === 'zh' ? '选择语言' : 'Choose a language');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.alignSelf(ItemAlign.Start);
            Text.margin({ left: Theme.SPACING_SM, bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.backgroundColor('rgba(255, 255, 255, 0.8)');
            Column.borderRadius(Theme.RADIUS_LG);
            Column.clip(true);
            Column.borderWidth(1);
            Column.borderColor('rgba(255, 255, 255, 0.5)');
            Column.shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 });
        }, Column);
        this.LanguageOption.bind(this)('zh', '中文', '简体中文');
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.color('rgba(199, 196, 215, 0.1)');
            Divider.margin({ left: Theme.SPACING_LG, right: Theme.SPACING_LG });
        }, Divider);
        this.LanguageOption.bind(this)('en', 'English', 'English');
        Column.pop();
        Column.pop();
        Column.pop();
    }
    LanguageOption(value: string, title: string, subtitle: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ left: Theme.SPACING_LG, right: Theme.SPACING_LG, top: Theme.SPACING_MD, bottom: Theme.SPACING_MD });
            Row.alignItems(VerticalAlign.Center);
            Row.onClick(() => {
                this.language = value;
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(subtitle);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.language === value) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        SymbolGlyph.create({ "id": 125831490, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
                        SymbolGlyph.fontSize(Theme.ICON_LG);
                        SymbolGlyph.fontColor([Theme.PRIMARY]);
                    }, SymbolGlyph);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
