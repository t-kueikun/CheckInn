//
//  AuthAndStaysViews.swift
//  Staly
//
//  Created by Codex on 2026/02/18.
//

import SwiftUI
import AuthenticationServices

private enum FlightyPalette {
    static let backgroundTop = Color(red: 0.05, green: 0.09, blue: 0.19)
    static let backgroundBottom = Color(red: 0.02, green: 0.04, blue: 0.10)
    static let glass = Color.white.opacity(0.08)
    static let glassBorder = Color.white.opacity(0.16)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let accentBlue = Color(red: 0.30, green: 0.64, blue: 1.00)
    static let accentCyan = Color(red: 0.34, green: 0.96, blue: 0.92)
    static let accentPurple = Color(red: 0.44, green: 0.37, blue: 0.98)
    static let accentRed = Color(red: 0.87, green: 0.30, blue: 0.28)
}

struct AuthGateView<Content: View>: View {
    @EnvironmentObject private var session: SessionViewModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if session.user == nil {
                SignInView()
            } else {
                content()
            }
        }
        .animation(.snappy, value: session.user?.id)
    }
}

private struct SignInView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private enum Mode: CaseIterable, Identifiable {
        case signIn
        case signUp

        var id: Self { self }
    }

    @EnvironmentObject private var session: SessionViewModel

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    modeSwitcher
                    formCard

                    if let error = session.errorMessage {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(FlightyPalette.accentRed.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }

            if session.isLoading {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView(t("処理中...", "Working..."))
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .onChange(of: email) { _, _ in session.clearError() }
        .onChange(of: password) { _, _ in session.clearError() }
        .onChange(of: displayName) { _, _ in session.clearError() }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [FlightyPalette.backgroundTop, FlightyPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Ellipse()
                .fill(FlightyPalette.accentPurple.opacity(0.28))
                .frame(width: 380, height: 240)
                .blur(radius: 48)
                .offset(x: 160, y: -290)

            Ellipse()
                .fill(FlightyPalette.accentCyan.opacity(0.22))
                .frame(width: 320, height: 230)
                .blur(radius: 58)
                .offset(x: -150, y: 310)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHECKINN")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(t("旅の滞在履歴を、見やすく・早く・確実に。", "Track your stays with clarity and speed."))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FlightyPalette.textSecondary)

            HStack(spacing: 8) {
                featurePill(t("安定ID", "Stable ID"), colors: [FlightyPalette.accentBlue, FlightyPalette.accentPurple])
                featurePill(t("日英切替", "JP/EN"), colors: [FlightyPalette.accentCyan, FlightyPalette.accentBlue])
                featurePill(t("Apple対応", "Apple Sign-In"), colors: [FlightyPalette.accentPurple, FlightyPalette.accentCyan])
            }
        }
        .padding(16)
        .flightyGlass()
    }

    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { item in
                Button {
                    mode = item
                    session.clearError()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item == .signIn ? "person.fill.checkmark" : "person.crop.circle.badge.plus")
                            .font(.caption)
                        Text(modeLabel(item))
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(mode == item ? FlightyPalette.accentBlue : Color.white.opacity(0.08))
                    )
                    .foregroundStyle(mode == item ? .white : FlightyPalette.textSecondary)
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(modeTitle(mode))
                .font(.headline)
                .foregroundStyle(.white)
            Text(modeDescription(mode))
                .font(.footnote)
                .foregroundStyle(FlightyPalette.textSecondary)

            FlightyInputField(
                title: t("メールアドレス", "Email"),
                icon: "envelope.fill",
                text: $email,
                secure: false
            )

            FlightyInputField(
                title: t("パスワード（4文字以上）", "Password (4+ chars)"),
                icon: "lock.fill",
                text: $password,
                secure: true
            )

            if mode == .signUp {
                FlightyInputField(
                    title: t("表示名（任意）", "Display name (optional)"),
                    icon: "person.text.rectangle",
                    text: $displayName,
                    secure: false
                )

                registrationPreview
            }

            Button(modeAction(mode)) {
                Task { await submit() }
            }
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: canSubmit ? [FlightyPalette.accentBlue, FlightyPalette.accentPurple] : [Color.gray.opacity(0.4), Color.gray.opacity(0.28)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .foregroundStyle(.white)
            .disabled(!canSubmit || session.isLoading)

            SignInWithAppleButton(.continue) { request in
                session.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task { await session.handleAppleSignInCompletion(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(session.isLoading)

            Text(t("Appleログインで名前が空の場合は、設定で表示名を変更できます。", "If Apple returns no name, you can set it in Settings."))
                .font(.caption)
                .foregroundStyle(FlightyPalette.textSecondary)
        }
        .padding(16)
        .flightyGlass()
    }

    private var registrationPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("登録プレビュー", "Registration Preview"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlightyPalette.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayNamePreview)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(identifierPreview)
                    .font(.caption)
                    .foregroundStyle(FlightyPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func featurePill(_ text: String, colors: [Color]) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
    }

    private var displayNamePreview: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? t("表示名未設定", "No display name") : name
    }

    private var identifierPreview: String {
        let base = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if base.isEmpty {
            return t("IDは登録時に自動発行されます", "ID will be generated when registering")
        }
        let token = String(base.prefix(20))
        return "ID: \(token)"
    }

    private func modeLabel(_ mode: Mode) -> String {
        switch mode {
        case .signIn: return t("ログイン", "Sign In")
        case .signUp: return t("新規登録", "Sign Up")
        }
    }

    private func modeTitle(_ mode: Mode) -> String {
        switch mode {
        case .signIn: return t("既存アカウントでログイン", "Access your existing account")
        case .signUp: return t("新しいアカウントを作成", "Create a new account")
        }
    }

    private func modeDescription(_ mode: Mode) -> String {
        switch mode {
        case .signIn: return t("登録済みメールアドレスとパスワードを入力してください。", "Use your registered email and password.")
        case .signUp: return t("表示名は後から設定画面でいつでも変更できます。", "Display name can be changed later in Settings.")
        }
    }

    private func modeAction(_ mode: Mode) -> String {
        switch mode {
        case .signIn: return t("ログインする", "Sign In")
        case .signUp: return t("アカウント作成", "Create Account")
        }
    }

    private func t(_ ja: String, _ en: String) -> String {
        appLanguage.isJapanese ? ja : en
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 4
    }

    @MainActor
    private func submit() async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if mode == .signUp {
            await session.signUp(
                email: normalizedEmail,
                password: password,
                displayName: normalizedName.isEmpty ? nil : normalizedName
            )
        } else {
            await session.signIn(email: normalizedEmail, password: password)
        }
    }
}

