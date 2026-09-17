//
//  NotesTextView.swift
//  NONO
//

import SwiftUI
import UIKit

struct NotesTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        guard textView.text != text else { return }
        textView.attributedText = styledText(text)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private func styledText(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let fullRange = NSRange(text.startIndex..., in: text)
        result.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: fullRange)
        result.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)

        let firstLine = text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        guard !firstLine.isEmpty, LinkProcessor.linkCount(in: firstLine) == 0 else { return result }
        result.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .title2), range: NSRange(firstLine.startIndex..., in: firstLine))
        return result
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }
}
