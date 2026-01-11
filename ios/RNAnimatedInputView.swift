import UIKit

/// A custom UITextView that supports dynamic font sizing and word-by-word dictation animations
@objc public class RNAnimatedInputView: UITextView, UITextViewDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Callbacks
    
    @objc public var onChangeText: RCTDirectEventBlock?
    @objc public var onInputFocus: RCTDirectEventBlock?
    @objc public var onInputBlur: RCTDirectEventBlock?
    @objc public var onInputSubmit: RCTDirectEventBlock?
    @objc public var onContentSizeChange: RCTDirectEventBlock?
    @objc public var onDictationTap: RCTDirectEventBlock?
    
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
            placeholderLabel?.textAlignment = _textAlign
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
            
            if dynamicSizing { 
                updateFontSizeForTextLength() 
            }
            
            // Schedule restoration after font rules change to prevent text clipping
            // This handles the case when rules change during keyboard blur
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.performTextContainerRestore()
            }
        }
    }
    
    @objc public var baseFontSize: CGFloat = 32 {
        didSet {
            currentFontSize = baseFontSize
            updateFont()
            
            // Schedule restoration after font size change to prevent text clipping
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.performTextContainerRestore()
            }
        }
    }
    
    @objc public var minFontSize: CGFloat = 14
    
    // MARK: - Dictation Animation
    
    @objc public var isDictating: Bool = false {
        didSet {
            // Save cursor position and text when dictation starts so we can insert new words at cursor
            if isDictating && !oldValue {
                dictationInsertPosition = selectedRange.location
                textBeforeDictation = text
            }
            
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
    
    @objc public var inputTextColor: UIColor? {
        didSet {
            if let color = inputTextColor {
                originalTextColor = color
                textColor = color
                // Update any existing text with the new color
                if !text.isEmpty {
                    isInternalUpdate = true
                    let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
                    mutableAttr.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutableAttr.length))
                    let savedCursorPosition = selectedRange
                    attributedText = mutableAttr
                    selectedRange = savedCursorPosition
                    isInternalUpdate = false
                }
            }
        }
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
    private var dictationInsertPosition: Int = 0  // Cursor position when dictation started
    private var textBeforeDictation: String = ""  // Text content before dictation started (baseline for comparison)
    
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
        
        // CRITICAL: Disable automatic font scaling from accessibility settings.
        // This ensures the font sizes passed via baseFontSize and fontSizeRules
        // are used literally, regardless of the user's accessibility font settings.
        adjustsFontForContentSizeCategory = false
        
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
        
        // NOTE: We intentionally do NOT add a custom tap gesture recognizer here.
        // UITextView has built-in tap handling for focus. Adding a custom gesture
        // with shouldRecognizeSimultaneouslyWith:true causes a conflict where both
        // fire simultaneously, resulting in immediate focus followed by blur.
        
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
    
    // MARK: - Touch Handling
    
    /// Handle tap anywhere in the view to ensure focus works on the entire area
    @objc private func handleTapAnywhere(_ gesture: UITapGestureRecognizer) {
        if !isFirstResponder {
            becomeFirstResponder()
        }
        
        // Position cursor at tap location
        let point = gesture.location(in: self)
        if let position = closestPosition(to: point) {
            selectedTextRange = textRange(from: position, to: position)
            
            // If user taps during dictation, update the insert position
            // so new dictated words go to the new cursor location
            if isDictating {
                let newCursorPos = offset(from: beginningOfDocument, to: position)
                
                // Update the baseline and insert position for the new cursor location
                dictationInsertPosition = newCursorPos
                textBeforeDictation = text
                
                // Notify React Native that user tapped during dictation
                // This allows the parent component to stop dictation if desired
                onDictationTap?([:])
            }
        }
    }
    
    /// Allow our tap gesture to work alongside UITextView's built-in gestures
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Reapply target height if React Native reset it
        if multiline && autoGrow && targetAutoGrowHeight > 0 && abs(frame.height - targetAutoGrowHeight) > 0.5 {
            var newFrame = frame
            newFrame.size.height = targetAutoGrowHeight
            frame = newFrame
            
            // Also update superview's frame so touches work correctly
            if let reactSuperview = superview, abs(reactSuperview.frame.height - targetAutoGrowHeight) > 0.5 {
                var superFrame = reactSuperview.frame
                superFrame.size.height = targetAutoGrowHeight
                reactSuperview.frame = superFrame
            }
        }
        
        // CRITICAL: Set text container width for proper text wrapping
        let containerWidth = bounds.width - textContainerInset.left - textContainerInset.right
        
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
            
            // Directly update frame height for both self and superview
            // This ensures touches work correctly while React Native catches up
            if abs(frame.height - newHeight) > 0.5 {
                var newFrame = frame
                newFrame.size.height = newHeight
                frame = newFrame
                
                // Also update the React Native container's frame so touches work
                if let reactSuperview = superview {
                    var superFrame = reactSuperview.frame
                    superFrame.size.height = newHeight
                    reactSuperview.frame = superFrame
                    reactSuperview.setNeedsLayout()
                }
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
            } completion: { [weak self] _ in
                // Restore text container settings after font animation completes
                // Font changes can invalidate layout and cause text clipping
                self?.performTextContainerRestore()
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
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        // Disable automatic font scaling from accessibility settings
        label.adjustsFontForContentSizeCategory = false
        
        insertSubview(label, at: 0)  // Insert behind text layer instead of on top
        
        // Use frameLayoutGuide for constraints - UITextView inherits from UIScrollView,
        // and its leadingAnchor/trailingAnchor reference content size, not the visible frame.
        // frameLayoutGuide ensures the placeholder fills the visible width correctly.
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: frameLayoutGuide.topAnchor, constant: textContainerInset.top),
            label.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor, constant: textContainerInset.left),
            label.trailingAnchor.constraint(equalTo: frameLayoutGuide.trailingAnchor, constant: -textContainerInset.right)
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
            // Find which words are new by comparing arrays
            // Since we now insert at cursor position, we need to find the actual new words
            let newWordsSet = Set(newWords)
            var oldWordsCopy = oldWords
            var newWordIndices: [Int] = []
            
            // Find indices of new words by comparing with old words
            for (index, word) in newWords.enumerated() {
                if let oldIndex = oldWordsCopy.firstIndex(of: word) {
                    oldWordsCopy.remove(at: oldIndex)
                } else {
                    newWordIndices.append(index)
                }
            }
            
            for (delayIndex, wordIndex) in newWordIndices.enumerated() {
                let word = newWords[wordIndex]
                if let range = rangeOfWord(at: wordIndex, in: newText) {
                    animateNewWord(word: word, range: range, delay: Double(delayIndex) * 0.05)
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
        
        // Preserve cursor position - setting attributedText resets it
        let savedCursorPosition = selectedRange
        attributedText = mutableAttr
        selectedRange = savedCursorPosition
        
        isInternalUpdate = false
    }
    
    private func showWordAt(range: NSRange) {
        isInternalUpdate = true
        
        let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
        guard range.location + range.length <= mutableAttr.length else {
            isInternalUpdate = false
            return
        }
        
        // Use originalTextColor because textColor might be affected by hideWordAt's clear color
        mutableAttr.addAttribute(.foregroundColor, value: originalTextColor, range: range)
        hiddenRanges.removeAll { $0 == range }
        
        // Preserve cursor position - setting attributedText resets it
        let savedCursorPosition = selectedRange
        attributedText = mutableAttr
        selectedRange = savedCursorPosition
        
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
        // Use originalTextColor because textColor might be affected by hideWordAt's clear color
        label.textColor = originalTextColor
        label.textAlignment = .left  // Label contains just the word, left align it
        label.frame = rect
        label.layer.zPosition = 1000  // Ensure label is above text layer
        label.backgroundColor = .clear
        label.isUserInteractionEnabled = false  // Allow touches to pass through
        // Disable automatic font scaling from accessibility settings
        label.adjustsFontForContentSizeCategory = false
        
        // Initial state: invisible and scaled up
        label.alpha = 0
        label.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        
        addSubview(label)
        bringSubviewToFront(label)
        animatingLabels.append(label)
        
        // Animate
        UIView.animate(
            withDuration: animationDuration / 1000.0,
            delay: delay,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3,
            options: [.allowUserInteraction],
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
        // Remove any in-flight animation overlays and restore hidden text
        completeAllAnimationsImmediately(restoreHiddenText: true)
        
        previousText = text ?? ""
        previousWordCount = previousText.split(separator: " ").count
    }
    
    /// Immediately complete all in-flight animations by removing overlay labels.
    /// - Parameter restoreHiddenText: If true, restore hidden text to visible. 
    ///   Set to false when new attributedText will be set immediately after.
    private func completeAllAnimationsImmediately(restoreHiddenText: Bool) {
        // Cancel all animations and remove labels immediately
        for label in animatingLabels {
            label.layer.removeAllAnimations()
            label.removeFromSuperview()
        }
        animatingLabels.removeAll()
        
        // Restore hidden text if requested (needed when dictation ends)
        if restoreHiddenText && !hiddenRanges.isEmpty {
            isInternalUpdate = true
            let mutableAttr = NSMutableAttributedString(attributedString: attributedText)
            for range in hiddenRanges {
                if range.location + range.length <= mutableAttr.length {
                    mutableAttr.addAttribute(.foregroundColor, value: originalTextColor, range: range)
                }
            }
            // Preserve cursor position - setting attributedText resets it
            let savedCursorPosition = selectedRange
            attributedText = mutableAttr
            selectedRange = savedCursorPosition
            isInternalUpdate = false
        }
        
        hiddenRanges.removeAll()
    }
    
    // MARK: - Keyboard Selection Handling
    
    /// Override the internal keyboardInputChangedSelection: method to prevent message forwarding.
    /// When using keyboard controller libraries (like react-native-keyboard-controller) that use
    /// composite delegates, the default ObjC message forwarding for this method causes infinite
    /// recursion in KCTextInputCompositeDelegate.forwardingTarget(for:).
    /// By implementing this method directly, we prevent the message from being forwarded.
    @objc public func keyboardInputChangedSelection(_ sender: Any?) {
        // No-op - just handle the message to prevent forwarding
    }
    
    /// Override the internal keyboardInputChanged: method to prevent message forwarding.
    /// This is a different method from keyboardInputChangedSelection: and also causes
    /// infinite recursion when forwarded to composite delegates.
    @objc public func keyboardInputChanged(_ sender: Any?) {
        // No-op - just handle the message to prevent forwarding
    }
    
    // MARK: - UITextViewDelegate
    
    public func textViewDidChange(_ textView: UITextView) {
        guard !isInternalUpdate else { return }
        
        let newText = textView.text ?? ""
        
        // Force layout recalculation
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
        // iOS may internally modify text container properties when keyboard appears
        // Force re-establish our settings to prevent text clipping
        restoreTextContainerSettings()
        
        onInputFocus?([:])
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        // iOS may internally modify text container properties when keyboard disappears
        // Force re-establish our settings to prevent text clipping
        restoreTextContainerSettings()
        
        onInputBlur?([:])
    }
    
    /// Restore text container settings that iOS may have modified during focus/blur
    /// This prevents text below the first line from being clipped
    private func restoreTextContainerSettings() {
        performTextContainerRestore()
        
        // Schedule a delayed restore to handle any asynchronous changes iOS makes
        // after keyboard animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performTextContainerRestore()
        }
    }
    
    /// Performs the actual text container restoration
    private func performTextContainerRestore() {
        // Re-establish unlimited height for proper text wrapping
        let containerWidth = bounds.width > 0 
            ? bounds.width - textContainerInset.left - textContainerInset.right 
            : (cachedContainerWidth > 0 ? cachedContainerWidth : 338)
        
        // Force disable tracking - iOS may have re-enabled these
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        
        // Restore multiline settings - iOS may have modified these
        if multiline {
            textContainer.maximumNumberOfLines = 0  // Unlimited lines
        }
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.lineFragmentPadding = 0
        
        // Set container size with unlimited height
        textContainer.size = CGSize(width: containerWidth, height: .greatestFiniteMagnitude)
        
        // Invalidate and re-ensure layout to recalculate text positions
        let textLength = (text ?? "").count
        if textLength > 0 {
            layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textLength), actualCharacterRange: nil)
            layoutManager.ensureLayout(for: textContainer)
        }
        
        // Ensure scroll settings are maintained for auto-grow mode
        if multiline && autoGrow {
            isScrollEnabled = false
        }
        
        // Force layout update
        setNeedsLayout()
        layoutIfNeeded()
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
        var newText = value ?? ""
        guard text != newText else { return }
        
        // During dictation, insert new words at the saved cursor position instead of the end
        // Compare against textBeforeDictation (baseline) to handle RN state sync issues
        if isDictating && dictationInsertPosition > 0 && dictationInsertPosition <= textBeforeDictation.count {
            // Detect what was appended by comparing incoming text against the baseline
            if newText.hasPrefix(textBeforeDictation) {
                var dictatedContent = String(newText.dropFirst(textBeforeDictation.count))
                if !dictatedContent.isEmpty {
                    // Build corrected text: [text before cursor] + [dictated content] + [text after cursor]
                    let beforeCursor = String(textBeforeDictation.prefix(dictationInsertPosition))
                    let afterCursor = String(textBeforeDictation.dropFirst(dictationInsertPosition))
                    
                    // Fix spacing: dictatedContent has leading space (for appending), but we're inserting in middle
                    // 1. Remove leading space from dictatedContent if beforeCursor ends with space
                    if beforeCursor.hasSuffix(" ") && dictatedContent.hasPrefix(" ") {
                        dictatedContent = String(dictatedContent.dropFirst())
                    }
                    // 2. Add trailing space if afterCursor doesn't start with space/punctuation and dictatedContent doesn't end with space
                    if !afterCursor.isEmpty && !dictatedContent.isEmpty {
                        let firstAfterChar = afterCursor.first!
                        let isAfterWhitespaceOrPunctuation = firstAfterChar.isWhitespace || firstAfterChar.isPunctuation
                        let dictatedEndsWithSpace = dictatedContent.hasSuffix(" ")
                        if !isAfterWhitespaceOrPunctuation && !dictatedEndsWithSpace {
                            dictatedContent += " "
                        }
                    }
                    
                    let correctedText = beforeCursor + dictatedContent + afterCursor
                    
                    newText = correctedText
                }
            }
        }
        
        // Complete any in-flight animations before setting new text to prevent overlapping
        if isDictating && !animatingLabels.isEmpty {
            completeAllAnimationsImmediately(restoreHiddenText: false)
        }
        
        // CRITICAL: Ensure text container has unlimited height before setting text
        if textContainer.size.height < 10000 {
            let containerWidth = bounds.width > 0 ? bounds.width - textContainerInset.left - textContainerInset.right : textContainer.size.width
            textContainer.size = CGSize(width: containerWidth > 0 ? containerWidth : 338, height: .greatestFiniteMagnitude)
        }
        
        // Update text with correct color - use attributedText to ensure originalTextColor is used
        // (plain text = would use textColor which might be transparent from hideWordAt)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = _textAlign
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: originalTextColor,
            .font: self.font ?? UIFont.systemFont(ofSize: baseFontSize),
            .paragraphStyle: paragraphStyle
        ]
        let attrString = NSAttributedString(string: newText, attributes: attributes)
        self.attributedText = attrString
        
        // Position cursor after the inserted dictated content
        if isDictating {
            // Cursor should be at: dictationInsertPosition + length of dictated content
            let dictatedLength = max(0, text.count - textBeforeDictation.count)
            let cursorPos = min(dictationInsertPosition + dictatedLength, text.count)
            
            selectedRange = NSRange(location: cursorPos, length: 0)
        }
        
        // Handle animation (compares previousText with new text, then hides new words)
        if isDictating {
            handleTextChangeForAnimation(newText: newText)
        }
        
        // Update tracking state AFTER animation handling
        previousText = newText
        previousWordCount = newText.split(separator: " ").count
        
        // Force layout after setting text
        layoutManager.ensureLayout(for: textContainer)
        
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
        NotificationCenter.default.removeObserver(self)
        animatingLabels.forEach { $0.removeFromSuperview() }
    }
}
