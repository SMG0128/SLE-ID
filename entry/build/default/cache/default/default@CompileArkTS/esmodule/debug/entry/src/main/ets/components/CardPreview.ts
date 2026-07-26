if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CardPreview_Params {
    card?: DigitalCard;
    language?: string;
    isTablet?: boolean;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { DigitalCardStatus } from "@normalized:N&&&entry/src/main/ets/models/DigitalCard&";
import type { DigitalCard } from "@normalized:N&&&entry/src/main/ets/models/DigitalCard&";
import { CredentialBindingStatus } from "@normalized:N&&&entry/src/main/ets/models/Credential&";
import { cardAccentColor, cardIcon } from "@normalized:N&&&entry/src/main/ets/common/CardModel&";
export class CardPreview extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__card = new SynchedPropertyObjectOneWayPU(params.card, this, "card");
        this.__language = new SynchedPropertySimpleOneWayPU(params.language, this, "language");
        this.__isTablet = new SynchedPropertySimpleOneWayPU(params.isTablet, this, "isTablet");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CardPreview_Params) {
        if (params.isTablet === undefined) {
            this.__isTablet.set(false);
        }
    }
    updateStateVars(params: CardPreview_Params) {
        this.__card.reset(params.card);
        this.__language.reset(params.language);
        this.__isTablet.reset(params.isTablet);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__card.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__isTablet.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__card.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__isTablet.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __card: SynchedPropertySimpleOneWayPU<DigitalCard>;
    get card() {
        return this.__card.get();
    }
    set card(newValue: DigitalCard) {
        this.__card.set(newValue);
    }
    private __language: SynchedPropertySimpleOneWayPU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    private __isTablet: SynchedPropertySimpleOneWayPU<boolean>;
    get isTablet() {
        return this.__isTablet.get();
    }
    set isTablet(newValue: boolean) {
        this.__isTablet.set(newValue);
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
            Column.constraintSize({ minHeight: this.isTablet ? Theme.TABLET_CARD_MIN_HEIGHT : 0 });
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
            Circle.width(this.isTablet ? 150 : 192);
            Circle.height(this.isTablet ? 150 : 192);
            Circle.fill(cardAccentColor(this.card));
            Circle.opacity(0.05);
        }, Circle);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(this.isTablet ? 18 : Theme.SPACING_LG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 4 });
            Row.width('100%');
            Row.margin({ bottom: this.isTablet ? Theme.SPACING_MD : Theme.SPACING_XL });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(this.isTablet ? 40 : 48);
            Stack.height(this.isTablet ? 40 : 48);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor(cardAccentColor(this.card));
            Stack.shadow({ radius: 16, color: cardAccentColor(this.card), offsetY: 4 });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create(cardIcon(this.card));
            SymbolGlyph.fontSize(this.isTablet ? Theme.ICON_MD : Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.ON_PRIMARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.statusText());
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(this.card.status === DigitalCardStatus.ACTIVE ?
                cardAccentColor(this.card) : Theme.ON_SURFACE_VARIANT);
            Text.maxLines(1);
            Text.padding({
                left: this.isTablet ? Theme.SPACING_XS : Theme.SPACING_MD,
                right: this.isTablet ? Theme.SPACING_XS : Theme.SPACING_MD,
                top: 4,
                bottom: 4
            });
            Text.backgroundColor(this.card.status === DigitalCardStatus.ACTIVE ?
                `${cardAccentColor(this.card)}1A` : Theme.SURFACE_CONTAINER_HIGH);
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
            Text.fontSize(this.isTablet ? Theme.BODY_LG_FONT_SIZE : Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.margin({ bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.card.detail);
            Text.fontSize(this.isTablet ? Theme.LABEL_MD_FONT_SIZE : Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.maxLines(2);
            Text.textOverflow({ overflow: TextOverflow.Ellipsis });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ top: this.isTablet ? Theme.SPACING_MD : Theme.SPACING_LG });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.card.category.length > 0 ? this.card.category :
                (this.language === 'zh' ? '未分类' : 'Uncategorized'));
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(cardAccentColor(this.card));
            Text.padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, top: 4, bottom: 4 });
            Text.backgroundColor(`${cardAccentColor(this.card)}12`);
            Text.borderRadius(Theme.RADIUS_FULL);
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        Column.pop();
    }
    private statusText(): string {
        if (this.isTablet) {
            if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITING ||
                this.card.credentialBindingStatus === CredentialBindingStatus.VERIFYING) {
                return this.language === 'zh' ? '写入中' : 'Writing';
            }
            if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITE_FAILED) {
                return this.language === 'zh' ? '写入失败' : 'Failed';
            }
            if (this.card.credentialBindingStatus === CredentialBindingStatus.UPDATE_REQUIRED) {
                return this.language === 'zh' ? '需要更新' : 'Update';
            }
            if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITTEN) {
                return this.language === 'zh' ? '已写入' : 'Written';
            }
            if (this.card.status === DigitalCardStatus.ACTIVE) {
                return this.language === 'zh' ? '未写卡' : 'Not written';
            }
            return this.language === 'zh' ? '未启用' : 'Disabled';
        }
        if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITING ||
            this.card.credentialBindingStatus === CredentialBindingStatus.VERIFYING) {
            return this.language === 'zh' ? '正在写入实体卡' : 'Writing to WS63';
        }
        if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITE_FAILED) {
            return this.language === 'zh' ? '写入失败' : 'Write failed';
        }
        if (this.card.credentialBindingStatus === CredentialBindingStatus.UPDATE_REQUIRED) {
            return this.language === 'zh' ? '凭证需要更新' : 'Credential update required';
        }
        if (this.card.credentialBindingStatus === CredentialBindingStatus.WRITTEN) {
            return this.language === 'zh' ? '已写入实体卡' : 'Written to WS63';
        }
        if (this.card.status === DigitalCardStatus.ACTIVE) {
            return this.language === 'zh' ? '尚未写入实体卡' : 'Not written to WS63';
        }
        return this.language === 'zh' ? '未启用' : 'Disabled';
    }
    rerender() {
        this.updateDirtyElements();
    }
}
