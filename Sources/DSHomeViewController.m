#import "DSHomeViewController.h"
#import "DSAppearance.h"
#import "DSApiClient.h"
#import "DSBalanceInfo.h"
#import "DSNotifier.h"
#import "DSStore.h"

/// A label with breathing room, used for the status pill.
@interface DSPaddedLabel : UILabel
@end

@implementation DSPaddedLabel

- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(4, 10, 4, 10))];
}

- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    return CGSizeMake(size.width + 20, size.height + 8);
}

@end

@interface DSHomeViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;

@property (nonatomic, strong) UIView *balanceCard;
@property (nonatomic, strong) UILabel *captionLabel;
@property (nonatomic, strong) UILabel *amountLabel;
@property (nonatomic, strong) DSPaddedLabel *statusLabel;
@property (nonatomic, strong) UIView *divider;
@property (nonatomic, strong) UILabel *grantedTitleLabel;
@property (nonatomic, strong) UILabel *grantedValueLabel;
@property (nonatomic, strong) UILabel *toppedUpTitleLabel;
@property (nonatomic, strong) UILabel *toppedUpValueLabel;

@property (nonatomic, strong) UIView *warningBox;
@property (nonatomic, strong) UILabel *warningLabel;
@property (nonatomic, strong) UILabel *updatedLabel;

@property (nonatomic, strong) UIView *emptyCard;
@property (nonatomic, strong) UILabel *emptyTitleLabel;
@property (nonatomic, strong) UILabel *emptyBodyLabel;
@property (nonatomic, strong) UIButton *emptyActionButton;

@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIBarButtonItem *refreshItem;

@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL didAutoRefresh;
@property (nonatomic, copy) NSArray<DSBalanceInfo *> *infos;
@property (nonatomic, assign) BOOL available;

@end

@implementation DSHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DS 余额";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    [self buildSubviews];
    [self observeNotifications];
    [self reloadFromStoredState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadFromStoredState];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.didAutoRefresh && DSStore.sharedStore.refreshOnLaunch) {
        self.didAutoRefresh = YES;
        [self refreshWithUserInteraction:NO];
    }
}

#pragma mark - Layout

- (void)buildSubviews {
    self.scrollView = [UIScrollView new];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(handlePullToRefresh) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.refreshControl];

    self.stackView = [UIStackView new];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 16;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.stackView];

    UILayoutGuide *content = self.scrollView.contentLayoutGuide;
    UILayoutGuide *frame = self.scrollView.frameLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.stackView.topAnchor constraintEqualToAnchor:content.topAnchor constant:8],
        [self.stackView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
        [self.stackView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
        [self.stackView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-24],
        [self.stackView.widthAnchor constraintEqualToAnchor:frame.widthAnchor constant:-32],
    ]];

    self.refreshItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(handleRefreshTap)];
    self.navigationItem.rightBarButtonItem = self.refreshItem;

    [self buildBalanceCard];
    [self buildWarningBox];
    [self buildUpdatedLabel];
    [self buildEmptyCard];
}

