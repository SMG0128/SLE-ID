if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CardDetailPage_Params {
    cardStore?: CardStore;
    language?: string;
    showCardDetailPage?: boolean;
    selectedCardId?: string;
    isTablet?: boolean;
    windowWidth?: number;
    showWriteCardModal?: boolean;
    selectedPhysicalCardId?: string;
    physicalOperationMessage?: string;
    physicalOperationId?: number;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import type { DigitalCard } from '../models/DigitalCard';
import { CredentialBindingStatus } from "@normalized:N&&&entry/src/main/ets/models/Credential&";
import type { Credential } from "@normalized:N&&&entry/src/main/ets/models/Credential&";
import { PhysicalCardConnectionState, PhysicalCardDiscoveryState } from "@normalized:N&&&entry/src/main/ets/models/PhysicalCard&";
import type { PhysicalCard } from "@normalized:N&&&entry/src/main/ets/models/PhysicalCard&";
import { PhysicalCardFailureReason } from "@normalized:N&&&entry/src/main/ets/models/PhysicalCardOperation&";
import type { CredentialWriteResult, PhysicalCardConnectionResult, PrimaryPhysicalCardBindingResult } from "@normalized:N&&&entry/src/main/ets/models/PhysicalCardOperation&";
import type { CardStore } from '../stores/CardStore';
export class CardDetailPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__cardStore = new SynchedPropertyNesedObjectPU(params.cardStore, this, "cardStore");
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__showCardDetailPage = new SynchedPropertySimpleTwoWayPU(params.showCardDetailPage, this, "showCardDetailPage");
        this.__selectedCardId = new SynchedPropertySimpleTwoWayPU(params.selectedCardId, this, "selectedCardId");
        this.__isTablet = new SynchedPropertySimpleOneWayPU(params.isTablet, this, "isTablet");
        this.__windowWidth = new SynchedPropertySimpleOneWayPU(params.windowWidth, this, "windowWidth");
        this.__showWriteCardModal = new ObservedPropertySimplePU(false, this, "showWriteCardModal");
        this.__selectedPhysicalCardId = new ObservedPropertySimplePU('', this, "selectedPhysicalCardId");
        this.__physicalOperationMessage = new ObservedPropertySimplePU('', this, "physicalOperationMessage");
        this.physicalOperationId = 0;
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CardDetailPage_Params) {
        this.__cardStore.set(params.cardStore);
        if (params.isTablet === undefined) {
            this.__isTablet.set(false);
        }
        if (params.windowWidth === undefined) {
            this.__windowWidth.set(0);
        }
        if (params.showWriteCardModal !== undefined) {
            this.showWriteCardModal = params.showWriteCardModal;
        }
        if (params.selectedPhysicalCardId !== undefined) {
            this.selectedPhysicalCardId = params.selectedPhysicalCardId;
        }
        if (params.physicalOperationMessage !== undefined) {
            this.physicalOperationMessage = params.physicalOperationMessage;
        }
        if (params.physicalOperationId !== undefined) {
            this.physicalOperationId = params.physicalOperationId;
        }
    }
    updateStateVars(params: CardDetailPage_Params) {
        this.__cardStore.set(params.cardStore);
        this.__isTablet.reset(params.isTablet);
        this.__windowWidth.reset(params.windowWidth);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__cardStore.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showCardDetailPage.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__isTablet.purgeDependencyOnElmtId(rmElmtId);
        this.__windowWidth.purgeDependencyOnElmtId(rmElmtId);
        this.__showWriteCardModal.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedPhysicalCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__physicalOperationMessage.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__cardStore.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__showCardDetailPage.aboutToBeDeleted();
        this.__selectedCardId.aboutToBeDeleted();
        this.__isTablet.aboutToBeDeleted();
        this.__windowWidth.aboutToBeDeleted();
        this.__showWriteCardModal.aboutToBeDeleted();
        this.__selectedPhysicalCardId.aboutToBeDeleted();
        this.__physicalOperationMessage.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __cardStore: SynchedPropertyNesedObjectPU<CardStore>;
    get cardStore() {
        return this.__cardStore.get();
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
    private __isTablet: SynchedPropertySimpleOneWayPU<boolean>;
    get isTablet() {
        return this.__isTablet.get();
    }
    set isTablet(newValue: boolean) {
        this.__isTablet.set(newValue);
    }
    private __windowWidth: SynchedPropertySimpleOneWayPU<number>;
    get windowWidth() {
        return this.__windowWidth.get();
    }
    set windowWidth(newValue: number) {
        this.__windowWidth.set(newValue);
    }
    private __showWriteCardModal: ObservedPropertySimplePU<boolean>;
    get showWriteCardModal() {
        return this.__showWriteCardModal.get();
    }
    set showWriteCardModal(newValue: boolean) {
        this.__showWriteCardModal.set(newValue);
    }
    private __selectedPhysicalCardId: ObservedPropertySimplePU<string>;
    get selectedPhysicalCardId() {
        return this.__selectedPhysicalCardId.get();
    }
    set selectedPhysicalCardId(newValue: string) {
        this.__selectedPhysicalCardId.set(newValue);
    }
    private __physicalOperationMessage: ObservedPropertySimplePU<string>;
    get physicalOperationMessage() {
        return this.__physicalOperationMessage.get();
    }
    set physicalOperationMessage(newValue: string) {
        this.__physicalOperationMessage.set(newValue);
    }
    private physicalOperationId: number;
    aboutToDisappear(): void {
        this.stopPhysicalCardFlow();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.TopStart });
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
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
            If.create();
            if (this.usesSplitLayout()) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.TabletDetailContent.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Phone keeps one vertically scrolling detail surface.
                        Scroll.create();
                        // Phone keeps one vertically scrolling detail surface.
                        Scroll.layoutWeight(1);
                        // Phone keeps one vertically scrolling detail surface.
                        Scroll.width('100%');
                        // Phone keeps one vertically scrolling detail surface.
                        Scroll.align(Alignment.TopStart);
                        // Phone keeps one vertically scrolling detail surface.
                        Scroll.scrollBar(BarState.Off);
                        // Phone keeps one vertically scrolling detail surface.
                        Scroll.edgeEffect(EdgeEffect.Spring);
                    }, Scroll);
                    this.PhoneDetailContent.bind(this)();
                    // Phone keeps one vertically scrolling detail surface.
                    Scroll.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.showWriteCardModal) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.WriteCardModal.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Stack.pop();
    }
    PhoneDetailContent(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding({
                left: Theme.CONTAINER_MARGIN,
                right: Theme.CONTAINER_MARGIN,
                bottom: 40
            });
        }, Column);
        this.CardVisualization.bind(this)();
        this.InformationSection.bind(this)();
        this.CardSettingsSection.bind(this)();
        this.CredentialBindingSection.bind(this)();
        this.SecuritySection.bind(this)();
        this.DangerZone.bind(this)();
        Column.pop();
    }
    TabletDetailContent(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: Theme.TABLET_CARD_GAP });
            Row.layoutWeight(1);
            Row.width('100%');
            Row.constraintSize({ maxWidth: 1400 });
            Row.alignItems(VerticalAlign.Top);
            Row.justifyContent(FlexAlign.Start);
            Row.padding({
                left: Theme.TABLET_CONTAINER_MARGIN,
                right: Theme.TABLET_CONTAINER_MARGIN,
                bottom: Theme.SPACING_XL
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width(this.tabletCardColumnWidth());
            Column.alignItems(HorizontalAlign.Start);
            Column.alignSelf(ItemAlign.Start);
        }, Column);
        this.CardVisualization.bind(this)();
        this.InformationSection.bind(this)();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.layoutWeight(1);
            Scroll.height('100%');
            Scroll.align(Alignment.TopStart);
            Scroll.alignSelf(ItemAlign.Start);
            Scroll.scrollBar(BarState.Off);
            Scroll.edgeEffect(EdgeEffect.Spring);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.CredentialBindingSection.bind(this)();
        this.CardSettingsSection.bind(this)();
        this.SecuritySection.bind(this)();
        this.DangerZone.bind(this)();
        Column.pop();
        Scroll.pop();
        Row.pop();
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
                this.stopPhysicalCardFlow();
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
            Toggle.create({ type: ToggleType.Switch, isOn: this.cardStore.isCardEnabled(this.currentCard()) });
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
    CredentialBindingSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '实体卡凭证' : 'PHYSICAL CARD CREDENTIAL');
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
            Column.padding(Theme.SPACING_LG);
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOWEST);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(199, 196, 215, 0.1)');
            Column.shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.04)', offsetY: 4 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.bindingStatusText());
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.bindingDescription());
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_XL);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
        }, SymbolGlyph);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.currentCard().credentialBindingStatus ===
                CredentialBindingStatus.WRITTEN) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.WrittenCredentialDetails.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.currentCard().credentialBindingStatus ===
                CredentialBindingStatus.WRITTEN ?
                (this.language === 'zh' ? '查看实体卡' : 'View physical card') :
                (this.language === 'zh' ? '写入实体卡' : 'Write to WS63'));
            Button.width('100%');
            Button.height(48);
            Button.margin({ top: Theme.SPACING_LG });
            Button.backgroundColor(Theme.PRIMARY);
            Button.borderRadius(Theme.RADIUS_FULL);
            Button.onClick(() => {
                this.openWriteCardFlow();
            });
        }, Button);
        Button.pop();
        Column.pop();
        Column.pop();
    }
    WrittenCredentialDetails(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_MD });
        }, Column);
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '实体卡' : 'Physical card', this.boundPhysicalCardName());
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '实体卡编号' : 'Card identifier', this.boundPhysicalCardIdentifier());
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '写入时间' : 'Written at', this.boundCredentialWrittenAt());
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '凭证版本' : 'Credential version', this.boundCredentialVersion());
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '最近校验' : 'Last verified', this.boundCredentialVerifiedAt());
        Column.pop();
    }
    BindingDetailRow(label: string, value: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding({ top: Theme.SPACING_XS, bottom: Theme.SPACING_XS });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        Row.pop();
    }
    WriteCardModal(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Center });
            Stack.width('100%');
            Stack.height('100%');
            Stack.zIndex(100);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor('rgba(25, 28, 29, 0.46)');
            Column.backdropBlur(12);
            Column.onClick(() => {
                if (!this.isWriteBusy()) {
                    this.closeWriteCardFlow();
                }
            });
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('92%');
            Column.constraintSize({ maxWidth: 500, maxHeight: '88%' });
            Column.padding(Theme.SPACING_LG);
            Column.backgroundColor('rgba(248, 249, 250, 0.96)');
            Column.backdropBlur(40);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(255, 255, 255, 0.75)');
            Column.shadow({ radius: 48, color: 'rgba(0, 0, 0, 0.2)', offsetY: 12 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '写入 WS63 实体卡' : 'Write to WS63');
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.discoveryStatusText());
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.cardStore.primaryPhysicalCard) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel(this.language === 'zh' ? '重新连接' : 'Reconnect');
                        Button.fontSize(Theme.LABEL_SM_FONT_SIZE);
                        Button.fontColor(Theme.PRIMARY);
                        Button.backgroundColor('rgba(70, 72, 212, 0.08)');
                        Button.enabled(!this.isWriteBusy());
                        Button.onClick(() => {
                            this.connectPrimaryPhysicalCard().catch(() => {
                                this.physicalOperationMessage = this.language === 'zh' ?
                                    '连接失败，请重试' : 'Connection failed. Try again.';
                            });
                        });
                    }, Button);
                    Button.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithLabel(this.cardStore.discoveryState ===
                            PhysicalCardDiscoveryState.DISCOVERING ?
                            (this.language === 'zh' ? '停止发现' : 'Stop') :
                            (this.language === 'zh' ? '重新发现' : 'Discover'));
                        Button.fontSize(Theme.LABEL_SM_FONT_SIZE);
                        Button.fontColor(Theme.PRIMARY);
                        Button.backgroundColor('rgba(70, 72, 212, 0.08)');
                        Button.enabled(!this.isWriteBusy());
                        Button.onClick(() => {
                            if (this.cardStore.discoveryState ===
                                PhysicalCardDiscoveryState.DISCOVERING) {
                                this.cardStore.stopPhysicalCardDiscovery();
                            }
                            else {
                                this.cardStore.startPhysicalCardDiscovery();
                            }
                        });
                    }, Button);
                    Button.pop();
                });
            }
        }, If);
        If.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.cardStore.primaryPhysicalCard) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.PrimaryWriteTarget.bind(this)(this.cardStore.primaryPhysicalCard);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Scroll.create();
                        Scroll.height(300);
                        Scroll.scrollBar(BarState.Off);
                        Scroll.margin({ top: Theme.SPACING_LG });
                    }, Scroll);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create();
                        Column.width('100%');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const card = _item;
                            this.PhysicalCardChoice.bind(this)(card);
                        };
                        this.forEachUpdateFunction(elmtId, this.cardStore.discoveredPhysicalCards, forEachItemGenFunction, (card: PhysicalCard) => card.physicalCardId, false, false);
                    }, ForEach);
                    ForEach.pop();
                    Column.pop();
                    Scroll.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isSelectedPhysicalCardConnected()) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.SelectedPhysicalCardSummary.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.physicalOperationMessage.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.physicalOperationMessage);
                        Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
                        Text.fontColor(this.currentCard().credentialBindingStatus ===
                            CredentialBindingStatus.WRITTEN ? Theme.PRIMARY : Theme.ERROR);
                        Text.textAlign(TextAlign.Center);
                        Text.width('100%');
                        Text.margin({ top: Theme.SPACING_MD });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: Theme.SPACING_SM });
            Row.width('100%');
            Row.margin({ top: Theme.SPACING_LG });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.language === 'zh' ? '取消' : 'Cancel');
            Button.layoutWeight(1);
            Button.height(48);
            Button.onClick(() => {
                this.closeWriteCardFlow();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.writePrimaryButtonText());
            Button.layoutWeight(1);
            Button.height(48);
            Button.enabled(this.canConfirmWrite());
            Button.backgroundColor(Theme.PRIMARY);
            Button.onClick(() => {
                this.confirmCredentialWrite().catch(() => {
                    this.physicalOperationMessage = this.language === 'zh' ?
                        '写入失败，请稍后重试' : 'Write failed. Try again later.';
                });
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
        Stack.pop();
    }
    PrimaryWriteTarget(card: PhysicalCard, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(Theme.SPACING_LG);
            Row.margin({ top: Theme.SPACING_LG });
            Row.backgroundColor(Theme.SURFACE_CONTAINER_LOWEST);
            Row.borderRadius(Theme.RADIUS_LG);
            Row.borderWidth(1);
            Row.borderColor('rgba(199, 196, 215, 0.2)');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '当前主要实体卡' : 'Current primary card');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(card.displayName);
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(card.anonymousIdentifier);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.physicalCardConnectionText(card));
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(card.connectionState ===
                PhysicalCardConnectionState.CONNECTED ? Theme.PRIMARY :
                Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        Row.pop();
    }
    PhysicalCardChoice(card: PhysicalCard, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(Theme.SPACING_MD);
            Row.margin({ bottom: Theme.SPACING_SM });
            Row.backgroundColor(this.selectedPhysicalCardId === card.physicalCardId ?
                'rgba(70, 72, 212, 0.12)' : Theme.SURFACE_CONTAINER_LOWEST);
            Row.borderRadius(Theme.RADIUS_MD);
            Row.borderWidth(1);
            Row.borderColor(this.selectedPhysicalCardId === card.physicalCardId ?
                Theme.PRIMARY : 'rgba(199, 196, 215, 0.2)');
            Row.enabled(!this.isWriteBusy());
            Row.onClick(() => {
                this.selectAndConnectPhysicalCard(card.physicalCardId).catch(() => {
                    this.physicalOperationMessage = this.language === 'zh' ?
                        '连接失败，请重试' : 'Connection failed. Try again.';
                });
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(card.displayName);
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${card.usedCapacity}/${card.totalCapacity} · ${card.firmwareVersion}`);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ top: 2 });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.physicalCardConnectionText(card));
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor(card.connectionState ===
                PhysicalCardConnectionState.CONNECTED ? Theme.PRIMARY :
                Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        Row.pop();
    }
    SelectedPhysicalCardSummary(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.padding(Theme.SPACING_MD);
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            Column.borderRadius(Theme.RADIUS_MD);
        }, Column);
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '总容量' : 'Total capacity', `${this.selectedPhysicalCard()?.totalCapacity || 0}`);
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '已使用' : 'Used', `${this.selectedPhysicalCard()?.usedCapacity || 0}`);
        this.BindingDetailRow.bind(this)(this.language === 'zh' ? '已有凭证' : 'Credentials', `${this.selectedPhysicalCard()?.credentialIds.length || 0}`);
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
            Text.create(this.currentCard().adminConfirmationRequired ?
                (this.language === 'zh' ? '管理方要求二次确认' : 'Required by administrator') :
                (this.language === 'zh' ? '需要二次验证' : 'Secondary validation required'));
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
            Toggle.create({ type: ToggleType.Switch, isOn: this.cardStore.requiresConfirmation(this.currentCard()) });
            Toggle.selectedColor(Theme.PRIMARY);
            Toggle.switchPointColor(Color.White);
            Toggle.width(44);
            Toggle.height(24);
            Toggle.enabled(!this.currentCard().adminConfirmationRequired);
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
    private openWriteCardFlow(): void {
        this.physicalOperationId++;
        this.physicalOperationMessage = '';
        this.showWriteCardModal = true;
        if (this.cardStore.primaryPhysicalCard) {
            this.selectedPhysicalCardId =
                this.cardStore.primaryPhysicalCard.physicalCardId;
            this.connectPrimaryPhysicalCard().catch(() => {
                this.physicalOperationMessage = this.language === 'zh' ?
                    '连接失败，请重试' : 'Connection failed. Try again.';
            });
        }
        else {
            this.selectedPhysicalCardId = '';
            this.cardStore.startPhysicalCardDiscovery();
        }
    }
    private closeWriteCardFlow(): void {
        if (this.isWriteBusy()) {
            this.cardStore.cancelCredentialWrite();
        }
        this.physicalOperationId++;
        this.cardStore.stopPhysicalCardDiscovery();
        this.cardStore.disconnectPhysicalCard().catch(() => {
            console.error('Unable to disconnect Mock WS63 card');
        });
        this.showWriteCardModal = false;
        this.selectedPhysicalCardId = '';
        this.physicalOperationMessage = '';
    }
    private stopPhysicalCardFlow(): void {
        this.physicalOperationId++;
        this.cardStore.stopPhysicalCardDiscovery();
        if (this.isWriteBusy()) {
            this.cardStore.cancelCredentialWrite();
        }
        this.cardStore.disconnectPhysicalCard().catch(() => {
            console.error('Unable to disconnect Mock WS63 card');
        });
    }
    private async selectAndConnectPhysicalCard(physicalCardId: string): Promise<void> {
        if (this.isWriteBusy()) {
            return;
        }
        const operationId: number = ++this.physicalOperationId;
        this.selectedPhysicalCardId = physicalCardId;
        this.physicalOperationMessage = this.language === 'zh' ?
            '正在绑定主要实体卡…' : 'Binding the primary physical card…';
        const bindingResult: PrimaryPhysicalCardBindingResult = await this.cardStore.bindPrimaryPhysicalCard(physicalCardId);
        if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
            return;
        }
        if (!bindingResult.success) {
            this.physicalOperationMessage =
                this.physicalCardErrorText(bindingResult.reason);
            return;
        }
        this.selectedPhysicalCardId = physicalCardId;
        this.physicalOperationMessage = this.language === 'zh' ?
            '主要实体卡已绑定，正在连接…' :
            'Primary card bound. Connecting…';
        const result: PhysicalCardConnectionResult = await this.cardStore.connectPhysicalCard(physicalCardId);
        if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
            return;
        }
        if (result.state === PhysicalCardConnectionState.CONNECTED) {
            this.physicalOperationMessage = this.language === 'zh' ?
                '主要实体卡已连接，请确认容量后写入' :
                'Primary card connected. Review capacity before writing.';
            return;
        }
        this.physicalOperationMessage =
            this.physicalCardErrorText(result.reason);
    }
    private async connectPrimaryPhysicalCard(): Promise<void> {
        if (!this.cardStore.primaryPhysicalCard || this.isWriteBusy()) {
            return;
        }
        await this.selectAndConnectBoundPrimary(this.cardStore.primaryPhysicalCard.physicalCardId);
    }
    private async selectAndConnectBoundPrimary(physicalCardId: string): Promise<void> {
        const operationId: number = ++this.physicalOperationId;
        this.selectedPhysicalCardId = physicalCardId;
        this.physicalOperationMessage = this.language === 'zh' ?
            '正在连接主要实体卡…' : 'Connecting to the primary card…';
        const result: PhysicalCardConnectionResult = await this.cardStore.connectPhysicalCard(physicalCardId);
        if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
            return;
        }
        if (result.state === PhysicalCardConnectionState.CONNECTED) {
            this.physicalOperationMessage = this.language === 'zh' ?
                '主要实体卡已连接，请确认容量后写入' :
                'Primary card connected. Review capacity before writing.';
            return;
        }
        this.physicalOperationMessage =
            this.physicalCardErrorText(result.reason);
    }
    private async confirmCredentialWrite(): Promise<void> {
        if (!this.canConfirmWrite()) {
            return;
        }
        const operationId: number = ++this.physicalOperationId;
        this.physicalOperationMessage = this.language === 'zh' ?
            '正在生成并写入 Mock Credential…' :
            'Generating and writing the Mock credential…';
        const result: CredentialWriteResult = await this.cardStore.writeCardToPrimaryPhysicalCard(this.currentCard().id);
        if (!this.showWriteCardModal || operationId !== this.physicalOperationId) {
            return;
        }
        if (result.status === CredentialBindingStatus.WRITTEN &&
            result.reason === PhysicalCardFailureReason.NONE) {
            this.physicalOperationMessage = this.language === 'zh' ?
                '凭证写入并校验成功' : 'Credential written and verified';
            return;
        }
        this.physicalOperationMessage =
            this.physicalCardErrorText(result.reason);
    }
    private selectedPhysicalCard(): PhysicalCard | null {
        return this.cardStore.getPhysicalCard(this.selectedPhysicalCardId);
    }
    private canConfirmWrite(): boolean {
        const physicalCard: PhysicalCard | null = this.selectedPhysicalCard();
        if (!physicalCard || this.isWriteBusy()) {
            return false;
        }
        if (this.currentCard().credentialBindingStatus ===
            CredentialBindingStatus.WRITTEN) {
            return false;
        }
        return physicalCard.connectionState ===
            PhysicalCardConnectionState.CONNECTED;
    }
    private isSelectedPhysicalCardConnected(): boolean {
        const card: PhysicalCard | null = this.selectedPhysicalCard();
        return card !== null &&
            card.connectionState === PhysicalCardConnectionState.CONNECTED;
    }
    private isWriteBusy(): boolean {
        return this.cardStore.activeWriteStatus === CredentialBindingStatus.CONNECTING ||
            this.cardStore.activeWriteStatus === CredentialBindingStatus.WRITING ||
            this.cardStore.activeWriteStatus === CredentialBindingStatus.VERIFYING;
    }
    private writePrimaryButtonText(): string {
        if (this.cardStore.activeWriteStatus === CredentialBindingStatus.VERIFYING) {
            return this.language === 'zh' ? '校验中…' : 'Verifying…';
        }
        if (this.cardStore.activeWriteStatus === CredentialBindingStatus.WRITING) {
            return this.language === 'zh' ? '写入中…' : 'Writing…';
        }
        if (this.currentCard().credentialBindingStatus ===
            CredentialBindingStatus.WRITTEN) {
            return this.language === 'zh' ? '已写入' : 'Written';
        }
        return this.language === 'zh' ? '确认写入' : 'Write credential';
    }
    private discoveryStatusText(): string {
        if (this.cardStore.primaryPhysicalCard) {
            if (this.cardStore.connectionState ===
                PhysicalCardConnectionState.CONNECTING) {
                return this.language === 'zh' ?
                    '正在连接当前主要实体卡…' : 'Connecting to the current primary card…';
            }
            return this.language === 'zh' ?
                '许可将直接写入当前主要实体卡' :
                'This authorization will be written to the current primary card';
        }
        if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.DISCOVERING) {
            return this.language === 'zh' ? '正在发现虚拟实体卡…' : 'Discovering virtual cards…';
        }
        if (this.cardStore.discoveryState === PhysicalCardDiscoveryState.NO_DEVICE) {
            return this.language === 'zh' ? '未发现实体卡' : 'No physical card found';
        }
        if (this.cardStore.discoveryState ===
            PhysicalCardDiscoveryState.DISCOVERY_FAILED) {
            return this.language === 'zh' ? '实体卡发现失败' : 'Discovery failed';
        }
        return this.language === 'zh' ?
            '请选择一张实体卡并建立 Mock 连接' :
            'Select a card and establish a Mock connection';
    }
    private physicalCardConnectionText(card: PhysicalCard): string {
        if (card.connectionState === PhysicalCardConnectionState.CONNECTED) {
            return this.language === 'zh' ? '已连接' : 'Connected';
        }
        if (card.connectionState === PhysicalCardConnectionState.CONNECTING) {
            return this.language === 'zh' ? '连接中' : 'Connecting';
        }
        if (card.connectionState ===
            PhysicalCardConnectionState.CONNECTION_FAILED) {
            return this.language === 'zh' ? '连接失败' : 'Connection failed';
        }
        return this.language === 'zh' ? '选择' : 'Select';
    }
    private physicalCardErrorText(reason: PhysicalCardFailureReason): string {
        if (reason === PhysicalCardFailureReason.NO_DEVICE) {
            return this.language === 'zh' ? '未发现实体卡' : 'No physical card found';
        }
        if (reason === PhysicalCardFailureReason.DISCOVERY_FAILED) {
            return this.language === 'zh' ? '实体卡发现失败' : 'Discovery failed';
        }
        if (reason === PhysicalCardFailureReason.CONNECTION_FAILED) {
            return this.language === 'zh' ? '无法连接这张实体卡' : 'Unable to connect to this card';
        }
        if (reason === PhysicalCardFailureReason.CONNECTION_INTERRUPTED) {
            return this.language === 'zh' ? '连接过程中断' : 'Connection was interrupted';
        }
        if (reason === PhysicalCardFailureReason.CAPACITY_FULL) {
            return this.language === 'zh' ?
                '主要实体卡容量不足，请删除不需要的凭证或更换实体卡' :
                'The primary card is full. Remove an unused credential or replace the card.';
        }
        if (reason === PhysicalCardFailureReason.ALREADY_WRITTEN) {
            return this.language === 'zh' ?
                '该许可已经写入当前实体卡' :
                'This authorization is already on the card';
        }
        if (reason === PhysicalCardFailureReason.TRANSLATION_FAILED) {
            return this.language === 'zh' ?
                '无法生成实体卡凭证' : 'Unable to translate the credential';
        }
        if (reason === PhysicalCardFailureReason.VERIFICATION_FAILED) {
            return this.language === 'zh' ?
                '写后校验失败，可以重新尝试' :
                'Post-write verification failed. You can retry.';
        }
        if (reason === PhysicalCardFailureReason.PERSISTENCE_FAILED) {
            return this.language === 'zh' ?
                '保存 Mock 写卡结果失败，本次写入已回滚' :
                'Mock persistence failed. This write was rolled back.';
        }
        if (reason === PhysicalCardFailureReason.DEVICE_OFFLINE) {
            return this.language === 'zh' ?
                '实体卡在写入过程中离线' : 'The physical card went offline during writing';
        }
        if (reason === PhysicalCardFailureReason.CANCELLED) {
            return this.language === 'zh' ? '已取消写入' : 'Write cancelled';
        }
        if (reason === PhysicalCardFailureReason.NOT_CONNECTED) {
            return this.language === 'zh' ? '请先连接实体卡' : 'Connect the card first';
        }
        return this.language === 'zh' ?
            '写入失败，可以重新尝试' : 'Write failed. You can retry.';
    }
    private bindingStatusText(): string {
        const status: CredentialBindingStatus = this.currentCard().credentialBindingStatus;
        if (status === CredentialBindingStatus.WRITTEN) {
            return this.language === 'zh' ? '已写入实体卡' : 'Written to a physical card';
        }
        if (status === CredentialBindingStatus.WRITING ||
            status === CredentialBindingStatus.VERIFYING) {
            return this.language === 'zh' ? '正在写入' : 'Writing';
        }
        if (status === CredentialBindingStatus.WRITE_FAILED) {
            return this.language === 'zh' ? '写入失败' : 'Write failed';
        }
        if (status === CredentialBindingStatus.UPDATE_REQUIRED) {
            return this.language === 'zh' ? '凭证需要更新' : 'Credential update required';
        }
        if (status === CredentialBindingStatus.REMOVED) {
            return this.language === 'zh' ? '凭证已从实体卡删除' : 'Credential removed';
        }
        return this.language === 'zh' ? '尚未写入实体卡' : 'Not written to a physical card';
    }
    private bindingDescription(): string {
        if (this.currentCard().credentialBindingStatus ===
            CredentialBindingStatus.WRITTEN) {
            return this.language === 'zh' ?
                '授权保存在手机端，实体卡仅保存转译后的凭证材料。' :
                'The phone retains the authorization; WS63 stores only translated credential material.';
        }
        return this.language === 'zh' ?
            '授权有效，可选择一张 WS63 实体卡写入凭证。' :
            'The authorization is valid and can be written to a WS63 card.';
    }
    private boundPhysicalCardName(): string {
        const card: PhysicalCard | null = this.cardStore.getPhysicalCard(this.currentCard().physicalCardId);
        return card ? card.displayName : '-';
    }
    private boundPhysicalCardIdentifier(): string {
        const card: PhysicalCard | null = this.cardStore.getPhysicalCard(this.currentCard().physicalCardId);
        return card ? card.anonymousIdentifier : '****';
    }
    private boundCredential(): Credential | null {
        return this.cardStore.getCredentialForCard(this.currentCard());
    }
    private boundCredentialWrittenAt(): string {
        const credential: Credential | null = this.boundCredential();
        return credential && credential.writtenAt.length > 0 ?
            credential.writtenAt.substring(0, 19) : '-';
    }
    private boundCredentialVersion(): string {
        const credential: Credential | null = this.boundCredential();
        return credential ? `v${credential.credentialVersion}` : '-';
    }
    private boundCredentialVerifiedAt(): string {
        const credential: Credential | null = this.boundCredential();
        return credential && credential.verifiedAt.length > 0 ?
            credential.verifiedAt.substring(0, 19) : '-';
    }
    private currentCardIndex(): number {
        let selectedIndex: number = 0;
        this.cardStore.cards.forEach((card: DigitalCard, index: number) => {
            if (card.id === this.selectedCardId) {
                selectedIndex = index;
            }
        });
        return selectedIndex;
    }
    private usesSplitLayout(): boolean {
        return this.isTablet && this.windowWidth >= 840;
    }
    private tabletCardColumnWidth(): number {
        return this.windowWidth >= 1200 ? 420 : 340;
    }
    private currentCard(): DigitalCard {
        return this.cardStore.cards[this.currentCardIndex()];
    }
    private maskedCardNumber(): string {
        const number: string = this.currentCard().anonymousNumber.split(' ').join('');
        return `•••• •••• •••• ${number.slice(-4)}`;
    }
    private updateNickname(value: string): void {
        this.cardStore.updateNickname(this.currentCard().id, value);
    }
    private updateCategory(value: string): void {
        this.cardStore.updateCategory(this.currentCard().id, value);
    }
    private updateEnabled(isOn: boolean): void {
        this.cardStore.updateEnabled(this.currentCard().id, isOn);
    }
    private updateTwoFactor(isOn: boolean): void {
        this.cardStore.updateUserConfirmation(this.currentCard().id, isOn);
    }
    rerender() {
        this.updateDirtyElements();
    }
}
