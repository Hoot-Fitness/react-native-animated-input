# react-native-animated-input

A React Native text input component with **dynamic font sizing** and
**word-by-word dictation animations**, powered by native iOS/Swift for optimal
performance.

## Features

- **Dynamic Font Sizing** - Automatically adjusts font size based on text length
- **Dictation Animations** - Words animate in with opacity and scale effects
  during voice input
- **Custom Fonts** - Full support for React Native and Expo loaded fonts
- **Text Alignment** - Left, center, or right alignment
- **Multiline Support** - Single or multi-line input modes
- **Full Keyboard Control** - All standard TextInput keyboard props supported
- **Native Performance** - Built with Swift for smooth 60fps animations

## Installation

```bash
npm install react-native-animated-input
# or
yarn add react-native-animated-input
```

### iOS Setup

1. Install CocoaPods dependencies:

```bash
cd ios && pod install && cd ..
```

2. If this is your first Swift file in the project, Xcode may prompt you to
   create a bridging header. Accept this prompt.

3. If you encounter bridging header issues, ensure your Xcode project has the
   following build setting:
   - **Swift Language Version**: 5.0 or later

## Usage

### Basic Usage

```tsx
import React, { useState } from "react";
import { View } from "react-native";

import { AnimatedInput } from "react-native-animated-input";

function MyComponent() {
  const [text, setText] = useState("");

  return (
    <View style={{ flex: 1, padding: 20 }}>
      <AnimatedInput
        value={text}
        onChangeText={setText}
        placeholder="Start typing..."
        textAlign="center"
      />
    </View>
  );
}
```

### With Dynamic Sizing

Dynamic sizing automatically adjusts the font size based on how many characters
are in the input:

```tsx
import React, { useState } from "react";
import { View } from "react-native";

import { AnimatedInput } from "react-native-animated-input";

function DynamicSizingExample() {
  const [text, setText] = useState("");

  return (
    <AnimatedInput
      value={text}
      onChangeText={setText}
      dynamicSizing
      baseFontSize={36}
      minFontSize={12}
    />
  );
}
```

### Custom Font Size Rules

You can define your own breakpoints for dynamic font sizing:

```tsx
import React, { useState } from "react";
import { View } from "react-native";

import { AnimatedInput } from "react-native-animated-input";

function CustomRulesExample() {
  const [text, setText] = useState("");

  const customRules = [
    { maxLength: 10, fontSize: 48 }, // Large font for short text
    { maxLength: 30, fontSize: 32 }, // Medium font
    { maxLength: 60, fontSize: 24 }, // Smaller font
    { maxLength: Infinity, fontSize: 16 }, // Minimum for long text
  ];

  return (
    <AnimatedInput
      value={text}
      onChangeText={setText}
      dynamicSizing
      fontSizeRules={customRules}
    />
  );
}
```

### Dictation Animation

Enable word-by-word animations during voice dictation:

```tsx
import React, { useState } from "react";
import { Button, View } from "react-native";

import { AnimatedInput } from "react-native-animated-input";

function DictationExample() {
  const [text, setText] = useState("");
  const [isDictating, setIsDictating] = useState(false);

  const stopDictation = () => {
    setIsDictating(false);
    // Add your dictation stop logic here
  };

  return (
    <View>
      <AnimatedInput
        value={text}
        onChangeText={setText}
        isDictating={isDictating}
        animationDuration={300}
        textAlign="center"
        dynamicSizing
        onDictationTap={stopDictation} // Stop dictation when user taps input
      />

      <Button
        title={isDictating ? "Stop Dictation" : "Start Dictation"}
        onPress={() => setIsDictating(!isDictating)}
      />
    </View>
  );
}
```

When `isDictating` is `true`, each new word that appears will:

1. Fade in from 0 to 100% opacity
2. Scale up from 70% to 100% size with a spring animation
3. The underlying text is temporarily hidden during animation for a clean effect

### Custom Fonts

Works seamlessly with fonts loaded via React Native or Expo:

