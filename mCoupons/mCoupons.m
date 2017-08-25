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

#import "mCoupons.h"
#import "functionLibrary.h"
#import "TBXML+HTTP.h"
#import "mWebVC.h"
#import "reachability.h"
#import "NSURL+RootDomain.h"
#import "UIColor+HSL.h"
#import "NSString+size.h"
#import "downloadmanager.h"
#import "NSString+colorizer.h"

#import <SDWebImage/UIImageView+WebCache.h>

#import "sharedFunctions.h"

@interface mCouponsViewController()

@property (nonatomic, strong) TDownloadIndicator *downloadIndicator;
@property (nonatomic, strong) UITableView *tblView;

// Buffer for current element
@property (nonatomic, strong) NSMutableString *currentElement;
@end

@implementation mCouponsViewController

@synthesize
title,
normalFormatDate,
txtColor,
titleColor,
backgroundColor,
RSSPath,
tblView,
downloadIndicator,
currentElement = _currentElement;

#pragma mark - XML <data> parser

/**
 *  Special parser for processing original xml file
 *
 *  @param xmlElement_ XML node
 *  @param params_     Dictionary with module parameters
 */
+ (void)parseXML:(NSValue *)xmlElement_
     withParams:(NSMutableDictionary *)params_
{
  TBXMLElement element;
  [xmlElement_ getValue:&element];

  NSMutableArray *contentArray = [[NSMutableArray alloc] init];

  NSString *szTitle = @"";
  TBXMLElement *titleElement = [TBXML childElementNamed:@"title" parentElement:&element];
  if ( titleElement )
    szTitle = [TBXML textForElement:titleElement];
  
  
  NSMutableDictionary *contentDict = [[NSMutableDictionary alloc] init];
  [contentDict setObject:(szTitle ? szTitle : @"") forKey:@"title"];
  
    // search for tag <colorskin>
  TBXMLElement *colorskinElement = [TBXML childElementNamed:@"colorskin" parentElement:&element];
  if (colorskinElement)
  {
    TBXMLElement *colorElement = colorskinElement->firstChild;
    while( colorElement )
    {
      NSString *colorElementContent = [TBXML textForElement:colorElement];
      
      if ( [colorElementContent length] )
        [contentDict setValue:colorElementContent forKey:[[TBXML elementName:colorElement] lowercaseString]];
      
      colorElement = colorElement->nextSibling;
    }
  }
  
    // 1. adding a zero element to array
  [contentArray addObject:contentDict];
  
  
    /// 2. search for tag <rss>
  TBXMLElement *urlElement = [TBXML childElementNamed:@"rss" parentElement:&element];
  if ( urlElement )
  {
    NSString *szRssURL = [TBXML textForElement:urlElement];
    if ( [szRssURL length] )
      [contentArray addObject: [NSDictionary dictionaryWithObject:szRssURL forKey:@"rss"] ];
  }
  else
  {
      // search for tag <item> if <rss> is not exists
    TBXMLElement *itemElement = [TBXML childElementNamed:@"item" parentElement:&element];
    while( itemElement )
    {
        // search for tags title, indextext, date, url, description
      NSMutableDictionary *objDictionary = [[NSMutableDictionary alloc] init];

      TBXMLElement *tagElement = itemElement->firstChild;
      while( tagElement )
      {
        NSString *szTag = [[TBXML elementName:tagElement] lowercaseString];

        if ( [szTag isEqual:@"title"] )
        {
          NSString *tagContent = [TBXML textForElement:tagElement];
          if ( [tagContent length] )
            [objDictionary setObject:tagContent forKey:@"title"];
        }
        else if ( [szTag isEqual:@"description"] )
        {
          NSString *tagContent = [TBXML textForElement:tagElement];
          if ( [tagContent length] )
            [objDictionary setObject:tagContent forKey:@"description"];
        }
        else if ( [szTag isEqual:@"url"] )
        {
          NSString *tagContent = [TBXML textForElement:tagElement];
          if ( [tagContent length] )
            [objDictionary setObject:tagContent forKey:@"url"];
        }
        else if ( [szTag isEqual:@"html"] )
        {
          NSString *tagContent = [TBXML textForElement:tagElement];
          if ( [tagContent length] )
            [objDictionary setObject:tagContent forKey:@"html"];
        }

        tagElement = tagElement->nextSibling;
      }
      
      if ( [objDictionary count] )
        [contentArray addObject:objDictionary];
      
      itemElement = [TBXML nextSiblingNamed:@"item" searchFromElement:itemElement];
    }
  }
  
  [params_ setObject:contentArray forKey:@"data"];
}