- (void)buildBalanceCard {
    self.balanceCard = [UIView new];
    self.balanceCard.backgroundColor = DSAppearance.cardColor;
    self.balanceCard.layer.cornerRadius = 22;
    self.balanceCard.layer.cornerCurve = kCACornerCurveContinuous;

    self.captionLabel = [UILabel new];
    self.captionLabel.text = @"总余额";
    self.captionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    self.captionLabel.textColor = UIColor.secondaryLabelColor;

    self.amountLabel = [UILabel new];
    self.amountLabel.text = @"—";
    self.amountLabel.font = [UIFont monospacedDigitSystemFontOfSize:42 weight:UIFontWeightBold];
    self.amountLabel.adjustsFontSizeToFitWidth = YES;
    self.amountLabel.minimumScaleFactor = 0.5;
    self.amountLabel.numberOfLines = 1;
    self.amountLabel.accessibilityTraits = UIAccessibilityTraitHeader;

    self.statusLabel = [DSPaddedLabel new];
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.statusLabel.layer.cornerRadius = 9;
    self.statusLabel.layer.cornerCurve = kCACornerCurveContinuous;
    self.statusLabel.clipsToBounds = YES;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    UIStackView *headerRow = [[UIStackView alloc] initWithArrangedSubviews:@[ self.captionLabel, [UIView new], self.statusLabel ]];
    headerRow.axis = UILayoutConstraintAxisHorizontal;
    headerRow.alignment = UIStackViewAlignmentCenter;
    headerRow.spacing = 8;

    self.divider = [UIView new];
    self.divider.backgroundColor = UIColor.separatorColor;
    self.divider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.divider.heightAnchor constraintEqualToConstant:0.5].active = YES;

    self.grantedTitleLabel = [UILabel new];
    self.grantedTitleLabel.text = @"赠金余额";
    self.grantedTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.grantedTitleLabel.textColor = UIColor.secondaryLabelColor;

    self.grantedValueLabel = [UILabel new];
    self.grantedValueLabel.text = @"—";
    self.grantedValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightMedium];

    self.toppedUpTitleLabel = [UILabel new];
    self.toppedUpTitleLabel.text = @"充值余额";
    self.toppedUpTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.toppedUpTitleLabel.textColor = UIColor.secondaryLabelColor;

    self.toppedUpValueLabel = [UILabel new];
    self.toppedUpValueLabel.text = @"—";
    self.toppedUpValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightMedium];

    UIStackView *grantedColumn = [[UIStackView alloc] initWithArrangedSubviews:@[ self.grantedTitleLabel, self.grantedValueLabel ]];
    grantedColumn.axis = UILayoutConstraintAxisVertical;
    grantedColumn.spacing = 2;
    grantedColumn.alignment = UIStackViewAlignmentLeading;

    UIStackView *toppedUpColumn = [[UIStackView alloc] initWithArrangedSubviews:@[ self.toppedUpTitleLabel, self.toppedUpValueLabel ]];
    toppedUpColumn.axis = UILayoutConstraintAxisVertical;
    toppedUpColumn.spacing = 2;
    toppedUpColumn.alignment = UIStackViewAlignmentLeading;

    UIStackView *detailRow = [[UIStackView alloc] initWithArrangedSubviews:@[ grantedColumn, toppedUpColumn ]];
    detailRow.axis = UILayoutConstraintAxisHorizontal;
    detailRow.distribution = UIStackViewDistributionFillEqually;
    detailRow.alignment = UIStackViewAlignmentTop;

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        headerRow, self.amountLabel, self.divider, detailRow,
    ]];
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 12;
    cardStack.alignment = UIStackViewAlignmentFill;
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    [cardStack setCustomSpacing:16 afterView:self.amountLabel];
    [cardStack setCustomSpacing:16 afterView:self.divider];

    [self.balanceCard addSubview:cardStack];
    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:self.balanceCard.topAnchor constant:18],
        [cardStack.leadingAnchor constraintEqualToAnchor:self.balanceCard.leadingAnchor constant:18],
        [cardStack.trailingAnchor constraintEqualToAnchor:self.balanceCard.trailingAnchor constant:-18],
        [cardStack.bottomAnchor constraintEqualToAnchor:self.balanceCard.bottomAnchor constant:-18],
    ]];

    [self.stackView addArrangedSubview:self.balanceCard];
}

- (void)buildWarningBox {
    self.warningBox = [UIView new];
    self.warningBox.backgroundColor = DSAppearance.warningBackgroundColor;
    self.warningBox.layer.cornerRadius = 14;
    self.warningBox.layer.cornerCurve = kCACornerCurveContinuous;
    self.warningBox.hidden = YES;

    self.warningLabel = [UILabel new];
    self.warningLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.warningLabel.textColor = DSAppearance.warningTextColor;
    self.warningLabel.numberOfLines = 0;
    self.warningLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.warningBox addSubview:self.warningLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.warningLabel.topAnchor constraintEqualToAnchor:self.warningBox.topAnchor constant:12],
        [self.warningLabel.leadingAnchor constraintEqualToAnchor:self.warningBox.leadingAnchor constant:14],
        [self.warningLabel.trailingAnchor constraintEqualToAnchor:self.warningBox.trailingAnchor constant:-14],
        [self.warningLabel.bottomAnchor constraintEqualToAnchor:self.warningBox.bottomAnchor constant:-12],
    ]];
    [self.stackView addArrangedSubview:self.warningBox];
}

- (void)buildUpdatedLabel {
    self.updatedLabel = [UILabel new];
    self.updatedLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.updatedLabel.textColor = UIColor.tertiaryLabelColor;
    self.updatedLabel.textAlignment = NSTextAlignmentCenter;
    self.updatedLabel.numberOfLines = 0;
    self.updatedLabel.text = @"尚未刷新";
    [self.stackView addArrangedSubview:self.updatedLabel];
}

