//
//  NewsQuestionViewModelTests.swift
//  NeutralNewsTests
//
//  Created by Martí Espinosa Farran on 11/7/26.
//

import Foundation
import Testing
@testable import NeutralNews

@MainActor
@Suite("News Question View Model Tests")
struct NewsQuestionViewModelTests {
    @Test("Submits a cleaned question and displays referenced publishers")
    func submitsQuestion() async {
        let service = MockNewsQuestionService { question, _ in
            #expect(question == "What happened?")
            return NewsQuestionAnswer(
                text: "A concise answer.",
                referencedSources: ["Example Publisher", "Unknown Publisher"]
            )
        }
        let viewModel = NewsQuestionViewModel(context: Self.context, service: service)
        viewModel.draftQuestion = "  What   happened?  "

        await viewModel.submitQuestion()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages[0].text == "What happened?")
        #expect(viewModel.messages[1].text == "A concise answer.")
        #expect(viewModel.messages[1].referencedSources == ["Example Publisher"])
        #expect(!viewModel.isResponding)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Retries a failed question without duplicating the user message")
    func retriesFailedQuestion() async {
        let service = MockNewsQuestionService { _, _ in
            throw TestError.failed
        }
        let viewModel = NewsQuestionViewModel(context: Self.context, service: service)
        viewModel.draftQuestion = "Why?"

        await viewModel.submitQuestion()
        #expect(viewModel.messages.count == 1)
        #expect(viewModel.canRetry)

        service.handler = { _, _ in
            NewsQuestionAnswer(text: "Because.", referencedSources: [])
        }
        await viewModel.retryLastQuestion()

        #expect(viewModel.messages.count == 2)
        #expect(viewModel.messages.last?.text == "Because.")
        #expect(!viewModel.canRetry)
    }

    @Test("Submits follow-up questions without duplicating messages")
    func submitsFollowUpQuestionsWithoutDuplicatingMessages() async {
        var questions = [String]()
        let service = MockNewsQuestionService { question, _ in
            questions.append(question)
            return NewsQuestionAnswer(
                text: question == "What happened?" ? "The first answer." : "The follow-up answer.",
                referencedSources: []
            )
        }
        let viewModel = NewsQuestionViewModel(context: Self.context, service: service)

        viewModel.draftQuestion = "What happened?"
        await viewModel.submitQuestion()
        viewModel.draftQuestion = "Why?"
        await viewModel.submitQuestion()

        #expect(questions == ["What happened?", "Why?"])
        #expect(viewModel.messages.map(\.text) == [
            "What happened?",
            "The first answer.",
            "Why?",
            "The follow-up answer."
        ])
    }

    @Test("Cancellation does not show an error")
    func cancellationDoesNotShowError() async {
        let service = MockNewsQuestionService { _, _ in
            try await Task.sleep(for: .seconds(60))
            return NewsQuestionAnswer(text: "", referencedSources: [])
        }
        let viewModel = NewsQuestionViewModel(context: Self.context, service: service)
        viewModel.draftQuestion = "Why?"

        let task = Task {
            await viewModel.submitQuestion()
        }
        await Task.yield()
        task.cancel()
        await task.value

        #expect(!viewModel.isResponding)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.canRetry)
    }

    private static var context: NewsQuestionContext {
        NewsQuestionContext(news: .mock, relatedNews: [News(
            id: "source",
            title: "Headline",
            description: "Description",
            scrappedDescription: nil,
            category: Category.politics.rawValue,
            imageUrl: nil,
            link: "https://example.com",
            pubDate: .distantPast,
            createdAt: .distantPast,
            updatedAt: .distantPast,
            publisher: "Example Publisher",
            neutralScore: 50,
            group: 1,
            embedding: []
        )])
    }
}

@MainActor
private final class MockNewsQuestionService: NewsQuestionAnswering {
    var handler: (String, NewsQuestionContext) async throws -> NewsQuestionAnswer

    init(handler: @escaping (String, NewsQuestionContext) async throws -> NewsQuestionAnswer) {
        self.handler = handler
    }

    func answer(question: String, context: NewsQuestionContext) async throws -> NewsQuestionAnswer {
        try await handler(question, context)
    }
}

private enum TestError: Error {
    case failed
}
