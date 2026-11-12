import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isConfigured {
                WebContainer()
            } else {
                ConnectView(isFirstRun: true)
            }
        }
    }
}
