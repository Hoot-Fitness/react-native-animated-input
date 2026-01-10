import UIKit

/// A custom UITextView that supports dynamic font sizing and word-by-word dictation animations
@objc public class RNAnimatedInputView: UITextView, UITextViewDelegate {
    
    // MARK: - Callbacks
    
    @objc public var onChangeText: RCTDirectEventBlock?
    @objc public var onInputFocus: RCTDirectEventBlock?
    @objc public var onInputBlur: RCTDirectEventBlock?
    @objc public var onInputSubmit: RCTDirectEventBlock?
    @objc public var onContentSizeChange: RCTDirectEventBlock?
    
    // MARK: - Text Properties
    
    private var _textAlign: NSTextAlignment = .left
    @objc public var textAlignString: String = "left" {
        didSet {
            switch textAlignString {
            case "center": _textAlign = .center
            case "right": _textAlign = .right
            default: _textAlign = .left
            }
            self.textAlignment = _textAlign
        }
    }
    
    private var _fontFamily: String?
    @objc public var fontFamily: String? {
        didSet {
            _fontFamily = fontFamily
            updateFont()
        }
    }
    
    // MARK: - Multiline & Auto-grow
    
    @objc public var multiline: Bool = true {
        didSet {
            configureForMultiline()
        }
    }
    
    @objc public var autoGrow: Bool = true {
        didSet {
            configureForMultiline()
        }
    }
    
    @objc public var maxHeight: CGFloat = 0
    @objc public var minHeight: CGFloat = 50
    
    // MARK: - Keyboard Properties
    
    @objc public var keyboardTypeString: String = "default" {
        didSet {
            switch keyboardTypeString {
            case "number-pad": keyboardType = .numberPad
            case "decimal-pad": keyboardType = .decimalPad
            case "numeric": keyboardType = .numbersAndPunctuation
            case "email-address": keyboardType = .emailAddress
            case "phone-pad": keyboardType = .phonePad
            case "url": keyboardType = .URL
            default: keyboardType = .default
            }
        }
    }
    
    @objc public var returnKeyTypeString: String = "default" {
        didSet {
            switch returnKeyTypeString {
            case "go": returnKeyType = .go
            case "next": returnKeyType = .next
            case "search": returnKeyType = .search
            case "send": returnKeyType = .send
            case "done": returnKeyType = .done
            default: returnKeyType = .default
            }
        }
    }
    
    @objc public var autoCapitalizeString: String = "sentences" {
        didSet {
            switch autoCapitalizeString {
            case "none": autocapitalizationType = .none
            case "words": autocapitalizationType = .words
            case "characters": autocapitalizationType = .allCharacters
            default: autocapitalizationType = .sentences
            }
        }
    }
    
    @objc public var autoCorrectEnabled: Bool = true {
        didSet { autocorrectionType = autoCorrectEnabled ? .yes : .no }
    }
    
    @objc public var secureTextEntryEnabled: Bool = false {
        didSet { isSecureTextEntry = secureTextEntryEnabled }
    }
    
    @objc public var editableEnabled: Bool = true {
        didSet { isEditable = editableEnabled }
    }
    
    @objc public var maxLength: Int = 0
    
    // MARK: - Dynamic Sizing
    
    @objc public var dynamicSizing: Bool = false {
        didSet {
            if dynamicSizing { updateFontSizeForTextLength() }
        }
    }
    
    private var _fontSizeRules: [(maxLength: Int, fontSize: CGFloat)] = [
        (20, 32), (50, 24), (100, 18), (Int.max, 14)
    ]
    
    @objc public var fontSizeRulesJson: String? {
        didSet {
            guard let json = fontSizeRulesJson,
                  let data = json.data(using: .utf8),
                  let rules = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
            
            _fontSizeRules = rules.compactMap { rule in
                guard let maxLen = rule["maxLength"] as? Int,
                      let size = rule["fontSize"] as? CGFloat else { return nil }
                return (maxLen, size)
            }.sorted { $0.0 < $1.0 }
            
            if dynamicSizing { updateFontSizeForTextLength() }
        }
    }
    
    @objc public var baseFontSize: CGFloat = 32 {
        didSet {
            currentFontSize = baseFontSize
            updateFont()
        }
    }
    
    @objc public var minFontSize: CGFloat = 14
    
    // MARK: - Dictation Animation
    
    @objc public var isDictating: Bool = false {
        didSet {
            // Reset tracking when dictation mode toggles to avoid stale hidden ranges
            resetDictationTracking()
        }
    }
    @objc public var animationDuration: Double = 250
    
    // MARK: - Placeholder
    
