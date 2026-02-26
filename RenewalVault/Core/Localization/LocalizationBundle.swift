import Foundation
import ObjectiveC.runtime

private var bundleKey: UInt8 = 0

private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard
            let path = objc_getAssociatedObject(self, &bundleKey) as? String,
            let bundle = Bundle(path: path)
        else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

enum LocalizationBundle {
    private static var didSwap = false

    static func setLanguage(code: String) {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return }
        if !didSwap {
            object_setClass(Bundle.main, LocalizedBundle.self)
            didSwap = true
        }
        objc_setAssociatedObject(Bundle.main, &bundleKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