#pragma mark - Parsing

- (void)parseXMLWithData:(NSData *)data
{
  [arr removeAllObjects];
  //you must then convert the path to a proper NSURL or it won't work
  NSXMLParser *rssParser = [[NSXMLParser alloc] initWithData:data];
  
  // Set self as the delegate of the parser so that it will receive the parser delegate methods callbacks.
  [rssParser setDelegate:self];
  
  // Depending on the XML document you're parsing, you may want to enable these features of NSXMLParser.
  [rssParser setShouldProcessNamespaces:NO];
  [rssParser setShouldReportNamespacePrefixes:NO];
  [rssParser setShouldResolveExternalEntities:NO];
  if ([rssParser parse])
  {
    NSLog(@"... Start parsing ...");
  }
  else
  {
    NSLog(@"Parsing Error: %@", rssParser.parserError);
  }
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
  self.currentElement = [elementName mutableCopy];
  if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"])
  {
    [arr addObject:[NSMutableDictionary dictionary]];
  }
  else if ([elementName isEqualToString:@"link"])
  {
    NSMutableString *link=[[attributeDict objectForKey:@"href"] mutableCopy];
    if (link&&
        !([[arr lastObject] objectForKey:@"link"]&&[attributeDict objectForKey:@"rel"]&&[[attributeDict objectForKey:@"rel"] isEqualToString:@"image"])) //to avoid situations where link replaces with next image link
      [[arr lastObject] setObject:link forKey:@"link"];
    
    if ([attributeDict objectForKey:@"rel"]&&[[attributeDict objectForKey:@"rel"] isEqualToString:@"image"])
      [[arr lastObject] setObject:link forKey:@"url"];
    
  }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
  
  if ([elementName isEqualToString:@"item"] || [elementName isEqualToString:@"entry"])
  {
    NSString *title1 =[[arr lastObject] objectForKey:@"title"];
    if (title1)
    {
      [[arr lastObject] setObject:[title1 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"title"];
    }
    
    NSString *description = [[arr lastObject] objectForKey:@"description"];
    if (description)
    {
      NSString *updatedDescription =[functionLibrary stringByReplaceEntitiesInString:description];
      [[arr lastObject] setObject:updatedDescription forKey:@"description"];
    }
    
    NSString *url=[mCouponsViewController getAttribFromText:[[arr lastObject] objectForKey:@"description"] WithAttr:@"src="];
    if (url)
    {
      [[arr lastObject] setObject:url forKey:@"url"];
      
      NSString *imgUrl = [functionLibrary stringByReplaceEntitiesInString:url];
      [[arr lastObject] setObject:imgUrl forKey:@"imgURL"];
    }
  }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
  
  // save the characters for the current item...
  if ([self.currentElement isEqualToString:@"title"])
  {
    NSMutableString *title1 = [[arr lastObject] objectForKey:@"title"];
    if (title1)
    {
      [title1 appendString:string];
      [[arr lastObject] setObject:title1 forKey:@"title"];
    }
    else [[arr lastObject] setObject:[string mutableCopy] forKey:@"title"];
    
  }
  else if ([self.currentElement isEqualToString:@"content"])
  {
    NSMutableString *description=[[arr lastObject] objectForKey:@"description"];
    if (description)
    {
      [description appendString:string];
      [[arr lastObject] setObject:description forKey:@"description"];
    }
    else
      [[arr lastObject] setObject:[string mutableCopy] forKey:@"description"];
  }
  else if ([self.currentElement isEqualToString:@"description"])
  {
    if ([[arr lastObject] objectForKey:@"description"])
    {
      NSMutableString *tmpString = [[NSMutableString alloc] initWithString:string];
      NSMutableString *tmpDescription = [[NSMutableString alloc] initWithString:[[arr lastObject] objectForKey:@"description"]];
      [tmpDescription appendString:tmpString];
      
      NSRange tmpRange;
      tmpRange.location = 0;
      tmpRange.length = tmpString.length;
      [tmpDescription replaceOccurrencesOfString:@"&nbsp;" withString:@"" options:NSCaseInsensitiveSearch range:tmpRange];
      
      [[arr lastObject] setObject:tmpDescription forKey:@"description"];
      
      tmpDescription = nil;
      
      tmpString = nil;
    }
    else
      [[arr lastObject] setObject:[string mutableCopy] forKey:@"description"];
  }
  else if ([self.currentElement isEqualToString:@"summary"])
  {
    NSMutableString *description=[[arr lastObject] objectForKey:@"description"];
    if (description)
    {
      [description appendString:string];
      [[arr lastObject] setObject:description forKey:@"description"];
    }
    else
      [[arr lastObject] setObject:[string mutableCopy] forKey:@"description"];
  }
  else if ([self.currentElement isEqualToString:@"link"])
  {
    NSMutableString *link=[[arr lastObject] objectForKey:@"link"];
    if (link)
    {
      [link appendString:string];
      [[arr lastObject] setObject:link forKey:@"link"];
    }
    else
      [[arr lastObject] setObject:[string mutableCopy] forKey:@"link"];
    
  }
}

- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)parseError
{
  [parser abortParsing];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
  [self.tblView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
  [self.tblView reloadData];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
  [parser abortParsing];
}

+ (NSString*)getAttribFromText:(NSString*)text WithAttr:(NSString*)attrib
{
  NSString *res=nil;
  NSRange pos=[text rangeOfString:attrib];
  if (pos.location!=NSNotFound)
  {
    NSRange separator_pos;
    separator_pos.location = pos.location+pos.length;
    separator_pos.length = 1;
    NSString *separator = [text substringWithRange:separator_pos];
    
    if (![separator isEqualToString:@"\""]&&![separator isEqualToString:@"\'"])
    {
      separator = @" ";
    }
    
    NSRange content;
    content.location=pos.location+pos.length;
    
    NSRange space=[text rangeOfString:separator options:NSCaseInsensitiveSearch range:NSMakeRange(pos.location+pos.length+1, [text length]-pos.location-pos.length-1)];
    if (space.location==NSNotFound) space.location=[text length];
    content.length=space.location-pos.location-[attrib length];
    res=[[text substringWithRange:content] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\'\""]];
  }
  return res;
}

#pragma mark -

- (id)init
{
  self = [super init];
  if ( self )
  {
    
    self.backgroundColor = nil;
    self.titleColor = nil;
    self.txtColor = nil;
    self.RSSPath  = nil;
    self.tblView  = nil;
    self.downloadIndicator = nil;
    
    self.currentElement  = nil;
  }
  return self;
}

- (void)dealloc
{
  [self.downloadIndicator removeFromSuperview];
  
}

- (void)setParams:(NSMutableDictionary *)inputParams
{
  if (inputParams != nil)
  {
    NSArray *data = [inputParams objectForKey:@"data"];
    NSDictionary *contentDict = [data objectAtIndex:0];
    
    title = [contentDict objectForKey:@"title"];
    
    self.navigationItem.title = ([title length] > 0) ? title : NSLocalizedString(@"mC_pageTitle", @"Coupons");
    
      //      1 - background
      //      2 - month - not used
      //      3 - text header
      //      4 - text
      //      5 - date - not used
    
      // set colors
    if ([contentDict objectForKey:@"color1"])
      self.backgroundColor = [[contentDict objectForKey:@"color1"] asColor];
    
    if ([contentDict objectForKey:@"color3"])
      self.titleColor = [[contentDict objectForKey:@"color3"] asColor];
    
    if ([contentDict objectForKey:@"color4"])
      self.txtColor = [[contentDict objectForKey:@"color4"] asColor];
    
    
      // if colors wasn't defined - set default colors:
    if (!self.titleColor)
      self.titleColor = [UIColor blackColor];
    
    if (!self.txtColor)
      self.txtColor = [UIColor grayColor];
    
    if (!self.backgroundColor)
      self.backgroundColor = [UIColor whiteColor];
    
    
    normalFormatDate = [[inputParams objectForKey:@"normalFormatDate"] isEqual:@"1"];
    
    NSRange range;
    range.location = 1;
    range.length = [data count] - 1;
    
    if (range.length)
      arr = [[NSMutableArray alloc] initWithArray:[data objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range]] copyItems:true];
  }
}


#pragma mark - View Lifecycle

- (void)viewDidLoad
{
  [self.navigationItem setHidesBackButton:NO animated:NO];
  [self.navigationController setNavigationBarHidden:NO animated:YES];
  [[self.tabBarController tabBar] setHidden:YES];
  
  self.tblView = [[UITableView alloc] initWithFrame:self.view.frame
                                               style:UITableViewStylePlain];
  self.tblView.autoresizesSubviews = YES;
  self.tblView.autoresizingMask    = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.tblView setDelegate:self];
  [self.tblView setDataSource:self];
  self.tblView.backgroundView = nil;
  self.tblView.backgroundColor = self.backgroundColor;
if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
  if ([self.tblView respondsToSelector:@selector(setSeparatorInset:)])
    [self.tblView setSeparatorInset:UIEdgeInsetsZero];
  
  if ([self.tblView respondsToSelector:@selector(setLayoutMargins:)])
    [self.tblView setLayoutMargins:UIEdgeInsetsZero];
}
  self.view = self.tblView;
  
    // load data by rss link (if link exists)
  self.RSSPath = [[arr objectAtIndex:0] objectForKey:@"rss"];
  if ( [self.RSSPath length] )
  {
    [self.tblView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    isRSSFeed = YES;
    [arr removeAllObjects];
    
    NSString *szURL = [self.RSSPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    szURL = [szURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:szURL];
    Reachability *hostReachable = [Reachability reachabilityWithHostName: [url rootDomain]];
    NetworkStatus hostStatus = [hostReachable currentReachabilityStatus];
    if (hostStatus == NotReachable)
    {
      NSLog(@"hostStatus = NotReachable!!! mCoupons parsing RSS canceled...");
      [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
      return;
    }
    
      // show download indicator
    [self.downloadIndicator removeFromSuperview];
    self.downloadIndicator = [[TDownloadIndicator alloc] initWithFrame:self.view.bounds];
    [self.downloadIndicator createViews];
    
    [self.view addSubview:self.downloadIndicator];
    
    self.downloadIndicator.autoresizesSubviews = YES;
    self.downloadIndicator.autoresizingMask    = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.downloadIndicator];
    [self.downloadIndicator setHidden:NO];
    [self.downloadIndicator startLockViewAnimating:YES];
    
      // load async
    TURLLoader *loader = [[TURLLoader alloc] initWithURL:self.RSSPath
                                              cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                          timeoutInterval:30.f];
    TURLLoader *pOldLoader = [[TDownloadManager instance] appendTarget:loader];
    if ( pOldLoader != loader )
    {
      [pOldLoader addDelegate:self];
      [pOldLoader addDelegate:self.downloadIndicator];
    }
    else
    {
      [loader addDelegate:self.downloadIndicator];
      [loader addDelegate:self];
    }
    [[TDownloadManager instance] runAll];
  }
  else
  {
    isRSSFeed = NO;
    
    NSMutableArray *tmpContent = [[NSMutableArray alloc] init];
    NSMutableDictionary *tmp = [[NSMutableDictionary alloc] init];
    
    for (int i = 0; i < arr.count; i++)
    {
      NSMutableDictionary *currentElement = [arr objectAtIndex:i];
      [tmp setValue:[currentElement objectForKey:@"description"]      forKey:@"description"];
      [tmp setValue:[currentElement objectForKey:@"description_text"] forKey:@"description_text"];
      [tmp setValue:[currentElement objectForKey:@"title"]            forKey:@"title"];
      [tmp setValue:[currentElement objectForKey:@"url"]              forKey:@"url"];
      [tmpContent addObject:[tmp copy]];
      [tmp removeAllObjects];
    }
    [arr removeAllObjects];
    arr = [tmpContent mutableCopy];
  }
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
  [super viewDidLoad];
}


#pragma mark - UITableView delegate & datasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return arr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSURL* url = nil;
  NSDictionary *currentElement = [arr objectAtIndex:indexPath.row];
  
  NSString *url_str=[[currentElement objectForKey:@"url"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	if ( url_str )
    url = [NSURL URLWithString:[url_str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  
  CGSize titleSize = [[currentElement objectForKey:@"title"]
                      sizeForFont:[UIFont boldSystemFontOfSize:15]
                      limitSize:url?CGSizeMake(220, 40):CGSizeMake(280, 40)
                      nslineBreakMode:NSLineBreakByTruncatingTail];
	
	NSString *descr=htmlToText([functionLibrary stringByReplaceEntitiesInString:[currentElement objectForKey:@"description"]]);
  
	if (!descr) descr=@"";
  
  CGSize descrSize = [descr
                      sizeForFont:[UIFont systemFontOfSize:13]
                      limitSize:url?CGSizeMake(220, 40):CGSizeMake(300, 40)
                      nslineBreakMode:NSLineBreakByTruncatingTail];
  
  
	CGFloat res=descrSize.height+titleSize.height+8;
	NSString *date=[currentElement objectForKey:@"expires"];
	
	if (date)
    res += 30;
  
  if (res < 80)
    res = 80;
  
	return res;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CellIdentifier = @"Cell";
  
  NSDictionary *currentElement = [arr objectAtIndex:indexPath.row];
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
		cell = [self getCellContentView:CellIdentifier];
	
	UIImageView *img=(UIImageView*)[cell.contentView viewWithTag:555];
	NSURL* url =nil;
  NSString *url_str = [[currentElement objectForKey:@"imgURL"] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
  
  NSURL *urlRssPath = [NSURL URLWithString:self.RSSPath];
  
  if (url_str && urlRssPath)
  {
    NSString *scheme = urlRssPath.scheme;
    
    if ([url_str hasPrefix:@"//"])
    {
        // no scheme:
      url_str = [NSString stringWithFormat:@"%@:%@", scheme, url_str];
    }
    else if ([url_str hasPrefix:@"/"])
    {
        // processing relative path:
      url_str = [NSString stringWithFormat:@"%@://%@%@", scheme, urlRssPath.host, url_str];
    }
    url=[NSURL URLWithString:[url_str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  }
  
	if ( url )
	{
    [img setImageWithURL:url
        placeholderImage:[UIImage imageNamed:@"photo_placeholder_small"]];
    
    [img setHidden:NO];
	}
  else
  {
    [img setImage:nil];
    [img setHidden:YES];
  }
	
	UILabel *lblTitle =  (UILabel *)[cell viewWithTag:1];
  
	CGRect frame;
  if ( url )
    lblTitle.frame = CGRectMake(75, 8,220, 40);
	else
    lblTitle.frame = CGRectMake( 7, 8, cell.frame.size.width-30, 40);
  
    // &amp;amp etc ))
	lblTitle.text= [functionLibrary stringByReplaceEntitiesInString:[functionLibrary stringByReplaceEntitiesInString:[currentElement objectForKey:@"title"]]];
  
  CGSize titleSize = [lblTitle.text sizeForFont:lblTitle.font
                                      limitSize:lblTitle.frame.size
                                nslineBreakMode:lblTitle.lineBreakMode];
  
	frame = lblTitle.frame;
	frame.size.height = titleSize.height;
	lblTitle.frame = frame;
	
  if ( url )
    frame = CGRectMake( 75, titleSize.height + 5, 220, 40);
	else
    frame = CGRectMake( 7 , titleSize.height + 5, 300, 40);
  
	NSString *descr = htmlToText([functionLibrary stringByReplaceEntitiesInString:[currentElement objectForKey:@"description"]]);
  
	if (!descr)
    descr=@"";
  
	UILabel *lblDescr =  (UILabel *)[cell viewWithTag:4];
	lblDescr.frame = frame;
	[lblDescr setText: [functionLibrary stringByReplaceEntitiesInString: descr]];
	
	UILabel *lblTempDate =  (UILabel *)[cell viewWithTag:2];
	lblTempDate.frame = CGRectMake(7, [self tableView:tableView heightForRowAtIndexPath:indexPath]-35, cell.frame.size.width-30, 40);
  
  if ([currentElement objectForKey:@"expires"] != NULL)
    lblTempDate.text=[NSString stringWithFormat:NSLocalizedString(@"mC_expDateString", @"Exp.date %@"),[currentElement objectForKey:@"expires"]];
  
  cell.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:([self.backgroundColor isLight] ? @"mContacts_ArrowLight.png" : @"mContacts_Arrow.png")]];
  
  return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NSDictionary *arrElement = [arr objectAtIndex:indexPath.row];
  NSString *link = nil;
  
  if (isRSSFeed)
    link = [arrElement objectForKey:@"link"];
  else
    link = [arrElement objectForKey:@"url"];
  
  
  mWebVCViewController *webVC = [[mWebVCViewController alloc] initWithNibName:nil bundle:nil];
  
  if (isRSSFeed)
  {
    NSString *scheme;
    NSURL *url = [NSURL URLWithString:self.RSSPath];
    if (url)
      scheme = url.scheme;
    else
      scheme = @"http";
    
    NSString *description = [arrElement objectForKey:@"description"];
    
      // processing image urls without scheme:
    description = [description stringByReplacingOccurrencesOfString:@"img src=\"//" withString:[NSString stringWithFormat:@"img src=\"%@://", scheme]];
      // processing relative links:
    description = [description stringByReplacingOccurrencesOfString:@"src=\"/" withString:[NSString stringWithFormat:@"src=\"%@://%@/", scheme, url.host]];
      // mantis #350:
    description = [description stringByReplacingOccurrencesOfString:@"position: absolute;" withString:@""];

    webVC.content  = [NSString stringWithFormat:@"<style>a {text-decoration: none; color:#3399FF;}</style><span style='font-family:Helvetica; font-size:16px; font-weight:bold;'>%@</span><br><span style='font-family:Helvetica; font-size:12px; color:#555555;'></span><br /><br />%@<br /><br /><a href=%@>%@</a>", [arrElement objectForKey:@"title"],
                      description,
                      link,
                      NSLocalizedString(@"mC_readMoreLink", @"Read more...")];
    
  }
  else
  {
    
    if ([link rangeOfString:@"goo.gl"].location != NSNotFound)
    {
        // task_id=2562
      webVC.URL = link;
    }
    else if ([[[link pathExtension] lowercaseString] isEqualToString:@"pdf"])
    {
        // similar crutch for PDF-files
      webVC.URL = link;
      webVC.scalable = YES;
    }
    
    else
    {
        // 0000794: iPhone: chiness symbols in Coupons widget
        // show content with UTF8 encoding! )
      NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:link]];
      NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      
      if (str && str.length)
      {
        webVC.content = [str copy];
      }
      else
      {
        webVC.URL = link;
      }
      
    }
  }
  webVC.withoutTBar        = YES;
  webVC.showTBarOnNextStep = YES;
  webVC.title = [functionLibrary stringByReplaceEntitiesInString:[[arr objectAtIndex:indexPath.row] objectForKey:@"title"]];
  [self.navigationController pushViewController:webVC animated:YES];
}


- (UITableViewCell *) getCellContentView:(NSString *)cellIdentifier
{
  
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
  
  if ([cell respondsToSelector:@selector(setLayoutMargins:)])
  {
    [cell setPreservesSuperviewLayoutMargins:NO];
    [cell setLayoutMargins:UIEdgeInsetsZero];
  }
  
  cell.backgroundColor = [UIColor clearColor];
  
    //  [cell setBackgroundView:nil];
    //  [cell setBackgroundColor:self.backgroundColor];
  
  UIView *backgroungView = [[UIView alloc] initWithFrame:cell.frame];
  backgroungView.backgroundColor = self.backgroundColor;
  cell.backgroundView = backgroungView;
	
	UILabel *lblTemp = [[UILabel alloc] init];
	lblTemp.tag = 1;
    //	lblTemp.textColor = [UIColor blackColor];
	lblTemp.numberOfLines = 2;
	lblTemp.font = [UIFont boldSystemFontOfSize:15];
  if (self.titleColor)
    lblTemp.textColor = self.titleColor;
	lblTemp.backgroundColor = [UIColor clearColor];
	[cell.contentView addSubview:lblTemp];
	
	lblTemp = [[UILabel alloc] init];
	lblTemp.tag = 2;
	lblTemp.frame = CGRectMake(75, 24, 220, 50);
	lblTemp.font = [UIFont systemFontOfSize:11];
  if (self.txtColor)
    lblTemp.textColor = self.txtColor;
	lblTemp.backgroundColor = [UIColor clearColor];
	[cell.contentView addSubview:lblTemp];
	
	UILabel *descr = [[UILabel alloc] init];
	descr.tag = 4;
    //	descr.textColor = [UIColor grayColor];
	descr.font = [UIFont systemFontOfSize:13];
  descr.textColor = self.txtColor;
	descr.backgroundColor = [UIColor clearColor];
	descr.numberOfLines = 2;
	[cell.contentView addSubview:descr];
	
	UIImageView *img = [[UIImageView alloc] initWithFrame:CGRectMake(8, 8, 60, 60)];
  [img setClipsToBounds:YES];
  [img setContentMode:UIViewContentModeScaleAspectFill];
	[img.layer setBorderColor: [[UIColor lightGrayColor] CGColor]];
	[img.layer setBorderWidth: 1.0];
	img.tag = 555;
	[cell.contentView addSubview:img];
	[img setHidden:true];
	
	return cell;
}



#pragma mark - IURLLoaderDelegate methods
- (void)didFinishLoading:(NSData *)data
           withURLloader:(TURLLoader *)urlLoader
{
  [self.downloadIndicator removeFromSuperview];
  self.downloadIndicator = nil;
  
  [self parseXMLWithData:data];
}

- (void)loaderConnection:(NSURLConnection *)connection
        didFailWithError:(NSError *)error
            andURLloader:(TURLLoader *)urlLoader
{
  UIAlertView *message = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"mC_errorLoadingRSSAlertTitle", @"error loading")// @"error loading"
                                                     message:NSLocalizedString(@"mC_errorLoadingRSSAlertMessage", @"can't download rss feed")//@"can't download rss feed"
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedString(@"mC_errorLoadingRSSAlertOkButton", @"OK")//@"OK"
                                           otherButtonTitles:nil];
  [message show];
  [self.downloadIndicator removeFromSuperview];
  self.downloadIndicator = nil;
}


#pragma mark - Autorotate handlers
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
  return UIInterfaceOrientationIsPortrait( toInterfaceOrientation );
}

- (BOOL)shouldAutorotate
{
  return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
  return UIInterfaceOrientationMaskPortrait |
  UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
  return UIInterfaceOrientationPortrait;
}

@end
