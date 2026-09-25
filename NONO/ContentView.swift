//
//  ContentView.swift
//  NONO
//
//  Created by Theo on 9/17/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    private enum ActionState { case paste, copy }

    @State private var text = ""
    @State private var actionState: ActionState = .paste
    @State private var didCopy = false
    @State private var showsCopyConfirmation = false
    @State private var copyFeedbackID = UUID()
    @State private var showsAbout = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    Text("NONO")
                        .font(.largeTitle.weight(.bold))
                        .tracking(0.5)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    aboutButton
                }

                NotesTextView(text: $text)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        if text.isEmpty && actionState == .paste {
                            Text("Paste your social links here")
                                .foregroundStyle(.secondary)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel("Links")

            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(linkCount == 1 ? "\(linkCount) link" : "\(linkCount) links")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    if didCopy {
                        clearButton
                    }
                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            if showsCopyConfirmation {
                Label("Copied", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.clear))
                    .glassEffect(.regular, in: Capsule())
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .sheet(isPresented: $showsAbout) {
            NavigationStack {
                Form {
                    LabeledContent("Version", value: appVersion)

                    Button("Open App Settings") {
                        openAppSettings()
                    }
                }
                .navigationTitle("About")
            }
        }
    }

    private var aboutButton: some View {
        Button {
            showsAbout = true
        } label: {
            Image(systemName: "info.circle")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(Circle().fill(.clear))
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("About")
        .accessibilityHint("Opens app information")
    }

    private var actionButton: some View {
        Button(action: performAction) {
            Group {
                switch actionState {
                case .paste: Image(systemName: "doc.on.clipboard.fill")
                case .copy: Image(systemName: "doc.on.doc.fill")
                }
            }
            .font(.title3.weight(.semibold))
            .frame(width: 56, height: 56)
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Circle().fill(buttonColor))
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(actionState == .copy ? "Copy organized links" : "Paste links")
        .accessibilityHint(actionState == .copy ? "Copies the organized links to the clipboard" : "Pastes links from the clipboard")
    }

    private var clearButton: some View {
        Button(action: clearText) {
            Image(systemName: "xmark")
                .font(.title3.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(Circle().fill(.clear))
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Clear links")
        .accessibilityHint("Clears the current links and prepares a new note")
    }

    private var buttonColor: Color {
        switch actionState {
        case .paste: .blue
        case .copy: .green
        }
    }

    private var linkCount: Int {
        LinkProcessor.linkCount(in: text)
    }

    private var statusText: String {
        switch actionState {
        case .paste: "Ready to paste"
        case .copy: didCopy ? "Copied" : "Organized"
        }
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

        return "\(shortVersion) (\(buildVersion))"
    }

    private func performAction() {
        switch actionState {
        case .paste:
            guard let pastedText = UIPasteboard.general.string, !pastedText.isEmpty else { return }
            text = LinkProcessor.organize(pastedText)
            actionState = .copy
            didCopy = false
        case .copy:
            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]])
            didCopy = true
            showCopyFeedback()
        }
    }

    private func clearText() {
        text = ""
        actionState = .paste
        didCopy = false
        showsCopyConfirmation = false
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private func showCopyFeedback() {
        let feedbackID = UUID()
        copyFeedbackID = feedbackID
        withAnimation(.easeOut(duration: 0.15)) {
            showsCopyConfirmation = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1))
            guard copyFeedbackID == feedbackID else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                showsCopyConfirmation = false
            }
        }
    }
}

#Preview { ContentView() }