- (void)buildEmptyCard {
    self.emptyCard = [UIView new];
    self.emptyCard.backgroundColor = DSAppearance.cardColor;
    self.emptyCard.layer.cornerRadius = 22;
    self.emptyCard.layer.cornerCurve = kCACornerCurveContinuous;

    self.emptyTitleLabel = [UILabel new];
    self.emptyTitleLabel.text = @"先填入 DeepSeek API Key";
    self.emptyTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

    self.emptyBodyLabel = [UILabel new];
    self.emptyBodyLabel.text = @"在 platform.deepseek.com 创建 API Key 后填入，即可查询余额、跟踪消耗并接收低余额提醒。";
    self.emptyBodyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.emptyBodyLabel.textColor = UIColor.secondaryLabelColor;
    self.emptyBodyLabel.numberOfLines = 0;

    self.emptyActionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.emptyActionButton setTitle:@"去设置" forState:UIControlStateNormal];
    self.emptyActionButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.emptyActionButton.backgroundColor = DSAppearance.brandColor;
    [self.emptyActionButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.emptyActionButton.layer.cornerRadius = 12;
    self.emptyActionButton.layer.cornerCurve = kCACornerCurveContinuous;
    [self.emptyActionButton addTarget:self action:@selector(goToSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.emptyActionButton.heightAnchor constraintEqualToConstant:46].active = YES;

    UIStackView *cardStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        self.emptyTitleLabel, self.emptyBodyLabel, self.emptyActionButton,
    ]];
    cardStack.axis = UILayoutConstraintAxisVertical;
    cardStack.spacing = 12;
    cardStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.emptyCard addSubview:cardStack];
    [NSLayoutConstraint activateConstraints:@[
        [cardStack.topAnchor constraintEqualToAnchor:self.emptyCard.topAnchor constant:20],
        [cardStack.leadingAnchor constraintEqualToAnchor:self.emptyCard.leadingAnchor constant:20],
        [cardStack.trailingAnchor constraintEqualToAnchor:self.emptyCard.trailingAnchor constant:-20],
        [cardStack.bottomAnchor constraintEqualToAnchor:self.emptyCard.bottomAnchor constant:-20],
    ]];
    [self.stackView addArrangedSubview:self.emptyCard];
    self.emptyCard.hidden = YES;
}

#pragma mark - Notifications

- (void)observeNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleStoreChange)
                                              name:DSDataDidChangeNotification
                                            object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleRefreshRequested)
                                              name:DSRefreshRequestedNotification
                                            object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleAppearanceChange)
                                              name:DSAppearanceDidChangeNotification
                                            object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                          selector:@selector(handleDidBecomeActive)
                                              name:UIApplicationDidBecomeActiveNotification
                                            object:nil];
}

- (void)handleStoreChange {
    [self reloadFromStoredState];
}

- (void)handleRefreshRequested {
    [self reloadFromStoredState];
    if (DSStore.sharedStore.apiKey.length > 0) {
        [self refreshWithUserInteraction:NO];
    }
}

- (void)handleAppearanceChange {
    [self applyColors];
}

- (void)handleDidBecomeActive {
    if (self.presentedViewController != nil) {
        return;
    }
    if (DSStore.sharedStore.apiKey.length > 0 && self.infos.count == 0) {
        [self refreshWithUserInteraction:NO];
    }
}

#pragma mark - State

- (void)reloadFromStoredState {
    BOOL hasKey = DSStore.sharedStore.apiKey.length > 0;
    self.emptyCard.hidden = hasKey;
    self.balanceCard.hidden = !hasKey;
    self.updatedLabel.hidden = !hasKey;
    if (!hasKey) {
        self.warningBox.hidden = YES;
        [self updateUpdatedLabelWithText:nil];
        return;
    }
    if (self.infos.count == 0) {
        [self updateWithPlaceholder];
    } else {
        [self applyInfos];
    }
}

- (void)updateWithPlaceholder {
    self.amountLabel.text = @"—";
    self.grantedValueLabel.text = @"—";
    self.toppedUpValueLabel.text = @"—";
    self.statusLabel.text = @"未刷新";
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.backgroundColor = UIColor.tertiarySystemFillColor;
    self.warningBox.hidden = YES;
    [self updateUpdatedLabelWithText:nil];
}

- (void)applyColors {
    self.balanceCard.backgroundColor = DSAppearance.cardColor;
    self.emptyCard.backgroundColor = DSAppearance.cardColor;
    self.warningBox.backgroundColor = DSAppearance.warningBackgroundColor;
    self.warningLabel.textColor = DSAppearance.warningTextColor;
    self.emptyActionButton.backgroundColor = DSAppearance.brandColor;
    self.updatedLabel.textColor = UIColor.tertiaryLabelColor;
    [self applyInfos];
}

