package com.reactnativeanimatedinput

import com.facebook.react.bridge.ReadableArray
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp

class RNAnimatedInputViewManager : SimpleViewManager<RNAnimatedInputView>() {

    companion object {
        const val REACT_CLASS = "RNAnimatedInputView"
        const val COMMAND_SET_VALUE = 0
        const val COMMAND_FOCUS = 1
        const val COMMAND_BLUR = 2
    }

    override fun getName(): String = REACT_CLASS

    override fun createViewInstance(reactContext: ThemedReactContext): RNAnimatedInputView {
        return RNAnimatedInputView(reactContext)
    }

    // -- Content props --

    @ReactProp(name = "placeholder")
    fun setPlaceholder(view: RNAnimatedInputView, placeholder: String?) {
        view.setPlaceholderText(placeholder)
    }

    @ReactProp(name = "placeholderTextColor", customType = "Color")
    fun setPlaceholderTextColor(view: RNAnimatedInputView, color: Int?) {
        view.setPlaceholderColor(color)
    }

    @ReactProp(name = "inputTextColor", customType = "Color")
    fun setInputTextColor(view: RNAnimatedInputView, color: Int?) {
        view.setInputColor(color)
    }

    @ReactProp(name = "selectionColor", customType = "Color")
    fun setSelectionColor(view: RNAnimatedInputView, color: Int?) {
        view.setSelectionHighlightColor(color)
    }

    @ReactProp(name = "textAlignString")
    fun setTextAlignString(view: RNAnimatedInputView, align: String?) {
        view.setTextAlignProp(align ?: "left")
    }

    @ReactProp(name = "fontFamily")
    fun setFontFamily(view: RNAnimatedInputView, fontFamily: String?) {
        view.setFontFamilyProp(fontFamily)
    }

    // -- Multiline & Auto-grow --

    @ReactProp(name = "multiline", defaultBoolean = true)
    fun setMultiline(view: RNAnimatedInputView, multiline: Boolean) {
        view.setMultilineProp(multiline)
    }

    @ReactProp(name = "autoGrow", defaultBoolean = true)
    fun setAutoGrow(view: RNAnimatedInputView, autoGrow: Boolean) {
        view.setAutoGrowProp(autoGrow)
    }

    @ReactProp(name = "maxHeight", defaultFloat = 0f)
    fun setMaxHeight(view: RNAnimatedInputView, maxHeight: Float) {
        view.setMaxHeightProp(maxHeight)
    }

    @ReactProp(name = "minHeight", defaultFloat = 0f)
    fun setMinHeight(view: RNAnimatedInputView, minHeight: Float) {
        view.setMinHeightProp(minHeight)
    }

    // -- Keyboard & Input --

    @ReactProp(name = "keyboardTypeString")
    fun setKeyboardTypeString(view: RNAnimatedInputView, keyboardType: String?) {
        view.setKeyboardTypeProp(keyboardType ?: "default")
    }

    @ReactProp(name = "returnKeyTypeString")
    fun setReturnKeyTypeString(view: RNAnimatedInputView, returnKeyType: String?) {
        view.setReturnKeyTypeProp(returnKeyType ?: "default")
    }

    @ReactProp(name = "autoCapitalizeString")
    fun setAutoCapitalizeString(view: RNAnimatedInputView, autoCapitalize: String?) {
        view.setAutoCapitalizeProp(autoCapitalize ?: "sentences")
    }

    @ReactProp(name = "autoCorrectEnabled", defaultBoolean = true)
    fun setAutoCorrectEnabled(view: RNAnimatedInputView, autoCorrect: Boolean) {
        view.setAutoCorrectProp(autoCorrect)
    }

    @ReactProp(name = "secureTextEntryEnabled", defaultBoolean = false)
    fun setSecureTextEntryEnabled(view: RNAnimatedInputView, secure: Boolean) {
        view.setSecureTextEntryProp(secure)
    }

    @ReactProp(name = "editableEnabled", defaultBoolean = true)
    fun setEditableEnabled(view: RNAnimatedInputView, editable: Boolean) {
        view.setEditableProp(editable)
    }

    @ReactProp(name = "maxLength", defaultInt = 0)
    fun setMaxLength(view: RNAnimatedInputView, maxLength: Int) {
        view.setMaxLengthProp(maxLength)
    }

    // -- Dynamic sizing --

    @ReactProp(name = "dynamicSizing", defaultBoolean = false)
    fun setDynamicSizing(view: RNAnimatedInputView, dynamicSizing: Boolean) {
        view.setDynamicSizingProp(dynamicSizing)
    }

    @ReactProp(name = "fontSizeRulesJson")
    fun setFontSizeRulesJson(view: RNAnimatedInputView, json: String?) {
        view.setFontSizeRulesJsonProp(json)
    }

    @ReactProp(name = "baseFontSize", defaultFloat = 32f)
    fun setBaseFontSize(view: RNAnimatedInputView, size: Float) {
        view.setBaseFontSizeProp(size)
    }

    @ReactProp(name = "minFontSize", defaultFloat = 14f)
    fun setMinFontSize(view: RNAnimatedInputView, size: Float) {
        view.setMinFontSizeProp(size)
    }

    // -- Dictation animation --

    @ReactProp(name = "isDictating", defaultBoolean = false)
    fun setIsDictating(view: RNAnimatedInputView, isDictating: Boolean) {
        view.setIsDictatingProp(isDictating)
    }

    @ReactProp(name = "animationDuration", defaultDouble = 250.0)
    fun setAnimationDuration(view: RNAnimatedInputView, duration: Double) {
        view.setAnimationDurationProp(duration)
    }

    // -- Commands --

    override fun getCommandsMap(): Map<String, Int> {
        return MapBuilder.of(
            "setValue", COMMAND_SET_VALUE,
            "focus", COMMAND_FOCUS,
            "blur", COMMAND_BLUR
        )
    }

    override fun receiveCommand(view: RNAnimatedInputView, commandId: Int, args: ReadableArray?) {
        when (commandId) {
            COMMAND_SET_VALUE -> {
                val value = args?.getString(0)
                view.setValueFromJS(value)
            }
            COMMAND_FOCUS -> view.focusInput()
            COMMAND_BLUR -> view.blurInput()
        }
    }

    @Suppress("DEPRECATION")
    override fun receiveCommand(view: RNAnimatedInputView, commandId: String?, args: ReadableArray?) {
        when (commandId) {
            "setValue" -> {
                val value = args?.getString(0)
                view.setValueFromJS(value)
            }
            "focus" -> view.focusInput()
            "blur" -> view.blurInput()
        }
    }

    // -- Events --

    override fun getExportedCustomDirectEventTypeConstants(): Map<String, Any> {
        return MapBuilder.builder<String, Any>()
            .put("onChangeText", MapBuilder.of("registrationName", "onChangeText"))
            .put("onInputFocus", MapBuilder.of("registrationName", "onInputFocus"))
            .put("onInputBlur", MapBuilder.of("registrationName", "onInputBlur"))
            .put("onInputSubmit", MapBuilder.of("registrationName", "onInputSubmit"))
            .put("onContentSizeChange", MapBuilder.of("registrationName", "onContentSizeChange"))
            .put("onDictationTap", MapBuilder.of("registrationName", "onDictationTap"))
            .build()
    }

    override fun onDropViewInstance(view: RNAnimatedInputView) {
        super.onDropViewInstance(view)
        view.cleanup()
    }
}
