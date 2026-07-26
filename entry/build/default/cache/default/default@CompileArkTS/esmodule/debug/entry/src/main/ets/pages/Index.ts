if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    currentIndex?: number;
    showAddCardModal?: boolean;
    language?: string;
    showLanguagePage?: boolean;
    showCardDetailPage?: boolean;
    showMockSettingsPage?: boolean;
    showVerificationDialog?: boolean;
    slideProgress?: number;
    verificationPending?: boolean;
    verificationCardId?: string;
    selectedCardId?: string;
    cards?: CardModel[];
}
import { BottomNavBar } from "@normalized:N&&&entry/src/main/ets/components/BottomNavBar&";
import { CardsPage } from "@normalized:N&&&entry/src/main/ets/pages/CardsPage&";
import { CardDetailPage } from "@normalized:N&&&entry/src/main/ets/pages/CardDetailPage&";
import { ProfilePage } from "@normalized:N&&&entry/src/main/ets/pages/ProfilePage&";
import { LanguagePage } from "@normalized:N&&&entry/src/main/ets/pages/LanguagePage&";
import { MockSettingsPage } from "@normalized:N&&&entry/src/main/ets/pages/MockSettingsPage&";
import type { CardModel } from '../common/CardModel';
import { CardPreview } from "@normalized:N&&&entry/src/main/ets/components/CardPreview&";
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__currentIndex = new ObservedPropertySimplePU(0, this, "currentIndex");
        this.__showAddCardModal = new ObservedPropertySimplePU(false, this, "showAddCardModal");
        this.__language = new ObservedPropertySimplePU('zh', this, "language");
        this.__showLanguagePage = new ObservedPropertySimplePU(false, this, "showLanguagePage");
        this.__showCardDetailPage = new ObservedPropertySimplePU(false, this, "showCardDetailPage");
        this.__showMockSettingsPage = new ObservedPropertySimplePU(false, this, "showMockSettingsPage");
        this.__showVerificationDialog = new ObservedPropertySimplePU(false, this, "showVerificationDialog");
        this.__slideProgress = new ObservedPropertySimplePU(0, this, "slideProgress");
        this.__verificationPending = this.createStorageLink('verificationPending', false, "verificationPending");
        this.__verificationCardId = this.createStorageLink('verificationCardId', '2', "verificationCardId");
        this.__selectedCardId = new ObservedPropertySimplePU('2', this, "selectedCardId");
        this.__cards = new ObservedPropertyObjectPU([
            {
                id: '1',
                name: 'Identity Card',
                issuer: 'SleKey Identity Services',
                cardNumber: '8820 1104 7312',
                twoFactorEnabled: true,
                nickname: 'My Identity',
                detail: 'Digital identification',
                category: 'Identity',
                enabled: true,
                icon: { "id": 125834962, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                accentColor: Theme.PRIMARY
            },
            {
                id: '2',
                name: 'MTR Ticket',
                issuer: 'Hong Kong Transport',
                cardNumber: '0021 4521 4422',
                twoFactorEnabled: true,
                nickname: 'Metro',
                detail: 'Ticket pass for MTR',
                category: 'Traffic',
                enabled: true,
                icon: { "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                accentColor: Theme.SECONDARY
            },
            {
                id: '3',
                name: 'Access Key',
                issuer: 'SleKey Workplace',
                cardNumber: '4108 7621 0096',
                twoFactorEnabled: false,
                nickname: 'Office',
                detail: 'Smart office entry',
                category: 'Access',
                enabled: true,
                icon: { "id": 125832254, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                accentColor: Theme.TERTIARY
            }
        ], this, "cards");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.currentIndex !== undefined) {
            this.currentIndex = params.currentIndex;
        }
        if (params.showAddCardModal !== undefined) {
            this.showAddCardModal = params.showAddCardModal;
        }
        if (params.language !== undefined) {
            this.language = params.language;
        }
        if (params.showLanguagePage !== undefined) {
            this.showLanguagePage = params.showLanguagePage;
        }
        if (params.showCardDetailPage !== undefined) {
            this.showCardDetailPage = params.showCardDetailPage;
        }
        if (params.showMockSettingsPage !== undefined) {
            this.showMockSettingsPage = params.showMockSettingsPage;
        }
        if (params.showVerificationDialog !== undefined) {
            this.showVerificationDialog = params.showVerificationDialog;
        }
        if (params.slideProgress !== undefined) {
            this.slideProgress = params.slideProgress;
        }
        if (params.selectedCardId !== undefined) {
            this.selectedCardId = params.selectedCardId;
        }
        if (params.cards !== undefined) {
            this.cards = params.cards;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__currentIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__showAddCardModal.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showLanguagePage.purgeDependencyOnElmtId(rmElmtId);
        this.__showCardDetailPage.purgeDependencyOnElmtId(rmElmtId);
        this.__showMockSettingsPage.purgeDependencyOnElmtId(rmElmtId);
        this.__showVerificationDialog.purgeDependencyOnElmtId(rmElmtId);
        this.__slideProgress.purgeDependencyOnElmtId(rmElmtId);
        this.__verificationPending.purgeDependencyOnElmtId(rmElmtId);
        this.__verificationCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__cards.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__currentIndex.aboutToBeDeleted();
        this.__showAddCardModal.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__showLanguagePage.aboutToBeDeleted();
        this.__showCardDetailPage.aboutToBeDeleted();
        this.__showMockSettingsPage.aboutToBeDeleted();
        this.__showVerificationDialog.aboutToBeDeleted();
        this.__slideProgress.aboutToBeDeleted();
        this.__verificationPending.aboutToBeDeleted();
        this.__verificationCardId.aboutToBeDeleted();
        this.__selectedCardId.aboutToBeDeleted();
        this.__cards.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __currentIndex: ObservedPropertySimplePU<number>;
    get currentIndex() {
        return this.__currentIndex.get();
    }
    set currentIndex(newValue: number) {
        this.__currentIndex.set(newValue);
    }
    private __showAddCardModal: ObservedPropertySimplePU<boolean>;
    get showAddCardModal() {
        return this.__showAddCardModal.get();
    }
    set showAddCardModal(newValue: boolean) {
        this.__showAddCardModal.set(newValue);
    }
    private __language: ObservedPropertySimplePU<string>;
    get language() {
        return this.__language.get();
    }
    set language(newValue: string) {
        this.__language.set(newValue);
    }
    private __showLanguagePage: ObservedPropertySimplePU<boolean>;
    get showLanguagePage() {
        return this.__showLanguagePage.get();
    }
    set showLanguagePage(newValue: boolean) {
        this.__showLanguagePage.set(newValue);
    }
    private __showCardDetailPage: ObservedPropertySimplePU<boolean>;
    get showCardDetailPage() {
        return this.__showCardDetailPage.get();
    }
    set showCardDetailPage(newValue: boolean) {
        this.__showCardDetailPage.set(newValue);
    }
    private __showMockSettingsPage: ObservedPropertySimplePU<boolean>;
    get showMockSettingsPage() {
        return this.__showMockSettingsPage.get();
    }
    set showMockSettingsPage(newValue: boolean) {
        this.__showMockSettingsPage.set(newValue);
    }
    private __showVerificationDialog: ObservedPropertySimplePU<boolean>;
    get showVerificationDialog() {
        return this.__showVerificationDialog.get();
    }
    set showVerificationDialog(newValue: boolean) {
        this.__showVerificationDialog.set(newValue);
    }
    private __slideProgress: ObservedPropertySimplePU<number>;
    get slideProgress() {
        return this.__slideProgress.get();
    }
    set slideProgress(newValue: number) {
        this.__slideProgress.set(newValue);
    }
    private __verificationPending: ObservedPropertyAbstractPU<boolean>;
    get verificationPending() {
        return this.__verificationPending.get();
    }
    set verificationPending(newValue: boolean) {
        this.__verificationPending.set(newValue);
    }
    private __verificationCardId: ObservedPropertyAbstractPU<string>;
    get verificationCardId() {
        return this.__verificationCardId.get();
    }
    set verificationCardId(newValue: string) {
        this.__verificationCardId.set(newValue);
    }
    private __selectedCardId: ObservedPropertySimplePU<string>;
    get selectedCardId() {
        return this.__selectedCardId.get();
    }
    set selectedCardId(newValue: string) {
        this.__selectedCardId.set(newValue);
    }
    private __cards: ObservedPropertyObjectPU<CardModel[]>;
    get cards() {
        return this.__cards.get();
    }
    set cards(newValue: CardModel[]) {
        this.__cards.set(newValue);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Bottom });
            Stack.width('100%');
            Stack.height('100%');
            Stack.backgroundColor(Theme.BACKGROUND);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // Main content area
            if (this.showCardDetailPage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new CardDetailPage(this, {
                                    cards: this.__cards,
                                    language: this.__language,
                                    showCardDetailPage: this.__showCardDetailPage,
                                    selectedCardId: this.__selectedCardId
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 71, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        cards: this.cards,
                                        language: this.language,
                                        showCardDetailPage: this.showCardDetailPage,
                                        selectedCardId: this.selectedCardId
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "CardDetailPage" });
                    }
                });
            }
            else if (this.showLanguagePage) {
                this.ifElseBranchUpdateFunction(1, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new LanguagePage(this, { language: this.__language, showLanguagePage: this.__showLanguagePage }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 78, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        language: this.language,
                                        showLanguagePage: this.showLanguagePage
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "LanguagePage" });
                    }
                });
            }
            else if (this.showMockSettingsPage) {
                this.ifElseBranchUpdateFunction(2, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new MockSettingsPage(this, {
                                    language: this.__language,
                                    showMockSettingsPage: this.__showMockSettingsPage,
                                    showVerificationDialog: this.__showVerificationDialog
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 80, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        language: this.language,
                                        showMockSettingsPage: this.showMockSettingsPage,
                                        showVerificationDialog: this.showVerificationDialog
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "MockSettingsPage" });
                    }
                });
            }
            else if (this.currentIndex === 0) {
                this.ifElseBranchUpdateFunction(3, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new CardsPage(this, {
                                    showAddCardModal: this.__showAddCardModal,
                                    language: this.__language,
                                    cards: this.__cards,
                                    showCardDetailPage: this.__showCardDetailPage,
                                    selectedCardId: this.__selectedCardId,
                                    showMockSettingsPage: this.__showMockSettingsPage
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 86, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        showAddCardModal: this.showAddCardModal,
                                        language: this.language,
                                        cards: this.cards,
                                        showCardDetailPage: this.showCardDetailPage,
                                        selectedCardId: this.selectedCardId,
                                        showMockSettingsPage: this.showMockSettingsPage
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "CardsPage" });
                    }
                });
            }
            else {
                this.ifElseBranchUpdateFunction(4, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new ProfilePage(this, { language: this.__language, showLanguagePage: this.__showLanguagePage }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 95, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        language: this.language,
                                        showLanguagePage: this.showLanguagePage
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "ProfilePage" });
                    }
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // Add Card Modal
            if (this.showAddCardModal) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.AddCardModal.bind(this)();
                });
            }
            // Bottom Navigation Bar
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // Bottom Navigation Bar
            if (!this.showLanguagePage && !this.showCardDetailPage && !this.showMockSettingsPage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new BottomNavBar(this, { currentIndex: this.__currentIndex, language: this.__language }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 105, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        currentIndex: this.currentIndex,
                                        language: this.language
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "BottomNavBar" });
                    }
                });
            }
            // SLE verification request overlay
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // SLE verification request overlay
            if (this.showVerificationDialog || this.verificationPending) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.VerificationDialog.bind(this)();
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
    VerificationDialog(parent = null) {
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
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('90%');
            Column.constraintSize({ maxWidth: 460 });
            Column.padding(Theme.SPACING_LG);
            Column.backgroundColor('rgba(248, 249, 250, 0.94)');
            Column.backdropBlur(40);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(255, 255, 255, 0.75)');
            Column.shadow({ radius: 48, color: 'rgba(0, 0, 0, 0.2)', offsetY: 12 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '二次验证' : 'Secondary Verification');
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.textAlign(TextAlign.Center);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '请核对卡片信息，并滑动确认本次连接。' :
                'Review the card information, then slide to approve this connection.');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.textAlign(TextAlign.Center);
            Text.width('100%');
            Text.margin({ top: Theme.SPACING_XS, bottom: Theme.SPACING_LG });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.width('100%');
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new CardPreview(this, { card: this.verificationCard(), language: this.language }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 143, col: 9 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            card: this.verificationCard(),
                            language: this.language
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        card: this.verificationCard(), language: this.language
                    });
                }
            }, { name: "CardPreview" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Center });
            Stack.width('100%');
            Stack.height(56);
            Stack.margin({ top: Theme.SPACING_LG });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '滑动以同意  →' : 'Slide to approve  →');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(this.slideProgress > 54 ? Theme.ON_PRIMARY : Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Slider.create({
                value: this.slideProgress,
                min: 0,
                max: 100,
                step: 1,
                style: SliderStyle.InSet,
                direction: Axis.Horizontal,
                reverse: false
            });
            Slider.width('100%');
            Slider.height(56);
            Slider.selectedColor(Theme.PRIMARY);
            Slider.trackColor(Theme.SURFACE_CONTAINER_HIGH);
            Slider.blockColor(Color.White);
            Slider.trackThickness(52);
            Slider.blockSize({ width: 44, height: 44 });
            Slider.onChange((value: number) => {
                this.slideProgress = value;
                if (value >= 98) {
                    this.approveVerification();
                }
            });
        }, Slider);
        Stack.pop();
        Column.pop();
        Stack.pop();
    }
    private verificationCard(): CardModel {
        let result: CardModel = this.cards[0];
        this.cards.forEach((card: CardModel) => {
            if (card.id === this.verificationCardId) {
                result = card;
            }
        });
        return result;
    }
    private approveVerification(): void {
        this.verificationPending = false;
        this.showVerificationDialog = false;
        this.slideProgress = 0;
        try {
            this.getUIContext().getPromptAction().showToast({
                message: this.language === 'zh' ? '已同意二次验证' : 'Verification approved'
            });
        }
        catch (error) {
            console.error(`Unable to show verification result: ${JSON.stringify(error)}`);
        }
    }
    AddCardModal(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Backdrop
            Column.create();
            // Backdrop
            Column.width('100%');
            // Backdrop
            Column.height('100%');
            // Backdrop
            Column.backgroundColor('rgba(0, 0, 0, 0.4)');
            // Backdrop
            Column.onClick(() => {
                this.showAddCardModal = false;
            });
        }, Column);
        // Backdrop
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Modal content
            Column.create();
            // Modal content
            Column.width('90%');
            // Modal content
            Column.padding(Theme.SPACING_XL);
            // Modal content
            Column.backgroundColor(Theme.SURFACE);
            // Modal content
            Column.borderRadius(Theme.RADIUS_MD);
            // Modal content
            Column.shadow({
                radius: 40,
                color: 'rgba(0, 0, 0, 0.08)',
                offsetY: 12
            });
            // Modal content
            Column.position({ x: '50%', y: '50%' });
            // Modal content
            Column.translate({ x: '-50%', y: '-50%' });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Header
            Column.create();
            // Header
            Column.width('100%');
            // Header
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '添加卡片' : 'Add Card');
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '输入卡片信息以完成关联' : 'Enter card information to link it');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.opacity(0.7);
            Text.textAlign(TextAlign.Center);
            Text.margin({ top: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        // Header
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Input section
            Column.create();
            // Input section
            Column.width('100%');
            // Input section
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.End });
            Stack.width('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ placeholder: this.language === 'zh' ? '请输入卡片代号' : 'Enter card code' });
            TextInput.width('100%');
            TextInput.height(56);
            TextInput.fontSize(Theme.BODY_LG_FONT_SIZE);
            TextInput.fontColor(Theme.ON_SURFACE);
            TextInput.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            TextInput.borderRadius(Theme.RADIUS_DEFAULT);
            TextInput.padding({ left: Theme.SPACING_MD, right: Theme.SPACING_MD + Theme.ICON_MD + Theme.SPACING_XS });
            TextInput.placeholderColor('rgba(70, 69, 84, 0.4)');
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832318, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_MD);
            SymbolGlyph.fontColor([Theme.ON_SURFACE_VARIANT]);
            SymbolGlyph.margin({ right: Theme.SPACING_MD });
        }, SymbolGlyph);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.margin({ top: Theme.SPACING_XS });
            Row.padding({ left: Theme.SPACING_BASE });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832644, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_SM);
            SymbolGlyph.fontColor(['rgba(70, 69, 84, 0.6)']);
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '代号通常位于卡片背面' : 'The code is usually on the back of the card');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor('rgba(70, 69, 84, 0.6)');
            Text.margin({ left: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        Row.pop();
        // Input section
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Action buttons
            Row.create();
            // Action buttons
            Row.width('100%');
            // Action buttons
            Row.margin({ top: Theme.SPACING_XL });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.language === 'zh' ? '取消' : 'Cancel');
            Button.flexGrow(1);
            Button.height(48);
            Button.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Button.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Button.fontColor(Theme.ON_SURFACE_VARIANT);
            Button.backgroundColor(Theme.SURFACE_CONTAINER_HIGH);
            Button.borderRadius(Theme.RADIUS_DEFAULT);
            Button.borderWidth(1);
            Button.borderColor('rgba(199, 196, 215, 0.3)');
            Button.onClick(() => {
                this.showAddCardModal = false;
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.language === 'zh' ? '确认' : 'Confirm');
            Button.flexGrow(1);
            Button.height(48);
            Button.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Button.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Button.fontColor(Theme.ON_PRIMARY);
            Button.backgroundColor(Theme.PRIMARY);
            Button.borderRadius(Theme.RADIUS_DEFAULT);
            Button.shadow({
                radius: 16,
                color: 'rgba(70, 72, 212, 0.3)',
                offsetY: 4
            });
            Button.margin({ left: Theme.SPACING_MD });
            Button.onClick(() => {
                this.showAddCardModal = false;
            });
        }, Button);
        Button.pop();
        // Action buttons
        Row.pop();
        // Modal content
        Column.pop();
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.slekey.app", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
