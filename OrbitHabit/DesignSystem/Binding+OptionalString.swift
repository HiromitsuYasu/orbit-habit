import SwiftUI

extension Binding where Value == String? {
    /// Optional 文字列があるときだけ true。Alert の isPresented 用。
    var isPresented: Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } }
        )
    }
}
