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
            return @"余额提醒依赖应用刷新：打开或下拉刷新时检查。系统不给此安装方式的应用通知权限，所以应用不在前台时不会提醒。";
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
                cell.detailTextLabel.text = @"此安装方式不可用";
                cell.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"测试提醒";
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
            [self presentThresholdEditor];
        } else if (indexPath.row == 3) {
            [self explainSystemNotifications];
        } else if (indexPath.row == 4) {
            [self sendTestNotification];
        }
    } else if (indexPath.section == DSSettingsSectionData) {
        [self confirmClearRecords];
    }
}

#pragma mark - Actions

- (void)explainSystemNotifications {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"系统通知不可用"
                                                                   message:@"这个应用安装在 /Applications，系统把它当作平台组件，不给它通知授权，设置里也不会出现它的通知开关。这是安装方式决定的，改代码绕不过去。\n\n作为替代：打开或刷新应用时，余额低于阈值会弹窗提醒。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
