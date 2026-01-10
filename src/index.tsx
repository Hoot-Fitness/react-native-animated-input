import React, {
  useCallback,
  useRef,
  useEffect,
  useState,
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

// Default minimum height
const DEFAULT_MIN_HEIGHT = 50;

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
    
    // Track height for auto-grow
    const effectiveMinHeight = minHeight > 0 ? minHeight : DEFAULT_MIN_HEIGHT;
    const [height, setHeight] = useState<number>(effectiveMinHeight);

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
        // #region agent log
        fetch('http://127.0.0.1:7244/ingest/266566fa-a225-481b-9c55-e41f1945d4eb',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'index.tsx:handleContentSizeChange',message:'contentSizeChange received',data:{contentSize,multiline,autoGrow,effectiveMinHeight,maxHeight,currentHeight:height},timestamp:Date.now(),sessionId:'debug-session',hypothesisId:'J'})}).catch(()=>{});
        // #endregion
        if (contentSize) {
          // Update height for auto-grow
          if (multiline && autoGrow) {
            let newHeight = contentSize.height;
            
            // Apply min height
            newHeight = Math.max(newHeight, effectiveMinHeight);
            
            // Apply max height if set
            if (maxHeight > 0) {
              newHeight = Math.min(newHeight, maxHeight);
            }
            
            // #region agent log
            fetch('http://127.0.0.1:7244/ingest/266566fa-a225-481b-9c55-e41f1945d4eb',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'index.tsx:handleContentSizeChange',message:'setting new height',data:{newHeight,contentSizeHeight:contentSize.height},timestamp:Date.now(),sessionId:'debug-session',hypothesisId:'J'})}).catch(()=>{});
            // #endregion
            
            setHeight(newHeight);
          }
          
          // Call user's callback
          onContentSizeChange?.(contentSize);
        }
      },
      [multiline, autoGrow, effectiveMinHeight, maxHeight, onContentSizeChange, height]
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

    // Build style with auto-grow height
    // When auto-grow is enabled, we need to set an explicit height
    const finalStyle = StyleSheet.flatten([styles.default, style]);
    
    // Override with auto-grow height if enabled
    if (multiline && autoGrow) {
      (finalStyle as any).height = height;
    }
    
    // #region agent log
    fetch('http://127.0.0.1:7244/ingest/266566fa-a225-481b-9c55-e41f1945d4eb',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({location:'index.tsx:render',message:'building style',data:{height,multiline,autoGrow,styleHeight:(finalStyle as any).height},timestamp:Date.now(),sessionId:'debug-session',hypothesisId:'K'})}).catch(()=>{});
    // #endregion
    
    const combinedStyle = finalStyle;

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
        minHeight={effectiveMinHeight}
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
    minHeight: DEFAULT_MIN_HEIGHT,
    width: '100%',
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
