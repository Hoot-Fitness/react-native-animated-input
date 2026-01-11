import type {
  ViewStyle,
  ColorValue,
  NativeSyntheticEvent,
} from 'react-native';

/**
 * Font size rule for dynamic sizing.
 * Use `as const` when defining rules to get type-safe font size constraints.
 * 
 * @example
 * ```tsx
 * const rules = [
 *   { maxLength: 20, fontSize: 32 },
 *   { maxLength: 50, fontSize: 24 },
 * ] as const;
 * 
 * // baseFontSize will only accept 32 | 24
 * <AnimatedInput fontSizeRules={rules} baseFontSize={32} />
 * ```
 */
export interface FontSizeRule<TFontSize extends number = number> {
  /** Maximum character length for this font size to apply */
  maxLength: number;
  /** Font size in points to use when text length is within maxLength */
  fontSize: TFontSize;
}

/**
 * Content size dimensions
 */
export interface ContentSize {
  width: number;
  height: number;
}

/**
 * Native event payload for text events
 */
export interface NativeTextEventData {
  text?: string;
}

/**
 * Native event payload for content size changes
 */
export interface NativeContentSizeEventData {
  contentSize?: ContentSize;
}

/**
 * Props passed directly to the native iOS component.
 * These use different naming conventions than the JS props
 * (e.g., textAlignString instead of textAlign).
 * 
 * @internal This interface is for internal use only and may change between versions.
 */
export interface NativeAnimatedInputProps {
  // Style - accepts ViewStyle, height is managed internally as a number for auto-grow
  style?: ViewStyle;

  // Event handlers (using native event format)
  onChangeText?: (event: NativeSyntheticEvent<NativeTextEventData>) => void;
  onInputFocus?: (event: NativeSyntheticEvent<Record<string, unknown>>) => void;
  onInputBlur?: (event: NativeSyntheticEvent<Record<string, unknown>>) => void;
  onInputSubmit?: (event: NativeSyntheticEvent<NativeTextEventData>) => void;
  onContentSizeChange?: (event: NativeSyntheticEvent<NativeContentSizeEventData>) => void;

  // Content
  placeholder?: string;
  placeholderTextColor?: ColorValue;
  inputTextColor?: ColorValue;

  // Alignment (native uses string suffix)
  textAlignString?: 'left' | 'center' | 'right';

  // Typography
  fontFamily?: string;

  // Multiline & Auto-grow
  multiline?: boolean;
  autoGrow?: boolean;
  maxHeight?: number;
  minHeight?: number;

  // Keyboard & Input (native uses string/enabled suffix naming)
  keyboardTypeString?: string;
  returnKeyTypeString?: string;
  autoCapitalizeString?: string;
  autoCorrectEnabled?: boolean;
  secureTextEntryEnabled?: boolean;
  editableEnabled?: boolean;
  maxLength?: number;

  // Dynamic sizing
  dynamicSizing?: boolean;
  fontSizeRulesJson?: string;
  baseFontSize?: number;
  minFontSize?: number;

  // Dictation animation
  isDictating?: boolean;
  animationDuration?: number;
  onDictationTap?: (event: NativeSyntheticEvent<Record<string, unknown>>) => void;
}

/**
 * Keyboard types supported by the input
 */
export type KeyboardType =
  | 'default'
  | 'number-pad'
  | 'decimal-pad'
  | 'numeric'
  | 'email-address'
  | 'phone-pad'
  | 'url';

/**
 * Return key types supported by the input
 */
export type ReturnKeyType =
  | 'default'
  | 'go'
  | 'next'
  | 'search'
  | 'send'
  | 'done';

/**
 * Auto-capitalize options
 */
export type AutoCapitalize =
  | 'none'
  | 'sentences'
  | 'words'
  | 'characters';

/**
 * Props for the AnimatedInput component
 */
