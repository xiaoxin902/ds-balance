#import "DSHistoryViewController.h"
#import "DSAppearance.h"
#import "DSBalanceInfo.h"
#import "DSLineChartView.h"
#import "DSStore.h"

typedef NS_ENUM(NSInteger, DSHistoryPeriod) {
    DSHistoryPeriodHour = 0,
    DSHistoryPeriodToday,
    DSHistoryPeriodWeek,
};

static NSString *DSSymbolForCurrency(NSString *currency) {
    if ([currency caseInsensitiveCompare:@"CNY"] == NSOrderedSame) {
        return @"¥";
    }
    if ([currency caseInsensitiveCompare:@"USD"] == NSOrderedSame) {
        return @"$";
    }
    return [currency stringByAppendingString:@" "];
}

static NSString *DSTimeText(NSTimeInterval timestamp, NSString *format) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
    formatter.dateFormat = format;
    return [formatter stringFromDate:date];
}

static NSString *DSDurationText(NSTimeInterval seconds) {
    if (seconds >= 86400 * 30) {
        return @"30 天以上";
    }
    NSInteger totalMinutes = (NSInteger)(seconds / 60.0);
    NSInteger days = totalMinutes / (60 * 24);
    NSInteger hours = (totalMinutes - days * 60 * 24) / 60;
    NSInteger minutes = totalMinutes % 60;
    if (days > 0) {
        return [NSString stringWithFormat:@"%ld 天 %ld 小时", (long)days, (long)hours];
    }
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld 小时 %ld 分", (long)hours, (long)minutes];
    }
    return [NSString stringWithFormat:@"%ld 分钟", (long)MAX(minutes, 1)];
}

@interface DSChartCell : UITableViewCell

@property (nonatomic, copy) NSArray<NSDictionary *> *snapshots; // oldest first
@property (nonatomic, assign) DSHistoryPeriod period;
@property (nonatomic, copy) void (^onPeriodChanged)(DSHistoryPeriod period);

- (void)refreshContent;

@end

@interface DSChartCell ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UILabel *trendLabel;
@property (nonatomic, strong) UISegmentedControl *segmented;
@property (nonatomic, strong) DSLineChartView *chartView;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *forecastLabel;
@end

@implementation DSChartCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        [self buildSubviews];
    }
    return self;
}

- (void)buildSubviews {
    self.titleLabel = [UILabel new];
    self.titleLabel.text = @"余额趋势";
    self.titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold];

    self.badgeLabel = [UILabel new];
    self.badgeLabel.text = @"  本机记录  ";
    self.badgeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.badgeLabel.textColor = DSAppearance.brandColor;
    self.badgeLabel.backgroundColor = [DSAppearance.brandColor colorWithAlphaComponent:0.10];
    self.badgeLabel.layer.cornerRadius = 9;
    self.badgeLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.badgeLabel.clipsToBounds = YES;
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    [self.badgeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.badgeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *titleRow = [[UIStackView alloc] initWithArrangedSubviews:@[ self.titleLabel, [UIView new], self.badgeLabel ]];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.alignment = UIStackViewAlignmentCenter;

    self.amountLabel = [UILabel new];
    self.amountLabel.text = @"—";
    self.amountLabel.font = [UIFont monospacedDigitSystemFontOfSize:34 weight:UIFontWeightBold];
    self.amountLabel.textColor = DSAppearance.brandColor;
    self.amountLabel.adjustsFontSizeToFitWidth = YES;
    self.amountLabel.minimumScaleFactor = 0.6;

    self.captionLabel = [UILabel new];
    self.captionLabel.text = @"最新余额";
    self.captionLabel.font = [UIFont systemFontOfSize:12];
    self.captionLabel.textColor = UIColor.secondaryLabelColor;

    self.trendLabel = [UILabel new];
    self.trendLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.trendLabel.textAlignment = NSTextAlignmentCenter;
    self.trendLabel.layer.cornerRadius = 8;
    self.trendLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.trendLabel.clipsToBounds = YES;
    self.trendLabel.text = @"  持平  ";
    [self.trendLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.trendLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *captionRow = [[UIStackView alloc] initWithArrangedSubviews:@[ self.captionLabel, self.trendLabel, [UIView new] ]];
    captionRow.axis = UILayoutConstraintAxisHorizontal;
    captionRow.alignment = UIStackViewAlignmentCenter;
    captionRow.spacing = 8;

    self.segmented = [[UISegmentedControl alloc] initWithItems:@[ @"最近一小时", @"今天", @"近 7 天" ]];
    self.segmented.selectedSegmentIndex = DSHistoryPeriodHour;
    [self.segmented addTarget:self action:@selector(handlePeriodChanged) forControlEvents:UIControlEventValueChanged];

    self.chartView = [[DSLineChartView alloc] initWithFrame:CGRectZero];
    self.chartView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chartView.heightAnchor constraintEqualToConstant:170].active = YES;

    self.summaryLabel = [UILabel new];
    self.summaryLabel.font = [UIFont systemFontOfSize:13];
    self.summaryLabel.textColor = UIColor.secondaryLabelColor;
    self.summaryLabel.numberOfLines = 0;

    self.forecastLabel = [UILabel new];
    self.forecastLabel.font = [UIFont systemFontOfSize:13];
    self.forecastLabel.textColor = DSAppearance.brandColor;
    self.forecastLabel.numberOfLines = 0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        titleRow, self.amountLabel, captionRow, self.segmented, self.chartView, self.summaryLabel, self.forecastLabel,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [stack setCustomSpacing:14 afterView:self.segmented];
    [stack setCustomSpacing:12 afterView:self.chartView];
    [self.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-16],
    ]];
}

