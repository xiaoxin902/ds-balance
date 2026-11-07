#import "DSSettingsViewController.h"
#import "DSAppearance.h"
#import "DSBalanceInfo.h"
#import "DSKeyEditorViewController.h"
#import "DSNotifier.h"
#import "DSStore.h"
#import <UserNotifications/UserNotifications.h>

typedef NS_ENUM(NSInteger, DSSettingsSection) {
    DSSettingsSectionKey = 0,
    DSSettingsSectionAlerts,
    DSSettingsSectionAppearance,
    DSSettingsSectionData,
    DSSettingsSectionAbout,
    DSSettingsSectionCount,
};

@interface DSSettingsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) UNAuthorizationStatus notifyStatus;

@end

@implementation DSSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"设置";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    [DSNotifier authorizationStatus:^(UNAuthorizationStatus status) {
        self.notifyStatus = status;
        [self.tableView reloadData];
    }];
}

#pragma mark - Helpers

- (NSString *)maskedKey {
    NSString *key = DSStore.sharedStore.apiKey;
    if (key.length == 0) {
        return @"未设置";
    }
    if (key.length <= 10) {
        return @"已设置";
    }
    return [NSString stringWithFormat:@"%@…%@", [key substringToIndex:4], [key substringFromIndex:key.length - 4]];
}