```tsx
import React, { useState } from "react";
import { View } from "react-native";
import { useFonts } from "expo-font";

import { AnimatedInput } from "react-native-animated-input";

function CustomFontExample() {
  const [text, setText] = useState("");

  const [fontsLoaded] = useFonts({
    "Poppins-Bold": require("./assets/fonts/Poppins-Bold.ttf"),
  });

  if (!fontsLoaded) {
    return null;
  }

  return (
    <AnimatedInput
      value={text}
      onChangeText={setText}
      fontFamily="Poppins-Bold"
      baseFontSize={28}
    />
  );
}
```

### Auto-Growing Input

By default, multiline inputs auto-grow as you type. You can control the behavior
with `autoGrow`, `minHeight`, and `maxHeight`:

```tsx
import React, { useState } from "react";
import { View } from "react-native";

import { AnimatedInput } from "react-native-animated-input";

function AutoGrowExample() {
  const [text, setText] = useState("");

  return (
    <AnimatedInput
      value={text}
      onChangeText={setText}
      placeholder="Type something..."
      multiline
      autoGrow
      minHeight={50}
      maxHeight={200}
      onContentSizeChange={(size) => {
        console.log("New height:", size.height);
      }}
    />
  );
}
```

When the content exceeds `maxHeight`, scrolling is automatically enabled.

### Single-Line Mode

Use `multiline={false}` for single-line input behavior:

```tsx
import React, { useState } from "react";
import { View } from "react-native";

import { AnimatedInput } from "react-native-animated-input";

function SingleLineExample() {
  const [text, setText] = useState("");

  return (
    <AnimatedInput
      value={text}
      onChangeText={setText}
      multiline={false}
      returnKeyType="done"
      onSubmitEditing={(text) => console.log("Submitted:", text)}
    />
  );
}
```

### Using Ref Methods

You can programmatically focus and blur the input:

```tsx
import React, { useRef, useState } from "react";
import { Button, View } from "react-native";

import { AnimatedInput, AnimatedInputRef } from "react-native-animated-input";

function RefExample() {
  const [text, setText] = useState("");
  const inputRef = useRef<AnimatedInputRef>(null);

  return (
    <View>
      <AnimatedInput
        ref={inputRef}
        value={text}
        onChangeText={setText}
      />

      <Button
        title="Focus Input"
        onPress={() => inputRef.current?.focus()}
      />
      <Button
        title="Blur Input"
        onPress={() => inputRef.current?.blur()}
      />
    </View>
  );
}
```

## Props

### Content Props

| Prop                   | Type                     | Default        | Description                                |
| ---------------------- | ------------------------ | -------------- | ------------------------------------------ |
| `value`                | `string`                 | `''`           | The text value of the input                |
| `onChangeText`         | `(text: string) => void` | -              | Callback fired when text changes           |
| `placeholder`          | `string`                 | -              | Placeholder text shown when input is empty |
| `placeholderTextColor` | `ColorValue`             | System default | Color of the placeholder text              |

### Typography Props

| Prop         | Type                            | Default     | Description                                              |
| ------------ | ------------------------------- | ----------- | -------------------------------------------------------- |
| `textAlign`  | `'left' \| 'center' \| 'right'` | `'left'`    | Text alignment within the input                          |
| `fontFamily` | `string`                        | System font | Custom font family name (React Native/Expo loaded fonts) |

### Input Behavior Props

| Prop              | Type                                               | Default       | Description                                        |
| ----------------- | -------------------------------------------------- | ------------- | -------------------------------------------------- |
| `multiline`       | `boolean`                                          | `true`        | Whether the input supports multiple lines          |
| `autoGrow`        | `boolean`                                          | `true`        | Auto-grow height based on content (when multiline) |
| `maxHeight`       | `number`                                           | `0`           | Maximum height for auto-grow (0 = no limit)        |
| `minHeight`       | `number`                                           | `0`           | Minimum height for auto-grow                       |
| `editable`        | `boolean`                                          | `true`        | Whether the input is editable                      |
| `maxLength`       | `number`                                           | `0`           | Maximum characters allowed (0 = no limit)          |
| `secureTextEntry` | `boolean`                                          | `false`       | Hide text for password entry                       |
| `autoCorrect`     | `boolean`                                          | `true`        | Enable auto-correct                                |
| `autoCapitalize`  | `'none' \| 'sentences' \| 'words' \| 'characters'` | `'sentences'` | Auto-capitalization behavior                       |

### Keyboard Props