    private var placeholderLabel: UILabel?
    
    @objc public var placeholder: String? {
        didSet { setupPlaceholder() }
    }
    
    @objc public var placeholderTextColor: UIColor = .placeholderText {
        didSet { placeholderLabel?.textColor = placeholderTextColor }
    }
    
    // MARK: - Internal State
    
    private var previousText: String = ""
    private var previousWordCount: Int = 0
    private var currentFontSize: CGFloat = 32
    private var originalTextColor: UIColor = .label
    private var lastContentHeight: CGFloat = 0
    private var targetAutoGrowHeight: CGFloat = 0  // Store target height to reapply after RN layout
    private var animatingLabels: [UILabel] = []
    private var hiddenRanges: [NSRange] = []
    private var isInternalUpdate: Bool = false
    private var cachedContainerWidth: CGFloat = 0
    
    // MARK: - Initialization
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        delegate = self
        backgroundColor = .clear
        
        // Configure text container for proper wrapping
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.lineFragmentPadding = 0
        textContainer.heightTracksTextView = false
        textContainer.widthTracksTextView = false
        
        // CRITICAL: Set unlimited height immediately so text can wrap
        // This must be done before any text is set
        textContainer.size = CGSize(width: textContainer.size.width, height: .greatestFiniteMagnitude)
        
        // Insets
        textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Initial setup
        currentFontSize = baseFontSize
        originalTextColor = textColor ?? .label
        
