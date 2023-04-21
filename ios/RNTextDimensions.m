#import "RNTextDimensions.h"

#if __has_include(<React/RCTConvert.h>)
#import <React/RCTConvert.h>
#import <React/RCTFont.h>
#import <React/RCTUtils.h>
#else
#import "React/RCTConvert.h"
#import "React/RCTFont.h"
#import "React/RCTUtils.h"
#endif

#import <CoreText/CoreText.h>

static NSString *const E_MISSING_TEXT = @"E_MISSING_TEXT";
static NSString *const E_INVALID_FONT_SPEC = @"E_INVALID_FONT_SPEC";
static NSString *const E_INVALID_TEXTSTYLE = @"E_INVALID_TEXTSTYLE";
static NSString *const E_INVALID_FONTFAMILY = @"E_INVALID_FONTFAMILY";

static inline BOOL isNull(id str) {
  return !str || str == (id) kCFNull;
}

static inline CGFloat CGFloatValueFrom(NSNumber * _Nullable num) {
#if CGFLOAT_IS_DOUBLE
  return num ? num.doubleValue : NAN;
#else
  return num ? num.floatValue : NAN;
#endif
}

#define A_SIZE(x) (sizeof (x)/sizeof (x)[0])

@implementation RNTextDimensions

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (dispatch_queue_t)methodQueue {
  return dispatch_get_main_queue();
}

RCT_EXPORT_METHOD(measure:(NSDictionary * _Nullable)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *const _Nullable text = [RCTConvert NSString:options[@"text"]];
  if (isNull(text)) {
    reject(E_MISSING_TEXT, @"Missing required text.", nil);
    return;
  }

  if (!text.length) {
    resolve(@{
              @"width": @0,
              @"height": @14,
              @"lastLineWidth": @0,
              @"lineCount": @0,
              });
    return;
  }

  UIFont *const _Nullable font = [self scaledUIFontFromUserSpecs:options];
  if (!font) {
    reject(E_INVALID_FONT_SPEC, @"Invalid font specification.", nil);
    return;
  }

  const CGFloat optWidth = CGFloatValueFrom(options[@"width"]);
  const CGFloat maxWidth = isnan(optWidth) || isinf(optWidth) ? CGFLOAT_MAX : optWidth;
  const CGSize maxSize = CGSizeMake(maxWidth, CGFLOAT_MAX);

  const CGFloat letterSpacing = CGFloatValueFrom(options[@"letterSpacing"]);
  NSDictionary<NSAttributedStringKey,id> *const attributes = isnan(letterSpacing)
  ? @{NSFontAttributeName: font}
  : @{NSFontAttributeName: font, NSKernAttributeName: @(letterSpacing)};

  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:maxSize];
  textContainer.lineFragmentPadding = 0.0;
  textContainer.lineBreakMode = NSLineBreakByClipping;

  NSLayoutManager *layoutManager = [NSLayoutManager new];
  [layoutManager addTextContainer:textContainer];
  layoutManager.allowsNonContiguousLayout = YES;

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:text attributes:attributes];
  [textStorage addLayoutManager:layoutManager];

  [layoutManager ensureLayoutForTextContainer:textContainer];
  CGSize size = [layoutManager usedRectForTextContainer:textContainer].size;
  if (!isnan(letterSpacing) && letterSpacing < 0) {
    size.width -= letterSpacing;
  }

  const CGFloat epsilon = 0.001;
  const CGFloat width = MIN(RCTCeilPixelValue(size.width + epsilon), maxSize.width);
  const CGFloat height = MIN(RCTCeilPixelValue(size.height + epsilon), maxSize.height);
  const NSInteger lineCount = [self getLineCount:layoutManager];

  NSMutableDictionary *result = [[NSMutableDictionary alloc]
                                 initWithObjectsAndKeys:@(width), @"width",
                                 @(height), @"height",
                                 @(lineCount), @"lineCount",
                                 nil];

  if ([options[@"usePreciseWidth"] boolValue]) {
    const CGFloat lastIndex = layoutManager.numberOfGlyphs - 1;
    const CGSize lastSize = [layoutManager lineFragmentUsedRectForGlyphAtIndex:lastIndex
                                                                effectiveRange:nil].size;
    [result setValue:@(lastSize.width) forKey:@"lastLineWidth"];
  }

  const CGFloat optLine = CGFloatValueFrom(options[@"lineInfoForLine"]);
  if (!isnan(optLine) && optLine >= 0) {
    const NSInteger line = MIN((NSInteger) optLine, lineCount);
    NSDictionary *lineInfo = [self getLineInfo:layoutManager str:text lineNo:line];
    if (lineInfo) {
      [result setValue:lineInfo forKey:@"lineInfo"];
    }
  }

  resolve(result);
}

