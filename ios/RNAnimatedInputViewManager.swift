import UIKit

@objc(RNAnimatedInputViewManager)
class RNAnimatedInputViewManager: RCTViewManager {
    
    override func view() -> UIView! {
        return RNAnimatedInputView()
    }
    
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - Methods
    
    @objc func setValue(_ node: NSNumber, value: String?) {
        DispatchQueue.main.async {
            guard let view = self.bridge?.uiManager.view(forReactTag: node) as? RNAnimatedInputView else {
                return
            }
            view.setValue(value)
        }
    }
    
    @objc func focus(_ node: NSNumber) {
        DispatchQueue.main.async {
            guard let view = self.bridge?.uiManager.view(forReactTag: node) as? RNAnimatedInputView else {
                return
            }
            view.focus()
        }
    }
    
    @objc func blur(_ node: NSNumber) {
        DispatchQueue.main.async {
            guard let view = self.bridge?.uiManager.view(forReactTag: node) as? RNAnimatedInputView else {
                return
            }
            view.blur()
        }
    }
}
