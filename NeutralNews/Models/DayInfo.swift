//
//  DayInfo.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/5/25.
//

import Foundation

struct DayInfo: Identifiable, Hashable {
    let id = UUID()
    let dayNumber: Int
    let monthName: String
    let date: Date

    var dayName: String {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let relativeDayFormatter = DateFormatter()

        dayFormatter.locale = .autoupdatingCurrent
        dayFormatter.dateFormat = "EEEE"
        relativeDayFormatter.locale = .autoupdatingCurrent
        relativeDayFormatter.dateStyle = .full
        relativeDayFormatter.timeStyle = .none
        relativeDayFormatter.doesRelativeDateFormatting = true

        if calendar.isDateInToday(date) {
            return relativeDayFormatter.string(from: date).capitalized
        } else if calendar.isDateInYesterday(date) {
            return relativeDayFormatter.string(from: date).capitalized
        } else {
            return dayFormatter.string(from: date).capitalized
        }
    }
    
    init(dayNumber: Int, monthName: String, date: Date) {
        self.dayNumber = dayNumber
        self.monthName = monthName
        self.date = date
    }

    init(date: Date) {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()

        monthFormatter.locale = .autoupdatingCurrent
        monthFormatter.dateFormat = "LLLL"

        self.dayNumber = calendar.component(.day, from: date)
        self.monthName = monthFormatter.string(from: date)
        self.date = date
    }
    
    var formattedDateLong: String {
        date.formatted(
            Date.FormatStyle.dateTime
                .weekday(.wide)
                .day()
                .month(.wide)
                .locale(.autoupdatingCurrent)
        ).capitalized
    }
    var formattedDateShort: String {
        date.formatted(
            Date.FormatStyle.dateTime
                .day()
                .month(.wide)
                .locale(.autoupdatingCurrent)
        )
    }
    
    var shortFormat: String {
        switch Calendar.current {
        case let calendar where calendar.isDateInToday(date):
            return dayName
        case let calendar where calendar.isDateInYesterday(date):
            return dayName
        default:
            return "\(dayName) \(dayNumber)"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(date)
    }
    
    static func == (lhs: DayInfo, rhs: DayInfo) -> Bool {
        Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date)
    }
    
    static var today: DayInfo {
        DayInfo(date: Date())
    }
}
