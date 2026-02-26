package com.reactnativeanimatedinput

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.TextWatcher
import android.text.style.ForegroundColorSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.TextView

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerModule
import com.facebook.react.uimanager.events.RCTEventEmitter

import org.json.JSONArray

class RNAnimatedInputView(context: Context) : FrameLayout(context) {

    private val editText: InnerEditText
    private val reactContext: ReactContext = context as ReactContext

    // -- Internal state --
    private var isInternalUpdate = false
    private var previousText = ""
    private var previousWordCount = 0
    private var currentFontSize = 32f
    private var originalTextColor = Color.BLACK
    private var lastContentHeight = 0f

    // Dynamic sizing
    private var dynamicSizing = false
    private var fontSizeRules: List<Pair<Int, Float>> = listOf(
        Pair(20, 32f), Pair(50, 24f), Pair(100, 18f), Pair(Int.MAX_VALUE, 14f)
    )
    private var baseFontSize = 32f
    private var minFontSize = 14f

    // Multiline & auto-grow
    private var multiline = true
    private var autoGrow = true
    private var propMaxHeight = 0f
    private var propMinHeight = 0f

    // Dictation
    private var isDictating = false
    private var animationDuration = 250.0
    private var dictationInsertPosition = 0
    private var textBeforeDictation = ""
    private val animatingViews = mutableListOf<View>()
    private val hiddenSpans = mutableListOf<HiddenSpanInfo>()

    // Font
    private var fontFamily: String? = null

    // Max length (0 = no limit)
    private var maxLength = 0

    private data class HiddenSpanInfo(val span: ForegroundColorSpan, val start: Int, val end: Int)

    init {
        editText = InnerEditText(context)
        editText.layoutParams = LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.WRAP_CONTENT
        )

