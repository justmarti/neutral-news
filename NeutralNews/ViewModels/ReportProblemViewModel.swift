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
    
    // MARK: - Initialization
    init(news: NeutralNews) {
        self.news = news
    }
    
    // MARK: - Computed Properties
    var canSubmitReport: Bool {
        Date().timeIntervalSince1970 - lastReportTime > ReportConstants.Timing.cooldownPeriod
    }
    
    var remainingCooldownText: String {
        let remaining = ReportConstants.Timing.cooldownPeriod - (Date().timeIntervalSince1970 - lastReportTime)
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        return "\(minutes):\(String(format: "%02d", seconds))"
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
        
        guard canSubmitReport else {
            reportError = .cooldown(remainingTime: remainingCooldownText)
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
            
            withAnimation(.spring(duration: ReportConstants.Animation.springDuration, bounce: ReportConstants.Animation.springBounce)) {
                isSubmitted = true
                isSubmitting = false
            }
            
        } catch {
#if DEBUG
            print("❌ Error submitting report: \(error)")
#endif
            
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
}
