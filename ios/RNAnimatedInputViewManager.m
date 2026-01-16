//
//  RNAnimatedInputViewManager.m
//  react-native-animated-input
//
//  Objective-C bridge for RNAnimatedInputViewManager
//

#import <React/RCTViewManager.h>
#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(RNAnimatedInputViewManager, RCTViewManager)

// Content callbacks
RCT_EXPORT_VIEW_PROPERTY(onChangeText, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onInputFocus, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onInputBlur, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onInputSubmit, RCTDirectEventBlock)

// Text props
RCT_EXPORT_VIEW_PROPERTY(placeholder, NSString)
RCT_EXPORT_VIEW_PROPERTY(placeholderTextColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(inputTextColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(selectionColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(textAlignString, NSString)

// Typography
RCT_EXPORT_VIEW_PROPERTY(fontFamily, NSString)

// Multiline & Auto-grow
RCT_EXPORT_VIEW_PROPERTY(multiline, BOOL)
RCT_EXPORT_VIEW_PROPERTY(autoGrow, BOOL)
RCT_EXPORT_VIEW_PROPERTY(maxHeight, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(minHeight, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(onContentSizeChange, RCTDirectEventBlock)

// Keyboard props
RCT_EXPORT_VIEW_PROPERTY(keyboardTypeString, NSString)
RCT_EXPORT_VIEW_PROPERTY(returnKeyTypeString, NSString)
RCT_EXPORT_VIEW_PROPERTY(autoCapitalizeString, NSString)
RCT_EXPORT_VIEW_PROPERTY(autoCorrectEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(secureTextEntryEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(editableEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(maxLength, int)

// Dynamic sizing
RCT_EXPORT_VIEW_PROPERTY(dynamicSizing, BOOL)
RCT_EXPORT_VIEW_PROPERTY(fontSizeRulesJson, NSString)
RCT_EXPORT_VIEW_PROPERTY(baseFontSize, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(minFontSize, CGFloat)

// Dictation animation
RCT_EXPORT_VIEW_PROPERTY(isDictating, BOOL)
RCT_EXPORT_VIEW_PROPERTY(animationDuration, double)
RCT_EXPORT_VIEW_PROPERTY(onDictationTap, RCTDirectEventBlock)

// Methods
RCT_EXTERN_METHOD(setValue:(nonnull NSNumber *)node value:(NSString *)value)
RCT_EXTERN_METHOD(focus:(nonnull NSNumber *)node)
RCT_EXTERN_METHOD(blur:(nonnull NSNumber *)node)

@end
