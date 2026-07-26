if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CardsPage_Params {
    showAddCardModal?: boolean;
    language?: string;
    cardStore?: CardStore;
    showCardDetailPage?: boolean;
    selectedCardId?: string;
    showMockSettingsPage?: boolean;
    showPhysicalCardManagerPage?: boolean;
    isTablet?: boolean;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import type { DigitalCard } from '../models/DigitalCard';
import type { CardStore } from '../stores/CardStore';
import { CardPreview } from "@normalized:N&&&entry/src/main/ets/components/CardPreview&";
export class CardsPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__showAddCardModal = new SynchedPropertySimpleTwoWayPU(params.showAddCardModal, this, "showAddCardModal");
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__cardStore = new SynchedPropertyNesedObjectPU(params.cardStore, this, "cardStore");
        this.__showCardDetailPage = new SynchedPropertySimpleTwoWayPU(params.showCardDetailPage, this, "showCardDetailPage");
        this.__selectedCardId = new SynchedPropertySimpleTwoWayPU(params.selectedCardId, this, "selectedCardId");
        this.__showMockSettingsPage = new SynchedPropertySimpleTwoWayPU(params.showMockSettingsPage, this, "showMockSettingsPage");
        this.__showPhysicalCardManagerPage = new SynchedPropertySimpleTwoWayPU(params.showPhysicalCardManagerPage, this, "showPhysicalCardManagerPage");
        this.__isTablet = new SynchedPropertySimpleOneWayPU(params.isTablet, this, "isTablet");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CardsPage_Params) {
        this.__cardStore.set(params.cardStore);
        if (params.isTablet === undefined) {
            this.__isTablet.set(false);
        }
    }
    updateStateVars(params: CardsPage_Params) {
        this.__cardStore.set(params.cardStore);
        this.__isTablet.reset(params.isTablet);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__showAddCardModal.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__cardStore.purgeDependencyOnElmtId(rmElmtId);
        this.__showCardDetailPage.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__showMockSettingsPage.purgeDependencyOnElmtId(rmElmtId);
        this.__showPhysicalCardManagerPage.purgeDependencyOnElmtId(rmElmtId);
        this.__isTablet.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__showAddCardModal.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__cardStore.aboutToBeDeleted();
        this.__showCardDetailPage.aboutToBeDeleted();
        this.__selectedCardId.aboutToBeDeleted();
        this.__showMockSettingsPage.aboutToBeDeleted();
        this.__showPhysicalCardManagerPage.aboutToBeDeleted();
        this.__isTablet.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __showAddCardModal: SynchedPropertySimpleTwoWayPU<boolean>;
    get showAddCardModal() {
        return this.__showAddCardModal.get();
    }
    set showAddCardModal(newValue: boolean) {
        this.__showAddCardModal.set(newValue);
    }
    private __language: SynchedPropertySimpleTwoWayPU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    private __cardStore: SynchedPropertyNesedObjectPU<CardStore>;
    get cardStore() {
        return this.__cardStore.get();
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
    private __showMockSettingsPage: SynchedPropertySimpleTwoWayPU<boolean>;
    get showMockSettingsPage() {
        return this.__showMockSettingsPage.get();
    }
    set showMockSettingsPage(newValue: boolean) {
        this.__showMockSettingsPage.set(newValue);
    }
    private __showPhysicalCardManagerPage: SynchedPropertySimpleTwoWayPU<boolean>;
    get showPhysicalCardManagerPage() {
        return this.__showPhysicalCardManagerPage.get();
    }
    set showPhysicalCardManagerPage(newValue: boolean) {
        this.__showPhysicalCardManagerPage.set(newValue);
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
            Column.height('100%');
            Column.justifyContent(FlexAlign.Start);
            Column.alignItems(HorizontalAlign.Start);
            Column.padding({ top: Theme.STATUS_BAR_PADDING });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // Phone keeps the top app bar; tablet actions live in the side navigation.
            if (!this.isTablet) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.TopAppBar.bind(this)();
                });
            }
            // Scrollable content
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Scrollable content
            Scroll.create();
            // Scrollable content
            Scroll.layoutWeight(1);
            // Scrollable content
            Scroll.width('100%');
            // Scrollable content
            Scroll.align(Alignment.TopStart);
            // Scrollable content
            Scroll.alignSelf(ItemAlign.Start);
            // Scrollable content
            Scroll.scrollBar(BarState.Off);
            // Scrollable content
            Scroll.edgeEffect(EdgeEffect.Spring);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.justifyContent(FlexAlign.Start);
            Column.alignItems(HorizontalAlign.Start);
            Column.padding({
                left: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN,
                right: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN,
                bottom: this.isTablet ? Theme.SPACING_XL : 120
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Section header
            Row.create();
            // Section header
            Row.width('100%');
            // Section header
            Row.justifyContent(FlexAlign.SpaceBetween);
            // Section header
            Row.alignItems(VerticalAlign.Bottom);
            // Section header
            Row.margin({ bottom: Theme.SPACING_LG });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '卡片管理' : 'Card Management');
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.margin({ bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '我的卡片' : 'My Cards');
            Text.fontSize(this.isTablet ? Theme.HEADLINE_LG_FONT_SIZE : Theme.HEADLINE_LG_MOBILE_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.padding({ left: Theme.SPACING_SM, right: Theme.SPACING_SM, top: Theme.SPACING_XS, bottom: Theme.SPACING_XS });
            Row.backgroundColor('rgba(70, 72, 212, 0.1)');
            Row.borderRadius(Theme.RADIUS_FULL);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.activeCountText());
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
            Text.fontColor(Theme.PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
        // Section header
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // Cards list
            if (this.isTablet) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Tablet: multi-column grid
                        GridRow.create({ columns: { sm: 2, md: 2, lg: 3 }, gutter: Theme.TABLET_CARD_GAP });
                        // Tablet: multi-column grid
                        GridRow.width('100%');
                    }, GridRow);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const card = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                GridCol.create();
                            }, GridCol);
                            this.CardItem.bind(this)(card);
                            GridCol.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.cardStore.cards, forEachItemGenFunction, (card: DigitalCard) => card.id, false, false);
                    }, ForEach);
                    ForEach.pop();
                    // Tablet: multi-column grid
                    GridRow.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // Phone: single column
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const card = _item;
                            this.CardItem.bind(this)(card);
                        };
                        this.forEachUpdateFunction(elmtId, this.cardStore.cards, forEachItemGenFunction, (card: DigitalCard) => card.id, false, false);
                    }, ForEach);
                    // Phone: single column
                    ForEach.pop();
                });
            }
        }, If);
        If.pop();
        // Security banner
        this.SecurityBanner.bind(this)();
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
            Row.padding({
                left: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN,
                right: this.isTablet ? Theme.TABLET_CONTAINER_MARGIN : Theme.CONTAINER_MARGIN
            });
            Row.backgroundColor(this.isTablet ? 'rgba(255, 255, 255, 0.58)' : 'rgba(255, 255, 255, 0.7)');
            Row.backdropBlur(this.isTablet ? 24 : 40);
            Row.borderWidth({ bottom: 1 });
            Row.borderColor('rgba(199, 196, 215, 0.1)');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (!this.isTablet) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        SymbolGlyph.create({ "id": 125831710, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
                        SymbolGlyph.fontSize(Theme.ICON_XL);
                        SymbolGlyph.fontColor([Theme.PRIMARY]);
                    }, SymbolGlyph);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.language === 'zh' ? '卡包' : 'Wallet');
                        Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
                        Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
                        Text.fontColor(Theme.PRIMARY);
                        Text.margin({ left: Theme.SPACING_SM });
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.language === 'zh' ? '我的卡片' : 'My Cards');
                        Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
                        Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
                        Text.fontColor(Theme.ON_SURFACE);
                    }, Text);
                    Text.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_XL);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
            SymbolGlyph.margin({ right: Theme.SPACING_LG });
            SymbolGlyph.onClick(() => {
                this.showPhysicalCardManagerPage = true;
            });
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125831481, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_XL);
            SymbolGlyph.fontColor([Theme.PRIMARY]);
            SymbolGlyph.onClick(() => {
                this.showAddCardModal = true;
            });
        }, SymbolGlyph);
        Row.pop();
    }
    CardItem(card: DigitalCard, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            globalThis.Context.animation({
                duration: Theme.ANIMATION_FAST_DURATION,
                curve: Curve.EaseInOut
            });
            __Common__.width('100%');
            __Common__.margin({ bottom: this.isTablet ? 0 : Theme.CARD_GAP });
            __Common__.onClick(() => {
                this.selectedCardId = card.id;
                this.showCardDetailPage = true;
            });
            __Common__.scale({ x: this.selectedCardId === card.id ? 0.97 : 1, y: this.selectedCardId === card.id ? 0.97 : 1 });
            globalThis.Context.animation(null);
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new CardPreview(this, { card: card, language: this.language, isTablet: this.isTablet }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/CardsPage.ets", line: 153, col: 5 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            card: card,
                            language: this.language,
                            isTablet: this.isTablet
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        card: card, language: this.language, isTablet: this.isTablet
                    });
                }
            }, { name: "CardPreview" });
        }
        __Common__.pop();
    }
    SecurityBanner(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width('100%');
            Stack.height(this.isTablet ? 140 : 160);
            Stack.borderRadius(Theme.RADIUS_DEFAULT);
            Stack.shadow({
                radius: 40,
                color: 'rgba(0, 0, 0, 0.2)',
                offsetY: 8
            });
            Stack.clip(true);
            Stack.margin({ top: Theme.SPACING_XL });
            Stack.backgroundImage({ "id": 16777218, "type": 20000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            Stack.backgroundImageSize(ImageSize.Cover);
            Stack.backgroundImagePosition(Alignment.Center);
            Stack.onClick(() => {
                this.showMockSettingsPage = true;
            });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.linearGradient({
                direction: GradientDirection.Bottom,
                colors: [['rgba(0, 0, 0, 0.6)', 0], ['transparent', 1]]
            });
            Column.zIndex(10);
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.alignItems(HorizontalAlign.Start);
            Column.padding(Theme.SPACING_MD);
            Column.zIndex(20);
            Column.alignSelf(ItemAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '安全至上' : 'Security First');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor('rgba(255, 255, 255, 0.8)');
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.textCase(TextCase.Normal);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '端到端加密保护' : 'Protected by end-to-end encryption');
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Color.White);
            Text.margin({ top: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        Column.pop();
        Stack.pop();
    }
    private activeCountText(): string {
        let count: number = 0;
        this.cardStore.cards.forEach((card: DigitalCard) => {
            if (this.cardStore.isCardEnabled(card)) {
                count++;
            }
        });
        return this.language === 'zh' ? `${count} 张已启用` : `${count} Enabled`;
    }
    rerender() {
        this.updateDirtyElements();
    }
}
