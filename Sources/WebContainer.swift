import SwiftUI

struct WebContainer: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false
    @State private var showDiagnostics = false

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
            } else if !model.diagnostics.isEmpty {
                diagnosticsChip
            }
        }
        .tint(.cyan)
        .sheet(isPresented: $showSettings) {
            ConnectView(isFirstRun: false)
        }
        .sheet(isPresented: $model.needsToken) {
            ConnectView(isFirstRun: false)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsSheet()
        }
    }

    private var diagnosticsChip: some View {
        VStack {
            Spacer()
            Button {
                showDiagnostics = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ladybug.fill")
                    Text("診断 \(model.diagnostics.count) 件")
                        .font(.caption2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.bottom, 24)
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

/// Full diagnostics log, copyable so it can be pasted into a chat.
struct DiagnosticsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(model.serverURL)\nビルド \(ConnectView.buildLabel)")
                        .font(.system(.footnote, design: .monospaced))
                }
                Section("イベント（新しい順）") {
                    if model.diagnostics.isEmpty {
                        Text("まだ何もありません").foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.diagnostics.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("診断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = (["\(model.serverURL) build \(ConnectView.buildLabel)"] + model.diagnostics)
                                .joined(separator: "\n")
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        Button(role: .destructive) {
                            model.clearDiagnostics()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
