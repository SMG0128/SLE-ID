if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CardPreview_Params {
    card?: CardModel;
    language?: string;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import type { CardModel } from '../common/CardModel';
export class CardPreview extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__card = new SynchedPropertyObjectOneWayPU(params.card, this, "card");
        this.__language = new SynchedPropertySimpleOneWayPU(params.language, this, "language");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CardPreview_Params) {
    }
    updateStateVars(params: CardPreview_Params) {
        this.__card.reset(params.card);
        this.__language.reset(params.language);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__card.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__card.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __card: SynchedPropertySimpleOneWayPU<CardModel>;
    get card() {
        return this.__card.get();
    }
    set card(newValue: CardModel) {
        this.__card.set(newValue);
    }
    private __language: SynchedPropertySimpleOneWayPU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.backgroundColor('rgba(255, 255, 255, 0.82)');
            Column.backdropBlur(24);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(255, 255, 255, 0.6)');
            Column.shadow({ radius: 40, color: 'rgba(0, 0, 0, 0.1)', offsetY: 8 });
            Column.clip(true);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width('100%');
            Stack.alignContent(Alignment.TopEnd);
            Stack.position({ x: 0, y: 0 });
            Stack.offset({ x: 48, y: -48 });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Circle.create();
            Circle.width(192);
            Circle.height(192);
            Circle.fill(this.card.accentColor);
            Circle.opacity(0.05);
        }, Circle);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(Theme.SPACING_LG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 4 });
            Row.width('100%');
            Row.margin({ bottom: Theme.SPACING_XL });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(48);
            Stack.height(48);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor(this.card.accentColor);
            Stack.shadow({ radius: 16, color: this.card.accentColor, offsetY: 4 });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create(this.card.icon);
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.ON_PRIMARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.card.enabled ? (this.language === 'zh' ? '已启用' : 'Enabled') :
                (this.language === 'zh' ? '未启用' : 'Disabled'));
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(this.card.enabled ? this.card.accentColor : Theme.ON_SURFACE_VARIANT);
            Text.padding({ left: Theme.SPACING_MD, right: Theme.SPACING_MD, top: 4, bottom: 4 });
            Text.backgroundColor(this.card.enabled ? `${this.card.accentColor}1A` : Theme.SURFACE_CONTAINER_HIGH);
            Text.borderRadius(Theme.RADIUS_FULL);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.card.nickname.length > 0 ? this.card.nickname : this.card.name);
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.margin({ bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.card.detail);
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ top: Theme.SPACING_LG });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.card.category.length > 0 ? this.card.category :
                (this.language === 'zh' ? '未分类' : 'Uncategorized'));
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(this.card.accentColor);
            Text.padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, top: 4, bottom: 4 });
            Text.backgroundColor(`${this.card.accentColor}12`);
            Text.borderRadius(Theme.RADIUS_FULL);
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