RCT_EXPORT_METHOD(flatHeights:(NSDictionary * _Nullable)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSArray *const _Nullable texts = [RCTConvert NSArray:options[@"text"]];
  if (isNull(texts)) {
    reject(E_MISSING_TEXT, @"Missing required text, must be an array.", nil);
    return;
  }

  UIFont *const _Nullable font = [self scaledUIFontFromUserSpecs:options];
  if (!font) {
    reject(E_INVALID_FONT_SPEC, @"Invalid font specification.", nil);
    return;
  }

  const CGFloat optWidth = CGFloatValueFrom(options[@"width"]);
  const CGFloat maxWidth = isnan(optWidth) || isinf(optWidth) ? CGFLOAT_MAX : optWidth;
  const CGSize maxSize = CGSizeMake(maxWidth, CGFLOAT_MAX);

  const CGFloat letterSpacing = CGFloatValueFrom(options[@"letterSpacing"]);
  NSDictionary<NSAttributedStringKey,id> *const attributes = isnan(letterSpacing)
  ? @{NSFontAttributeName: font}
  : @{NSFontAttributeName: font, NSKernAttributeName: @(letterSpacing)};

  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:maxSize];
  textContainer.lineFragmentPadding = 0.0;
  textContainer.lineBreakMode = NSLineBreakByClipping;

  NSLayoutManager *layoutManager = [NSLayoutManager new];
  [layoutManager addTextContainer:textContainer];

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:@" " attributes:attributes];
  [textStorage addLayoutManager:layoutManager];

  NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] initWithCapacity:texts.count];
  const CGFloat epsilon = 0.001;

  for (int ix = 0; ix < texts.count; ix++) {
    NSString *text = texts[ix];

    if (![text isKindOfClass:[NSString class]]) {
      result[ix] = @0;
      continue;
    }

    if (!text.length) {
      result[ix] = @14;
      continue;
    }

    NSRange range = NSMakeRange(0, textStorage.length);
    [textStorage replaceCharactersInRange:range withString:text];
    CGSize size = [layoutManager usedRectForTextContainer:textContainer].size;

    const CGFloat height = MIN(RCTCeilPixelValue(size.height + epsilon), maxSize.height);
    result[ix] = @(height);
  }

  resolve(result);
}

RCT_EXPORT_METHOD(fontFromSpecs:(NSDictionary *)specs
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (isNull(specs)) {
    reject(E_INVALID_FONT_SPEC, @"Missing font specification.", nil);
  } else {
    UIFont * _Nullable font = [self UIFontFromUserSpecs:specs withScale:1.0];
    if (font) {
      resolve([self fontInfoFromUIFont:font]);
    } else {
      reject(E_INVALID_FONT_SPEC, @"Invalid font specification.", nil);
    }
  }
}