        updateFont()
        configureForMultiline()
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:commonInit", "commonInit completed", [
            "lineBreakMode": String(describing: textContainer.lineBreakMode.rawValue),
            "lineFragmentPadding": textContainer.lineFragmentPadding,
            "widthTracksTextView": textContainer.widthTracksTextView,
            "heightTracksTextView": textContainer.heightTracksTextView,
            "maximumNumberOfLines": textContainer.maximumNumberOfLines,
            "isScrollEnabled": isScrollEnabled,
            "multiline": multiline,
            "autoGrow": autoGrow
        ], hypothesisId: "C")
        // #endregion
    }
    
    private func configureForMultiline() {
        if multiline {
            textContainer.maximumNumberOfLines = 0  // Unlimited lines
            if autoGrow {
                isScrollEnabled = false  // Disable scroll so view can grow
            } else {
                isScrollEnabled = true
            }
        } else {
            // Single line mode
            textContainer.maximumNumberOfLines = 1
            isScrollEnabled = false
        }
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:configureForMultiline", "configured multiline", [
            "multiline": multiline,
            "autoGrow": autoGrow,
            "maximumNumberOfLines": textContainer.maximumNumberOfLines,
            "isScrollEnabled": isScrollEnabled
        ], hypothesisId: "C")
        // #endregion
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:layoutSubviews", "layoutSubviews called", [
            "boundsWidth": bounds.width,
            "boundsHeight": bounds.height,
            "frameWidth": frame.width,
            "frameHeight": frame.height,
            "targetAutoGrowHeight": targetAutoGrowHeight,
            "textContainerSizeWidthBefore": textContainer.size.width,
            "textContainerSizeHeightBefore": textContainer.size.height
        ], hypothesisId: "A")
        // #endregion
        
        // Reapply target height if React Native reset it (Hypothesis M fix)
        if multiline && autoGrow && targetAutoGrowHeight > 0 && abs(frame.height - targetAutoGrowHeight) > 0.5 {
            var newFrame = frame
            newFrame.size.height = targetAutoGrowHeight
            frame = newFrame
            
            // #region agent log
            debugLog("RNAnimatedInputView.swift:layoutSubviews", "reapplied targetAutoGrowHeight", [
                "targetAutoGrowHeight": targetAutoGrowHeight,
                "newFrameHeight": frame.height
            ], hypothesisId: "M")
            // #endregion
        }
        
        // CRITICAL: Set text container width for proper text wrapping
        let containerWidth = bounds.width - textContainerInset.left - textContainerInset.right
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:layoutSubviews", "containerWidth calculated", [
            "containerWidth": containerWidth,
            "insetLeft": textContainerInset.left,
            "insetRight": textContainerInset.right,
            "heightTracksTextView": textContainer.heightTracksTextView,
            "widthTracksTextView": textContainer.widthTracksTextView
        ], hypothesisId: "B")
        // #endregion
        
        // Force disable tracking - UITextView may override our settings
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        
        // Always set the container size for proper wrapping - width for wrap, height unlimited
        if containerWidth > 0 {
            let needsInvalidation = textContainer.size.width != containerWidth || textContainer.size.height < 10000
            textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
            cachedContainerWidth = containerWidth
            
            // Force layout manager to recalculate text layout with new container size
            if needsInvalidation {
                layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: (text ?? "").count), actualCharacterRange: nil)
                layoutManager.ensureLayout(for: textContainer)
            }
            
            // #region agent log
            debugLog("RNAnimatedInputView.swift:layoutSubviews", "textContainer.size updated", [
                "newWidth": textContainer.size.width,
                "newHeight": String(describing: textContainer.size.height),
                "cachedContainerWidth": cachedContainerWidth,
                "heightTracksTextViewAfter": textContainer.heightTracksTextView,
                "needsInvalidation": needsInvalidation
            ], hypothesisId: "B")
            // #endregion
        }
        
        // Update placeholder width
        placeholderLabel?.preferredMaxLayoutWidth = containerWidth
        
        // Notify about content size changes for auto-grow
        notifyContentSizeIfNeeded()
    }
    
    private func notifyContentSizeIfNeeded() {
        guard multiline && autoGrow else { return }
        guard bounds.width > 0 else { return }
        
        // Calculate the height needed for current content using layout manager's used rect
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let calculatedHeight = usedRect.height + textContainerInset.top + textContainerInset.bottom
        
        // Also get sizeThatFits for comparison
        let fittingSize = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        let containerWidth = cachedContainerWidth > 0 ? cachedContainerWidth : bounds.width - textContainerInset.left - textContainerInset.right
        
        // Include placeholder height when there is no text so the control matches multi-line placeholders
        let placeholderHeight = placeholderLabel?.sizeThatFits(CGSize(width: containerWidth, height: .greatestFiniteMagnitude)).height ?? 0
        let contentBaseHeight = text.isEmpty ? placeholderHeight + textContainerInset.top + textContainerInset.bottom : max(calculatedHeight, fittingSize.height)
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:notifyContentSizeIfNeeded", "calculating content size", [
            "usedRectHeight": usedRect.height,
            "calculatedHeight": calculatedHeight,
            "fittingHeight": fittingSize.height,
            "contentBaseHeight": contentBaseHeight,
            "textLength": (text ?? "").count
        ], hypothesisId: "I")
        // #endregion
        
        var newHeight = contentBaseHeight
        
        // Apply constraints
        newHeight = max(newHeight, minHeight)
        if maxHeight > 0 {
            newHeight = min(newHeight, maxHeight)
            isScrollEnabled = fittingSize.height > maxHeight
        }
        
        // Only notify if changed
        if abs(newHeight - lastContentHeight) > 0.5 {
            lastContentHeight = newHeight
            
            // #region agent log
            debugLog("RNAnimatedInputView.swift:notifyContentSizeIfNeeded", "sending onContentSizeChange", [
                "newHeight": newHeight,
                "boundsWidth": bounds.width,
                "hasCallback": onContentSizeChange != nil
            ], hypothesisId: "I")
            // #endregion
            
            // Store target height so layoutSubviews can reapply it after RN layout
            targetAutoGrowHeight = newHeight
            
            onContentSizeChange?([
                "contentSize": [
                    "width": bounds.width,
                    "height": newHeight
                ]
            ])
            
            // Force intrinsic content size update and React Native layout
            invalidateIntrinsicContentSize()
            
            // Directly update frame height
            if abs(frame.height - newHeight) > 0.5 {
                var newFrame = frame
                newFrame.size.height = newHeight
                frame = newFrame
                
                // #region agent log
                debugLog("RNAnimatedInputView.swift:notifyContentSizeIfNeeded", "directly set frame height", [
                    "newFrameHeight": frame.height,
                    "newHeight": newHeight,
                    "targetAutoGrowHeight": targetAutoGrowHeight
                ], hypothesisId: "L")
                // #endregion
            }
            
            // Tell React Native to update the view's frame
            if let reactSuperview = superview {
                reactSuperview.setNeedsLayout()
            }
        }
    }
    
    public override var intrinsicContentSize: CGSize {
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        let height = usedRect.height + textContainerInset.top + textContainerInset.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: max(height, minHeight))
    }
    
    // MARK: - Font Management
    
    private func updateFont() {
        let size = dynamicSizing ? currentFontSize : baseFontSize
        
        if let family = _fontFamily, !family.isEmpty,
           let customFont = UIFont(name: family, size: size) {
            self.font = customFont
        } else {
            self.font = UIFont.systemFont(ofSize: size)
        }
        
        placeholderLabel?.font = self.font
    }
    
    private func updateFontSizeForTextLength() {
        let length = text.count
        var targetSize = baseFontSize
        
        for rule in _fontSizeRules {
            if length <= rule.0 {
                targetSize = rule.1
                break
            }
        }
        
        targetSize = max(targetSize, minFontSize)
        
        if targetSize != currentFontSize {
            UIView.animate(withDuration: animationDuration / 1000.0) {
                self.currentFontSize = targetSize
                self.updateFont()
            }
        }
    }
    
    // MARK: - Placeholder
    
    private func setupPlaceholder() {
        placeholderLabel?.removeFromSuperview()
        
        guard let text = placeholder, !text.isEmpty else {
            placeholderLabel = nil
            return
        }
        
        let label = UILabel()
        label.text = text
        label.font = self.font
        label.textColor = placeholderTextColor
        label.textAlignment = _textAlign
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: textContainerInset.top),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: textContainerInset.left + textContainer.lineFragmentPadding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -(textContainerInset.right + textContainer.lineFragmentPadding))
        ])
        
        placeholderLabel = label
        updatePlaceholderVisibility()
    }
    
    private func updatePlaceholderVisibility() {
        placeholderLabel?.isHidden = !text.isEmpty
    }
    
    // MARK: - Dictation Animation
    
    private func handleTextChangeForAnimation(newText: String) {
        guard isDictating else {
            previousText = newText
            previousWordCount = newText.split(separator: " ").count
            return
        }
        
        let oldWords = previousText.split(separator: " ").map(String.init)
        let newWords = newText.split(separator: " ").map(String.init)
        
        // Only animate if words were added (not removed or modified)
        if newWords.count > oldWords.count {
            // Find new words
            let newWordStartIndex = oldWords.count
            
            for i in newWordStartIndex..<newWords.count {
                let word = newWords[i]
                if let range = rangeOfWord(at: i, in: newText) {
                    animateNewWord(word: word, range: range, delay: Double(i - newWordStartIndex) * 0.05)
                }
            }
        }
        
        previousText = newText
        previousWordCount = newWords.count
    }
    
    private func rangeOfWord(at index: Int, in text: String) -> NSRange? {
        let nsString = text as NSString
        var wordIndex = 0
        var i = 0
        
        while i < nsString.length {
            // Skip spaces
            while i < nsString.length {
                let char = nsString.character(at: i)
                if char != 32 && char != 10 && char != 13 && char != 9 { break }
                i += 1
            }
            
            guard i < nsString.length else { break }
            
            let wordStart = i
            
            // Find word end
            while i < nsString.length {
                let char = nsString.character(at: i)
                if char == 32 || char == 10 || char == 13 || char == 9 { break }
                i += 1
            }
            
            if wordIndex == index {
                return NSRange(location: wordStart, length: i - wordStart)
            }
            
            wordIndex += 1
        }
        
        return nil
    }
    
    private func animateNewWord(word: String, range: NSRange, delay: Double) {
        // Hide the word in the text view
        hideWordAt(range: range)
        
        // Wait for layout then create overlay
        DispatchQueue.main.async { [weak self] in
            self?.createAndAnimateLabel(word: word, range: range, delay: delay)
        }
    }
    
    private func hideWordAt(range: NSRange) {
        isInternalUpdate = true
        
        let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
        guard range.location + range.length <= mutableAttr.length else {
            isInternalUpdate = false
            return
        }
        
        mutableAttr.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
        hiddenRanges.append(range)
        
        attributedText = mutableAttr
        
        isInternalUpdate = false
    }
    
    private func showWordAt(range: NSRange) {
        isInternalUpdate = true
        
        let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
        guard range.location + range.length <= mutableAttr.length else {
            isInternalUpdate = false
            return
        }
        
        mutableAttr.addAttribute(.foregroundColor, value: textColor ?? originalTextColor, range: range)
        hiddenRanges.removeAll { $0 == range }
        
        attributedText = mutableAttr
        
        isInternalUpdate = false
    }
    
    private func createAndAnimateLabel(word: String, range: NSRange, delay: Double) {
        layoutIfNeeded()
        
        // Get word position
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.ensureLayout(forCharacterRange: glyphRange)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Adjust for insets
        rect.origin.x += textContainerInset.left
        rect.origin.y += textContainerInset.top - contentOffset.y
        
        // Create label
        let label = UILabel()
        label.text = word
        label.font = self.font
        label.textColor = textColor ?? originalTextColor
        label.frame = rect
        
        // Initial state: invisible and scaled up
        label.alpha = 0
        label.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        
        addSubview(label)
        animatingLabels.append(label)
        
        // Animate
        UIView.animate(
            withDuration: animationDuration / 1000.0,
            delay: delay,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: [],
            animations: {
                label.alpha = 1
                label.transform = .identity
            },
            completion: { [weak self] _ in
                // Show the actual text and remove label
                self?.showWordAt(range: range)
                label.removeFromSuperview()
                self?.animatingLabels.removeAll { $0 === label }
            }
        )
    }
    
    private func resetDictationTracking() {
        // Remove any in-flight animation overlays
        animatingLabels.forEach { $0.removeFromSuperview() }
        animatingLabels.removeAll()
        
        // Restore any hidden text
        if !hiddenRanges.isEmpty {
            isInternalUpdate = true
            let rangesToRestore = hiddenRanges
            hiddenRanges.removeAll()
            
            let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
            for range in rangesToRestore {
                if range.location + range.length <= mutableAttr.length {
                    mutableAttr.addAttribute(.foregroundColor, value: textColor ?? originalTextColor, range: range)
                }
            }
            attributedText = mutableAttr
            isInternalUpdate = false
        }
        
        previousText = text ?? ""
        previousWordCount = previousText.split(separator: " ").count
    }
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        if isInternalUpdate {
            return
        }
    }
    
    // MARK: - UITextViewDelegate
    
    public func textViewDidChange(_ textView: UITextView) {
        // #region agent log
        debugLog("RNAnimatedInputView.swift:textViewDidChange", "textViewDidChange ENTRY", [
            "isInternalUpdate": isInternalUpdate,
            "textLength": (textView.text ?? "").count
        ], hypothesisId: "F")
        // #endregion
        
        guard !isInternalUpdate else { return }
        
        let newText = textView.text ?? ""
        
        // Force layout recalculation
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:textViewDidChange", "text changed - layout info", [
            "textLength": newText.count,
            "textContainerWidth": textContainer.size.width,
            "textContainerHeight": String(describing: textContainer.size.height),
            "boundsWidth": bounds.width,
            "usedRectWidth": usedRect.width,
            "usedRectHeight": usedRect.height,
            "numberOfGlyphs": layoutManager.numberOfGlyphs,
            "numberOfLines": textContainer.maximumNumberOfLines,
            "lineBreakMode": textContainer.lineBreakMode.rawValue
        ], hypothesisId: "G")
        // #endregion
        
        updatePlaceholderVisibility()
        
        if dynamicSizing {
            updateFontSizeForTextLength()
        }
        
        // Handle dictation animation
        handleTextChangeForAnimation(newText: newText)
        
        // Notify content size change for auto-grow
        notifyContentSizeIfNeeded()
        
        // Notify React Native
        onChangeText?(["text": newText])
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        onInputFocus?([:])
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        onInputBlur?([:])
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Single-line: return key submits
        if text == "\n" && !multiline {
            onInputSubmit?(["text": textView.text ?? ""])
            return false
        }
        
        // Max length check
        if maxLength > 0 {
            let currentLength = (textView.text ?? "").count
            let newLength = currentLength + text.count - range.length
            if newLength > maxLength { return false }
        }
        
        return true
    }
    
    // MARK: - React Native Methods
    
    @objc public func setValue(_ value: String?) {
        let newText = value ?? ""
        guard text != newText else { return }
        
        // CRITICAL: Ensure text container has unlimited height before setting text (Hypothesis T)
        if textContainer.size.height < 10000 {
            let containerWidth = bounds.width > 0 ? bounds.width - textContainerInset.left - textContainerInset.right : textContainer.size.width
            textContainer.size = CGSize(width: containerWidth > 0 ? containerWidth : 338, height: .greatestFiniteMagnitude)
        }
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:setValue", "setValue called", [
            "newTextLength": newText.count,
            "textContainerWidth": textContainer.size.width,
            "textContainerHeight": String(describing: textContainer.size.height),
            "boundsWidth": bounds.width
        ], hypothesisId: "H")
        // #endregion
        
        text = newText
        previousText = newText
        previousWordCount = newText.split(separator: " ").count
        
        // Force layout after setting text
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        
        // #region agent log
        debugLog("RNAnimatedInputView.swift:setValue", "setValue after layout", [
            "usedRectWidth": usedRect.width,
            "usedRectHeight": usedRect.height,
            "textContainerWidth": textContainer.size.width
        ], hypothesisId: "H")
        // #endregion
        
        updatePlaceholderVisibility()
        
        if dynamicSizing {
            updateFontSizeForTextLength()
        }
        
        notifyContentSizeIfNeeded()
    }
    
    @objc public func focus() {
        becomeFirstResponder()
    }
    
    @objc public func blur() {
        resignFirstResponder()
    }
    
    // MARK: - Cleanup
    
    deinit {
        animatingLabels.forEach { $0.removeFromSuperview() }
    }
}
