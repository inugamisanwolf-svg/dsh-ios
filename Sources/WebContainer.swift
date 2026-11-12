import SwiftUI

struct WebContainer: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebView(url: model.launchURL, ticket: model.loadTicket, model: model)
                .ignoresSafeArea(.container, edges: .bottom)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(9)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .opacity(0.4)
            .padding(.top, 4)
            .padding(.trailing, 6)

            if let message = model.lastError {
                errorCard(message)
            }
        }
        .tint(.cyan)
        .sheet(isPresented: $showSettings) {
            ConnectView(isFirstRun: false)
        }
        .sheet(isPresented: $model.needsToken) {
            ConnectView(isFirstRun: false)
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
            Text("ホストに繋がらない")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("再試行") { model.reload() }
                    .buttonStyle(.borderedProminent)
                Button("接続設定") { showSettings = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(22)
        .frame(maxWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
    }
}
