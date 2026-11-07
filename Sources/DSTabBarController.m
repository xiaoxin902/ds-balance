#import "DSTabBarController.h"
#import "DSHistoryViewController.h"
#import "DSHomeViewController.h"
#import "DSSettingsViewController.h"

@implementation DSTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIViewController *home = [self navigationControllerWithRoot:[DSHomeViewController new]
                                                          title:@"余额"
                                                      imageName:@"creditcard"
                                              selectedImageName:@"creditcard.fill"];
    UIViewController *history = [self navigationControllerWithRoot:[DSHistoryViewController new]
                                                              title:@"记录"
                                                          imageName:@"chart.xyaxis.line"
                                                  selectedImageName:@"chart.xyaxis.line"];
    UIViewController *settings = [self navigationControllerWithRoot:[DSSettingsViewController new]
                                                               title:@"设置"
                                                           imageName:@"gearshape"
                                                   selectedImageName:@"gearshape.fill"];

    self.viewControllers = @[ home, history, settings ];
    self.selectedIndex = 0;
}

- (UIViewController *)navigationControllerWithRoot:(UIViewController *)root
                                             title:(NSString *)title
                                         imageName:(NSString *)imageName
                                 selectedImageName:(NSString *)selectedImageName {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.navigationBar.prefersLargeTitles = YES;
    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:title
                                                       image:[UIImage systemImageNamed:imageName]
                                               selectedImage:[UIImage systemImageNamed:selectedImageName]];
    navigation.tabBarItem = item;
    return navigation;
}

@end
