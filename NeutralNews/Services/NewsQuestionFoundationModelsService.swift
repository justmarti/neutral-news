//
//  NewsQuestionFoundationModelsService.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 9/7/26.
//

import Foundation

@MainActor
protocol NewsQuestionAnswering: AnyObject {
    func answer(question: String, context: NewsQuestionContext) async throws -> NewsQuestionAnswer
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@MainActor
final class NewsQuestionFoundationModelsService: NewsQuestionAnswering {
    private var session: LanguageModelSession?

    static var availability: NewsQuestionAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            .available
        case .unavailable(.appleIntelligenceNotEnabled):
            .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            .modelNotReady
        case .unavailable(.deviceNotEligible):
            .deviceNotEligible
        case .unavailable:
            .unavailable
        }
    }

    func answer(question: String, context: NewsQuestionContext) async throws -> NewsQuestionAnswer {
        guard Self.availability == .available else {
            throw NewsQuestionServiceError.unavailable
        }

        let isNewSession = session == nil
        let session = session ?? LanguageModelSession(instructions: Self.instructions)
        self.session = session
#if compiler(>=6.4)
        let options = GenerationOptions(
            samplingMode: nil,
            temperature: 0.2,
            maximumResponseTokens: 550
        )
#else
        let options = GenerationOptions(
            sampling: nil,
            temperature: 0.2,
            maximumResponseTokens: 550
        )
#endif
        do {
            let response = try await session.respond(
                to: isNewSession ? context.initialPrompt(for: question) : context.followUpPrompt(for: question),
                generating: GeneratedNewsQuestionAnswer.self,
                options: options
            )

            return NewsQuestionAnswer(
                text: response.content.answer,
                referencedSources: response.content.referencedSources
            )
        } catch {
            if Self.shouldResetSession(for: error) {
                self.session = nil
            }

            throw error
        }
    }

    static func displayMessage(for error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return String(localized: "This story has too much context to answer that question.")
            case .guardrailViolation, .refusal:
                return String(localized: "This question cannot be answered safely.")
            case .unsupportedLanguageOrLocale:
                return String(localized: "This language is not supported on this device yet.")
            case .assetsUnavailable:
                return String(localized: "Apple Intelligence is still getting ready on this device.")
            case .rateLimited:
                return String(localized: "Apple Intelligence is busy right now. Try again in a moment.")
            case .concurrentRequests:
                return String(localized: "Please wait for the current answer to finish.")
            case .decodingFailure, .unsupportedGuide:
                return String(localized: "The answer could not be generated. Try a simpler question.")
            @unknown default:
                return String(localized: "The answer could not be generated. Try again.")
            }
        }

#if compiler(>=6.4)
        if #available(iOS 27.0, *), let languageModelError = error as? LanguageModelError {
            switch languageModelError {
            case .contextSizeExceeded:
                return String(localized: "This story has too much context to answer that question.")
            case .guardrailViolation, .refusal:
                return String(localized: "This question cannot be answered safely.")
            case .unsupportedLanguageOrLocale:
                return String(localized: "This language is not supported on this device yet.")
            case .rateLimited:
                return String(localized: "Apple Intelligence is busy right now. Try again in a moment.")
            case .timeout:
                return String(localized: "The answer took too long. Try again.")
            case .unsupportedCapability, .unsupportedGenerationGuide, .unsupportedTranscriptContent:
                return String(localized: "The answer could not be generated. Try a simpler question.")
            @unknown default:
                return String(localized: "The answer could not be generated. Try again.")
            }
        }
#endif

        return String(localized: "The answer could not be generated. Try again.")
    }

    private static func shouldResetSession(for error: Error) -> Bool {
        if let generationError = error as? LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = generationError {
                return true
            }
        }

#if compiler(>=6.4)
        if #available(iOS 27.0, *), let languageModelError = error as? LanguageModelError {
            if case .contextSizeExceeded = languageModelError {
                return true
            }
        }
#endif

        return false
    }

    private static let instructions = """
    You answer questions about a news story for the Facts app.
    Use only the story context provided in the prompt.
    Do not use outside knowledge, assumptions, or speculation.
    If the provided context is insufficient, say so directly.
    Always answer in the same language as the user's question.
    Distinguish facts from the provided sources from neutral explanation.
    Keep answers concise and useful.
    """
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedNewsQuestionAnswer {
    @Guide(description: "A concise answer based only on the provided story context, written in the same language as the user's question.")
    var answer: String

    @Guide(description: "Exact publisher names from the provided source context that the answer references. Do not return labels such as Source 1. Use an empty list when no publisher is referenced.")
    var referencedSources: [String]

}

private enum NewsQuestionServiceError: Error {
    case unavailable
}
#endif
