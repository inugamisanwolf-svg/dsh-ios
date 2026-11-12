import SwiftUI
import UIKit

/// Host configuration. Doubles as the first-run screen and the settings sheet.
struct ConnectView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var isFirstRun: Bool = false

    @State private var input: String = ""
    @State private var parseError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.0.200:59714", text: $input)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.URL)
                        .font(.system(.body, design: .monospaced))
                    Button {
                        if let text = UIPasteboard.general.string { input = text }
                    } label: {
                        Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("DSH ホスト")
                } footer: {
                    Text("初回だけ、起動ログに出る `?token=...` 付き URL をそのまま貼る。トークンは Host 側で HttpOnly Cookie に交換され、以後30日は URL だけで繋がる。")
                }

                Section {
                    Text("同じ Wi-Fi 上の PC で `dsh --profile web --host <PCのIP> --port 59714` が動いている前提。外から使うなら Tailscale 側の IP を入れる。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let parseError {
                    Section {
                        Text(parseError).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        connect()
                    } label: {
                        Text("接続").frame(maxWidth: .infinity)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !isFirstRun {
                        Button("保存済みホストを削除", role: .destructive) {
                            model.forgetServer()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isFirstRun ? "DSH に接続" : "接続設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstRun {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
            }
            .onAppear {
                if input.isEmpty { input = model.serverURL }
            }
        }
    }

    private func connect() {
        guard let parsed = AppModel.normalize(input) else {
            parseError = "URL を解釈できなかった。例: 192.168.0.200:59714/?token=XXXX"
            return
        }
        parseError = nil
        model.serverURL = parsed.base
        model.pendingToken = parsed.token
        model.reload()
        if !isFirstRun { dismiss() }
    }
}
