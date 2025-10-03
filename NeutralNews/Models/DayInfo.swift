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

        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"

        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
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

        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "LLLL"

        self.dayNumber = calendar.component(.day, from: date)
        self.monthName = monthFormatter.string(from: date)
        self.date = date
    }
    
    var formattedDateLong: String {
        "\(dayName), \(dayNumber) de \(monthName)"
    }
    var formattedDateShort: String {
        "\(dayNumber) de \(monthName)"
    }
    
    var shortFormat: String {
        switch dayName {
        case "Hoy", "Ayer":
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
