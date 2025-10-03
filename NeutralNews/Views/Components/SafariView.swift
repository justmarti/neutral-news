//
//  SafariView.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/21/25.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    var configuration: SFSafariViewController.Configuration = {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        config.barCollapsingEnabled = true
        return config
    }()

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url, configuration: configuration)
        safari.preferredBarTintColor = UIColor.systemBackground
        safari.preferredControlTintColor = UIColor.label
        safari.delegate = context.coordinator
        safari.modalPresentationStyle = .pageSheet
        safari.preferredContentSize = CGSize(width: 0, height: 0)
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var parent: SafariView

        init(_ parent: SafariView) {
            self.parent = parent
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            // SwiftUI handles dismissal automatically
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    func safariSheet(url: URL?, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            if let url = url {
                SafariView(url: url)
                    .presentationDetents([.large])
            }
        }
    }
}