- (void)handlePeriodChanged {
    self.period = (DSHistoryPeriod)self.segmented.selectedSegmentIndex;
    [self refreshContent];
    if (self.onPeriodChanged) {
        self.onPeriodChanged(self.period);
    }
}

- (NSArray<NSDictionary *> *)pointsForPeriod {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    NSTimeInterval from = now - 3600;
    if (self.period == DSHistoryPeriodToday) {
        NSDate *start = [NSCalendar.currentCalendar startOfDayForDate:NSDate.date];
        from = start.timeIntervalSince1970;
    } else if (self.period == DSHistoryPeriodWeek) {
        from = now - 7 * 24 * 3600;
    }

    NSMutableArray<NSDictionary *> *points = [NSMutableArray array];
    for (NSDictionary *snapshot in self.snapshots) {
        if ([snapshot[@"t"] doubleValue] >= from) {
            [points addObject:snapshot];
        }
    }
    return points;
}

- (NSString *)periodName {
    switch (self.period) {
        case DSHistoryPeriodToday:
            return @"今天";
        case DSHistoryPeriodWeek:
            return @"近 7 天";
        case DSHistoryPeriodHour:
        default:
            return @"最近 1 小时";
    }
}

- (void)refreshContent {
    self.segmented.selectedSegmentIndex = self.period;

    NSDictionary *latestSnapshot = self.snapshots.lastObject;
    if (!latestSnapshot) {
        self.amountLabel.text = @"—";
        self.summaryLabel.text = @"还没有采样数据，刷新几次就能看到趋势。";
        self.forecastLabel.text = @"";
        self.chartView.values = @[];
        self.chartView.timestamps = @[];
        self.trendLabel.text = @"  持平  ";
        self.trendLabel.textColor = UIColor.secondaryLabelColor;
        self.trendLabel.backgroundColor = UIColor.tertiarySystemFillColor;
        return;
    }

    NSString *currency = latestSnapshot[@"c"];
    if (![currency isKindOfClass:NSString.class]) {
        currency = @"CNY";
    }
    NSString *symbol = DSSymbolForCurrency(currency);

    NSArray<NSDictionary *> *points = [self pointsForPeriod];
    NSMutableArray<NSNumber *> *values = [NSMutableArray array];
    NSMutableArray<NSNumber *> *times = [NSMutableArray array];
    for (NSDictionary *point in points) {
        [values addObject:@([point[@"b"] doubleValue])];
        [times addObject:@([point[@"t"] doubleValue])];
    }

    double latest = values.count > 0 ? values.lastObject.doubleValue : [latestSnapshot[@"b"] doubleValue];
    self.amountLabel.text = [NSString stringWithFormat:@"%@%@", symbol, DSMoneyText(latest)];

    self.chartView.currencySymbol = symbol;
    self.chartView.values = values;
    self.chartView.timestamps = times;

    // Consumption inside the period: every drop counts, top-ups are ignored.
    double spent = 0;
    for (NSUInteger i = 1; i < values.count; i++) {
        double delta = values[i - 1].doubleValue - values[i].doubleValue;
        if (delta > 0) {
            spent += delta;
        }
    }

    NSTimeInterval duration = 60;
    if (times.count >= 2) {
        duration = MAX(times.lastObject.doubleValue - times.firstObject.doubleValue, 60);
    }

    double change = 0;
    if (values.count >= 2) {
        change = values.lastObject.doubleValue - values.firstObject.doubleValue;
    }

    if (fabs(change) < 0.005) {
        self.trendLabel.text = @"  持平  ";
        self.trendLabel.textColor = UIColor.secondaryLabelColor;
        self.trendLabel.backgroundColor = UIColor.tertiarySystemFillColor;
    } else if (change < 0) {
        self.trendLabel.text = @"  下降  ";
        self.trendLabel.textColor = UIColor.systemRedColor;
        self.trendLabel.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.10];
    } else {
        self.trendLabel.text = @"  上升  ";
        self.trendLabel.textColor = UIColor.systemGreenColor;
        self.trendLabel.backgroundColor = [UIColor.systemGreenColor colorWithAlphaComponent:0.10];
    }

    if (values.count < 2) {
        self.summaryLabel.text = [NSString stringWithFormat:@"%@的数据还不够，再刷新几次就能看出消耗。", [self periodName]];
        self.forecastLabel.text = @"";
        return;
    }

    if (spent > 0.004) {
        self.summaryLabel.text = [NSString stringWithFormat:@"%@余额减少 %@%@。", [self periodName], symbol, DSMoneyText(spent)];
    } else {
        self.summaryLabel.text = [NSString stringWithFormat:@"%@没有检测到消耗。", [self periodName]];
    }

    double rate = spent / (duration / 3600.0);
    if (rate > 0.0001 && latest > 0) {
        NSTimeInterval remaining = latest / rate * 3600.0;
        self.forecastLabel.text = [NSString stringWithFormat:@"按这个速度（约 %@%@/小时）估算，预计还能用 %@。",
                                   symbol, DSMoneyText(rate), DSDurationText(remaining)];
    } else if (latest <= 0) {
        self.forecastLabel.text = @"余额已经用完了。";
    } else {
        self.forecastLabel.text = @"这段时间没有消耗，暂时估算不出可用时长。";
    }
}

