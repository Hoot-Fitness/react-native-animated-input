import UIKit

/// A custom UITextView that supports dynamic font sizing and word-by-word dictation animations
@objc public class RNAnimatedInputView: UITextView, UITextViewDelegate {
    
    // MARK: - Callbacks
    
    /// Callback for text changes
    @objc public var onChangeText: RCTDirectEventBlock?
    
    /// Callback for focus events
    @objc public var onInputFocus: RCTDirectEventBlock?
    
    /// Callback for blur events
    @objc public var onInputBlur: RCTDirectEventBlock?
    
    /// Callback for submit editing
    @objc public var onInputSubmit: RCTDirectEventBlock?
    
    /// Callback for content size changes (for auto-grow)
    @objc public var onContentSizeChange: RCTDirectEventBlock?
    
    // MARK: - Text Properties
    
    /// Text alignment
    private var _textAlign: NSTextAlignment = .left
    @objc public var textAlignString: String = "left" {
        didSet {
            switch textAlignString {
            case "center":
                _textAlign = .center
            case "right":
                _textAlign = .right
            default:
                _textAlign = .left
            }
            self.textAlignment = _textAlign
        }
    }
    
    /// Custom font family name
    private var _fontFamily: String?
    @objc public var fontFamily: String? {
        didSet {
            _fontFamily = fontFamily
            updateFont()
        }
    }
    
    /// Multiline support
    @objc public var multiline: Bool = true {
        didSet {
            updateReturnKeyBehavior()
            updateScrollBehavior()
        }
    }
    
    /// Whether to auto-grow height based on content (only when multiline is true)
    @objc public var autoGrow: Bool = true {
        didSet {
            updateScrollBehavior()
            updateContentSize()
        }
    }
    
    /// Maximum height for auto-grow (0 = no limit)
    @objc public var maxHeight: CGFloat = 0 {
        didSet {
            updateContentSize()
        }
    }
    
    /// Minimum height for auto-grow
    @objc public var minHeight: CGFloat = 0 {
        didSet {
            updateContentSize()
        }
    }
    
    // MARK: - Keyboard Properties
    
    /// Keyboard type
    @objc public var keyboardTypeString: String = "default" {
        didSet {
            switch keyboardTypeString {
            case "number-pad":
                keyboardType = .numberPad
            case "decimal-pad":
                keyboardType = .decimalPad
            case "numeric":
                keyboardType = .numbersAndPunctuation
            case "email-address":
                keyboardType = .emailAddress
            case "phone-pad":
                keyboardType = .phonePad
            case "url":
                keyboardType = .URL
            default:
                keyboardType = .default
            }
        }
    }
    
    /// Return key type
    @objc public var returnKeyTypeString: String = "default" {
        didSet {
            switch returnKeyTypeString {
            case "go":
                returnKeyType = .go
            case "next":
                returnKeyType = .next
            case "search":
                returnKeyType = .search
            case "send":
                returnKeyType = .send
            case "done":
                returnKeyType = .done
            default:
                returnKeyType = .default
            }
        }
    }
    
    /// Auto-capitalize
    @objc public var autoCapitalizeString: String = "sentences" {
        didSet {
            switch autoCapitalizeString {
            case "none":
                autocapitalizationType = .none
            case "words":
                autocapitalizationType = .words
            case "characters":
                autocapitalizationType = .allCharacters
            default:
                autocapitalizationType = .sentences
            }
        }
    }
    
    /// Auto-correct
    @objc public var autoCorrectEnabled: Bool = true {
        didSet {
            autocorrectionType = autoCorrectEnabled ? .yes : .no
        }
    }
    
    /// Secure text entry
    @objc public var secureTextEntryEnabled: Bool = false {
        didSet {
            isSecureTextEntry = secureTextEntryEnabled
        }
    }
    
    /// Editable
    @objc public var editableEnabled: Bool = true {
        didSet {
            isEditable = editableEnabled
        }
    }
    
    /// Max length
    @objc public var maxLength: Int = 0 // 0 means no limit
    
    // MARK: - Dynamic Sizing Properties
    
    /// Whether dynamic sizing is enabled
    @objc public var dynamicSizing: Bool = false {
        didSet {
            if dynamicSizing {
                updateFontSizeForTextLength()
            }
        }
    }
    
