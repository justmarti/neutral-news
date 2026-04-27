//
//  ReportProblemViewModel.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 3/9/25.
//

import SwiftUI

@MainActor
@Observable
final class ReportProblemViewModel {
    // MARK: - Properties
    let news: NeutralNews
    
    // MARK: - Published State
    var selectedProblem: Problem?
    var isSubmitted = false
    var isSubmitting = false
    var isShowingError = false
    var reportError: ReportError?
    
    // MARK: - Private State
    @ObservationIgnored
    @AppStorage("lastReportTime") private var lastReportTime: TimeInterval = 0
    @ObservationIgnored
    private let reportedNewsIDsKey = "reportedNewsIds"
    
    // MARK: - Initialization
    init(news: NeutralNews) {
        self.news = news
    }
    
    // MARK: - Computed Properties
    var canSubmitReport: Bool {
        Date().timeIntervalSince1970 - lastReportTime > ReportConstants.Timing.cooldownPeriod
    }
    
    var remainingCooldownSeconds: Int {
        let remaining = ReportConstants.Timing.cooldownPeriod - (Date().timeIntervalSince1970 - lastReportTime)
        return Int(max(0, remaining).rounded(.up))
    }
    
    var hasError: Bool {
        reportError != nil
    }
    
    var showMainContent: Bool {
        !isSubmitted && reportError == nil
    }
    
    // MARK: - Actions
    func selectProblem(_ problem: Problem) {
        withAnimation {
            selectedProblem = problem
        }
    }
    
    func submitReport() async {
        guard let problem = selectedProblem else { return }

        guard !hasReportedCurrentNews else {
            reportError = .alreadyReported
            isShowingError = false
            return
        }
        
        guard canSubmitReport else {
            reportError = .cooldown(remainingSeconds: remainingCooldownSeconds)
            isShowingError = false
            return
        }
        
        isSubmitting = true
        
#if DEBUG
        print("🔄 Starting report submission for news: \(news.id)")
#endif
        
        do {
            try await FirestoreService.shared.submitReport(for: news, problemType: problem)
            
#if DEBUG
            print("✅ Report submitted successfully")
#endif
            
            lastReportTime = Date().timeIntervalSince1970
            markCurrentNewsReported()
            
            withAnimation(.spring(duration: ReportConstants.Animation.springDuration, bounce: ReportConstants.Animation.springBounce)) {
                isSubmitted = true
                isSubmitting = false
            }
            
        } catch {
            print("❌ Error submitting report: \(error)")
            
            isSubmitting = false
            reportError = ReportError.from(error)
            isShowingError = false
        }
    }
    
    func reset() {
        selectedProblem = nil
        isSubmitted = false
        isSubmitting = false
        isShowingError = false
        reportError = nil
    }

    private var hasReportedCurrentNews: Bool {
        reportedNewsIDs.contains(news.id)
    }

    private var reportedNewsIDs: Set<String> {
        get {
            let storedValue = UserDefaults.standard.string(forKey: reportedNewsIDsKey) ?? ""
            return Set(storedValue.split(separator: "\n").map(String.init))
        }
        set {
            UserDefaults.standard.set(newValue.sorted().joined(separator: "\n"), forKey: reportedNewsIDsKey)
        }
    }

    private func markCurrentNewsReported() {
        var reportedNewsIDs = reportedNewsIDs
        reportedNewsIDs.insert(news.id)
        self.reportedNewsIDs = reportedNewsIDs
    }
}