RCT_EXPORT_METHOD(specsForTextStyles:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  static const int T_OFFSET = 10;
  static const char trackings[] = {
    12, 6, 0, -6, -11, -16, -20, -24, -25, -26,
    19, 17, 16, 16, 15, 14, 14, 13, 13, 13,
    12, 12, 12, 11, 11,
  };

  static char *keys[] = {
    "title1", "title2", "title3", "headline",
    "body",  "callout", "subheadline",
    "footnote", "caption1", "caption2",
    "largeTitle",
  };

  static char sizes[] = {
    28, 22, 20, 17,
    17, 16, 15,
    13, 12, 11,
    34,
  };

  UIFontTextStyle textStyleLargeTitle;
  int length = A_SIZE(keys);
  if (@available(iOS 11.0, *)) {
    textStyleLargeTitle = UIFontTextStyleLargeTitle;
  } else {
    textStyleLargeTitle = (id) [NSNull null];
    length--;
  }

  NSArray<UIFontTextStyle> *textStyles =
  @[
    UIFontTextStyleTitle1, UIFontTextStyleTitle2, UIFontTextStyleTitle3, UIFontTextStyleHeadline,
    UIFontTextStyleBody, UIFontTextStyleCallout, UIFontTextStyleSubheadline,
    UIFontTextStyleFootnote, UIFontTextStyleCaption1, UIFontTextStyleCaption2,
    textStyleLargeTitle,
    ];

  NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[textStyles count]];

  for (int ix = 0; ix < length; ix++) {
    const UIFontTextStyle textStyle = textStyles[ix];

    const UIFont *font = [UIFont preferredFontForTextStyle:textStyle];
    const UIFontDescriptor *descriptor = font.fontDescriptor;
    const NSDictionary *traits = [descriptor objectForKey:UIFontDescriptorTraitsAttribute];

    const NSString *fontFamily = font.familyName ?: font.fontName ?: (id) [NSNull null];
    const NSArray *fontVariant = [self fontVariantFromDescriptor:descriptor];
    const NSString *fontStyle  = [self fontStyleFromTraits:traits];
    const NSString *fontWeight = [self fontWeightFromTraits:traits];

    const int fontSize = sizes[ix];
    const int index = fontSize - T_OFFSET;
    const int tracking = index >= 0 && index < A_SIZE(trackings) ? trackings[index] : 0;
    const CGFloat letterSpacing = fontSize * tracking / 1000.0;

    NSMutableDictionary *value = [[NSMutableDictionary alloc]
                                  initWithObjectsAndKeys:fontFamily, @"fontFamily",
                                  @(fontSize), @"fontSize",
                                  @(letterSpacing), @"letterSpacing",
                                  nil];
    if (![fontWeight isEqualToString:@"normal"]) {
      [value setValue:fontWeight forKey:@"fontWeight"];
    }
    if (![fontStyle isEqualToString:@"normal"]) {
      [value setValue:fontStyle forKey:@"fontStyle"];
    }
    if (fontVariant) {
      [value setValue:fontVariant forKey:@"fontVariant"];
    }

    [result setValue:value forKey:@(keys[ix])];
  }

  resolve(result);
}

