import type React from "react";
import {
	forwardRef,
	useCallback,
	useEffect,
	useImperativeHandle,
	useRef,
	useState,
} from "react";
import type {
	HostComponent,
	NativeSyntheticEvent,
	ViewStyle,
} from "react-native";
import {
	findNodeHandle,
	Platform,
	processColor,
	requireNativeComponent,
	StyleSheet,
	UIManager,
} from "react-native";

import type {
	AnimatedInputProps,
	AnimatedInputRef,
	NativeAnimatedInputProps,
	NativeContentSizeEventData,
	NativeTextEventData,
} from "./types";

// Component name in native code
const COMPONENT_NAME = "RNAnimatedInputView";

// Check if the native component is available
const isNativeComponentAvailable =
	Platform.OS === "ios" &&
	UIManager.getViewManagerConfig(COMPONENT_NAME) != null;

// Lazy initialization to prevent duplicate registration during HMR
let NativeAnimatedInput: HostComponent<NativeAnimatedInputProps> | null = null;

function getNativeComponent(): HostComponent<NativeAnimatedInputProps> | null {
	if (NativeAnimatedInput === null && isNativeComponentAvailable) {
		NativeAnimatedInput =
			requireNativeComponent<NativeAnimatedInputProps>(COMPONENT_NAME);
	}
	return NativeAnimatedInput;
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
			value = "",
			onChangeText,
			placeholder,
			placeholderTextColor,
			textAlign = "left",
			fontFamily,
			multiline = true,
			autoGrow = true,
			maxHeight = 0,
			minHeight = 0,
			onContentSizeChange,
			onFocus,
			onBlur,
			onSubmitEditing,
			keyboardType = "default",
			returnKeyType = "default",
			autoCapitalize = "sentences",
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
			onDictationTap,
			style,
		},
		ref,
	) => {
		const nativeRef = useRef<React.ElementRef<
			HostComponent<NativeAnimatedInputProps>
		> | null>(null);

		// Track height for auto-grow
		const effectiveMinHeight = minHeight > 0 ? minHeight : DEFAULT_MIN_HEIGHT;
		const [height, setHeight] = useState<number>(effectiveMinHeight);

		// Expose focus/blur methods via ref
		useImperativeHandle(ref, () => ({
			focus: () => {
				if (nativeRef.current && Platform.OS === "ios") {
					const nodeHandle = findNodeHandle(nativeRef.current);
					if (nodeHandle != null) {
						UIManager.dispatchViewManagerCommand(
							nodeHandle,
							UIManager.getViewManagerConfig(COMPONENT_NAME).Commands?.focus ??
								1,
							[],
						);
					}
				}
			},
			blur: () => {
				if (nativeRef.current && Platform.OS === "ios") {
					const nodeHandle = findNodeHandle(nativeRef.current);
					if (nodeHandle != null) {
						UIManager.dispatchViewManagerCommand(
							nodeHandle,
							UIManager.getViewManagerConfig(COMPONENT_NAME).Commands?.blur ??
								2,
							[],
						);
					}
				}
			},
		}));

		// Handle text change from native
		const handleChangeText = useCallback(
			(event: NativeSyntheticEvent<NativeTextEventData>) => {
				const text = event.nativeEvent?.text ?? "";
				onChangeText?.(text);
			},
			[onChangeText],
		);

		// Handle focus
		const handleFocus = useCallback(
			(_event: NativeSyntheticEvent<Record<string, unknown>>) => {
				onFocus?.();
			},
			[onFocus],
		);

		// Handle blur
		const handleBlur = useCallback(
			(_event: NativeSyntheticEvent<Record<string, unknown>>) => {
				onBlur?.();
			},
			[onBlur],
		);

		// Handle submit
		const handleSubmitEditing = useCallback(
			(event: NativeSyntheticEvent<NativeTextEventData>) => {
				const text = event.nativeEvent?.text ?? "";
				onSubmitEditing?.(text);
			},
			[onSubmitEditing],
		);

		// Handle dictation tap
		const handleDictationTap = useCallback(
			(_event: NativeSyntheticEvent<Record<string, unknown>>) => {
				onDictationTap?.();
			},
			[onDictationTap],
		);

		// Handle content size change (for auto-grow)
		const handleContentSizeChange = useCallback(
			(event: NativeSyntheticEvent<NativeContentSizeEventData>) => {
				const contentSize = event.nativeEvent?.contentSize;
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

						setHeight(newHeight);
					}

					// Call user's callback
					onContentSizeChange?.(contentSize);
				}
			},
			[multiline, autoGrow, effectiveMinHeight, maxHeight, onContentSizeChange],
		);

		// Update native value when prop changes
		useEffect(() => {
			if (nativeRef.current && Platform.OS === "ios") {
				const nodeHandle = findNodeHandle(nativeRef.current);
				if (nodeHandle != null) {
					UIManager.dispatchViewManagerCommand(
						nodeHandle,
						UIManager.getViewManagerConfig(COMPONENT_NAME).Commands?.setValue ??
							0,
						[value],
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
					})),
				)
			: undefined;

		// Process placeholder color
		const processedPlaceholderColor = placeholderTextColor
			? processColor(placeholderTextColor)
			: undefined;

		// Build style with auto-grow height
		// When auto-grow is enabled, we need to set an explicit height
		const baseStyle = StyleSheet.flatten([styles.default, style]);

		// Create combined style with optional auto-grow height override
		const combinedStyle: ViewStyle & { height?: number } =
			multiline && autoGrow ? { ...baseStyle, height } : baseStyle;

		// Get the native component (lazy initialization prevents HMR duplicate registration)
		const NativeComponent = getNativeComponent();

		// Handle unsupported platform
		if (!NativeComponent) {
			console.warn(
				"react-native-animated-input: Native component not available. " +
					"This library currently only supports iOS.",
			);
			return null;
		}

		return (
			<NativeComponent
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
				onDictationTap={handleDictationTap}
			/>
		);
	},
);

AnimatedInput.displayName = "AnimatedInput";

const styles = StyleSheet.create({
	default: {
		minHeight: DEFAULT_MIN_HEIGHT,
		width: "100%",
	},
});

// Re-export types
export type {
	AnimatedInputProps,
	AnimatedInputRef,
	AutoCapitalize,
	ContentSize,
	FontSizeRule,
	KeyboardType,
	ReturnKeyType,
} from "./types";

// Default export
export default AnimatedInput;
