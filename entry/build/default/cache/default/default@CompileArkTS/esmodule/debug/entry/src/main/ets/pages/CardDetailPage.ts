if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CardDetailPage_Params {
    cards?: CardModel[];
    language?: string;
    showCardDetailPage?: boolean;
    selectedCardId?: string;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import type { CardModel } from '../common/CardModel';
export class CardDetailPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__cards = new SynchedPropertyObjectTwoWayPU(params.cards, this, "cards");
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__showCardDetailPage = new SynchedPropertySimpleTwoWayPU(params.showCardDetailPage, this, "showCardDetailPage");
        this.__selectedCardId = new SynchedPropertySimpleTwoWayPU(params.selectedCardId, this, "selectedCardId");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CardDetailPage_Params) {
    }
    updateStateVars(params: CardDetailPage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__cards.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showCardDetailPage.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedCardId.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__cards.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__showCardDetailPage.aboutToBeDeleted();
        this.__selectedCardId.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __cards: SynchedPropertySimpleOneWayPU<CardModel[]>;
    get cards() {
        return this.__cards.get();
    }
    set cards(newValue: CardModel[]) {
        this.__cards.set(newValue);
    }
    private __language: SynchedPropertySimpleTwoWayPU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    private __showCardDetailPage: SynchedPropertySimpleTwoWayPU<boolean>;
    get showCardDetailPage() {
        return this.__showCardDetailPage.get();
    }
    set showCardDetailPage(newValue: boolean) {
        this.__showCardDetailPage.set(newValue);
    }
    private __selectedCardId: SynchedPropertySimpleTwoWayPU<string>;
    get selectedCardId() {
        return this.__selectedCardId.get();
    }
    set selectedCardId(newValue: string) {
        this.__selectedCardId.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(Theme.SURFACE);
            Column.padding({ top: Theme.STATUS_BAR_PADDING });
        }, Column);
        // Top App Bar
        this.TopAppBar.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Scrollable content
            Scroll.create();
            // Scrollable content
            Scroll.layoutWeight(1);
            // Scrollable content
            Scroll.scrollBar(BarState.Off);
            // Scrollable content
            Scroll.edgeEffect(EdgeEffect.Spring);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN, bottom: 40 });
        }, Column);
        // Card visualization
        this.CardVisualization.bind(this)();
        // Information section
        this.InformationSection.bind(this)();
        // Editable card settings
        this.CardSettingsSection.bind(this)();
        // Security section
        this.SecuritySection.bind(this)();
        // Danger zone
        this.DangerZone.bind(this)();
        Column.pop();
        // Scrollable content
        Scroll.pop();
        Column.pop();
    }
    TopAppBar(parent = null) {
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
                this.showCardDetailPage = false;
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832663, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(20);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '卡片详情' : 'Card Details');
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
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832644, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Row.pop();
    }
    CardVisualization(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width('100%');
            Stack.aspectRatio(Theme.CARD_ASPECT_RATIO);
            Stack.borderRadius(Theme.RADIUS_LG);
            Stack.shadow({
                radius: 20,
                color: 'rgba(0, 0, 0, 0.04)',
                offsetY: 4
            });
            Stack.clip(true);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Gradient background
            Column.create();
            // Gradient background
            Column.width('100%');
            // Gradient background
            Column.height('100%');
            // Gradient background
            Column.linearGradient({
                direction: GradientDirection.RightBottom,
                colors: [
                    [Theme.PRIMARY, 0],
                    [Theme.SECONDARY, 0.5],
                    [Theme.TERTIARY_CONTAINER, 1]
                ]
            });
        }, Column);
        // Gradient background
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Holographic overlay
            Column.create();
            // Holographic overlay
            Column.width('100%');
            // Holographic overlay
            Column.height('100%');
            // Holographic overlay
            Column.opacity(0.4);
        }, Column);
        // Holographic overlay
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Card content
            Column.create();
            // Card content
            Column.width('100%');
            // Card content
            Column.height('100%');
            // Card content
            Column.padding(Theme.SPACING_LG);
            // Card content
            Column.justifyContent(FlexAlign.SpaceBetween);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Top section
            Row.create();
            // Top section
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.currentCard().issuer);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor('rgba(255, 255, 255, 0.8)');
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.currentCard().name);
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Color.White);
            Text.letterSpacing(Theme.HEADLINE_MD_LETTER_SPACING);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_XXL);
            SymbolGlyph.fontColor([Color.White]);
        }, SymbolGlyph);
        // Top section
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Bottom section
            Column.create();
            // Bottom section
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.maskedCardNumber());
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Color.White);
            Text.letterSpacing(0.2);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.alignItems(VerticalAlign.Bottom);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.currentCard().nickname.length > 0 ? this.currentCard().nickname : this.currentCard().name);
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(32);
            Stack.height(32);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor('rgba(255, 255, 255, 0.2)');
            Stack.backdropBlur(8);
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_SM);
            SymbolGlyph.fontColor([Color.White]);
        }, SymbolGlyph);
        Stack.pop();
        Row.pop();
        // Bottom section
        Column.pop();
        // Card content
        Column.pop();
        Stack.pop();
    }
    InformationSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '信息' : 'INFORMATION');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.padding({ left: Theme.SPACING_BASE });
            Text.margin({ bottom: Theme.SPACING_MD });
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOWEST);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(199, 196, 215, 0.1)');
            Column.shadow({
                radius: 20,
                color: 'rgba(0, 0, 0, 0.04)',
                offsetY: 4
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Issuer row
            Row.create();
            // Issuer row
            Row.width('100%');
            // Issuer row
            Row.padding(Theme.SPACING_MD);
            // Issuer row
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(40);
            Stack.height(40);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor('rgba(70, 72, 212, 0.1)');
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_MD);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '发行方' : 'Issuer');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE);
            Text.margin({ left: Theme.SPACING_MD });
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.currentCard().issuer);
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        // Issuer row
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.color('rgba(199, 196, 215, 0.1)');
            Divider.margin({ left: Theme.SPACING_MD, right: Theme.SPACING_MD });
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Card ID row
            Row.create();
            // Card ID row
            Row.width('100%');
            // Card ID row
            Row.padding(Theme.SPACING_MD);
            // Card ID row
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(40);
            Stack.height(40);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor('rgba(75, 90, 155, 0.1)');
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_MD);
            SymbolGlyph.fontColor([Theme.TERTIARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '卡片 ID' : 'Card ID');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE);
            Text.margin({ left: Theme.SPACING_MD });
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.maskedCardNumber());
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.fontFamily('monospace');
        }, Text);
        Text.pop();
        // Card ID row
        Row.pop();
        Column.pop();
        Column.pop();
    }
    CardSettingsSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '卡片设置' : 'CARD SETTINGS');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.padding({ left: Theme.SPACING_BASE });
            Text.margin({ bottom: Theme.SPACING_MD });
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOWEST);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(199, 196, 215, 0.1)');
            Column.shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 });
            Column.clip(true);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(Theme.SPACING_MD);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '昵称' : 'Nickname');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({
                text: this.currentCard().nickname,
                placeholder: this.language === 'zh' ? '默认使用卡片名称' : 'Defaults to the card name'
            });
            TextInput.width('100%');
            TextInput.height(44);
            TextInput.fontSize(Theme.BODY_MD_FONT_SIZE);
            TextInput.fontColor(Theme.ON_SURFACE);
            TextInput.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            TextInput.borderRadius(Theme.RADIUS_SM);
            TextInput.margin({ top: Theme.SPACING_XS });
            TextInput.onChange((value: string) => {
                this.updateNickname(value);
            });
        }, TextInput);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.color('rgba(199, 196, 215, 0.1)');
            Divider.margin({ left: Theme.SPACING_MD, right: Theme.SPACING_MD });
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(Theme.SPACING_MD);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '类别' : 'Category');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({
                text: this.currentCard().category,
                placeholder: this.language === 'zh' ? '输入自定义类别' : 'Enter a custom category'
            });
            TextInput.width('100%');
            TextInput.height(44);
            TextInput.fontSize(Theme.BODY_MD_FONT_SIZE);
            TextInput.fontColor(Theme.ON_SURFACE);
            TextInput.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            TextInput.borderRadius(Theme.RADIUS_SM);
            TextInput.margin({ top: Theme.SPACING_XS });
            TextInput.onChange((value: string) => {
                this.updateCategory(value);
            });
        }, TextInput);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.color('rgba(199, 196, 215, 0.1)');
            Divider.margin({ left: Theme.SPACING_MD, right: Theme.SPACING_MD });
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(Theme.SPACING_MD);
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '启用卡片' : 'Enable Card');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '控制卡片是否在主页显示为可用' : 'Controls whether the card is available on the home screen');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Toggle.create({ type: ToggleType.Switch, isOn: this.currentCard().enabled });
            Toggle.selectedColor(Theme.PRIMARY);
            Toggle.switchPointColor(Color.White);
            Toggle.width(44);
            Toggle.height(24);
            Toggle.onChange((isOn: boolean) => {
                this.updateEnabled(isOn);
            });
        }, Toggle);
        Toggle.pop();
        Row.pop();
        Column.pop();
        Column.pop();
    }
    SecuritySection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '安全' : 'SECURITY');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.padding({ left: Theme.SPACING_BASE });
            Text.margin({ bottom: Theme.SPACING_MD });
            Text.alignSelf(ItemAlign.Start);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(Theme.SPACING_MD);
            Row.backgroundColor(Theme.SURFACE_CONTAINER_LOWEST);
            Row.borderRadius(Theme.RADIUS_LG);
            Row.borderWidth(1);
            Row.borderColor('rgba(199, 196, 215, 0.1)');
            Row.shadow({
                radius: 20,
                color: 'rgba(0, 0, 0, 0.04)',
                offsetY: 4
            });
            Row.alignItems(VerticalAlign.Center);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(40);
            Stack.height(40);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.backgroundColor('rgba(75, 65, 225, 0.1)');
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832274, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_MD);
            SymbolGlyph.fontColor([Theme.SECONDARY]);
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.margin({ left: Theme.SPACING_MD });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '双重身份验证' : 'Two-Factor Authentication');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '需要二次验证' : 'Secondary validation required');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Toggle.create({ type: ToggleType.Switch, isOn: this.currentCard().twoFactorEnabled });
            Toggle.selectedColor(Theme.PRIMARY);
            Toggle.switchPointColor(Color.White);
            Toggle.width(44);
            Toggle.height(24);
            Toggle.onChange((isOn: boolean) => {
                this.updateTwoFactor(isOn);
            });
        }, Toggle);
        Toggle.pop();
        Row.pop();
        Column.pop();
    }
    DangerZone(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_LG + Theme.SPACING_LG });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild();
            Button.width('100%');
            Button.height(56);
            Button.backgroundColor('rgba(186, 26, 26, 0.2)');
            Button.borderRadius(Theme.RADIUS_FULL);
            Button.borderWidth(1);
            Button.borderColor('rgba(186, 26, 26, 0.1)');
            Button.type(ButtonType.Normal);
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125831542, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.ERROR]);
            SymbolGlyph.margin({ right: Theme.SPACING_MD });
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '删除卡片' : 'Delete Card');
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ERROR);
        }, Text);
        Text.pop();
        Row.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '删除卡片后无法恢复。' : 'Deleting this card is permanent and cannot be undone.');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor('rgba(70, 69, 84, 0.6)');
            Text.textAlign(TextAlign.Center);
            Text.width('100%');
            Text.margin({ top: Theme.SPACING_MD });
        }, Text);
        Text.pop();
        Column.pop();
    }
    private currentCardIndex(): number {
        let selectedIndex: number = 0;
        this.cards.forEach((card: CardModel, index: number) => {
            if (card.id === this.selectedCardId) {
                selectedIndex = index;
            }
        });
        return selectedIndex;
    }
    private currentCard(): CardModel {
        return this.cards[this.currentCardIndex()];
    }
    private maskedCardNumber(): string {
        const number: string = this.currentCard().cardNumber.split(' ').join('');
        return `•••• •••• •••• ${number.slice(-4)}`;
    }
    private updateNickname(value: string): void {
        this.cards[this.currentCardIndex()].nickname = value;
        this.cards = this.cards.slice();
    }
    private updateCategory(value: string): void {
        this.cards[this.currentCardIndex()].category = value;
        this.cards = this.cards.slice();
    }
    private updateEnabled(isOn: boolean): void {
        this.cards[this.currentCardIndex()].enabled = isOn;
        this.cards = this.cards.slice();
    }
    private updateTwoFactor(isOn: boolean): void {
        this.cards[this.currentCardIndex()].twoFactorEnabled = isOn;
        this.cards = this.cards.slice();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