RCT_EXPORT_METHOD(fontFamilyNames:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSArray<NSString *> *fonts = [UIFont.familyNames
                                sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  resolve(fonts);
}

RCT_EXPORT_METHOD(fontNamesForFamilyName:(NSString * _Nullable)fontFamily
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (isNull(fontFamily)) {
    reject(E_INVALID_FONTFAMILY, @"Missing fontFamily name.", nil);
  } else {
    NSArray<NSString *> *fontNames = [UIFont fontNamesForFamilyName:fontFamily];
    if (fontNames) {
      resolve(UIFont.familyNames);
    } else {
      reject(E_INVALID_FONTFAMILY, @"Invalid fontFamily name.", nil);
    }
  }
}

- (NSInteger)getLineCount:(NSLayoutManager *)layoutManager {
  NSRange lineRange;
  NSUInteger glyphCount = layoutManager.numberOfGlyphs;
  NSInteger lineCount = 0;

  for (NSUInteger index = 0; index < glyphCount; lineCount++) {
    [layoutManager
     lineFragmentUsedRectForGlyphAtIndex:index effectiveRange:&lineRange withoutAdditionalLayout:YES];
    index = NSMaxRange(lineRange);
  }

  return lineCount;
}

- (NSDictionary *)getLineInfo:(NSLayoutManager *)layoutManager str:(NSString *)str lineNo:(NSInteger)line {
  CGRect lineRect = CGRectZero;
  NSRange lineRange;
  NSUInteger glyphCount = layoutManager.numberOfGlyphs;
  NSInteger lineCount = 0;

  for (NSUInteger index = 0; index < glyphCount; lineCount++) {
    lineRect = [layoutManager
                lineFragmentUsedRectForGlyphAtIndex:index
                effectiveRange:&lineRange
                withoutAdditionalLayout:YES];
    index = NSMaxRange(lineRange);

    if (line == lineCount) {
      NSCharacterSet *ws = NSCharacterSet.whitespaceAndNewlineCharacterSet;
      NSRange charRange = [layoutManager characterRangeForGlyphRange:lineRange actualGlyphRange:nil];
      NSUInteger start = charRange.location;
      index = NSMaxRange(charRange);
      while (index > start && [ws characterIsMember:[str characterAtIndex:index - 1]]) {
        index--;
      }
      return @{
               @"line": @(line),
               @"start": @(start),
               @"end": @(index),
               @"bottom": @(lineRect.origin.y + lineRect.size.height),
               @"width": @(lineRect.size.width)
               };
    }
  }

  return nil;
}

- (UIFont * _Nullable)scaledUIFontFromUserSpecs:(const NSDictionary *)specs
{
  const id allowFontScalingSrc = specs[@"allowFontScaling"];
  const BOOL allowFontScaling = allowFontScalingSrc ? [allowFontScalingSrc boolValue] : YES;
  const CGFloat scaleMultiplier =
  allowFontScaling && _bridge ? _bridge.accessibilityManager.multiplier : 1.0;

  return [self UIFontFromUserSpecs:specs withScale:scaleMultiplier];
}

- (UIFont * _Nullable)UIFontFromUserSpecs:(const NSDictionary *)specs
                                withScale:(CGFloat)scaleMultiplier
{
  return [RCTFont updateFont:nil
                  withFamily:[RCTConvert NSString:specs[@"fontFamily"]]
                        size:[RCTConvert NSNumber:specs[@"fontSize"]]
                      weight:[RCTConvert NSString:specs[@"fontWeight"]]
                       style:[RCTConvert NSString:specs[@"fontStyle"]]
                     variant:[RCTConvert NSStringArray:specs[@"fontVariant"]]
             scaleMultiplier:scaleMultiplier];
}

- (NSDictionary *)fontInfoFromUIFont:(const UIFont *)font
{
  const UIFontDescriptor *descriptor = font.fontDescriptor;
  const NSDictionary *traits = [descriptor objectForKey:UIFontDescriptorTraitsAttribute];
  const NSArray *fontVariant = [self fontVariantFromDescriptor:descriptor];

  return @{
           @"fontFamily": RCTNullIfNil(font.familyName),
           @"fontName": RCTNullIfNil(font.fontName),
           @"fontSize": @(font.pointSize),
           @"fontStyle": [self fontStyleFromTraits:traits],
           @"fontWeight": [self fontWeightFromTraits:traits],
           @"fontVariant": RCTNullIfNil(fontVariant),
           @"ascender": @(font.ascender),
           @"descender": @(font.descender),
           @"capHeight": @(font.capHeight),
           @"xHeight": @(font.xHeight),
           @"leading": @(font.leading),
           @"lineHeight": @(font.lineHeight),
           @"_hash": @(font.hash),
           };
}

- (NSString *)fontWeightFromTraits:(const NSDictionary *)traits
{

  const CGFloat weight = CGFloatValueFrom(traits[UIFontWeightTrait]) + 0.01;

  return (weight >= UIFontWeightBlack) ? @"900"
  : (weight >= UIFontWeightHeavy) ? @"800"
  : (weight >= UIFontWeightBold) ? @"bold"
  : (weight >= UIFontWeightSemibold) ? @"600"
  : (weight >= UIFontWeightMedium) ? @"500"
  : (weight >= UIFontWeightRegular) ? @"normal"
  : (weight >= UIFontWeightLight) ? @"300"
  : (weight >= UIFontWeightThin) ? @"200" : @"100";
}

- (NSString *)fontStyleFromTraits:(const NSDictionary *)traits
{
  const UIFontDescriptorSymbolicTraits symbolicTrais = [traits[UIFontSymbolicTrait] unsignedIntValue];
  const BOOL isItalic = (symbolicTrais & UIFontDescriptorTraitItalic) != 0;

  return isItalic ? @"italic" : @"normal";
}

- (NSArray<NSString *> * _Nullable)fontVariantFromDescriptor:(const UIFontDescriptor *)descriptor
{
  const NSArray *features = descriptor.fontAttributes[UIFontDescriptorFeatureSettingsAttribute];
  if (isNull(features)) {
    return nil;
  }

  const NSString *outArr[features.count];
  NSUInteger count = 0;

  for (NSDictionary *item in features) {
    const NSNumber *type = item[UIFontFeatureTypeIdentifierKey];
    if (type) {
      const int value = (int) [item[UIFontFeatureSelectorIdentifierKey] longValue];

      switch (type.integerValue) {
        case kLowerCaseType:
          if (value == kLowerCaseSmallCapsSelector) {
            outArr[count++] = @"small-caps";
          }
          break;
        case kNumberCaseType:
          if (value == kLowerCaseNumbersSelector) {
            outArr[count++] = @"oldstyle-nums";
          } else if (value == kUpperCaseNumbersSelector) {
            outArr[count++] = @"lining-nums";
          }
          break;
        case kNumberSpacingType:
          if (value == kMonospacedNumbersSelector) {
            outArr[count++] = @"tabular-nums";
          } else if (value == kProportionalNumbersSelector) {
            outArr[count++] = @"proportional-nums";
          }
          break;
      }
    }
  }

  return count ? [NSArray arrayWithObjects:outArr count:count] : nil;
}

@end
