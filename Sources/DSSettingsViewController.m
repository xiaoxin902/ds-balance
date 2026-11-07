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
    DSSettingsSectionRefresh,
    DSSettingsSectionAppearance,
    DSSettingsSectionData,
    DSSettingsSectionAbout,
    DSSettingsSectionCount,
};

@interface DSSettingsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

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
        case DSSettingsSectionRefresh:
            return 4;
        case DSSettingsSectionAppearance:
            return 1;
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
        case DSSettingsSectionRefresh:
            return @"刷新";
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
            return @"调用 AppSyncUnified 插件安装时无法调用系统通知，只会在打开或刷新时弹窗；以 IPA 或 TIPA 安装后，系统通知可用。";
        case DSSettingsSectionRefresh:
            return @"刷新余额只是查询，不消耗 token，也不会扣费。\n\n遇到 HTTP 429 时，通常是刷新余额太频繁触发了限流。开启指数退避后按首次间隔倍增重试（如 5 秒、10 秒、20 秒……），上限 5 分钟；算出的等待超过 5 分钟就按 5 分钟处理。刷新成功后计数清零，下次限流又从首次间隔开始。";
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
                cell.textLabel.text = @"低余额提醒";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.lowBalanceAlertEnabled;
                [toggle addTarget:self action:@selector(lowAlertSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"提醒阈值";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"¥%@", DSMoneyText(store.lowBalanceThreshold)];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"打开应用时提醒";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.alertOnOpen;
                [toggle addTarget:self action:@selector(alertOnOpenChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"系统通知";
                if (![DSNotifier isUserAppInstallation]) {
                    cell.detailTextLabel.text = @"此安装方式不可用";
                    cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
                } else if ([DSNotifier systemNotificationsAvailable]) {
                    cell.detailTextLabel.text = @"已允许";
                    cell.detailTextLabel.textColor = UIColor.systemGreenColor;
                } else {
                    cell.detailTextLabel.text = @"未授权";
                    cell.detailTextLabel.textColor = UIColor.systemRedColor;
                }
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"测试提醒";
                cell.textLabel.textColor = UIColor.linkColor;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
            break;
        }
        case DSSettingsSectionRefresh: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"自动刷新间隔";
                cell.detailTextLabel.text = [self intervalText];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"启动时刷新";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.refreshOnLaunch;
                [toggle addTarget:self action:@selector(refreshOnLaunchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"指数退避";
                UISwitch *toggle = [UISwitch new];
                toggle.on = store.retryBackoffEnabled;
                [toggle addTarget:self action:@selector(retryBackoffChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = toggle;
            } else {
                cell.textLabel.text = @"首次重试间隔";
                cell.detailTextLabel.text = [self retryBaseText];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.selectionStyle = store.retryBackoffEnabled
                    ? UITableViewCellSelectionStyleDefault
                    : UITableViewCellSelectionStyleNone;
                cell.textLabel.textColor = store.retryBackoffEnabled ? UIColor.labelColor : UIColor.secondaryLabelColor;
            }
            break;
        }
        case DSSettingsSectionAppearance: {
            cell.textLabel.text = @"外观";
            UISegmentedControl *segmented = [[UISegmentedControl alloc] initWithItems:@[ @"跟随系统", @"浅色", @"深色" ]];
            segmented.selectedSegmentIndex = store.appearanceMode;
            [segmented addTarget:self action:@selector(appearanceChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = segmented;
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
            [self presentThresholdEditor];
        } else if (indexPath.row == 3) {
            [self explainSystemNotifications];
        } else if (indexPath.row == 4) {
            [self sendTestNotification];
        }
    } else if (indexPath.section == DSSettingsSectionRefresh) {
        if (indexPath.row == 0) {
            [self presentIntervalPicker];
        } else if (indexPath.row == 3 && DSStore.sharedStore.retryBackoffEnabled) {
            [self presentRetryBasePicker];
        }
    } else if (indexPath.section == DSSettingsSectionData) {
        [self confirmClearRecords];
    }
}

#pragma mark - Actions

- (void)explainSystemNotifications {
    NSString *message;
    if (![DSNotifier isUserAppInstallation]) {
        message = @"这个应用安装在 /Applications，系统把它当作平台组件，不给它通知授权，设置里也不会出现它的通知开关。这是安装方式决定的，改代码绕不过去。\n\n把应用打包成 IPA，用 TrollStore 或侧载工具安装，通知就能用。";
    } else if ([DSNotifier systemNotificationsAvailable]) {
        message = @"系统通知已允许，余额偏低时会直接发通知。";
    } else {
        message = @"应用以侧载方式运行，但系统通知还没有被允许。请在 设置 › 通知 里找到本应用并允许，然后回到这里点「测试提醒」。";
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"系统通知"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)intervalText {
    NSTimeInterval interval = DSStore.sharedStore.refreshInterval;
    if (interval <= 0) {
        return @"关闭";
    }
    NSInteger minutes = (NSInteger)lround(interval / 60.0);
    if (minutes >= 60 && minutes % 60 == 0) {
        return [NSString stringWithFormat:@"%ld 小时", (long)(minutes / 60)];
    }
    return [NSString stringWithFormat:@"%ld 分钟", (long)minutes];
}

- (void)presentIntervalPicker {
    NSArray<NSString *> *titles = @[ @"关闭", @"1 分钟", @"5 分钟", @"15 分钟", @"30 分钟", @"1 小时" ];
    NSArray<NSNumber *> *values = @[ @0, @60, @300, @900, @1800, @3600 ];
    NSTimeInterval current = DSStore.sharedStore.refreshInterval;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"自动刷新间隔"
                                                                   message:@"前台按这个间隔刷新；后台由系统调度，可能延后。"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSUInteger i = 0; i < titles.count; i++) {
        double value = values[i].doubleValue;
        NSString *title = titles[i];
        if (fabs(current - value) < 1) {
            title = [title stringByAppendingString:@"  ✓"];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action;
            DSStore.sharedStore.refreshInterval = value;
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = self.view.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (NSString *)retryBaseText {
    NSInteger seconds = (NSInteger)lround(DSStore.sharedStore.retryBaseInterval);
    return [NSString stringWithFormat:@"%ld 秒", (long)seconds];
}

- (void)presentRetryBasePicker {
    NSArray<NSString *> *titles = @[ @"1 秒", @"5 秒", @"10 秒", @"30 秒", @"60 秒" ];
    NSArray<NSNumber *> *values = @[ @1, @5, @10, @30, @60 ];
    double current = DSStore.sharedStore.retryBaseInterval;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"首次重试间隔"
                                                                   message:@"之后每次翻倍，最长等 5 分钟。"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSUInteger i = 0; i < titles.count; i++) {
        double value = values[i].doubleValue;
        NSString *title = titles[i];
        if (fabs(current - value) < 0.5) {
            title = [title stringByAppendingString:@"  ✓"];
        }
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action;
            DSStore.sharedStore.retryBaseInterval = value;
            [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect = self.view.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)retryBackoffChanged:(UISwitch *)sender {
    DSStore.sharedStore.retryBackoffEnabled = sender.isOn;
    [self.tableView reloadData];
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

- (void)alertOnOpenChanged:(UISwitch *)sender {
    DSStore.sharedStore.alertOnOpen = sender.isOn;
    if (sender.isOn) {
        DSStore.sharedStore.lowBalanceNotified = NO;
    }
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
    if ([DSNotifier systemNotificationsAvailable]) {
        [DSNotifier postTestNotification];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已发送"
                                                                       message:@"测试通知已经交给系统，如果几秒内没有横幅，检查 设置 › 通知 › DS 余额。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    double threshold = DSStore.sharedStore.lowBalanceThreshold;
    double sample = threshold > 0 ? threshold - 0.01 : 0.0;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DeepSeek 余额偏低"
                                                                   message:[NSString stringWithFormat:@"这是一条测试提醒：当前余额 ¥%@，已低于你设置的提醒线 ¥%@。真实余额在刷新后会按同样方式提醒。", DSMoneyText(sample), DSMoneyText(threshold)]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
