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
    showPhysicalCardManagerPage?: boolean;
    showVerificationDialog?: boolean;
    slideProgress?: number;
    verificationPending?: boolean;
    verificationCardId?: string;
    selectedCardId?: string;
    cardStore?: CardStore;
    windowWidth?: number;
    invitationCode?: string;
    invitationState?: InvitationFlowState;
    invitationFailureReason?: InvitationFailureReason;
    invitationPreview?: InvitationAuthorizationPreview | null;
    invitationOperationId?: number;
}
import { BottomNavBar } from "@normalized:N&&&entry/src/main/ets/components/BottomNavBar&";
import { SideNavBar } from "@normalized:N&&&entry/src/main/ets/components/SideNavBar&";
import { CardsPage } from "@normalized:N&&&entry/src/main/ets/pages/CardsPage&";
import { CardDetailPage } from "@normalized:N&&&entry/src/main/ets/pages/CardDetailPage&";
import { ProfilePage } from "@normalized:N&&&entry/src/main/ets/pages/ProfilePage&";
import { LanguagePage } from "@normalized:N&&&entry/src/main/ets/pages/LanguagePage&";
import { MockSettingsPage } from "@normalized:N&&&entry/src/main/ets/pages/MockSettingsPage&";
import { PhysicalCardManagerPage } from "@normalized:N&&&entry/src/main/ets/pages/PhysicalCardManagerPage&";
import { CardPreview } from "@normalized:N&&&entry/src/main/ets/components/CardPreview&";
import { DigitalCardStatus } from "@normalized:N&&&entry/src/main/ets/models/DigitalCard&";
import type { DigitalCard } from "@normalized:N&&&entry/src/main/ets/models/DigitalCard&";
import { CredentialBindingStatus } from "@normalized:N&&&entry/src/main/ets/models/Credential&";
import { AuthorizationAlertPolicy, AuthorizationUsageMode } from "@normalized:N&&&entry/src/main/ets/models/Authorization&";
import { InvitationFailureReason, InvitationFlowState } from "@normalized:N&&&entry/src/main/ets/models/Invitation&";
import type { InvitationAuthorizationPreview, InvitationPreviewResult, InvitationRedemptionResult } from "@normalized:N&&&entry/src/main/ets/models/Invitation&";
import { CardStore } from "@normalized:N&&&entry/src/main/ets/stores/CardStore&";
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
        this.__showPhysicalCardManagerPage = new ObservedPropertySimplePU(false, this, "showPhysicalCardManagerPage");
        this.__showVerificationDialog = new ObservedPropertySimplePU(false, this, "showVerificationDialog");
        this.__slideProgress = new ObservedPropertySimplePU(0, this, "slideProgress");
        this.__verificationPending = this.createStorageLink('verificationPending', false, "verificationPending");
        this.__verificationCardId = this.createStorageLink('verificationCardId', '2', "verificationCardId");
        this.__selectedCardId = new ObservedPropertySimplePU('2', this, "selectedCardId");
        this.__cardStore = new ObservedPropertyObjectPU(CardStore.getInstance(), this, "cardStore");
        this.__windowWidth = new ObservedPropertySimplePU(0, this, "windowWidth");
        this.__invitationCode = new ObservedPropertySimplePU('', this, "invitationCode");
        this.__invitationState = new ObservedPropertySimplePU(InvitationFlowState.IDLE, this, "invitationState");
        this.__invitationFailureReason = new ObservedPropertySimplePU(InvitationFailureReason.NONE, this, "invitationFailureReason");
        this.__invitationPreview = new ObservedPropertyObjectPU(null, this, "invitationPreview");
        this.invitationOperationId = 0;
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
        if (params.showPhysicalCardManagerPage !== undefined) {
            this.showPhysicalCardManagerPage = params.showPhysicalCardManagerPage;
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
        if (params.cardStore !== undefined) {
            this.cardStore = params.cardStore;
        }
        if (params.windowWidth !== undefined) {
            this.windowWidth = params.windowWidth;
        }
        if (params.invitationCode !== undefined) {
            this.invitationCode = params.invitationCode;
        }
        if (params.invitationState !== undefined) {
            this.invitationState = params.invitationState;
        }
        if (params.invitationFailureReason !== undefined) {
            this.invitationFailureReason = params.invitationFailureReason;
        }
        if (params.invitationPreview !== undefined) {
            this.invitationPreview = params.invitationPreview;
        }
        if (params.invitationOperationId !== undefined) {
            this.invitationOperationId = params.invitationOperationId;
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
        this.__showPhysicalCardManagerPage.purgeDependencyOnElmtId(rmElmtId);
        this.__showVerificationDialog.purgeDependencyOnElmtId(rmElmtId);
        this.__slideProgress.purgeDependencyOnElmtId(rmElmtId);
        this.__verificationPending.purgeDependencyOnElmtId(rmElmtId);
        this.__verificationCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedCardId.purgeDependencyOnElmtId(rmElmtId);
        this.__cardStore.purgeDependencyOnElmtId(rmElmtId);
        this.__windowWidth.purgeDependencyOnElmtId(rmElmtId);
        this.__invitationCode.purgeDependencyOnElmtId(rmElmtId);
        this.__invitationState.purgeDependencyOnElmtId(rmElmtId);
        this.__invitationFailureReason.purgeDependencyOnElmtId(rmElmtId);
        this.__invitationPreview.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__currentIndex.aboutToBeDeleted();
        this.__showAddCardModal.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__showLanguagePage.aboutToBeDeleted();
        this.__showCardDetailPage.aboutToBeDeleted();
        this.__showMockSettingsPage.aboutToBeDeleted();
        this.__showPhysicalCardManagerPage.aboutToBeDeleted();
        this.__showVerificationDialog.aboutToBeDeleted();
        this.__slideProgress.aboutToBeDeleted();
        this.__verificationPending.aboutToBeDeleted();
        this.__verificationCardId.aboutToBeDeleted();
        this.__selectedCardId.aboutToBeDeleted();
        this.__cardStore.aboutToBeDeleted();
        this.__windowWidth.aboutToBeDeleted();
        this.__invitationCode.aboutToBeDeleted();
        this.__invitationState.aboutToBeDeleted();
        this.__invitationFailureReason.aboutToBeDeleted();
        this.__invitationPreview.aboutToBeDeleted();
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
    private __showPhysicalCardManagerPage: ObservedPropertySimplePU<boolean>;
    get showPhysicalCardManagerPage() {
        return this.__showPhysicalCardManagerPage.get();
    }
    set showPhysicalCardManagerPage(newValue: boolean) {
        this.__showPhysicalCardManagerPage.set(newValue);
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
    private __cardStore: ObservedPropertyObjectPU<CardStore>;
    get cardStore() {
        return this.__cardStore.get();
    }
    set cardStore(newValue: CardStore) {
        this.__cardStore.set(newValue);
    }
    private __windowWidth: ObservedPropertySimplePU<number>;
    get windowWidth() {
        return this.__windowWidth.get();
    }
    set windowWidth(newValue: number) {
        this.__windowWidth.set(newValue);
    }
    private __invitationCode: ObservedPropertySimplePU<string>;
    get invitationCode() {
        return this.__invitationCode.get();
    }
    set invitationCode(newValue: string) {
        this.__invitationCode.set(newValue);
    }
    private __invitationState: ObservedPropertySimplePU<InvitationFlowState>;
    get invitationState() {
        return this.__invitationState.get();
    }
    set invitationState(newValue: InvitationFlowState) {
        this.__invitationState.set(newValue);
    }
    private __invitationFailureReason: ObservedPropertySimplePU<InvitationFailureReason>;
    get invitationFailureReason() {
        return this.__invitationFailureReason.get();
    }
    set invitationFailureReason(newValue: InvitationFailureReason) {
        this.__invitationFailureReason.set(newValue);
    }
    private __invitationPreview: ObservedPropertyObjectPU<InvitationAuthorizationPreview | null>;
    get invitationPreview() {
        return this.__invitationPreview.get();
    }
    set invitationPreview(newValue: InvitationAuthorizationPreview | null) {
        this.__invitationPreview.set(newValue);
    }
    private invitationOperationId: number;
    aboutToAppear(): void {
        this.cardStore.refresh().catch(() => {
            console.error('Unable to refresh mock card data');
        });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(Theme.BACKGROUND);
            Column.onAreaChange((_oldVal: Area, newVal: Area) => {
                this.windowWidth = newVal.width as number;
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.windowWidth >= Theme.BREAKPOINT_TABLET) {
                this.ifElseBranchUpdateFunction(0, () => {
                    // Tablet layout: side nav + content
                    this.TabletLayout.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    // Phone layout: stack + bottom nav
                    this.PhoneLayout.bind(this)();
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    TabletLayout(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.height('100%');
            Row.alignItems(VerticalAlign.Top);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // Side navigation
            if (!this.showLanguagePage && !this.showCardDetailPage &&
                !this.showMockSettingsPage && !this.showPhysicalCardManagerPage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new SideNavBar(this, {
                                    currentIndex: this.__currentIndex,
                                    language: this.__language,
                                    showAddCardModal: this.__showAddCardModal,
                                    showPhysicalCardManagerPage: this.__showPhysicalCardManagerPage
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 79, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        currentIndex: this.currentIndex,
                                        language: this.language,
                                        showAddCardModal: this.showAddCardModal,
                                        showPhysicalCardManagerPage: this.showPhysicalCardManagerPage
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "SideNavBar" });
                    }
                });
            }
            // Content area
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Content area
            Stack.create({ alignContent: Alignment.TopStart });
            // Content area
            Stack.layoutWeight(1);
            // Content area
            Stack.height('100%');
        }, Stack);
        this.ContentArea.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.showAddCardModal) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.AddCardModal.bind(this)();
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
        // Content area
        Stack.pop();
        Row.pop();
    }
    PhoneLayout(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Bottom });
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.ContentArea.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.showAddCardModal) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.AddCardModal.bind(this)();
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
            if (!this.showLanguagePage && !this.showCardDetailPage &&
                !this.showMockSettingsPage && !this.showPhysicalCardManagerPage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new BottomNavBar(this, { currentIndex: this.__currentIndex, language: this.__language }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 118, col: 9 });
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
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
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
    ContentArea(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.showCardDetailPage) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new CardDetailPage(this, {
                                    cardStore: this.cardStore,
                                    language: this.__language,
                                    showCardDetailPage: this.__showCardDetailPage,
                                    selectedCardId: this.__selectedCardId,
                                    isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
                                    windowWidth: this.windowWidth
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 132, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        cardStore: this.cardStore,
                                        language: this.language,
                                        showCardDetailPage: this.showCardDetailPage,
                                        selectedCardId: this.selectedCardId,
                                        isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
                                        windowWidth: this.windowWidth
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    cardStore: this.cardStore,
                                    isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
                                    windowWidth: this.windowWidth
                                });
                            }
                        }, { name: "CardDetailPage" });
                    }
                });
            }
            else if (this.showPhysicalCardManagerPage) {
                this.ifElseBranchUpdateFunction(1, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new PhysicalCardManagerPage(this, {
                                    cardStore: this.cardStore,
                                    language: this.__language,
                                    showPhysicalCardManagerPage: this.__showPhysicalCardManagerPage
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 141, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        cardStore: this.cardStore,
                                        language: this.language,
                                        showPhysicalCardManagerPage: this.showPhysicalCardManagerPage
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    cardStore: this.cardStore
                                });
                            }
                        }, { name: "PhysicalCardManagerPage" });
                    }
                });
            }
            else if (this.showLanguagePage) {
                this.ifElseBranchUpdateFunction(2, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new LanguagePage(this, { language: this.__language, showLanguagePage: this.__showLanguagePage }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 147, col: 7 });
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
                this.ifElseBranchUpdateFunction(3, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new MockSettingsPage(this, {
                                    language: this.__language,
                                    showMockSettingsPage: this.__showMockSettingsPage,
                                    showVerificationDialog: this.__showVerificationDialog
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 149, col: 7 });
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
                this.ifElseBranchUpdateFunction(4, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new CardsPage(this, {
                                    showAddCardModal: this.__showAddCardModal,
                                    language: this.__language,
                                    cardStore: this.cardStore,
                                    showCardDetailPage: this.__showCardDetailPage,
                                    selectedCardId: this.__selectedCardId,
                                    showMockSettingsPage: this.__showMockSettingsPage,
                                    showPhysicalCardManagerPage: this.__showPhysicalCardManagerPage,
                                    isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 155, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        showAddCardModal: this.showAddCardModal,
                                        language: this.language,
                                        cardStore: this.cardStore,
                                        showCardDetailPage: this.showCardDetailPage,
                                        selectedCardId: this.selectedCardId,
                                        showMockSettingsPage: this.showMockSettingsPage,
                                        showPhysicalCardManagerPage: this.showPhysicalCardManagerPage,
                                        isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    cardStore: this.cardStore,
                                    isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET
                                });
                            }
                        }, { name: "CardsPage" });
                    }
                });
            }
            else {
                this.ifElseBranchUpdateFunction(5, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new ProfilePage(this, {
                                    language: this.__language,
                                    showLanguagePage: this.__showLanguagePage,
                                    isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
                                    windowWidth: this.windowWidth
                                }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 166, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        language: this.language,
                                        showLanguagePage: this.showLanguagePage,
                                        isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
                                        windowWidth: this.windowWidth
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    isTablet: this.windowWidth >= Theme.BREAKPOINT_TABLET,
                                    windowWidth: this.windowWidth
                                });
                            }
                        }, { name: "ProfilePage" });
                    }
                });
            }
        }, If);
        If.pop();
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
                    let componentCall = new CardPreview(this, { card: this.verificationCard(), language: this.language }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 200, col: 9 });
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
    private verificationCard(): DigitalCard {
        let result: DigitalCard = this.cardStore.cards[0];
        this.cardStore.cards.forEach((card: DigitalCard) => {
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
            Column.create();
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor('rgba(0, 0, 0, 0.4)');
            Column.onClick(() => {
                this.closeAddCardModal();
            });
        }, Column);
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('90%');
            Column.constraintSize({ maxWidth: 520, maxHeight: '90%' });
            Column.padding(Theme.SPACING_XL);
            Column.backgroundColor(Theme.SURFACE);
            Column.borderRadius(Theme.RADIUS_MD);
            Column.shadow({
                radius: 40,
                color: 'rgba(0, 0, 0, 0.08)',
                offsetY: 12
            });
            Column.position({ x: '50%', y: '50%' });
            Column.translate({ x: '-50%', y: '-50%' });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '领取数字卡片' : 'Claim Digital Card');
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_BOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '输入管理方提供的邀请码' : 'Enter the invitation code from the issuer');
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.opacity(0.7);
            Text.textAlign(TextAlign.Center);
            Text.margin({ top: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.width('100%');
            Scroll.constraintSize({ maxHeight: 520 });
            Scroll.scrollBar(BarState.Off);
            Scroll.edgeEffect(EdgeEffect.Spring);
            Scroll.margin({ top: Theme.SPACING_XL });
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.End });
            Stack.width('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({
                text: this.invitationCode,
                placeholder: this.language === 'zh' ? '例如 SLE-DEMO-2026' : 'e.g. SLE-DEMO-2026'
            });
            TextInput.width('100%');
            TextInput.height(56);
            TextInput.fontSize(Theme.BODY_LG_FONT_SIZE);
            TextInput.fontColor(Theme.ON_SURFACE);
            TextInput.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            TextInput.borderRadius(Theme.RADIUS_DEFAULT);
            TextInput.padding({
                left: Theme.SPACING_MD,
                right: Theme.SPACING_MD + Theme.ICON_MD + Theme.SPACING_XS
            });
            TextInput.placeholderColor('rgba(70, 69, 84, 0.4)');
            TextInput.maxLength(13);
            TextInput.enabled(!this.isInvitationBusy());
            TextInput.onChange((value: string) => {
                this.onInvitationCodeChange(value);
            });
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
            Text.create(this.language === 'zh' ? '邀请码格式：SLE-XXXX-XXXX' : 'Format: SLE-XXXX-XXXX');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontColor('rgba(70, 69, 84, 0.6)');
            Text.margin({ left: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.invitationState === InvitationFlowState.PREVIEW_READY && this.invitationPreview) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.InvitationPreviewSection.bind(this)();
                });
            }
            else if (this.invitationState !== InvitationFlowState.IDLE) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.InvitationStateFeedback.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
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
                this.closeAddCardModal();
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel(this.invitationPrimaryButtonText());
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
            Button.enabled(!this.isInvitationBusy());
            Button.onClick(() => {
                this.handleInvitationPrimaryAction();
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
        Stack.pop();
    }
    InvitationPreviewSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_LG });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.width('100%');
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new CardPreview(this, { card: this.invitationPreviewCard(), language: this.language }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 422, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            card: this.invitationPreviewCard(),
                            language: this.language
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        card: this.invitationPreviewCard(), language: this.language
                    });
                }
            }, { name: "CardPreview" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ top: Theme.SPACING_MD });
            Column.padding(Theme.SPACING_MD);
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            Column.borderRadius(Theme.RADIUS_DEFAULT);
        }, Column);
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '签发方' : 'Issuer', this.invitationPreviewIssuer());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '权限范围' : 'Permission Scope', this.invitationPermissionScope());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '有效期' : 'Validity', this.invitationValidity());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '使用次数' : 'Usage', this.invitationUsageText());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '二次确认' : 'Confirmation', this.invitationConfirmationText());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '手机临时通行' : 'Phone Substitute', this.invitationPhoneSubstituteText());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '离线使用' : 'Offline Use', this.invitationOfflineText());
        this.InvitationPreviewRow.bind(this)(this.language === 'zh' ? '提醒策略' : 'Alert Policy', this.invitationAlertPolicyText());
        Column.pop();
        Column.pop();
    }
    InvitationPreviewRow(label: string, value: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.alignItems(VerticalAlign.Top);
            Row.padding({ top: Theme.SPACING_XS, bottom: Theme.SPACING_XS });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(value);
            Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE);
            Text.textAlign(TextAlign.End);
            Text.layoutWeight(1);
            Text.maxLines(3);
            Text.margin({ left: Theme.SPACING_MD });
        }, Text);
        Text.pop();
        Row.pop();
    }
    InvitationStateFeedback(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.width('100%');
            Row.padding(Theme.SPACING_MD);
            Row.margin({ top: Theme.SPACING_LG });
            Row.backgroundColor(this.isInvitationError() ? 'rgba(186, 26, 26, 0.08)' :
                Theme.SURFACE_CONTAINER_LOW);
            Row.borderRadius(Theme.RADIUS_DEFAULT);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create(this.isInvitationError() ? { "id": 125832650, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" } : { "id": 125832302, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_MD);
            SymbolGlyph.fontColor([this.isInvitationError() ? Theme.ERROR : Theme.PRIMARY]);
        }, SymbolGlyph);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.invitationStateMessage());
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            Text.fontColor(this.isInvitationError() ? Theme.ERROR : Theme.ON_SURFACE_VARIANT);
            Text.layoutWeight(1);
            Text.margin({ left: Theme.SPACING_SM });
        }, Text);
        Text.pop();
        Row.pop();
    }
    private handleInvitationPrimaryAction(): void {
        if (this.invitationState === InvitationFlowState.PREVIEW_READY) {
            this.redeemInvitation().catch(() => {
                this.applyInvitationRequestError();
            });
            return;
        }
        if (this.isInvitationBusy()) {
            return;
        }
        this.loadInvitationPreview().catch(() => {
            this.applyInvitationRequestError();
        });
    }
    private async loadInvitationPreview(): Promise<void> {
        const normalizedCode: string = this.invitationCode.trim().toUpperCase();
        this.invitationCode = normalizedCode;
        this.invitationPreview = null;
        if (normalizedCode.length === 0) {
            this.invitationState = InvitationFlowState.INVALID;
            this.invitationFailureReason = InvitationFailureReason.EMPTY;
            return;
        }
        if (!this.cardStore.validateInvitationFormat(normalizedCode)) {
            this.invitationState = InvitationFlowState.INVALID;
            this.invitationFailureReason = InvitationFailureReason.FORMAT;
            return;
        }
        const operationId: number = ++this.invitationOperationId;
        this.invitationState = InvitationFlowState.VALIDATING;
        this.invitationFailureReason = InvitationFailureReason.NONE;
        const result: InvitationPreviewResult = await this.cardStore.previewInvitation(normalizedCode);
        if (!this.isInvitationOperationActive(operationId)) {
            return;
        }
        this.invitationState = result.state;
        this.invitationFailureReason = result.reason;
        this.invitationPreview = result.preview;
    }
    private async redeemInvitation(): Promise<void> {
        if (this.invitationState !== InvitationFlowState.PREVIEW_READY ||
            !this.invitationPreview) {
            return;
        }
        const operationId: number = ++this.invitationOperationId;
        this.invitationState = InvitationFlowState.REDEEMING;
        this.invitationFailureReason = InvitationFailureReason.NONE;
        const result: InvitationRedemptionResult = await this.cardStore.redeemInvitation(this.invitationCode);
        if (!this.isInvitationOperationActive(operationId)) {
            return;
        }
        this.invitationState = result.state;
        this.invitationFailureReason = result.reason;
        this.invitationPreview = result.preview;
        if (result.state !== InvitationFlowState.SUCCESS) {
            return;
        }
        this.showAddCardModal = false;
        this.invitationOperationId++;
        this.resetInvitationFlow();
        try {
            this.getUIContext().getPromptAction().showToast({
                message: this.language === 'zh' ? '数字卡片领取成功' : 'Digital card claimed'
            });
        }
        catch (error) {
            console.error('Unable to show invitation redemption result');
        }
    }
    private closeAddCardModal(): void {
        this.invitationOperationId++;
        this.showAddCardModal = false;
        this.resetInvitationFlow();
    }
    private resetInvitationFlow(): void {
        this.invitationCode = '';
        this.invitationState = InvitationFlowState.IDLE;
        this.invitationFailureReason = InvitationFailureReason.NONE;
        this.invitationPreview = null;
    }
    private onInvitationCodeChange(value: string): void {
        this.invitationOperationId++;
        this.invitationCode = value;
        this.invitationState = InvitationFlowState.IDLE;
        this.invitationFailureReason = InvitationFailureReason.NONE;
        this.invitationPreview = null;
    }
    private applyInvitationRequestError(): void {
        if (!this.showAddCardModal) {
            return;
        }
        this.invitationState = InvitationFlowState.REQUEST_ERROR;
        this.invitationFailureReason = InvitationFailureReason.REQUEST_ERROR;
        this.invitationPreview = null;
    }
    private isInvitationOperationActive(operationId: number): boolean {
        return this.showAddCardModal && operationId === this.invitationOperationId;
    }
    private isInvitationBusy(): boolean {
        return this.invitationState === InvitationFlowState.VALIDATING ||
            this.invitationState === InvitationFlowState.REDEEMING;
    }
    private isInvitationError(): boolean {
        return this.invitationState === InvitationFlowState.INVALID ||
            this.invitationState === InvitationFlowState.EXPIRED ||
            this.invitationState === InvitationFlowState.ALREADY_USED ||
            this.invitationState === InvitationFlowState.ALREADY_BOUND ||
            this.invitationState === InvitationFlowState.REQUEST_ERROR;
    }
    private invitationPrimaryButtonText(): string {
        if (this.invitationState === InvitationFlowState.PREVIEW_READY) {
            return this.language === 'zh' ? '确认领取' : 'Claim Card';
        }
        if (this.invitationState === InvitationFlowState.VALIDATING) {
            return this.language === 'zh' ? '正在验证' : 'Validating';
        }
        if (this.invitationState === InvitationFlowState.REDEEMING) {
            return this.language === 'zh' ? '正在领取' : 'Claiming';
        }
        return this.language === 'zh' ? '验证邀请码' : 'Validate Code';
    }
    private invitationStateMessage(): string {
        if (this.invitationState === InvitationFlowState.VALIDATING) {
            return this.language === 'zh' ? '正在验证邀请码…' : 'Validating invitation code…';
        }
        if (this.invitationState === InvitationFlowState.REDEEMING) {
            return this.language === 'zh' ? '正在领取许可…' : 'Claiming authorization…';
        }
        if (this.invitationFailureReason === InvitationFailureReason.EMPTY) {
            return this.language === 'zh' ? '请输入邀请码' : 'Enter an invitation code';
        }
        if (this.invitationFailureReason === InvitationFailureReason.FORMAT) {
            return this.language === 'zh' ? '邀请码格式不正确' : 'Invalid invitation code format';
        }
        if (this.invitationFailureReason === InvitationFailureReason.NOT_FOUND) {
            return this.language === 'zh' ? '邀请码不存在' : 'Invitation code not found';
        }
        if (this.invitationState === InvitationFlowState.EXPIRED) {
            return this.language === 'zh' ? '邀请码已过期' : 'Invitation code has expired';
        }
        if (this.invitationState === InvitationFlowState.ALREADY_USED) {
            return this.language === 'zh' ? '邀请码已经使用' : 'Invitation code has already been used';
        }
        if (this.invitationState === InvitationFlowState.ALREADY_BOUND) {
            return this.language === 'zh' ? '该许可已经在你的卡包中' :
                'This authorization is already in your wallet';
        }
        return this.language === 'zh' ? '暂时无法验证邀请码，请稍后重试' :
            'Unable to validate the invitation code. Try again later.';
    }
    private invitationPreviewCard(): DigitalCard {
        if (!this.invitationPreview) {
            return this.cardStore.cards[0];
        }
        return {
            id: 'invitation-preview',
            name: this.invitationPreview.cardName,
            issuer: this.invitationPreview.issuerName,
            anonymousNumber: 'PREVIEW 0000 0000',
            nickname: this.invitationPreview.cardName,
            detail: this.invitationPreview.cardDescription,
            category: this.invitationPreview.category,
            status: DigitalCardStatus.ACTIVE,
            visualStyle: this.invitationPreview.cardAppearance,
            authorizationId: this.invitationPreview.authorizationId,
            credentialId: '',
            physicalCardId: '',
            credentialBindingStatus: CredentialBindingStatus.NOT_WRITTEN,
            adminConfirmationRequired: this.invitationPreview.adminConfirmationRequired,
            userConfirmationEnabled: false,
            allowTemporaryPass: this.invitationPreview.phoneSubstituteAllowed,
            validFrom: this.invitationPreview.validFrom,
            validUntil: this.invitationPreview.validUntil,
            lastSyncedAt: ''
        };
    }
    private invitationPreviewIssuer(): string {
        return this.invitationPreview ? this.invitationPreview.issuerName : '';
    }
    private invitationPermissionScope(): string {
        if (!this.invitationPreview) {
            return '';
        }
        return this.invitationPreview.permissionScope.join(this.language === 'zh' ? '、' : ', ');
    }
    private invitationValidity(): string {
        if (!this.invitationPreview) {
            return '';
        }
        return `${this.invitationPreview.validFrom.substring(0, 10)} – ` +
            this.invitationPreview.validUntil.substring(0, 10);
    }
    private invitationUsageText(): string {
        if (!this.invitationPreview) {
            return '';
        }
        if (this.invitationPreview.usageMode === AuthorizationUsageMode.UNLIMITED) {
            return this.language === 'zh' ? '不限次数' : 'Unlimited';
        }
        return this.language === 'zh' ? `${this.invitationPreview.usageLimit} 次` :
            `${this.invitationPreview.usageLimit} uses`;
    }
    private invitationConfirmationText(): string {
        if (this.invitationPreview && this.invitationPreview.adminConfirmationRequired) {
            return this.language === 'zh' ? '管理方要求二次确认' : 'Required by administrator';
        }
        return this.language === 'zh' ? '可由用户自行开启' : 'Optional';
    }
    private invitationPhoneSubstituteText(): string {
        if (this.invitationPreview && this.invitationPreview.phoneSubstituteAllowed) {
            return this.language === 'zh' ? '允许' : 'Allowed';
        }
        return this.language === 'zh' ? '不允许' : 'Not allowed';
    }
    private invitationOfflineText(): string {
        if (this.invitationPreview && this.invitationPreview.offlineAllowed) {
            return this.language === 'zh' ? '允许' : 'Allowed';
        }
        return this.language === 'zh' ? '不允许' : 'Not allowed';
    }
    private invitationAlertPolicyText(): string {
        if (!this.invitationPreview) {
            return '';
        }
        if (this.invitationPreview.alertPolicy === AuthorizationAlertPolicy.HIGH_ATTENTION) {
            return this.language === 'zh' ? '重点提醒' : 'High attention';
        }
        if (this.invitationPreview.alertPolicy === AuthorizationAlertPolicy.NOTIFY_ON_USE) {
            return this.language === 'zh' ? '使用时提醒' : 'Notify on use';
        }
        return this.language === 'zh' ? '默认' : 'Default';
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.slekey.app", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
