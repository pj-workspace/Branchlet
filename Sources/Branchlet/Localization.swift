import Foundation

func localized(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}
