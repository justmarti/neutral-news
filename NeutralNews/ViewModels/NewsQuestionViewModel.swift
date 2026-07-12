//
//  NewsQuestionViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/7/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class NewsQuestionViewModel {
    var draftQuestion = ""
    private(set) var messages = [NewsQuestionMessage]()
    private(set) var isResponding = false
    private(set) var errorMessage: String?
    private(set) var canRetry = false

    let context: NewsQuestionContext
    private let service: (any NewsQuestionAnswering)?
    @ObservationIgnored private var failedQuestion: String?

    var canSubmit: Bool {
        !NewsQuestionContext.clean(draftQuestion, limit: 800).isEmpty
            && !isResponding
            && context.hasUsableContent
    }

    init(context: NewsQuestionContext, service: (any NewsQuestionAnswering)? = nil) {
        self.context = context
        if let service {
            self.service = service
            return
        }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            self.service = NewsQuestionFoundationModelsService()
        } else {
            self.service = nil
        }
#else
        self.service = nil
#endif
    }

    func submitQuestion() async {
        let question = NewsQuestionContext.clean(draftQuestion, limit: 800)
        guard !question.isEmpty, !isResponding else {
            return
        }

        draftQuestion = ""
        await perform(question: question, appendingUserMessage: true)
    }

    func retryLastQuestion() async {
        guard let failedQuestion, !isResponding else {
            return
        }

        await perform(question: failedQuestion, appendingUserMessage: false)
    }

    private func perform(question: String, appendingUserMessage: Bool) async {
        guard let service else {
            errorMessage = String(localized: "Apple Intelligence is not available on this device.")
            return
        }

        if appendingUserMessage {
            messages.append(NewsQuestionMessage(role: .user, text: question))
        }

        errorMessage = nil
        canRetry = false
        isResponding = true

        defer {
            isResponding = false
        }

        do {
            let answer = try await service.answer(question: question, context: context)
            try Task.checkCancellation()
            messages.append(NewsQuestionMessage(
                role: .assistant,
                text: answer.text,
                referencedSources: displaySources(from: answer.referencedSources)
            ))
            failedQuestion = nil
        } catch is CancellationError {
            return
        } catch {
            failedQuestion = question
            canRetry = true
            errorMessage = Self.displayMessage(for: error)
        }
    }

    private static func displayMessage(for error: Error) -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return NewsQuestionFoundationModelsService.displayMessage(for: error)
        }
#endif
        return String(localized: "Apple Intelligence is not available on this device.")
    }

    private func displaySources(from referencedSources: [String]) -> [String] {
        let publishersBySourceNumber = Dictionary(
            uniqueKeysWithValues: context.sources.enumerated().map { index, source in
                ("source \(index + 1)", source.publisher)
            }
        )

        let sourcePublishers = Set(context.sources.map(\.publisher))
        var displaySources = [String]()

        for referencedSource in referencedSources {
            let normalizedSource = referencedSource
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: ":", with: "")

            let displaySource = publishersBySourceNumber[normalizedSource] ?? sourcePublishers.first {
                $0.localizedCaseInsensitiveCompare(referencedSource) == .orderedSame
            }

            guard let displaySource, !displaySource.isEmpty, !displaySources.contains(displaySource) else {
                continue
            }

            displaySources.append(displaySource)
        }

        return displaySources
    }
}