        editText.background = null
        editText.setPadding(dpToPx(8f), dpToPx(8f), dpToPx(8f), dpToPx(8f))
        editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, baseFontSize)
        editText.gravity = Gravity.START or Gravity.TOP
        editText.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        editText.isSingleLine = false
        editText.setHorizontallyScrolling(false)

        originalTextColor = editText.currentTextColor

        addView(editText)

        editText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                if (isInternalUpdate) return
                val newText = s?.toString() ?: ""

                updatePlaceholderVisibility()

                if (dynamicSizing) {
                    updateFontSizeForTextLength()
                }

                handleTextChangeForAnimation(newText)
                notifyContentSizeIfNeeded()

                sendEvent("onChangeText", Arguments.createMap().apply {
                    putString("text", newText)
                })
            }
        })

        editText.onFocusChangeListener = OnFocusChangeListener { _, hasFocus ->
            if (hasFocus) {
                sendEvent("onInputFocus", Arguments.createMap())
            } else {
                sendEvent("onInputBlur", Arguments.createMap())
            }
        }

        editText.setOnEditorActionListener { _, actionId, event ->
            if (!multiline && (actionId == EditorInfo.IME_ACTION_DONE ||
                    actionId == EditorInfo.IME_ACTION_GO ||
                    actionId == EditorInfo.IME_ACTION_NEXT ||
                    actionId == EditorInfo.IME_ACTION_SEARCH ||
                    actionId == EditorInfo.IME_ACTION_SEND ||
                    (event != null && event.keyCode == KeyEvent.KEYCODE_ENTER))) {
                sendEvent("onInputSubmit", Arguments.createMap().apply {
                    putString("text", editText.text?.toString() ?: "")
                })
                true
            } else {
                false
            }
        }

        editText.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP && isDictating) {
                val offset = editText.getOffsetForPosition(event.x, event.y)
                dictationInsertPosition = offset
                textBeforeDictation = editText.text?.toString() ?: ""
                sendEvent("onDictationTap", Arguments.createMap())
            }
            false
        }

        currentFontSize = baseFontSize
    }

    // -- Prop setters called from ViewManager --

    fun setPlaceholderText(text: String?) {
        editText.hint = text
    }

    fun setPlaceholderColor(color: Int?) {
        if (color != null) {
            editText.setHintTextColor(color)
        }
    }

    fun setInputColor(color: Int?) {
        if (color != null) {
            originalTextColor = color
            editText.setTextColor(color)
            refreshExistingTextColor()
        }
    }

    fun setSelectionHighlightColor(color: Int?) {
        if (color != null) {
            editText.highlightColor = color
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    val drawable = editText.textCursorDrawable
                    drawable?.setTint(color)
                    editText.textCursorDrawable = drawable
                } catch (_: Exception) {}
            }
            try {
                val selectHandleField = TextView::class.java.getDeclaredField("mTextSelectHandleRes")
                selectHandleField.isAccessible = true
            } catch (_: Exception) {}
        }
    }

    fun setTextAlignProp(align: String) {
        val gravity = when (align) {
            "center" -> Gravity.CENTER_HORIZONTAL or Gravity.TOP
            "right" -> Gravity.END or Gravity.TOP
            else -> Gravity.START or Gravity.TOP
        }
        editText.gravity = gravity
    }

    fun setFontFamilyProp(family: String?) {
        fontFamily = family
        updateFont()
    }

    fun setMultilineProp(value: Boolean) {
        multiline = value
        configureInputType()
    }

    fun setAutoGrowProp(value: Boolean) {
        autoGrow = value
        configureInputType()
    }

    fun setMaxHeightProp(value: Float) {
        propMaxHeight = value
    }

    fun setMinHeightProp(value: Float) {
        propMinHeight = value
    }

    fun setKeyboardTypeProp(keyboardType: String) {
        val baseType = when (keyboardType) {
            "number-pad" -> InputType.TYPE_CLASS_NUMBER
            "decimal-pad" -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
            "numeric" -> InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL or InputType.TYPE_NUMBER_FLAG_SIGNED
            "email-address" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            "phone-pad" -> InputType.TYPE_CLASS_PHONE
            "url" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            else -> InputType.TYPE_CLASS_TEXT
        }
        applyInputType(baseType)
    }

    fun setReturnKeyTypeProp(returnKeyType: String) {
        editText.imeOptions = when (returnKeyType) {
            "go" -> EditorInfo.IME_ACTION_GO
            "next" -> EditorInfo.IME_ACTION_NEXT
            "search" -> EditorInfo.IME_ACTION_SEARCH
            "send" -> EditorInfo.IME_ACTION_SEND
            "done" -> EditorInfo.IME_ACTION_DONE
            else -> EditorInfo.IME_ACTION_UNSPECIFIED
        }
    }

    fun setAutoCapitalizeProp(autoCapitalize: String) {
        val capFlag = when (autoCapitalize) {
            "none" -> 0
            "words" -> InputType.TYPE_TEXT_FLAG_CAP_WORDS
            "characters" -> InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            else -> InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        }
        val current = editText.inputType
        val cleared = current and (InputType.TYPE_TEXT_FLAG_CAP_SENTENCES or
                InputType.TYPE_TEXT_FLAG_CAP_WORDS or
                InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS).inv()
        editText.inputType = cleared or capFlag
    }

    fun setAutoCorrectProp(autoCorrect: Boolean) {
        val current = editText.inputType
        editText.inputType = if (autoCorrect) {
            current or InputType.TYPE_TEXT_FLAG_AUTO_CORRECT
        } else {
            (current and InputType.TYPE_TEXT_FLAG_AUTO_CORRECT.inv()) or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
        }
    }

    fun setSecureTextEntryProp(secure: Boolean) {
        val current = editText.inputType
        editText.inputType = if (secure) {
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        } else {
            current and InputType.TYPE_TEXT_VARIATION_PASSWORD.inv()
        }
    }

    fun setEditableProp(editable: Boolean) {
        editText.isFocusable = editable
        editText.isFocusableInTouchMode = editable
        editText.isEnabled = editable
    }

    fun setMaxLengthProp(length: Int) {
        maxLength = length
        if (length > 0) {
            editText.filters = arrayOf(InputFilter.LengthFilter(length))
        } else {
            editText.filters = arrayOf()
        }
    }

    fun setDynamicSizingProp(value: Boolean) {
        dynamicSizing = value
        if (dynamicSizing) {
            updateFontSizeForTextLength()
        }
    }

    fun setFontSizeRulesJsonProp(json: String?) {
        if (json == null) return
        try {
            val arr = JSONArray(json)
            val rules = mutableListOf<Pair<Int, Float>>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val maxLen = obj.getInt("maxLength")
                val fontSize = obj.getDouble("fontSize").toFloat()
                rules.add(Pair(maxLen, fontSize))
            }
            rules.sortBy { it.first }
            fontSizeRules = rules

            if (dynamicSizing) {
                updateFontSizeForTextLength()
            }
        } catch (_: Exception) {}
    }

    fun setBaseFontSizeProp(size: Float) {
        baseFontSize = size
        currentFontSize = size
        updateFont()
    }

    fun setMinFontSizeProp(size: Float) {
        minFontSize = size
    }

    fun setIsDictatingProp(value: Boolean) {
        val wasDictating = isDictating
        isDictating = value
        if (isDictating && !wasDictating) {
            dictationInsertPosition = editText.selectionStart
            textBeforeDictation = editText.text?.toString() ?: ""
        }
        resetDictationTracking()
    }

    fun setAnimationDurationProp(duration: Double) {
        animationDuration = duration
    }

    // -- Commands from JS --

    fun setValueFromJS(value: String?) {
        var newText = value ?: ""
        val currentText = editText.text?.toString() ?: ""
        if (currentText == newText) return

        if (isDictating && dictationInsertPosition > 0 && dictationInsertPosition <= textBeforeDictation.length) {
            if (newText.startsWith(textBeforeDictation)) {
                var dictatedContent = newText.substring(textBeforeDictation.length)
                if (dictatedContent.isNotEmpty()) {
                    val beforeCursor = textBeforeDictation.substring(0, dictationInsertPosition)
                    val afterCursor = textBeforeDictation.substring(dictationInsertPosition)

                    if (beforeCursor.endsWith(" ") && dictatedContent.startsWith(" ")) {
                        dictatedContent = dictatedContent.substring(1)
                    }
                    if (afterCursor.isNotEmpty() && dictatedContent.isNotEmpty()) {
                        val firstAfterChar = afterCursor[0]
                        val isAfterWhitespaceOrPunctuation = firstAfterChar.isWhitespace() ||
                                !firstAfterChar.isLetterOrDigit()
                        val dictatedEndsWithSpace = dictatedContent.endsWith(" ")
                        if (!isAfterWhitespaceOrPunctuation && !dictatedEndsWithSpace) {
                            dictatedContent += " "
                        }
                    }
                    newText = beforeCursor + dictatedContent + afterCursor
                }
            }
        }

        if (isDictating && animatingViews.isNotEmpty()) {
            completeAllAnimationsImmediately(restoreHiddenText = false)
        }

        isInternalUpdate = true

        editText.setText(newText)

        if (isDictating) {
            val dictatedLength = (newText.length - textBeforeDictation.length).coerceAtLeast(0)
            val cursorPos = (dictationInsertPosition + dictatedLength).coerceAtMost(newText.length)
            editText.setSelection(cursorPos)
        } else if (editText.hasFocus()) {
            editText.setSelection(newText.length)
        } else {
            val cursorPos = editText.selectionStart.coerceAtMost(newText.length)
            editText.setSelection(cursorPos)
        }

        isInternalUpdate = false

        if (isDictating) {
            handleTextChangeForAnimation(newText)
        }

        previousText = newText
        previousWordCount = newText.split(" ").filter { it.isNotEmpty() }.size

        updatePlaceholderVisibility()
        if (dynamicSizing) {
            updateFontSizeForTextLength()
        }
        notifyContentSizeIfNeeded()
    }

    fun focusInput() {
        editText.requestFocus()
        post {
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    fun blurInput() {
        editText.clearFocus()
        val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        imm?.hideSoftInputFromWindow(editText.windowToken, 0)
    }

    fun cleanup() {
        animatingViews.forEach { view ->
            view.animate().cancel()
            (view.parent as? ViewGroup)?.removeView(view)
        }
        animatingViews.clear()
        hiddenSpans.clear()
    }

    // -- Internal helpers --

    private fun configureInputType() {
        val baseType = editText.inputType and InputType.TYPE_MASK_CLASS
        if (multiline) {
            editText.isSingleLine = false
            editText.inputType = editText.inputType or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            editText.setHorizontallyScrolling(false)
            if (autoGrow) {
                editText.maxLines = Integer.MAX_VALUE
            }
        } else {
            editText.isSingleLine = true
            editText.inputType = editText.inputType and InputType.TYPE_TEXT_FLAG_MULTI_LINE.inv()
            editText.maxLines = 1
        }
    }

    private fun applyInputType(baseType: Int) {
        var newType = baseType
        if (multiline && (newType and InputType.TYPE_MASK_CLASS) == InputType.TYPE_CLASS_TEXT) {
            newType = newType or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        }
        editText.inputType = newType
        editText.isSingleLine = !multiline
        if (multiline) {
            editText.setHorizontallyScrolling(false)
        }
    }

    private fun updateFont() {
        val size = if (dynamicSizing) currentFontSize else baseFontSize
        editText.setTextSize(TypedValue.COMPLEX_UNIT_SP, size)

        val family = fontFamily
        if (family != null && family.isNotEmpty()) {
            try {
                val typeface = Typeface.create(family, Typeface.NORMAL)
                editText.typeface = typeface
            } catch (_: Exception) {
                try {
                    val assetTypeface = Typeface.createFromAsset(context.assets, "fonts/$family.ttf")
                    editText.typeface = assetTypeface
                } catch (_: Exception) {}
            }
        }
    }

    private fun updateFontSizeForTextLength() {
        val length = editText.text?.length ?: 0
        var targetSize = baseFontSize

        for (rule in fontSizeRules) {
            if (length <= rule.first) {
                targetSize = rule.second
                break
            }
        }
        targetSize = targetSize.coerceAtLeast(minFontSize)

        if (targetSize != currentFontSize) {
            currentFontSize = targetSize
            updateFont()
        }
    }

    private fun updatePlaceholderVisibility() {
        // Android handles hint visibility automatically
    }

    private fun refreshExistingTextColor() {
        val text = editText.text ?: return
        if (text.isEmpty()) return

        isInternalUpdate = true
        val savedStart = editText.selectionStart
        val savedEnd = editText.selectionEnd

        val spannable = text as? Spannable ?: return
        val existingSpans = spannable.getSpans(0, spannable.length, ForegroundColorSpan::class.java)
        val hiddenStarts = hiddenSpans.map { it.start }.toSet()

        for (span in existingSpans) {
            val spanStart = spannable.getSpanStart(span)
            if (spanStart !in hiddenStarts) {
                spannable.removeSpan(span)
            }
        }
        spannable.setSpan(
            ForegroundColorSpan(originalTextColor),
            0,
            spannable.length,
            Spannable.SPAN_INCLUSIVE_EXCLUSIVE
        )

        editText.setSelection(
            savedStart.coerceAtMost(spannable.length),
            savedEnd.coerceAtMost(spannable.length)
        )
        isInternalUpdate = false
    }

    private fun notifyContentSizeIfNeeded() {
        if (!multiline || !autoGrow) return
        val layout = editText.layout ?: return

        val contentHeight = layout.height.toFloat() +
                editText.paddingTop.toFloat() +
                editText.paddingBottom.toFloat()

        var newHeight = contentHeight
        if (propMinHeight > 0) {
            newHeight = newHeight.coerceAtLeast(dpToPx(propMinHeight).toFloat())
        }
        if (propMaxHeight > 0) {
            newHeight = newHeight.coerceAtMost(dpToPx(propMaxHeight).toFloat())
            editText.isVerticalScrollBarEnabled = contentHeight > dpToPx(propMaxHeight)
        }

        if (Math.abs(newHeight - lastContentHeight) > 0.5f) {
            lastContentHeight = newHeight

            sendEvent("onContentSizeChange", Arguments.createMap().apply {
                putMap("contentSize", Arguments.createMap().apply {
                    putDouble("width", (width.toFloat() / resources.displayMetrics.density).toDouble())
                    putDouble("height", (newHeight / resources.displayMetrics.density).toDouble())
                })
            })
        }
    }

    // -- Dictation animation --

    private fun handleTextChangeForAnimation(newText: String) {
        if (!isDictating) {
            previousText = newText
            previousWordCount = newText.split(" ").filter { it.isNotEmpty() }.size
            return
        }

        val oldWords = previousText.split(" ").filter { it.isNotEmpty() }
        val newWords = newText.split(" ").filter { it.isNotEmpty() }

        if (newWords.size > oldWords.size) {
            val oldWordsCopy = oldWords.toMutableList()
            val newWordIndices = mutableListOf<Int>()

            for ((index, word) in newWords.withIndex()) {
                val oldIndex = oldWordsCopy.indexOf(word)
                if (oldIndex >= 0) {
                    oldWordsCopy.removeAt(oldIndex)
                } else {
                    newWordIndices.add(index)
                }
            }

            for ((delayIndex, wordIndex) in newWordIndices.withIndex()) {
                val word = newWords[wordIndex]
                val range = rangeOfWord(wordIndex, newText)
                if (range != null) {
                    animateNewWord(word, range.first, range.second, delayIndex * 0.05)
                }
            }
        }

        previousText = newText
        previousWordCount = newWords.size
    }

    private fun rangeOfWord(index: Int, text: String): Pair<Int, Int>? {
        var wordIndex = 0
        var i = 0
        while (i < text.length) {
            while (i < text.length && text[i].isWhitespace()) i++
            if (i >= text.length) break

            val wordStart = i
            while (i < text.length && !text[i].isWhitespace()) i++

            if (wordIndex == index) {
                return Pair(wordStart, i)
            }
            wordIndex++
        }
        return null
    }

    private fun animateNewWord(word: String, start: Int, end: Int, delay: Double) {
        hideWordAt(start, end)
        post { createAndAnimateLabel(word, start, end, delay) }
    }

    private fun hideWordAt(start: Int, end: Int) {
        isInternalUpdate = true
        val spannable = editText.text as? Spannable ?: run {
            isInternalUpdate = false
            return
        }
        if (end > spannable.length) {
            isInternalUpdate = false
            return
        }
        val span = ForegroundColorSpan(Color.TRANSPARENT)
        spannable.setSpan(span, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
        hiddenSpans.add(HiddenSpanInfo(span, start, end))
        isInternalUpdate = false
    }

    private fun showWordAt(info: HiddenSpanInfo) {
        isInternalUpdate = true
        val spannable = editText.text as? Spannable ?: run {
            isInternalUpdate = false
            return
        }
        spannable.removeSpan(info.span)
        if (info.end <= spannable.length) {
            spannable.setSpan(
                ForegroundColorSpan(originalTextColor),
                info.start,
                info.end,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        hiddenSpans.remove(info)
        isInternalUpdate = false
    }

    private fun createAndAnimateLabel(word: String, start: Int, end: Int, delay: Double) {
        val layout = editText.layout ?: return

        val line = layout.getLineForOffset(start)
        val x = layout.getPrimaryHorizontal(start) + editText.paddingLeft
        val y = layout.getLineTop(line).toFloat() + editText.paddingTop
        val lineHeight = (layout.getLineBottom(line) - layout.getLineTop(line)).toFloat()

        val label = TextView(context)
        label.text = word
        label.setTextSize(TypedValue.COMPLEX_UNIT_PX, editText.textSize)
        label.typeface = editText.typeface
        label.setTextColor(originalTextColor)
        label.includeFontPadding = editText.includeFontPadding

        label.measure(
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        )
        val labelWidth = label.measuredWidth
        val labelHeight = label.measuredHeight

        val lp = LayoutParams(labelWidth, labelHeight)
        lp.leftMargin = x.toInt()
        lp.topMargin = y.toInt()
        label.layoutParams = lp
        label.elevation = 10f

        label.alpha = 0f
        label.scaleX = 0.7f
        label.scaleY = 0.7f

        addView(label)
        animatingViews.add(label)

        val spanInfo = hiddenSpans.find { it.start == start && it.end == end }

        label.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setStartDelay((delay * 1000).toLong())
            .setDuration(animationDuration.toLong())
            .setInterpolator(DecelerateInterpolator(1.5f))
            .setListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (spanInfo != null) {
                        showWordAt(spanInfo)
                    }
                    removeView(label)
                    animatingViews.remove(label)
                }
            })
            .start()
    }

    private fun resetDictationTracking() {
        completeAllAnimationsImmediately(restoreHiddenText = true)
        previousText = editText.text?.toString() ?: ""
        previousWordCount = previousText.split(" ").filter { it.isNotEmpty() }.size
    }

    private fun completeAllAnimationsImmediately(restoreHiddenText: Boolean) {
        for (view in animatingViews) {
            view.animate().cancel()
            removeView(view)
        }
        animatingViews.clear()

        if (restoreHiddenText && hiddenSpans.isNotEmpty()) {
            isInternalUpdate = true
            val spannable = editText.text as? Spannable
            if (spannable != null) {
                for (info in hiddenSpans) {
                    spannable.removeSpan(info.span)
                    if (info.end <= spannable.length) {
                        spannable.setSpan(
                            ForegroundColorSpan(originalTextColor),
                            info.start,
                            info.end,
                            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                    }
                }
            }
            isInternalUpdate = false
        }
        hiddenSpans.clear()
    }

    // -- Event sending --

    private fun sendEvent(eventName: String, params: com.facebook.react.bridge.WritableMap) {
        reactContext.getJSModule(RCTEventEmitter::class.java)
            .receiveEvent(id, eventName, params)
    }

    // -- Utility --

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    override fun requestLayout() {
        super.requestLayout()
        post(measureAndLayout)
    }

    private val measureAndLayout = Runnable {
        measure(
            MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
        )
        layout(left, top, right, bottom)
    }

    /**
     * Inner EditText that notifies the parent FrameLayout about size changes
     * so auto-grow content size events fire correctly.
     */
    inner class InnerEditText(context: Context) : androidx.appcompat.widget.AppCompatEditText(context) {
        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            super.onSizeChanged(w, h, oldw, oldh)
            if (!isInternalUpdate) {
                this@RNAnimatedInputView.notifyContentSizeIfNeeded()
            }
        }

        override fun onTextChanged(text: CharSequence?, start: Int, lengthBefore: Int, lengthAfter: Int) {
            super.onTextChanged(text, start, lengthBefore, lengthAfter)
            if (!isInternalUpdate) {
                post { this@RNAnimatedInputView.notifyContentSizeIfNeeded() }
            }
        }
    }
}