- (NSString *)versionText {
    NSString *shortVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"1";
    return [NSString stringWithFormat:@"%@ (%@)", shortVersion, build];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return DSSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case DSSettingsSectionKey:
            return 1;
        case DSSettingsSectionAlerts:
            return 5;
        case DSSettingsSectionAppearance:
            return 2;
        case DSSettingsSectionData:
            return 1;
        case DSSettingsSectionAbout:
            return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case DSSettingsSectionKey:
            return @"DeepSeek API";
        case DSSettingsSectionAlerts:
            return @"余额提醒";
        case DSSettingsSectionAppearance:
            return @"显示";
        case DSSettingsSectionData:
            return @"数据";
        case DSSettingsSectionAbout:
            return @"关于";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case DSSettingsSectionKey:
            return @"API Key 保存在本机的钥匙串里，只会发送给 api.deepseek.com。";
        case DSSettingsSectionAlerts:
            return @"余额检查依赖 App 刷新或 iOS 后台调度，系统不保证检查时刻，因此提醒可能延迟。";
        case DSSettingsSectionAbout:
            return @"余额来自 DeepSeek 官方 /user/balance 接口。开放平台没有公开的用量明细接口，记录页显示的是本机采样。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = nil;
    cell.textLabel.text = @"";

    DSStore *store = DSStore.sharedStore;

    switch (indexPath.section) {
        case DSSettingsSectionKey: {
            cell.textLabel.text = @"API Key";
            cell.detailTextLabel.text = [self maskedKey];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case DSSettingsSectionAlerts: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"允许通知";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.notificationsEnabled;
                [toggle addTarget:self action:@selector(notifySwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"通知权限";
                cell.detailTextLabel.text = [self notificationStatusText];
                switch (self.notifyStatus) {
                    case UNAuthorizationStatusAuthorized:
                    case UNAuthorizationStatusProvisional:
                    case UNAuthorizationStatusEphemeral:
                        cell.detailTextLabel.textColor = UIColor.systemGreenColor;
                        break;
                    case UNAuthorizationStatusDenied:
                        cell.detailTextLabel.textColor = UIColor.systemRedColor;
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        break;
                    default:
                        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
                        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        break;
                }
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"低余额提醒";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.lowBalanceAlertEnabled;
                toggle.enabled = store.notificationsEnabled;
                [toggle addTarget:self action:@selector(lowAlertSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"提醒阈值";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"¥%@", DSMoneyText(store.lowBalanceThreshold)];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else {
                cell.textLabel.text = @"发送测试通知";
                cell.textLabel.textColor = UIColor.linkColor;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
            break;
        }
        case DSSettingsSectionAppearance: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"外观";
                UISegmentedControl *segmented = [[UISegmentedControl alloc] initWithItems:@[ @"跟随系统", @"浅色", @"深色" ]];
                segmented.selectedSegmentIndex = store.appearanceMode;
                [segmented addTarget:self action:@selector(appearanceChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = segmented;
            } else {
                cell.textLabel.text = @"启动时刷新";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.refreshOnLaunch;
                [toggle addTarget:self action:@selector(refreshOnLaunchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            }
            break;
        }
        case DSSettingsSectionData: {
            cell.textLabel.text = @"清空余额记录";
            cell.textLabel.textColor = UIColor.systemRedColor;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case DSSettingsSectionAbout: {
            cell.textLabel.text = @"版本";
            cell.detailTextLabel.text = [self versionText];
            break;
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == DSSettingsSectionKey) {
        [self.navigationController pushViewController:[DSKeyEditorViewController new] animated:YES];
    } else if (indexPath.section == DSSettingsSectionAlerts) {
        if (indexPath.row == 1) {
            [self handleNotificationPermissionRow];
        } else if (indexPath.row == 3) {
            [self presentThresholdEditor];
        } else if (indexPath.row == 4) {
            [self sendTestNotification];
        }
    } else if (indexPath.section == DSSettingsSectionData) {
        [self confirmClearRecords];
    }
}

#pragma mark - Actions

- (NSString *)notificationStatusText {
    switch (self.notifyStatus) {
        case UNAuthorizationStatusNotDetermined:
            return @"未请求";
        case UNAuthorizationStatusDenied:
            return @"已拒绝";
        case UNAuthorizationStatusAuthorized:
            return @"已允许";
        case UNAuthorizationStatusProvisional:
            return @"临时允许";
        case UNAuthorizationStatusEphemeral:
            return @"临时允许";
    }
    return @"未知";
}

/// Asks once; when the system already refused, it explains instead of asking again.
- (void)requestNotificationPermissionAndThen:(void (^)(BOOL granted))completion {
    [DSNotifier authorizationStatus:^(UNAuthorizationStatus status) {
        self.notifyStatus = status;
        if (status == UNAuthorizationStatusDenied) {
            [self.tableView reloadData];
            [self showNotificationDeniedAlert];
            if (completion) {
                completion(NO);
            }
            return;
        }
        if (status == UNAuthorizationStatusAuthorized ||
            status == UNAuthorizationStatusProvisional ||
            status == UNAuthorizationStatusEphemeral) {
            [self.tableView reloadData];
            if (completion) {
                completion(YES);
            }
            return;
        }
        [DSNotifier requestAuthorizationWithCompletion:^(BOOL granted) {
            [DSNotifier authorizationStatus:^(UNAuthorizationStatus updated) {
                self.notifyStatus = updated;
                [self.tableView reloadData];
            }];
            if (!granted) {
                [self showNotificationDeniedAlert];
            }
            if (completion) {
                completion(granted);
            }
        }];
    }];
}

- (void)showNotificationDeniedAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"通知未获允许"
                                                                   message:@"系统没有允许本应用发通知。请打开 设置 › 通知 › DS 余额，手动开启通知。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleNotificationPermissionRow {
    [self requestNotificationPermissionAndThen:^(BOOL granted) {
        if (granted) {
            DSStore.sharedStore.notificationsEnabled = YES;
            [self.tableView reloadData];
        }
    }];
}

- (void)presentThresholdEditor {
    double current = DSStore.sharedStore.lowBalanceThreshold;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提醒阈值"
                                                                   message:@"余额低于或等于这个数值时提醒一次，余额回升后再次低于才会再提醒。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.text = [NSString stringWithFormat:@"%.2f", current];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *text = alert.textFields.firstObject.text ?: @"";
        double value = text.doubleValue;
        DSStore.sharedStore.lowBalanceThreshold = value >= 0 ? value : 10.0;
        DSStore.sharedStore.lowBalanceNotified = NO;
        [self.tableView reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)notifySwitchChanged:(UISwitch *)sender {
    if (!sender.isOn) {
        DSStore.sharedStore.notificationsEnabled = NO;
        [self.tableView reloadData];
        return;
    }
    [self requestNotificationPermissionAndThen:^(BOOL granted) {
        DSStore.sharedStore.notificationsEnabled = granted;
        [self.tableView reloadData];
    }];
}

- (void)lowAlertSwitchChanged:(UISwitch *)sender {
    DSStore.sharedStore.lowBalanceAlertEnabled = sender.isOn;
    if (!sender.isOn) {
        DSStore.sharedStore.lowBalanceNotified = NO;
    }
}

- (void)refreshOnLaunchChanged:(UISwitch *)sender {
    DSStore.sharedStore.refreshOnLaunch = sender.isOn;
}

- (void)appearanceChanged:(UISegmentedControl *)sender {
    DSStore.sharedStore.appearanceMode = (DSAppearanceMode)sender.selectedSegmentIndex;
    [DSAppearance apply];
}

- (void)sendTestNotification {
    [self requestNotificationPermissionAndThen:^(BOOL granted) {
        if (!granted) {
            return;
        }
        DSStore.sharedStore.notificationsEnabled = YES;
        [DSNotifier sendTestNotificationWithInfos:nil];
        [self.tableView reloadData];
    }];
}

- (void)confirmClearRecords {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空余额记录"
                                                                   message:@"本机采样的余额历史会被删除，此操作无法撤销。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action;
        [DSStore.sharedStore clearSnapshots];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
