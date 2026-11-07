#import "DSKeyEditorViewController.h"
#import "DSAppearance.h"
#import "DSStore.h"

@interface DSKeyEditorViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *saveButton;

@end

@implementation DSKeyEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"API Key";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(handleSave)];

    UILabel *hint = [UILabel new];
    hint.text = @"在 platform.deepseek.com 的 API keys 页面创建，形如 sk-…。它只保存在本机钥匙串里，只会发送给 api.deepseek.com。";
    hint.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    hint.textColor = UIColor.secondaryLabelColor;
    hint.numberOfLines = 0;

    self.textField = [UITextField new];
    self.textField.placeholder = @"sk-…";
    self.textField.text = DSStore.sharedStore.apiKey ?: @"";
    self.textField.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    self.textField.borderStyle = UITextBorderStyleRoundedRect;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.textField.smartQuotesType = UITextSmartQuotesTypeNo;
    self.textField.smartDashesType = UITextSmartDashesTypeNo;
    self.textField.keyboardType = UIKeyboardTypeASCIICapable;
    self.textField.returnKeyType = UIReturnKeyDone;
    self.textField.clearButtonMode = UITextFieldViewModeAlways;
    self.textField.delegate = self;
    [self.textField.heightAnchor constraintEqualToConstant:44].active = YES;

    self.pasteButton = [self makeButtonWithTitle:@"从剪贴板粘贴" action:@selector(handlePaste)];
    self.clearButton = [self makeButtonWithTitle:@"清空" action:@selector(handleClear)];
    self.saveButton = [self makeButtonWithTitle:@"保存" action:@selector(handleSave)];
    self.saveButton.backgroundColor = DSAppearance.brandColor;
    [self.saveButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

    UIStackView *buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[ self.pasteButton, self.clearButton ]];
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.distribution = UIStackViewDistributionFillEqually;
    buttonRow.spacing = 12;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ hint, self.textField, buttonRow, self.saveButton ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.textField becomeFirstResponder];
}

- (UIButton *)makeButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    button.backgroundColor = UIColor.secondarySystemBackgroundColor;
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.layer.cornerRadius = 12;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    [button.heightAnchor constraintEqualToConstant:46].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Actions

- (void)handlePaste {
    UIPasteboard *pasteboard = UIPasteboard.generalPasteboard;
    NSString *text = pasteboard.string;
    if (text.length == 0) {
        [self showMessage:@"剪贴板里没有文本"];
        return;
    }
    self.textField.text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [self showMessage:@"已从剪贴板填入"];
}

- (void)handleClear {
    self.textField.text = @"";
    [self showMessage:@"已清空输入框，点保存才会移除已存的 Key"];
}

- (void)handleSave {
    NSString *text = [self.textField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    DSStore.sharedStore.apiKey = text;
    [self.view endEditing:YES];
    [self.navigationController popViewControllerAnimated:YES];
    [NSNotificationCenter.defaultCenter postNotificationName:DSRefreshRequestedNotification object:nil];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
