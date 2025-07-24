//
//  DayInfo.swift
//  NeutralNews
//
//  Created by Martí Espinosa Farran on 4/5/25.
//

import Foundation

struct DayInfo: Identifiable, Hashable {
    let id = UUID()
    let dayName: String
    let dayNumber: Int
    let monthName: String
    let date: Date
    
    init(dayName: String, dayNumber: Int, monthName: String, date: Date) {
        self.dayName = dayName
        self.dayNumber = dayNumber
        self.monthName = monthName
        self.date = date
    }
    
    init(date: Date) {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let monthFormatter = DateFormatter()
        
        dayFormatter.locale = Locale(identifier: "es_ES")
        dayFormatter.dateFormat = "EEEE"
        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "LLLL"
        
        if calendar.isDateInToday(date) {
            self.dayName = "Hoy"
        } else if calendar.isDateInYesterday(date) {
            self.dayName = "Ayer"
        } else {
            self.dayName = dayFormatter.string(from: date).capitalized
        }
        
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
    
    static let today: DayInfo = {
        let calendar = Calendar.current
        let dayFormatter = DateFormatter()
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "es_ES")
        monthFormatter.dateFormat = "LLLL"
        
        return DayInfo(
            dayName: "Hoy",
            dayNumber: calendar.component(.day, from: .now),
            monthName: monthFormatter.string(from: .now),
            date: .now
        )
    }()
}