    /// Font size rules for dynamic sizing - stored as JSON string from React Native
    private var _fontSizeRules: [(maxLength: Int, fontSize: CGFloat)] = [
        (maxLength: 20, fontSize: 32),
        (maxLength: 50, fontSize: 24),
        (maxLength: 100, fontSize: 18),
        (maxLength: Int.max, fontSize: 14)
    ]
    
    @objc public var fontSizeRulesJson: String? {
        didSet {
            guard let jsonString = fontSizeRulesJson,
                  let data = jsonString.data(using: .utf8),
                  let rules = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }
            
            _fontSizeRules = rules.compactMap { rule in
                guard let maxLength = rule["maxLength"] as? Int,
                      let fontSize = rule["fontSize"] as? CGFloat else {
                    return nil
                }
                return (maxLength: maxLength, fontSize: fontSize)
            }.sorted { $0.maxLength < $1.maxLength }
            
            if dynamicSizing {
                updateFontSizeForTextLength()
            }
        }
    }
    
    /// Base font size (used when dynamic sizing is disabled or as starting point)
    @objc public var baseFontSize: CGFloat = 32 {
        didSet {
            if !dynamicSizing {
                currentFontSize = baseFontSize
                updateFont()
            }
        }
    }
    
    /// Minimum font size for dynamic sizing
    @objc public var minFontSize: CGFloat = 14
    
    // MARK: - Dictation Animation Properties
    
    /// Whether dictation mode is active
    @objc public var isDictating: Bool = false
    
    /// Animation duration in milliseconds
    @objc public var animationDuration: Double = 250
    
    // MARK: - Placeholder Properties
    
    private var _placeholder: String?
    private var placeholderLabel: UILabel?
    
    @objc public var placeholder: String? {
        didSet {
            _placeholder = placeholder
            setupPlaceholder()
        }
    }
    
    @objc public var placeholderTextColor: UIColor = .placeholderText {
        didSet {
            placeholderLabel?.textColor = placeholderTextColor
        }
    }
    
    // MARK: - Internal State
    
    /// Track previous text for word detection
    private var previousText: String = ""
    
    /// Animation layers for cleanup
    private var animatingLayers: [CALayer] = []
    
    /// Ranges currently being animated (to hide in actual text)
    private var animatingRanges: [NSRange] = []
    
    /// Current font size
    private var currentFontSize: CGFloat = 32
    
    /// Store the original text color
    private var originalTextColor: UIColor = .label
    
    /// Last reported content size (to avoid redundant callbacks)
    private var lastReportedContentSize: CGSize = .zero
    
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
        textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        currentFontSize = baseFontSize
        originalTextColor = textColor ?? .label
        updateFont()
        updateScrollBehavior()
    }
    
    private func updateReturnKeyBehavior() {
        // For single-line behavior, we'll handle return key in shouldChangeText
    }
    
    private func updateScrollBehavior() {
        // Disable scrolling when auto-grow is enabled for multiline
        // This allows the view to grow instead of scroll
        if multiline && autoGrow {
            isScrollEnabled = false
        } else {
            isScrollEnabled = true
        }
    }
    
    // MARK: - Auto-Grow
    
    private func updateContentSize() {
        guard multiline && autoGrow else { return }
        
        let newSize = calculateContentSize()
        
        // Only notify if size actually changed
        if newSize != lastReportedContentSize {
            lastReportedContentSize = newSize
            
            // Invalidate intrinsic content size so Auto Layout recalculates
            invalidateIntrinsicContentSize()
            
            // Notify React Native about size change
            onContentSizeChange?([
                "contentSize": [
                    "width": newSize.width,
                    "height": newSize.height
                ]
            ])
        }
    }
    
    private func calculateContentSize() -> CGSize {
        let fixedWidth = bounds.width
        let sizeThatFits = sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        
        var height = sizeThatFits.height
        
        // Apply min/max constraints
        if minHeight > 0 {
            height = max(height, minHeight)
        }
        if maxHeight > 0 {
            height = min(height, maxHeight)
            
            // Re-enable scrolling if content exceeds max height
            if sizeThatFits.height > maxHeight {
                isScrollEnabled = true
            } else {
                isScrollEnabled = false
            }
        }
        
        return CGSize(width: fixedWidth, height: height)
    }
    
    public override var intrinsicContentSize: CGSize {
        guard multiline && autoGrow else {
            return super.intrinsicContentSize
        }
        
        return calculateContentSize()
    }
    
    // MARK: - Font Management
    
    private func updateFont() {
        let size = dynamicSizing ? currentFontSize : baseFontSize
        
        if let familyName = _fontFamily, !familyName.isEmpty {
            if let customFont = UIFont(name: familyName, size: size) {
                self.font = customFont
            } else {
                self.font = UIFont.systemFont(ofSize: size)
            }
        } else {
            self.font = UIFont.systemFont(ofSize: size)
        }
        
        placeholderLabel?.font = self.font
    }
    
    private func updateFontSizeForTextLength() {
        let length = text.count
        var targetSize = baseFontSize
        
        for rule in _fontSizeRules {
            if length <= rule.maxLength {
                targetSize = rule.fontSize
                break
            }
        }
        
        targetSize = max(targetSize, minFontSize)
        
        if targetSize != currentFontSize {
            animateFontSizeChange(to: targetSize)
        }
    }
    
    private func animateFontSizeChange(to newSize: CGFloat) {
        let duration = animationDuration / 1000.0
        
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            self.currentFontSize = newSize
            self.updateFont()
            self.layoutIfNeeded()
        }
    }
    
    // MARK: - Placeholder
    
    private func setupPlaceholder() {
        placeholderLabel?.removeFromSuperview()
        
        guard let placeholderText = _placeholder, !placeholderText.isEmpty else {
            placeholderLabel = nil
            return
        }
        
        let label = UILabel()
        label.text = placeholderText
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
    
    // MARK: - Word Animation for Dictation
    
    private func detectAndAnimateNewWords(oldText: String, newText: String) {
        guard isDictating else { return }
        
        let oldWords = oldText.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let newWords = newText.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        
        guard newWords.count > oldWords.count else { return }
        
        // Find ranges of new words
        var newWordRanges: [(word: String, range: NSRange)] = []
        
        for i in oldWords.count..<newWords.count {
            if let range = findRangeOfWord(at: i, in: newText) {
                newWordRanges.append((word: newWords[i], range: range))
            }
        }
        
        guard !newWordRanges.isEmpty else { return }
        
        // Hide the new words in the actual text using attributed string
        hideWordsForAnimation(ranges: newWordRanges.map { $0.range })
        
        // Animate each new word
        for (index, wordInfo) in newWordRanges.enumerated() {
            animateWord(wordInfo.word, range: wordInfo.range, delay: Double(index) * 0.05)
        }
    }
    
    private func hideWordsForAnimation(ranges: [NSRange]) {
        guard !ranges.isEmpty else { return }
        
        animatingRanges = ranges
        
        let attributedText = NSMutableAttributedString(attributedString: self.attributedText ?? NSAttributedString(string: text))
        
        for range in ranges {
            guard range.location + range.length <= attributedText.length else { continue }
            attributedText.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
        }
        
        // Temporarily disable delegate to avoid infinite loop
        let savedDelegate = delegate
        delegate = nil
        self.attributedText = attributedText
        delegate = savedDelegate
    }
    
    private func restoreWordVisibility(range: NSRange) {
        guard let index = animatingRanges.firstIndex(of: range) else { return }
        animatingRanges.remove(at: index)
        
        let attributedText = NSMutableAttributedString(attributedString: self.attributedText ?? NSAttributedString(string: text))
        
        guard range.location + range.length <= attributedText.length else { return }
        
        attributedText.addAttribute(.foregroundColor, value: textColor ?? originalTextColor, range: range)
        
        let savedDelegate = delegate
        delegate = nil
        self.attributedText = attributedText
        delegate = savedDelegate
    }
    
    private func animateWord(_ word: String, range: NSRange, delay: Double) {
        // Force layout to get accurate positions
        layoutManager.ensureLayout(for: textContainer)
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var wordRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Adjust for text container insets
        wordRect.origin.x += textContainerInset.left
        wordRect.origin.y += textContainerInset.top - contentOffset.y
        
        // Create a text layer for animation
        let textLayer = CATextLayer()
        textLayer.string = word
        
        // Use the same font
        if let font = self.font {
            textLayer.font = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
            textLayer.fontSize = font.pointSize
        }
        
        textLayer.foregroundColor = (textColor ?? originalTextColor).cgColor
        textLayer.alignmentMode = .left
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.frame = wordRect
        textLayer.isWrapped = false
        textLayer.truncationMode = .none
        
        // Set initial state - invisible and scaled down
        textLayer.opacity = 0
        textLayer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0)
        
        // Set anchor point for scaling from center
        textLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        textLayer.position = CGPoint(x: wordRect.midX, y: wordRect.midY)
        textLayer.bounds = CGRect(origin: .zero, size: wordRect.size)
        
        layer.addSublayer(textLayer)
        animatingLayers.append(textLayer)
        
        let duration = animationDuration / 1000.0
        
        // Animate opacity
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0
        opacityAnimation.toValue = 1
        opacityAnimation.duration = duration * 0.6
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacityAnimation.fillMode = .forwards
        opacityAnimation.isRemovedOnCompletion = false
        opacityAnimation.beginTime = CACurrentMediaTime() + delay
        
        // Animate scale with spring effect
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.7
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = duration * 1.5
        scaleAnimation.damping = 12
        scaleAnimation.initialVelocity = 8
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.beginTime = CACurrentMediaTime() + delay
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            // Restore word visibility and clean up layer
            DispatchQueue.main.async {
                self?.restoreWordVisibility(range: range)
                textLayer.removeFromSuperlayer()
                self?.animatingLayers.removeAll { $0 === textLayer }
            }
        }
        
        textLayer.add(opacityAnimation, forKey: "opacity")
        textLayer.add(scaleAnimation, forKey: "scale")
        
        CATransaction.commit()
    }
    
    private func findRangeOfWord(at wordIndex: Int, in text: String) -> NSRange? {
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard wordIndex < words.count else { return nil }
        
        var currentLocation = 0
        var wordCount = 0
        let nsText = text as NSString
        
        for i in 0..<nsText.length {
            let char = nsText.character(at: i)
            let isSpace = char == 32 // space character
            
            if !isSpace {
                // Start of a word
                var wordEnd = i
                while wordEnd < nsText.length && nsText.character(at: wordEnd) != 32 {
                    wordEnd += 1
                }
                
                if wordCount == wordIndex {
                    return NSRange(location: i, length: wordEnd - i)
                }
                
                wordCount += 1
                currentLocation = wordEnd
                
                // Skip to end of word
                while i < currentLocation {
                    break
                }
            }
        }
        
        return nil
    }
    
    // MARK: - UITextViewDelegate
    
    public func textViewDidChange(_ textView: UITextView) {
        let newText = textView.text ?? ""
        
        updatePlaceholderVisibility()
        
        if dynamicSizing {
            updateFontSizeForTextLength()
        }
        
        // Update content size for auto-grow
        updateContentSize()
        
        detectAndAnimateNewWords(oldText: previousText, newText: newText)
        
        previousText = newText
        
        onChangeText?(["text": newText])
    }
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        onInputFocus?([:])
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        onInputBlur?([:])
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Handle return key for single-line mode
        if text == "\n" && !multiline {
            onInputSubmit?(["text": textView.text ?? ""])
            return false
        }
        
        // Handle max length
        if maxLength > 0 {
            let currentText = textView.text ?? ""
            let newLength = currentText.count + text.count - range.length
            if newLength > maxLength {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - React Native Integration
    
    @objc public func setValue(_ value: String?) {
        let newText = value ?? ""
        
        if text != newText {
            text = newText
            previousText = newText
            updatePlaceholderVisibility()
            
            if dynamicSizing {
                updateFontSizeForTextLength()
            }
        }
    }
    
    @objc public func focus() {
        becomeFirstResponder()
    }
    
    @objc public func blur() {
        resignFirstResponder()
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        if let placeholder = placeholderLabel {
            placeholder.preferredMaxLayoutWidth = bounds.width - textContainerInset.left - textContainerInset.right - (textContainer.lineFragmentPadding * 2)
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        animatingLayers.forEach { $0.removeFromSuperlayer() }
        animatingLayers.removeAll()
    }
}