- (void)applyInfos {
    DSBalanceInfo *primary = [DSNotifier primaryInfoFromInfos:self.infos];
    if (!primary) {
        [self updateWithPlaceholder];
        return;
    }

    self.amountLabel.text = [NSString stringWithFormat:@"%@%@", primary.currencySymbol, DSMoneyText(primary.total)];
    self.captionLabel.text = [NSString stringWithFormat:@"总余额（%@）", primary.currencyTitle];
    self.grantedValueLabel.text = [NSString stringWithFormat:@"%@%@", primary.currencySymbol, DSMoneyText(primary.granted)];
    self.toppedUpValueLabel.text = [NSString stringWithFormat:@"%@%@", primary.currencySymbol, DSMoneyText(primary.toppedUp)];

    if (self.available) {
        self.statusLabel.text = @"可用";
        self.statusLabel.textColor = UIColor.systemGreenColor;
        self.statusLabel.backgroundColor = [UIColor.systemGreenColor colorWithAlphaComponent:0.16];
    } else {
        self.statusLabel.text = @"不可用";
        self.statusLabel.textColor = UIColor.systemRedColor;
        self.statusLabel.backgroundColor = [UIColor.systemRedColor colorWithAlphaComponent:0.16];
    }

    DSStore *store = DSStore.sharedStore;
    BOOL below = store.lowBalanceAlertEnabled && primary.total <= store.lowBalanceThreshold;
    self.warningBox.hidden = !below;
    if (below) {
        self.warningLabel.text = [NSString stringWithFormat:@"余额已低于提醒线 %@%@，请及时充值。",
                                                            primary.currencySymbol,
                                                            DSMoneyText(store.lowBalanceThreshold)];
    }

    [self updateUpdatedLabelWithText:nil];
}

- (void)updateUpdatedLabelWithText:(NSString *)text {
    if (text.length > 0) {
        self.updatedLabel.textColor = UIColor.systemRedColor;
        self.updatedLabel.text = text;
        return;
    }
    self.updatedLabel.textColor = UIColor.tertiaryLabelColor;

    NSArray<NSDictionary *> *snapshots = DSStore.sharedStore.snapshots;
    NSDictionary *last = snapshots.lastObject;
    if (!last) {
        self.updatedLabel.text = @"尚未刷新";
        return;
    }

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[last[@"t"] doubleValue]];
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_Hans_CN"];
        formatter.dateFormat = @"M月d日 HH:mm";
    });

    NSString *text2 = [NSString stringWithFormat:@"更新于 %@", [formatter stringFromDate:date]];
    if (snapshots.count >= 2) {
        NSDictionary *previous = snapshots[snapshots.count - 2];
        double delta = [last[@"b"] doubleValue] - [previous[@"b"] doubleValue];
        if (fabs(delta) >= 0.005) {
            text2 = [NSString stringWithFormat:@"%@ · 较上次 %@", text2, DSDeltaText(delta)];
        }
    }
    self.updatedLabel.text = text2;
}

#pragma mark - Actions

- (void)handleRefreshTap {
    [self refreshWithUserInteraction:YES];
}

- (void)handlePullToRefresh {
    [self refreshWithUserInteraction:YES];
}

- (void)goToSettings {
    self.tabBarController.selectedIndex = 2;
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    self.refreshItem.enabled = !loading;
    if (loading) {
        [self.refreshControl beginRefreshing];
    }
}

- (void)refreshWithUserInteraction:(BOOL)userInteraction {
    if (self.loading) {
        return;
    }
    NSString *key = DSStore.sharedStore.apiKey;
    if (key.length == 0) {
        [self reloadFromStoredState];
        if (userInteraction) {
            [self goToSettings];
        }
        return;
    }

    self.loading = YES;
    __weak DSHomeViewController *weakSelf = self;
    [DSApiClient fetchBalanceWithKey:key completion:^(BOOL available, NSArray<DSBalanceInfo *> *infos, NSError *error) {
        DSHomeViewController *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loading = NO;
        [strongSelf.refreshControl endRefreshing];

        if (error) {
            [strongSelf updateUpdatedLabelWithText:[NSString stringWithFormat:@"刷新失败：%@", error.localizedDescription]];
            if (userInteraction && strongSelf.infos.count == 0) {
                [strongSelf presentError:error];
            }
            return;
        }

        strongSelf.available = available;
        strongSelf.infos = infos;
        [strongSelf applyInfos];

        DSBalanceInfo *primary = [DSNotifier primaryInfoFromInfos:infos];
        NSLog(@"[DSBalance] refresh ok, primary=%@ available=%d", primary, available);
        [DSStore.sharedStore addSnapshotWithInfo:primary];
        [DSNotifier evaluateInfos:infos];
    }];
}

- (void)presentError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法获取余额"
                                                                   message:error.localizedDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
