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
    
    @objc public var isDictating: Bool = false
    @objc public var animationDuration: Double = 300
    
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
    private var animatingLabels: [UILabel] = []
    private var hiddenRanges: [NSRange] = []
    private var isInternalUpdate: Bool = false
    
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
        textContainer.widthTracksTextView = false  // We'll manage this manually
        
        // Insets
        textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Initial setup
        currentFontSize = baseFontSize
        originalTextColor = textColor ?? .label
        
        updateFont()
        configureForMultiline()
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
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // CRITICAL: Set text container width for proper text wrapping
        let containerWidth = bounds.width - textContainerInset.left - textContainerInset.right
        if containerWidth > 0 && textContainer.size.width != containerWidth {
            textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
        }
        
        // Update placeholder width
        placeholderLabel?.preferredMaxLayoutWidth = containerWidth
        
        // Notify about content size changes for auto-grow
        notifyContentSizeIfNeeded()
    }
    
    private func notifyContentSizeIfNeeded() {
        guard multiline && autoGrow else { return }
        guard bounds.width > 0 else { return }
        
        // Calculate the height needed for current content
        let fittingSize = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        var newHeight = fittingSize.height
        
        // Apply constraints
        newHeight = max(newHeight, minHeight)
        if maxHeight > 0 {
            newHeight = min(newHeight, maxHeight)
            isScrollEnabled = fittingSize.height > maxHeight
        }
        
        // Only notify if changed
        if abs(newHeight - lastContentHeight) > 0.5 {
            lastContentHeight = newHeight
            
            onContentSizeChange?([
                "contentSize": [
                    "width": bounds.width,
                    "height": newHeight
                ]
            ])
        }
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
        
        let cursor = selectedRange
        attributedText = mutableAttr
        selectedRange = cursor
        
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
        
        let cursor = selectedRange
        attributedText = mutableAttr
        selectedRange = cursor
        
        isInternalUpdate = false
    }
    
    private func createAndAnimateLabel(word: String, range: NSRange, delay: Double) {
        layoutIfNeeded()
        
        // Get word position
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
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
        label.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        
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
    
    // MARK: - UITextViewDelegate
    
    public func textViewDidChange(_ textView: UITextView) {
        guard !isInternalUpdate else { return }
        
        let newText = textView.text ?? ""
        
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
        
        text = newText
        previousText = newText
        previousWordCount = newText.split(separator: " ").count
        
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
