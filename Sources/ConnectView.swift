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
                    Text("初回だけ、起動ログに出る `?token=...` 付き URL をそのまま貼る。トークンは Host 側で HttpOnly Cookie に交換され、以後30日は URL だけで繋がる。Cookie は authority ごとなので、別の IP / 名前で繋ぐ時はその authority でもう一度トークンを入れる。")
                }

                if !model.savedHosts.isEmpty {
                    Section("保存済み（タップで切替）") {
                        ForEach(model.savedHosts, id: \.self) { host in
                            HStack(spacing: 8) {
                                Button {
                                    model.select(host)
                                    if !isFirstRun { dismiss() }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(host)
                                            .font(.system(.footnote, design: .monospaced))
                                            .foregroundStyle(.primary)
                                        if host == model.serverURL {
                                            Text("使用中")
                                                .font(.caption2)
                                                .foregroundStyle(.cyan)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                Button {
                                    model.remove(host)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
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
                } footer: {
                    Text("同じ Wi-Fi なら LAN の IP、外からなら Tailscale の IP（100.x.x.x）を選ぶ。PC 側は `dsh-serve.ps1 -Target both` で両方同時に立てられる。")
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
        model.remember(parsed.base)
        model.reload()
        if !isFirstRun { dismiss() }
    }
}
