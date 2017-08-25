/****************************************************************************
 *                                                                           *
 *  Copyright (C) 2014-2015 iBuildApp, Inc. ( http://ibuildapp.com )         *
 *                                                                           *
 *  This file is part of iBuildApp.                                          *
 *                                                                           *
 *  This Source Code Form is subject to the terms of the iBuildApp License.  *
 *  You can obtain one at http://ibuildapp.com/license/                      *
 *                                                                           *
 ****************************************************************************/

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "mWebVC.h"
#import "downloadindicator.h"
#import "urlloader.h"

/**
 *  Main module class for widget Coupons. Module entry point.
 */

// NSXMLParserDelegate is added because of TBXML can't parse some "invalid" xmls
@interface mCouponsViewController : UIViewController <NSXMLParserDelegate,
                                                      UITableViewDataSource,
                                                      UITableViewDelegate,
                                                      IURLLoaderDelegate>
{
    NSMutableArray *arr;
    BOOL isRSSFeed;
}

/**
 *  Widget main page title
 */
@property (nonatomic, copy) NSString *title;

/**
 *  Use 24-hour time format
 */
@property (nonatomic, assign) BOOL normalFormatDate;

/**
 *  Text color
 */
@property (nonatomic, strong) UIColor       *txtColor;

/**
 *  Title color
 */
@property (nonatomic, strong) UIColor       *titleColor;

/**
 *  Background color
 */
@property (nonatomic, strong) UIColor       *backgroundColor;

/**
 *  URL string with RSS path for loading coupons feed
 */
@property (nonatomic, copy  ) NSString     *RSSPath;

@end