export interface AnimatedInputProps {
  // Content
  /** The text value of the input */
  value?: string;
  /** Callback fired when the text changes */
  onChangeText?: (text: string) => void;
  /** Placeholder text shown when input is empty */
  placeholder?: string;
  /** Color of the placeholder text */
  placeholderTextColor?: ColorValue;
  /** Color of the input text */
  textColor?: ColorValue;

  // Alignment
  /** Text alignment within the input */
  textAlign?: 'left' | 'center' | 'right';

  // Typography
  /** 
   * Custom font family name. Works with fonts loaded via React Native or Expo.
   * Pass the font name exactly as registered (e.g., 'Poppins-Bold')
   */
  fontFamily?: string;

  // Multiline & Auto-grow
  /** 
   * Whether the input supports multiple lines.
   * When false, pressing return will trigger onSubmitEditing instead of adding a newline.
   * @default true
   */
  multiline?: boolean;
  /**
   * Whether the input should auto-grow in height based on content.
   * Only applies when multiline is true.
   * @default true
   */
  autoGrow?: boolean;
  /**
   * Maximum height the input can grow to (in pixels).
   * After this height, scrolling is enabled. 0 means no limit.
   * @default 0
   */
  maxHeight?: number;
  /**
   * Minimum height for the input (in pixels).
   * @default 0
   */
  minHeight?: number;
  /**
   * Callback fired when the content size changes (for auto-grow).
   */
  onContentSizeChange?: (contentSize: { width: number; height: number }) => void;

  // Keyboard & Input
  /** Callback fired when the input gains focus */
  onFocus?: () => void;
  /** Callback fired when the input loses focus */
  onBlur?: () => void;
  /** Callback fired when the submit button is pressed (return key in single-line mode) */
  onSubmitEditing?: (text: string) => void;
  /** Type of keyboard to display @default 'default' */
  keyboardType?: KeyboardType;
  /** Appearance of the return key @default 'default' */
  returnKeyType?: ReturnKeyType;
  /** Auto-capitalization behavior @default 'sentences' */
  autoCapitalize?: AutoCapitalize;
  /** Whether auto-correct is enabled @default true */
  autoCorrect?: boolean;
  /** Whether to hide the text (password entry) @default false */
  secureTextEntry?: boolean;
  /** Whether the input is editable @default true */
  editable?: boolean;
  /** Maximum number of characters allowed (0 = no limit) @default 0 */
  maxLength?: number;

  // Dynamic sizing
  /** Enable dynamic font sizing based on text length */
  dynamicSizing?: boolean;
  /** 
   * Custom font size rules for dynamic sizing.
   * Each rule specifies a maxLength and fontSize.
   * Rules should be ordered by maxLength ascending.
   * @default [
   *   { maxLength: 20, fontSize: 32 },
   *   { maxLength: 50, fontSize: 24 },
   *   { maxLength: 100, fontSize: 18 },
   *   { maxLength: Infinity, fontSize: 14 }
   * ]
   */
  fontSizeRules?: FontSizeRule[];
  /** Base font size used when dynamic sizing is disabled @default 32 */
  baseFontSize?: number;
  /** Minimum font size for dynamic sizing @default 14 */
  minFontSize?: number;

  // Dictation animation
  /** 
   * Enable word-by-word animations for dictation.
   * When true, new words will animate in with opacity and scale effects.
   */
  isDictating?: boolean;
  /** Animation duration in milliseconds @default 250 */
  animationDuration?: number;
  /**
   * Callback fired when the user taps the input while dictation mode is active.
   * Use this to stop dictation when the user taps the input.
   */
  onDictationTap?: () => void;

  // Styling
  /** Style for the container view */
  style?: ViewStyle;
}

/**
 * Native event payload for text changes
 */
export interface TextChangeEvent {
  nativeEvent: {
    text: string;
  };
}

/**
 * Ref methods available on AnimatedInput
 */
export interface AnimatedInputRef {
  /** Focus the input */
  focus: () => void;
  /** Blur the input */
  blur: () => void;
}