private struct FlightyInputField: View {
    let title: String
    let icon: String
    @Binding var text: String
    let secure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlightyPalette.textSecondary)

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(FlightyPalette.textSecondary)
                Group {
                    if secure {
                        SecureField(title, text: $text)
                    } else {
                        TextField(title, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .foregroundStyle(FlightyPalette.textPrimary)
        }
    }
}

struct StaysRootView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private enum EditorMode: Identifiable {
        case create
        case edit(Stay)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let stay): return "edit_\(stay.id)"
            }
        }

        var initialStay: Stay? {
            switch self {
            case .create: return nil
            case .edit(let stay): return stay
            }
        }
    }

    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var session: SessionViewModel

    @State private var stays: [Stay] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var editorMode: EditorMode?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 14) {
                        dashboardPanel

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(FlightyPalette.accentRed.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if filteredStays.isEmpty {
                            emptyView
                        } else {
                            ForEach(filteredStays) { stay in
                                StayFlightCard(
                                    stay: stay,
                                    formatter: dateFormatter,
                                    isJapanese: appLanguage.isJapanese,
                                    onEdit: { editorMode = .edit(stay) },
                                    onDelete: { Task { await deleteStay(stay) } }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(t("滞在", "Stays"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 18, weight: .semibold))
                            Text(t("アカウント", "Account"))
                                .font(.footnote.weight(.semibold))
                        }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .tint(.white)
                    .disabled(session.user == nil)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorMode = .create
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .padding(8)
                            .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .tint(.white)
                    .disabled(session.user == nil)
                }
            }
        }
        .task(id: session.user?.id) {
            await reloadStays()
        }
        .refreshable {
            await reloadStays()
        }
        .sheet(item: $editorMode) { mode in
            StayEditorView(initialStay: mode.initialStay) { savedStay in
                Task { await saveStay(savedStay) }
            }
            .presentationDetents([.large])
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [FlightyPalette.backgroundTop, FlightyPalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(FlightyPalette.accentBlue.opacity(0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 52)
                .offset(x: -120, y: -260)

            Circle()
                .fill(FlightyPalette.accentPurple.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 46)
                .offset(x: 150, y: 280)
        }
    }

    private var dashboardPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FlightyStatCard(title: t("合計", "Total"), value: "\(stays.count)", colors: [FlightyPalette.accentBlue, FlightyPalette.accentPurple])
                FlightyStatCard(title: t("次回", "Next"), value: nextCheckInText, colors: [FlightyPalette.accentCyan, FlightyPalette.accentBlue])
            }

            FlightySearchField(query: $query, placeholder: t("タイトル / 都市 / メモで検索", "Search title / city / note"))
        }
        .padding(14)
        .flightyGlass()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            Text(query.isEmpty ? t("滞在がまだありません", "No stays yet") : t("検索結果がありません", "No matches"))
                .font(.headline)
                .foregroundStyle(FlightyPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .flightyGlass()
    }

    private var filteredStays: [Stay] {
        let sorted = stays.sorted(by: { $0.checkIn > $1.checkIn })
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return sorted }

        return sorted.filter { stay in
            stay.title.localizedCaseInsensitiveContains(normalizedQuery) ||
            (stay.city?.localizedCaseInsensitiveContains(normalizedQuery) ?? false) ||
            (stay.note?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
        }
    }

    private var nextCheckInText: String {
        guard let next = stays.sorted(by: { $0.checkIn < $1.checkIn }).first else {
            return t("未登録", "None")
        }
        return dateFormatter.string(from: next.checkIn)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = appLanguage.locale
        return formatter
    }

    private func t(_ ja: String, _ en: String) -> String {
        appLanguage.isJapanese ? ja : en
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }

    @MainActor
    private func reloadStays() async {
        guard let userId = session.user?.id else {
            stays = []
            return
        }

        do {
            stays = try await container.stays.listStays(for: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveStay(_ stay: Stay) async {
        guard let userId = session.user?.id else { return }

        do {
            try await container.stays.upsertStay(stay, for: userId)
            await reloadStays()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteStay(_ stay: Stay) async {
        guard let userId = session.user?.id else { return }
        do {
            try await container.stays.deleteStay(id: stay.id, for: userId)
            await reloadStays()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct FlightySearchField: View {
    @Binding var query: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FlightyPalette.textSecondary)
            TextField(placeholder, text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .foregroundStyle(.white)
    }
}

private struct FlightyStatCard: View {
    let title: String
    let value: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StayFlightCard: View {
    let stay: Stay
    let formatter: DateFormatter
    let isJapanese: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stay.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    if let city = stay.city, !city.isEmpty {
                        Text(city)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                }

                Spacer()

                Menu {
                    Button(isJapanese ? "編集" : "Edit", action: onEdit)
                    Button(isJapanese ? "削除" : "Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.84))
                }
            }

            Text(dateRangeText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

            if let note = stay.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.14), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture(perform: onEdit)
    }

    private var dateRangeText: String {
        let start = formatter.string(from: stay.checkIn)
        guard let checkOut = stay.checkOut else { return start }
        return "\(start) - \(formatter.string(from: checkOut))"
    }
}

private struct StayEditorView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss

    let initialStay: Stay?
    let onSave: (Stay) -> Void

    @State private var title: String
    @State private var city: String
    @State private var checkIn: Date
    @State private var hasCheckOut: Bool
    @State private var checkOut: Date
    @State private var note: String
    @State private var selectedPreset: String? = nil

    init(initialStay: Stay?, onSave: @escaping (Stay) -> Void) {
        self.initialStay = initialStay
        self.onSave = onSave

        _title = State(initialValue: initialStay?.title ?? "")
        _city = State(initialValue: initialStay?.city ?? "")
        _checkIn = State(initialValue: initialStay?.checkIn ?? Date())
        _hasCheckOut = State(initialValue: initialStay?.checkOut != nil)
        _checkOut = State(initialValue: initialStay?.checkOut ?? Date())
        _note = State(initialValue: initialStay?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [FlightyPalette.backgroundTop, FlightyPalette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        headerCard
                        destinationCard
                        scheduleCard
                        noteCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 100)
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .navigationTitle(initialStay == nil ? t("新規滞在", "New Stay") : t("滞在を編集", "Edit Stay"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t("閉じる", "Close")) { dismiss() }
                }
            }
        }
        .tint(FlightyPalette.accentBlue)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("滞在情報を入力", "Enter stay details"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(t("必要な項目だけを入力してすぐ保存できます。", "Fill only required fields and save quickly."))
                .font(.footnote)
                .foregroundStyle(FlightyPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .flightyGlass()
    }

    private var destinationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("目的地情報", "Destination"))
                .font(.headline)
                .foregroundStyle(.white)

            FlightyInputField(
                title: t("タイトル", "Title"),
                icon: "text.cursor",
                text: $title,
                secure: false
            )

            FlightyInputField(
                title: t("都市（任意）", "City (optional)"),
                icon: "mappin.and.ellipse",
                text: $city,
                secure: false
            )

            Text(t("クイック入力", "Quick presets"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlightyPalette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(titlePresets, id: \.self) { preset in
                        Button(preset) {
                            selectedPreset = preset
                            title = preset
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedPreset == preset ? Color.black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (selectedPreset == preset ? FlightyPalette.accentCyan : Color.white.opacity(0.12)),
                            in: Capsule()
                        )
                    }
                }
            }
        }
        .padding(14)
        .flightyGlass()
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("日程", "Schedule"))
                .font(.headline)
                .foregroundStyle(.white)

            DatePicker(t("チェックイン", "Check-in"), selection: $checkIn, displayedComponents: .date)
                .colorScheme(.dark)

            Toggle(t("チェックアウト日を設定する（連泊の場合）", "Set check-out date (for multi-night stays)"), isOn: $hasCheckOut)
                .tint(FlightyPalette.accentBlue)

            if hasCheckOut {
                DatePicker(t("チェックアウト", "Check-out"), selection: $checkOut, in: checkIn..., displayedComponents: .date)
                    .colorScheme(.dark)

                HStack(spacing: 8) {
                    quickNightButton(days: 1)
                    quickNightButton(days: 3)
                    quickNightButton(days: 7)
                }

                Text("\(t("宿泊数", "Nights")): \(nightsCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
            } else {
                Text(t("チェックアウト日を入れない場合は「1日分の滞在」として保存されます。", "Without check-out date, this will be saved as a one-day stay."))
                    .font(.caption)
                    .foregroundStyle(FlightyPalette.textSecondary)
            }
        }
        .padding(14)
        .flightyGlass()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("メモ", "Note"))
                .font(.headline)
                .foregroundStyle(.white)

            ZStack(alignment: .topLeading) {
                TextField("", text: $note, axis: .vertical)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .foregroundStyle(.white)

                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(t("予定・住所・メモを書けます", "Write plans, address, or notes"))
                        .font(.footnote)
                        .foregroundStyle(FlightyPalette.textSecondary)
                        .padding(.top, 18)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(14)
        .flightyGlass()
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(t("キャンセル", "Cancel")) { dismiss() }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)

            Button(t("保存", "Save")) {
                save()
            }
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [FlightyPalette.accentBlue, FlightyPalette.accentPurple], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var titlePresets: [String] {
        appLanguage.isJapanese
            ? ["出張", "旅行", "帰省", "週末", "ワーケーション"]
            : ["Business", "Trip", "Family", "Weekend", "Workation"]
    }

    private func quickNightButton(days: Int) -> some View {
        Button {
            if let date = Calendar.current.date(byAdding: .day, value: days, to: checkIn) {
                checkOut = date
            }
        } label: {
            Text("+\(days)\(t("泊", "d"))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var nightsCount: Int {
        guard hasCheckOut else { return 0 }
        let start = Calendar.current.startOfDay(for: checkIn)
        let end = Calendar.current.startOfDay(for: checkOut)
        return max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    private var dateRangePreview: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = appLanguage.locale
        let start = formatter.string(from: checkIn)
        guard hasCheckOut else { return start }
        return "\(start) - \(formatter.string(from: checkOut))"
    }

    private func save() {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String = {
            if !normalizedTitle.isEmpty { return normalizedTitle }
            if !normalizedCity.isEmpty { return normalizedCity }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = appLanguage.locale
            return t("滞在", "Stay") + " " + formatter.string(from: checkIn)
        }()

        let stay = Stay(
            id: initialStay?.id ?? UUID().uuidString,
            title: resolvedTitle,
            city: normalizedCity.isEmpty ? nil : normalizedCity,
            checkIn: checkIn,
            checkOut: hasCheckOut ? checkOut : nil,
            note: normalizedNote.isEmpty ? nil : normalizedNote
        )

        onSave(stay)
        dismiss()
    }

    private func t(_ ja: String, _ en: String) -> String {
        appLanguage.isJapanese ? ja : en
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .system
    }
}

private extension View {
    func flightyGlass() -> some View {
        self
            .background(FlightyPalette.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FlightyPalette.glassBorder, lineWidth: 1)
            )
    }
}