@end

#pragma mark -

@interface DSHistoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) DSChartCell *chartCell;
@property (nonatomic, copy) NSArray<NSDictionary *> *snapshots; // oldest first
@property (nonatomic, copy) NSArray<NSDictionary *> *rows;      // newest first
@property (nonatomic, assign) DSHistoryPeriod period;

@end

@implementation DSHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"余额记录";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
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

    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleStoreChange)
                                              name:DSDataDidChangeNotification
                                            object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Data

- (void)handleStoreChange {
    [self reloadData];
}

- (void)reloadData {
    self.snapshots = DSStore.sharedStore.snapshots;
    self.rows = [[self.snapshots reverseObjectEnumerator] allObjects];
    [self.tableView reloadData];
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 1 && self.rows.count > 0 ? @"刷新记录" : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"每次刷新记录一次余额，消耗由相邻记录计算。DeepSeek 开放平台没有公开的用量明细接口，这里显示的是本机采样。";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (!self.chartCell) {
            self.chartCell = [[DSChartCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"chart"];
            __weak DSHistoryViewController *weakSelf = self;
            self.chartCell.onPeriodChanged = ^(DSHistoryPeriod period) {
                weakSelf.period = period;
            };
        }
        self.chartCell.snapshots = self.snapshots;
        self.chartCell.period = self.period;
        [self.chartCell refreshContent];
        return self.chartCell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"record"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"record"];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;

    NSDictionary *row = self.rows[indexPath.row];
    NSString *currency = row[@"c"];
    if (![currency isKindOfClass:NSString.class]) {
        currency = @"CNY";
    }
    double total = [row[@"b"] doubleValue];

    cell.textLabel.text = DSTimeText([row[@"t"] doubleValue], @"MM-dd HH:mm");
    cell.textLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
    cell.textLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", DSSymbolForCurrency(currency), DSMoneyText(total)];
    cell.detailTextLabel.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.textColor = UIColor.labelColor;

    return cell;
}

#pragma mark - Actions

- (void)handleClearTap {
    if (self.rows.count == 0) {
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空余额记录"
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
