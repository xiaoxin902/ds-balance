#import "DSHistoryViewController.h"
#import "DSAppearance.h"
#import "DSBalanceInfo.h"
#import "DSLineChartView.h"
#import "DSStore.h"

static NSString *DSSymbolForCurrency(NSString *currency) {
    if ([currency caseInsensitiveCompare:@"CNY"] == NSOrderedSame) {
        return @"¥";
    }
    if ([currency caseInsensitiveCompare:@"USD"] == NSOrderedSame) {
        return @"$";
    }
    return [currency stringByAppendingString:@" "];
}

static NSString *DSTimeText(NSTimeInterval timestamp) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    BOOL sameYear = [calendar component:NSCalendarUnitYear fromDate:date] ==
                    [calendar component:NSCalendarUnitYear fromDate:NSDate.date];
    formatter.dateFormat = sameYear ? @"M月d日 HH:mm" : @"yyyy年M月d日 HH:mm";
    return [formatter stringFromDate:date];
}

@interface DSHistoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) DSLineChartView *chartView;
@property (nonatomic, strong) UILabel *chartTitleLabel;
@property (nonatomic, strong) UILabel *chartSubtitleLabel;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;

@end

@implementation DSHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"使用记录";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(handleClearTap)];

    [self buildHeader];
    [self buildFooter];

    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleStoreChange)
                                              name:DSDataDidChangeNotification
                                            object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutHeaderIfNeeded];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Header and footer

- (void)buildHeader {
    CGFloat width = MAX(CGRectGetWidth(self.view.bounds), 320);
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 214)];

    self.chartTitleLabel = [UILabel new];
    self.chartTitleLabel.text = @"余额走势";
    self.chartTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.chartTitleLabel.frame = CGRectMake(16, 4, width - 32, 22);
    [header addSubview:self.chartTitleLabel];

    self.chartSubtitleLabel = [UILabel new];
    self.chartSubtitleLabel.text = @"由本机每次刷新时采样";
    self.chartSubtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.chartSubtitleLabel.textColor = UIColor.secondaryLabelColor;
    self.chartSubtitleLabel.frame = CGRectMake(16, 26, width - 32, 16);
    [header addSubview:self.chartSubtitleLabel];

    self.chartView = [[DSLineChartView alloc] initWithFrame:CGRectMake(12, 46, width - 24, 150)];
    [header addSubview:self.chartView];

    self.tableView.tableHeaderView = header;
}

- (void)layoutHeaderIfNeeded {
    UIView *header = self.tableView.tableHeaderView;
    if (!header) {
        return;
    }
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (width < 1 || fabs(CGRectGetWidth(header.frame) - width) < 0.5) {
        return;
    }
    header.frame = CGRectMake(0, 0, width, 214);
    self.chartTitleLabel.frame = CGRectMake(16, 4, width - 32, 22);
    self.chartSubtitleLabel.frame = CGRectMake(16, 26, width - 32, 16);
    self.chartView.frame = CGRectMake(12, 46, width - 24, 150);
    self.tableView.tableHeaderView = header;

    UIView *footer = self.tableView.tableFooterView;
    if (footer) {
        footer.frame = CGRectMake(0, 0, width, 74);
        for (UIView *subview in footer.subviews) {
            if ([subview isKindOfClass:UILabel.class]) {
                subview.frame = CGRectMake(28, 8, width - 56, 56);
            }
        }
        self.tableView.tableFooterView = footer;
    }
}

- (void)buildFooter {
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 74)];
    UILabel *label = [UILabel new];
    label.text = @"这里只是本机记录的余额变化。DeepSeek 开放平台未提供按次用量的公开接口，因此无法显示官方明细。";
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    label.textColor = UIColor.tertiaryLabelColor;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.frame = CGRectMake(28, 8, CGRectGetWidth(footer.bounds) - 56, 56);
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [footer addSubview:label];
    self.tableView.tableFooterView = footer;
}

#pragma mark - Data

- (void)handleStoreChange {
    [self reloadData];
}

- (void)reloadData {
    NSArray<NSDictionary *> *snapshots = DSStore.sharedStore.snapshots;
    self.rows = [[snapshots reverseObjectEnumerator] allObjects];

    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    NSUInteger start = snapshots.count > 240 ? snapshots.count - 240 : 0;
    for (NSUInteger i = start; i < snapshots.count; i++) {
        [values addObject:@([snapshots[i][@"b"] doubleValue])];
    }
    self.chartView.values = values;

    BOOL empty = self.rows.count == 0;
    self.chartSubtitleLabel.text = empty ? @"还没有采样数据" : @"由本机每次刷新时采样";
    self.tableView.separatorStyle = empty ? UITableViewCellSeparatorStyleNone : UITableViewCellSeparatorStyleSingleLine;
    [self.tableView reloadData];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"history";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

    NSDictionary *row = self.rows[indexPath.row];
    NSString *currency = row[@"c"];
    if (![currency isKindOfClass:NSString.class]) {
        currency = @"CNY";
    }
    double total = [row[@"b"] doubleValue];

    cell.textLabel.text = [NSString stringWithFormat:@"余额 %@%@", DSSymbolForCurrency(currency), DSMoneyText(total)];
    cell.textLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightSemibold];

    NSString *detail = DSTimeText([row[@"t"] doubleValue]);
    if ((NSUInteger)(indexPath.row + 1) < self.rows.count) {
        NSDictionary *previous = self.rows[indexPath.row + 1];
        double delta = total - [previous[@"b"] doubleValue];
        if (fabs(delta) >= 0.005) {
            detail = [NSString stringWithFormat:@"%@ · %@%@", detail, delta > 0 ? @"+" : @"−", DSMoneyText(fabs(delta))];
        }
    } else if (self.rows.count > 0) {
        detail = [NSString stringWithFormat:@"%@ · 最早记录", detail];
    }
    cell.detailTextLabel.text = detail;

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

#pragma mark - Actions

- (void)handleClearTap {
    if (self.rows.count == 0) {
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空使用记录"
                                                                   message:@"本机采样的余额历史会被删除，此操作无法撤销。"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        (void)action;
        [DSStore.sharedStore clearSnapshots];
        [self reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:alert animated:YES completion:nil];
}

@end