| Prop            | Type            | Default     | Description                  |
| --------------- | --------------- | ----------- | ---------------------------- |
| `keyboardType`  | `KeyboardType`  | `'default'` | Type of keyboard to display  |
| `returnKeyType` | `ReturnKeyType` | `'default'` | Appearance of the return key |

**KeyboardType options:** `'default'`, `'number-pad'`, `'decimal-pad'`,
`'numeric'`, `'email-address'`, `'phone-pad'`, `'url'`

**ReturnKeyType options:** `'default'`, `'go'`, `'next'`, `'search'`, `'send'`,
`'done'`

### Event Props

| Prop                  | Type                                                | Default | Description                                         |
| --------------------- | --------------------------------------------------- | ------- | --------------------------------------------------- |
| `onFocus`             | `() => void`                                        | -       | Callback when input gains focus                     |
| `onBlur`              | `() => void`                                        | -       | Callback when input loses focus                     |
| `onSubmitEditing`     | `(text: string) => void`                            | -       | Callback when return key pressed (single-line mode) |
| `onContentSizeChange` | `(size: { width: number; height: number }) => void` | -       | Callback when content size changes (for auto-grow)  |

### Dynamic Sizing Props

| Prop            | Type                           | Default   | Description                          |
| --------------- | ------------------------------ | --------- | ------------------------------------ |
| `dynamicSizing` | `boolean`                      | `false`   | Enable dynamic font sizing           |
| `fontSizeRules` | `Array<{maxLength, fontSize}>` | See below | Custom sizing rules                  |
| `baseFontSize`  | `number`                       | `32`      | Base/starting font size in points    |
| `minFontSize`   | `number`                       | `14`      | Minimum font size for dynamic sizing |

### Dictation Animation Props

| Prop                | Type         | Default | Description                                              |
| ------------------- | ------------ | ------- | -------------------------------------------------------- |
| `isDictating`       | `boolean`    | `false` | Enable word-by-word animations                           |
| `animationDuration` | `number`     | `250`   | Animation duration in milliseconds                       |
| `onDictationTap`    | `() => void` | -       | Callback when user taps the input while dictation active |

### Styling Props

| Prop    | Type        | Default | Description                  |
| ------- | ----------- | ------- | ---------------------------- |
| `style` | `ViewStyle` | -       | Style for the container view |

### Default Font Size Rules

When `dynamicSizing` is enabled without custom rules, these defaults are used:

| Characters | Font Size |
| ---------- | --------- |
| 0-20       | 32pt      |
| 21-50      | 24pt      |
| 51-100     | 18pt      |
| 100+       | 14pt      |

## Ref Methods

| Method    | Description                      |
| --------- | -------------------------------- |
| `focus()` | Programmatically focus the input |
| `blur()`  | Programmatically blur the input  |

## TypeScript

Full TypeScript support is included:

```tsx
import {
  AnimatedInput,
  AnimatedInputProps,
  AnimatedInputRef,
  AutoCapitalize,
  FontSizeRule,
  KeyboardType,
  ReturnKeyType,
} from "react-native-animated-input";

// Use the types
const rules: FontSizeRule[] = [
  { maxLength: 20, fontSize: 32 },
  { maxLength: Infinity, fontSize: 18 },
];

const props: AnimatedInputProps = {
  value: "",
  onChangeText: (text) => console.log(text),
  dynamicSizing: true,
  fontSizeRules: rules,
};
```

## Platform Support

| Platform | Supported        |
| -------- | ---------------- |
| iOS      | ✅               |
| Android  | ❌ (coming soon) |

## How It Works

### Dynamic Font Sizing

The component tracks the character count of the input text. When the count
crosses a threshold defined in `fontSizeRules`, the font size smoothly animates
to the new size using `UIView.animate`.

### Dictation Animation

When `isDictating` is `true`, the component compares the current text to the
previous text on each change. New words are detected and animated using
`CATextLayer` with:

- **Opacity**: `CABasicAnimation` from 0 to 1 with ease-out timing
- **Scale**: `CASpringAnimation` from 0.7 to 1.0 with spring physics

The underlying text is temporarily hidden (via attributed string with clear
color) during animation, then restored when the animation completes. This
ensures the animation is visible without text appearing to "double".

## License

MIT
