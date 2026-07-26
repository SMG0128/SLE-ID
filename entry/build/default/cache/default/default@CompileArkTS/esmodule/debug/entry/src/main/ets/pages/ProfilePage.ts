if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ProfilePage_Params {
    isBiometricEnabled?: boolean;
    language?: string;
    showLanguagePage?: boolean;
}
import * as Theme from "@normalized:N&&&entry/src/main/ets/common/Theme&";
interface SettingsItem {
    icon: Resource;
    iconColor: string;
    title: string;
    hasArrow: boolean;
    hasToggle: boolean;
    toggleValue?: boolean;
    trailingText?: string;
    isExternal?: boolean;
    isError?: boolean;
    action?: string;
}
export class ProfilePage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__isBiometricEnabled = new ObservedPropertySimplePU(true, this, "isBiometricEnabled");
        this.__language = new SynchedPropertySimpleTwoWayPU(params.language, this, "language");
        this.__showLanguagePage = new SynchedPropertySimpleTwoWayPU(params.showLanguagePage, this, "showLanguagePage");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ProfilePage_Params) {
        if (params.isBiometricEnabled !== undefined) {
            this.isBiometricEnabled = params.isBiometricEnabled;
        }
    }
    updateStateVars(params: ProfilePage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__isBiometricEnabled.purgeDependencyOnElmtId(rmElmtId);
        this.__language.purgeDependencyOnElmtId(rmElmtId);
        this.__showLanguagePage.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__isBiometricEnabled.aboutToBeDeleted();
        this.__language.aboutToBeDeleted();
        this.__showLanguagePage.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __isBiometricEnabled: ObservedPropertySimplePU<boolean>;
    get isBiometricEnabled() {
        return this.__isBiometricEnabled.get();
    }
    set isBiometricEnabled(newValue: boolean) {
        this.__isBiometricEnabled.set(newValue);
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
            Column.padding({ left: Theme.CONTAINER_MARGIN, right: Theme.CONTAINER_MARGIN, bottom: 120 });
        }, Column);
        // User account section
        this.UserAccountSection.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Settings groups
            Column.create();
            // Settings groups
            Column.margin({ top: Theme.SPACING_XL });
        }, Column);
        // Security & Identity
        this.SettingsGroup.bind(this)(this.language === 'zh' ? '安全与身份' : 'Security & Identity', [
            {
                icon: { "id": 125834962, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.PRIMARY_CONTAINER,
                title: this.language === 'zh' ? '账户安全' : 'Account Security',
                hasArrow: true,
                hasToggle: false
            },
            {
                icon: { "id": 125834962, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.PRIMARY_CONTAINER,
                title: this.language === 'zh' ? '生物识别登录' : 'Biometric Login',
                hasArrow: false,
                hasToggle: true,
                toggleValue: this.isBiometricEnabled
            },
            {
                icon: { "id": 125834962, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.PRIMARY_CONTAINER,
                title: this.language === 'zh' ? '隐私与共享' : 'Privacy & Sharing',
                hasArrow: true,
                hasToggle: false
            }
        ]);
        // Preferences
        this.SettingsGroup.bind(this)(this.language === 'zh' ? '偏好设置' : 'Preferences', [
            {
                icon: { "id": 125831513, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '通知' : 'Notifications',
                hasArrow: true,
                hasToggle: false
            },
            {
                icon: { "id": 125831710, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '外观' : 'Appearance',
                hasArrow: true,
                hasToggle: false,
                trailingText: this.language === 'zh' ? '浅色' : 'Light'
            },
            {
                icon: { "id": 125832254, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '通用' : 'General',
                hasArrow: false,
                hasToggle: false
            },
            {
                icon: { "id": 125834182, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.TERTIARY_CONTAINER,
                title: this.language === 'zh' ? '语言' : 'Language',
                hasArrow: true,
                hasToggle: false,
                trailingText: this.language === 'zh' ? '中文' : 'English',
                action: 'language'
            }
        ]);
        // Support
        this.SettingsGroup.bind(this)(this.language === 'zh' ? '支持' : 'Support', [
            {
                icon: { "id": 125832644, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.ON_SURFACE_VARIANT,
                title: this.language === 'zh' ? '帮助中心' : 'Help Center',
                hasArrow: true,
                hasToggle: false,
                isExternal: true
            },
            {
                icon: { "id": 125834182, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" },
                iconColor: Theme.ERROR,
                title: this.language === 'zh' ? '退出登录' : 'Sign Out',
                hasArrow: false,
                hasToggle: false,
                isError: true
            }
        ]);
        // Settings groups
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Version info
            Text.create(this.language === 'zh' ? '版本 4.12.0（构建 992）' : 'Version 4.12.0 (Build 992)');
            // Version info
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            // Version info
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            // Version info
            Text.fontColor(Theme.OUTLINE_VARIANT);
            // Version info
            Text.textAlign(TextAlign.Center);
            // Version info
            Text.width('100%');
            // Version info
            Text.margin({ top: Theme.SPACING_XL });
        }, Text);
        // Version info
        Text.pop();
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
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '个人中心' : 'Profile');
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125832644, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(Theme.ICON_LG);
            SymbolGlyph.fontColor([Theme.ON_SURFACE_VARIANT]);
        }, SymbolGlyph);
        Row.pop();
    }
    UserAccountSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Center);
            Column.padding(Theme.SPACING_LG);
            Column.backgroundColor('rgba(255, 255, 255, 0.8)');
            Column.backdropBlur(20);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.borderWidth(1);
            Column.borderColor('rgba(255, 255, 255, 0.5)');
            Column.shadow({
                radius: 20,
                color: 'rgba(0, 0, 0, 0.04)',
                offsetY: 4
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Avatar
            Stack.create();
            // Avatar
            Stack.width(96);
            // Avatar
            Stack.height(96);
            // Avatar
            Stack.margin({ bottom: Theme.SPACING_MD });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.width(96);
            Stack.height(96);
            Stack.borderRadius(Theme.RADIUS_FULL);
            Stack.clip(true);
            Stack.borderWidth(2);
            Stack.borderColor(Color.White);
            Stack.shadow({
                radius: 16,
                color: 'rgba(0, 0, 0, 0.08)',
                offsetY: 4
            });
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Image.create({ "id": 16777218, "type": 20000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            Image.width('100%');
            Image.height('100%');
            Image.objectFit(ImageFit.Cover);
        }, Image);
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Edit button
            Stack.create();
            // Edit button
            Stack.width(28);
            // Edit button
            Stack.height(28);
            // Edit button
            Stack.borderRadius(Theme.RADIUS_FULL);
            // Edit button
            Stack.backgroundColor(Theme.PRIMARY_CONTAINER);
            // Edit button
            Stack.borderWidth(2);
            // Edit button
            Stack.borderColor(Color.White);
            // Edit button
            Stack.shadow({
                radius: 8,
                color: 'rgba(0, 0, 0, 0.08)',
                offsetY: 2
            });
            // Edit button
            Stack.position({ x: 68, y: 68 });
            // Edit button
            Stack.alignContent(Alignment.Center);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            SymbolGlyph.create({ "id": 125831710, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
            SymbolGlyph.fontSize(14);
            SymbolGlyph.fontColor([Theme.ON_PRIMARY_CONTAINER]);
        }, SymbolGlyph);
        // Edit button
        Stack.pop();
        // Avatar
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Name
            Text.create(this.language === 'zh' ? '亚历克斯·约翰逊' : 'Alex Johnson');
            // Name
            Text.fontSize(Theme.HEADLINE_MD_FONT_SIZE);
            // Name
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            // Name
            Text.fontColor(Theme.ON_SURFACE);
        }, Text);
        // Name
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Membership info
            Text.create(this.language === 'zh' ? '高级会员 · ID：8820-XL' : 'Premium Member • ID: 8820-XL');
            // Membership info
            Text.fontSize(Theme.BODY_MD_FONT_SIZE);
            // Membership info
            Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
            // Membership info
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            // Membership info
            Text.opacity(0.7);
            // Membership info
            Text.margin({ top: Theme.SPACING_XS });
        }, Text);
        // Membership info
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Stats row
            Row.create();
            // Stats row
            Row.width('100%');
            // Stats row
            Row.margin({ top: Theme.SPACING_LG });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Level
            Column.create();
            // Level
            Column.flexGrow(1);
            // Level
            Column.alignItems(HorizontalAlign.Center);
            // Level
            Column.padding(Theme.SPACING_MD);
            // Level
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            // Level
            Column.borderRadius(Theme.RADIUS_MD);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '等级' : 'Level');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.textCase(TextCase.Normal);
            Text.margin({ bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '黄金' : 'Gold');
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.PRIMARY);
        }, Text);
        Text.pop();
        // Level
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // Points
            Column.create();
            // Points
            Column.flexGrow(1);
            // Points
            Column.alignItems(HorizontalAlign.Center);
            // Points
            Column.padding(Theme.SPACING_MD);
            // Points
            Column.backgroundColor(Theme.SURFACE_CONTAINER_LOW);
            // Points
            Column.borderRadius(Theme.RADIUS_MD);
            // Points
            Column.margin({ left: Theme.SPACING_MD });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.language === 'zh' ? '积分' : 'Points');
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.textCase(TextCase.Normal);
            Text.margin({ bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('12,450');
            Text.fontSize(Theme.TITLE_LG_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.PRIMARY);
        }, Text);
        Text.pop();
        // Points
        Column.pop();
        // Stats row
        Row.pop();
        Column.pop();
    }
    SettingsGroup(title: string, items: SettingsItem[], parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.margin({ bottom: Theme.SPACING_XL });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(title);
            Text.fontSize(Theme.LABEL_SM_FONT_SIZE);
            Text.fontWeight(Theme.FONT_WEIGHT_SEMIBOLD);
            Text.fontColor(Theme.ON_SURFACE_VARIANT);
            Text.letterSpacing(Theme.LABEL_SM_LETTER_SPACING);
            Text.textCase(TextCase.Normal);
            Text.margin({ left: Theme.SPACING_SM, bottom: Theme.SPACING_XS });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.width('100%');
            Column.backgroundColor('rgba(255, 255, 255, 0.8)');
            Column.backdropBlur(20);
            Column.borderRadius(Theme.RADIUS_LG);
            Column.clip(true);
            Column.borderWidth(1);
            Column.borderColor('rgba(255, 255, 255, 0.5)');
            Column.shadow({
                radius: 20,
                color: 'rgba(0, 0, 0, 0.04)',
                offsetY: 4
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, index: number) => {
                const item = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.width('100%');
                    Row.padding({ left: Theme.SPACING_LG, right: Theme.SPACING_LG, top: Theme.SPACING_MD, bottom: Theme.SPACING_MD });
                    Row.alignItems(VerticalAlign.Center);
                    Row.onClick(() => {
                        if (item.action === 'language') {
                            this.showLanguagePage = true;
                        }
                    });
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    SymbolGlyph.create(item.icon);
                    SymbolGlyph.fontSize(Theme.ICON_LG);
                    SymbolGlyph.fontColor([item.iconColor]);
                    SymbolGlyph.margin({ right: Theme.SPACING_MD });
                }, SymbolGlyph);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(item.title);
                    Text.fontSize(Theme.BODY_MD_FONT_SIZE);
                    Text.fontWeight(Theme.FONT_WEIGHT_REGULAR);
                    Text.fontColor(item.isError ? Theme.ERROR : Theme.ON_SURFACE);
                    Text.layoutWeight(1);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (item.trailingText) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(item.trailingText);
                                Text.fontSize(Theme.LABEL_MD_FONT_SIZE);
                                Text.fontWeight(Theme.FONT_WEIGHT_MEDIUM);
                                Text.fontColor(Theme.ON_SURFACE_VARIANT);
                                Text.margin({ right: Theme.SPACING_XS });
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
                    If.create();
                    if (item.hasToggle) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Toggle.create({ type: ToggleType.Switch, isOn: item.toggleValue });
                                Toggle.selectedColor(Theme.PRIMARY);
                                Toggle.switchPointColor(Color.White);
                                Toggle.width(44);
                                Toggle.height(24);
                                Toggle.onChange((isOn: boolean) => {
                                    if (item.title === 'Biometric Login' || item.title === '生物识别登录') {
                                        this.isBiometricEnabled = isOn;
                                    }
                                });
                            }, Toggle);
                            Toggle.pop();
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
                    if (item.hasArrow) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                SymbolGlyph.create(item.isExternal ? { "id": 125834182, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" } : { "id": 125832664, "type": 40000, params: [], "bundleName": "com.slekey.app", "moduleName": "entry" });
                                SymbolGlyph.fontSize(Theme.ICON_MD);
                                SymbolGlyph.fontColor([Theme.OUTLINE_VARIANT]);
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
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (index < items.length - 1) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Divider.create();
                                Divider.color('rgba(199, 196, 215, 0.1)');
                                Divider.margin({ left: Theme.SPACING_LG, right: Theme.SPACING_LG });
                            }, Divider);
                        });
                    }
                    else {
                        this.ifElseBranchUpdateFunction(1, () => {
                        });
                    }
                }, If);
                If.pop();
            };
            this.forEachUpdateFunction(elmtId, items, forEachItemGenFunction, undefined, true, false);
        }, ForEach);
        ForEach.pop();
        Column.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
}
