import React, {
  useCallback,
  useRef,
  useEffect,
  forwardRef,
  useImperativeHandle,
} from 'react';
import {
  requireNativeComponent,
  UIManager,
  Platform,
  findNodeHandle,
  StyleSheet,
  processColor,
} from 'react-native';

import type {
  AnimatedInputProps,
  AnimatedInputRef,
} from './types';

// Component name in native code
const COMPONENT_NAME = 'RNAnimatedInputView';

// Check if the native component is available
const isNativeComponentAvailable =
  Platform.OS === 'ios' &&
  UIManager.getViewManagerConfig(COMPONENT_NAME) != null;

// Import native component
const NativeAnimatedInput = isNativeComponentAvailable
  ? requireNativeComponent<any>(COMPONENT_NAME)
  : null;

// Native event types
interface NativeTextEvent {
  nativeEvent: {
    text?: string;
  };
}

interface NativeEvent {
  nativeEvent: Record<string, unknown>;
}

interface NativeContentSizeEvent {
  nativeEvent: {
    contentSize?: {
      width: number;
      height: number;
    };
  };
}

/**
 * AnimatedInput - A React Native text input with dynamic font sizing
 * and word-by-word dictation animations.
 *
 * @example
 * ```tsx
 * import { AnimatedInput } from 'react-native-animated-input';
 *
 * function MyComponent() {
 *   const [text, setText] = useState('');
 *   const [isDictating, setIsDictating] = useState(false);
 *
 *   return (
 *     <AnimatedInput
 *       value={text}
 *       onChangeText={setText}
 *       isDictating={isDictating}
 *       textAlign="center"
 *       dynamicSizing
 *     />
 *   );
 * }
 * ```
 */
export const AnimatedInput = forwardRef<AnimatedInputRef, AnimatedInputProps>(
  (
    {
      value = '',
      onChangeText,
      placeholder,
      placeholderTextColor,
      textAlign = 'left',
      fontFamily,
      multiline = true,
      autoGrow = true,
      maxHeight = 0,
      minHeight = 0,
      onContentSizeChange,
      onFocus,
      onBlur,
      onSubmitEditing,
      keyboardType = 'default',
      returnKeyType = 'default',
      autoCapitalize = 'sentences',
      autoCorrect = true,
      secureTextEntry = false,
      editable = true,
      maxLength = 0,
      dynamicSizing = false,
      fontSizeRules,
      baseFontSize = 32,
      minFontSize = 14,
      isDictating = false,
      animationDuration = 250,
      style,
    },
    ref
  ) => {
    const nativeRef = useRef<any>(null);

    // Expose focus/blur methods via ref
    useImperativeHandle(ref, () => ({
      focus: () => {
        if (nativeRef.current && Platform.OS === 'ios') {
          const nodeHandle = findNodeHandle(nativeRef.current);
          if (nodeHandle != null) {
            UIManager.dispatchViewManagerCommand(
              nodeHandle,
              UIManager.getViewManagerConfig(COMPONENT_NAME).Commands?.focus ?? 1,
              []
            );
          }
        }
      },
      blur: () => {
        if (nativeRef.current && Platform.OS === 'ios') {
          const nodeHandle = findNodeHandle(nativeRef.current);
          if (nodeHandle != null) {
            UIManager.dispatchViewManagerCommand(
              nodeHandle,
              UIManager.getViewManagerConfig(COMPONENT_NAME).Commands?.blur ?? 2,
              []
            );
          }
        }
      },
    }));

    // Handle text change from native
    const handleChangeText = useCallback(
      (event: NativeTextEvent) => {
        const text = event.nativeEvent?.text ?? '';
        onChangeText?.(text);
      },
      [onChangeText]
    );

    // Handle focus
    const handleFocus = useCallback(
      (_event: NativeEvent) => {
        onFocus?.();
      },
      [onFocus]
    );

    // Handle blur
    const handleBlur = useCallback(
      (_event: NativeEvent) => {
        onBlur?.();
      },
      [onBlur]
    );

    // Handle submit
    const handleSubmitEditing = useCallback(
      (event: NativeTextEvent) => {
        const text = event.nativeEvent?.text ?? '';
        onSubmitEditing?.(text);
      },
      [onSubmitEditing]
    );

    // Handle content size change (for auto-grow)
    const handleContentSizeChange = useCallback(
      (event: NativeContentSizeEvent) => {
        const contentSize = event.nativeEvent?.contentSize;
        if (contentSize) {
          onContentSizeChange?.(contentSize);
        }
      },
      [onContentSizeChange]
    );

    // Update native value when prop changes
    useEffect(() => {
      if (nativeRef.current && Platform.OS === 'ios') {
        const nodeHandle = findNodeHandle(nativeRef.current);
        if (nodeHandle != null) {
          UIManager.dispatchViewManagerCommand(
            nodeHandle,
            UIManager.getViewManagerConfig(COMPONENT_NAME).Commands?.setValue ?? 0,
            [value]
          );
        }
      }
    }, [value]);

    // Convert fontSizeRules to JSON string for native
    const fontSizeRulesJson = fontSizeRules
      ? JSON.stringify(
          fontSizeRules.map((rule) => ({
            maxLength: rule.maxLength === Infinity ? 999999 : rule.maxLength,
            fontSize: rule.fontSize,
          }))
        )
      : undefined;

    // Process placeholder color
    const processedPlaceholderColor = placeholderTextColor
      ? processColor(placeholderTextColor)
      : undefined;

    // Combine styles
    const combinedStyle = StyleSheet.flatten([styles.default, style]);

    // Handle unsupported platform
    if (!isNativeComponentAvailable) {
      console.warn(
        'react-native-animated-input: Native component not available. ' +
          'This library currently only supports iOS.'
      );
      return null;
    }

    return (
      <NativeAnimatedInput
        ref={nativeRef}
        style={combinedStyle}
        // Content
        onChangeText={handleChangeText}
        placeholder={placeholder}
        placeholderTextColor={processedPlaceholderColor}
        // Alignment
        textAlignString={textAlign}
        // Typography
        fontFamily={fontFamily}
        // Multiline & Auto-grow
        multiline={multiline}
        autoGrow={autoGrow}
        maxHeight={maxHeight}
        minHeight={minHeight}
        onContentSizeChange={handleContentSizeChange}
        // Keyboard & Input handlers
        onInputFocus={handleFocus}
        onInputBlur={handleBlur}
        onInputSubmit={handleSubmitEditing}
        keyboardTypeString={keyboardType}
        returnKeyTypeString={returnKeyType}
        autoCapitalizeString={autoCapitalize}
        autoCorrectEnabled={autoCorrect}
        secureTextEntryEnabled={secureTextEntry}
        editableEnabled={editable}
        maxLength={maxLength}
        // Dynamic sizing
        dynamicSizing={dynamicSizing}
        fontSizeRulesJson={fontSizeRulesJson}
        baseFontSize={baseFontSize}
        minFontSize={minFontSize}
        // Dictation
        isDictating={isDictating}
        animationDuration={animationDuration}
      />
    );
  }
);

AnimatedInput.displayName = 'AnimatedInput';

const styles = StyleSheet.create({
  default: {
    minHeight: 50,
  },
});

// Re-export types
export type {
  AnimatedInputProps,
  AnimatedInputRef,
  FontSizeRule,
  KeyboardType,
  ReturnKeyType,
  AutoCapitalize,
} from './types';

// Default export
export default AnimatedInput;
