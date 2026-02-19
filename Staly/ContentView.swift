//
//  ContentView.swift
//  CheckInn
//
//  Created by 西村光篤 on 2026/02/18.
//

import SwiftUI

private enum SettingsPalette {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.11)
    static let backgroundTop = Color(red: 0.02, green: 0.36, blue: 0.42)
    static let backgroundBottom = Color(red: 0.10, green: 0.18, blue: 0.45)
    static let card = Color.white.opacity(0.07)
    static let cardBorder = Color.white.opacity(0.14)
    static let chip = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let accentBlue = Color(red: 0.28, green: 0.56, blue: 1.00)
    static let accentCyan = Color(red: 0.30, green: 0.90, blue: 0.86)
    static let accentPurple = Color(red: 0.38, green: 0.30, blue: 0.93)
    static let accentPurpleSoft = Color(red: 0.50, green: 0.44, blue: 0.98)
}

struct ContentView: View {
    var body: some View {
        AuthGateView {
            StaysRootView()
        }
    }
}

struct SettingsView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel
    @State private var stays: [Stay] = []
    @State private var statsError: String?
    @State private var showingSettingsSheet = false
    @State private var profileMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 14) {
                        if let user = session.user {
                            profileHeader(user)
                            actionChips
                            lifeStatusTabs
                            lifeStatusCard

                            if let profileMessage {
                                statusCard(profileMessage, color: SettingsPalette.accentCyan.opacity(0.9))
                            }

                            if let statsError {
                                statusCard(statsError, color: Color.red.opacity(0.86))
                            }

                            if let sessionError = session.errorMessage {
                                statusCard(sessionError, color: Color.red.opacity(0.85))
                            }
                        } else {
                            emptyCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("CheckInn")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(.white)
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsDetailSheet(profileMessage: $profileMessage)
        }
        .onChange(of: session.user?.id) { _, _ in
            profileMessage = nil
        }
        .task(id: session.user?.id) {
            await reloadStats()
        }
    }

    private var background: some View {
        ZStack(alignment: .top) {
            SettingsPalette.background
                .ignoresSafeArea()

            mapStrip
                .frame(height: 190)
                .ignoresSafeArea(edges: .top)

            LinearGradient(
                colors: [Color.black.opacity(0.04), Color.black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var mapStrip: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [SettingsPalette.backgroundTop, SettingsPalette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 80, style: .continuous)
                        .stroke(Color.white.opacity(index.isMultiple(of: 2) ? 0.16 : 0.10), lineWidth: index.isMultiple(of: 2) ? 1.5 : 1)
                        .frame(width: proxy.size.width * 1.2, height: 60 + CGFloat(index * 8))
                        .offset(x: index.isMultiple(of: 2) ? -36 : 42, y: CGFloat(index * 14) - 40)
                }
            }
        }
    }

    private func profileHeader(_ user: AuthUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName ?? t("名前", "Name"))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(SettingsPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(t("滞在ログ", "Stay Log"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SettingsPalette.textSecondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .settingsPanel()
    }

    private var actionChips: some View {
        HStack(spacing: 10) {
            Button {
                profileMessage = t("CheckInn Friend は準備中です", "CheckInn Friend is coming soon")
            } label: {
                chipLabel(icon: "figure.2", title: t("CheckInn フレンド", "CheckInn Friend"))
            }
            .buttonStyle(.plain)

            Button {
                showingSettingsSheet = true
            } label: {
                chipLabel(icon: "gearshape", title: t("設定", "Settings"))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chipLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
            Text(title)
                .font(.headline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SettingsPalette.chip, in: Capsule())
        .overlay(
            Capsule().stroke(SettingsPalette.cardBorder, lineWidth: 1)
        )
    }

    private var lifeStatusTabs: some View {
        HStack(spacing: 10) {
            Text(t("ライフステータス", "Life Status"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("\(Calendar.current.component(.year, from: Date()))")
                .font(.headline.weight(.medium))
                .foregroundStyle(SettingsPalette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lifeStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(t("CheckInn ライフステータス", "CheckInn Life Status"))
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()
                ShareLink(item: shareSummary) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                metricItem(
                    title: t("滞在", "Stays"),
                    value: "\(stayCount)",
                    subValue: yearFractionText
                )
                metricItem(
                    title: t("日数", "Days"),
                    value: daysText,
                    subValue: yearFractionText
                )
                metricItem(
                    title: t("都市", "Cities"),
                    value: "\(cityCount)",
                    subValue: t("訪問", "visited")
                )
                metricItem(
                    title: t("ホテル", "Hotels"),
                    value: "\(hotelCount)",
                    subValue: t("保存", "saved")
                )
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [SettingsPalette.accentPurple, SettingsPalette.accentPurpleSoft],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func metricItem(title: String, value: String, subValue: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.72))
            Text(value)
                .font(.system(size: 47, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(subValue)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text(t("ログインしていません", "Not logged in"))
                .font(.headline)
                .foregroundStyle(SettingsPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .settingsPanel()
    }

    private func statusCard(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stayCount: Int {
        stays.count
    }

    private var totalDays: Int {
        stays.reduce(0) { partialResult, stay in
            partialResult + dayCount(for: stay)
        }
    }

    private var cityCount: Int {
        Set(
            stays.compactMap { stay -> String? in
                let value = stay.city?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let value, !value.isEmpty else { return nil }
                return value.lowercased()
            }
        ).count
    }

    private var hotelCount: Int {
        Set(
            stays.map { stay in
                stay.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .filter { !$0.isEmpty }
        ).count
    }

    private var daysText: String {
        if appLanguage.isJapanese {
            return "\(totalDays)日"
        }
        return "\(totalDays) days"
    }

    private var yearFractionText: String {
        let value = String(format: "%.2f", Double(totalDays) / 365.0)
        return appLanguage.isJapanese ? "\(value)年" : "\(value) years"
    }

    private var shareSummary: String {
        [
            t("CheckInn ライフステータス", "CheckInn Life Status"),
            "\(t("滞在", "Stays")): \(stayCount)",
            "\(t("日数", "Days")): \(daysText)",
            "\(t("都市", "Cities")): \(cityCount)",
            "\(t("ホテル", "Hotels")): \(hotelCount)"
        ].joined(separator: "\n")
    }

    private func dayCount(for stay: Stay) -> Int {
        let start = Calendar.current.startOfDay(for: stay.checkIn)
        guard let checkOut = stay.checkOut else {
            return 1
        }
        let end = Calendar.current.startOfDay(for: checkOut)
        let distance = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, distance + 1)
    }

    @MainActor
    private func reloadStats() async {
        guard let userId = session.user?.id else {
            stays = []
            statsError = nil
            return
        }

        do {
            stays = try await container.stays.listStays(for: userId)
            statsError = nil
        } catch {
            statsError = error.localizedDescription
        }
    }

    private func t(_ ja: String, _ en: String) -> String {
        appLanguage.isJapanese ? ja : en
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }
}

private struct SettingsDetailSheet: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionViewModel

    @Binding var profileMessage: String?
    @State private var displayNameDraft = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [SettingsPalette.background, Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        nameCard
                        languageCard
                        accountCard
                        signOutCard

                        if let sessionError = session.errorMessage {
                            Text(sessionError)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(t("設定", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("閉じる", "Close")) {
                        dismiss()
                    }
                }
            }
        }
        .tint(SettingsPalette.accentCyan)
        .onAppear {
            displayNameDraft = session.user?.displayName ?? ""
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("表示名", "Name"))
                .font(.headline)
                .foregroundStyle(.white)

            TextField(t("表示名", "Display name"), text: $displayNameDraft)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .foregroundStyle(.white)

            Button(t("表示名を保存", "Save name")) {
                Task {
                    await session.updateDisplayName(normalizedDisplayName)
                    if session.errorMessage == nil {
                        profileMessage = t("表示名を保存しました。", "Display name saved.")
                    }
                }
            }
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                LinearGradient(
                    colors: [SettingsPalette.accentBlue, SettingsPalette.accentPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundStyle(.white)
            .disabled(session.isLoading || normalizedDisplayName == session.user?.displayName)
        }
        .settingsPanel()
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("言語", "Language"))
                .font(.headline)
                .foregroundStyle(SettingsPalette.textPrimary)

            Picker(t("アプリの言語", "App language"), selection: $appLanguageRaw) {
                Text("System").tag(AppLanguage.system.rawValue)
                Text("日本語").tag(AppLanguage.japanese.rawValue)
                Text("English").tag(AppLanguage.english.rawValue)
            }
            .pickerStyle(.segmented)
        }
        .settingsPanel()
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("アカウント", "Account"))
                .font(.headline)
                .foregroundStyle(SettingsPalette.textPrimary)

            accountRow(t("表示ID", "Public ID"), session.publicUserID ?? "-")
            accountRow(t("内部ID", "Internal ID"), session.user?.id ?? "-")
            if let email = session.user?.email {
                accountRow(t("メール", "Email"), email)
            }
        }
        .settingsPanel()
    }

    private var signOutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("セキュリティ", "Security"))
                .font(.headline)
                .foregroundStyle(SettingsPalette.textPrimary)

            Button(role: .destructive) {
                Task {
                    await session.signOut()
                    dismiss()
                }
            } label: {
                Text(t("サインアウト", "Sign out"))
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .settingsPanel()
    }

    private func accountRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SettingsPalette.textSecondary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundStyle(SettingsPalette.textPrimary)
                .lineLimit(1)
        }
    }

    private var normalizedDisplayName: String? {
        let value = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func t(_ ja: String, _ en: String) -> String {
        appLanguage.isJapanese ? ja : en
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }
}

private extension View {
    func settingsPanel() -> some View {
        self
            .padding(14)
            .background(SettingsPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SettingsPalette.cardBorder, lineWidth: 1)
            )
    }
}

#Preview {
    let container = AppContainer()
    let session = SessionViewModel(container: container)
    ContentView()
        .environmentObject(container)
        .environmentObject(session)
}
