import Foundation

extension Date {
    func startOfMonth(using calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self))!
    }
    
    func monthInterval(using calendar: Calendar = .current) -> DateInterval? {
        calendar.dateInterval(of: .month, for: self)
    }
}

extension Calendar {
    func generateDates(
        for dateInterval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates = [dateInterval.start]
        enumerateDates(
            startingAfter: dateInterval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            guard let date = date else { return }
            if date < dateInterval.end {
                dates.append(date)
            } else {
                stop = true
            }
        }
        return dates
    }
    
    func generateDaysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = dateInterval(of: .month, for: date),
              let monthFirstWeek = dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)
        else { return [] }
        
        return generateDates(
            for: DateInterval(start: monthFirstWeek.start, end: monthLastWeek.end),
            matching: dateComponents([.hour, .minute, .second], from: monthFirstWeek.start)
        )
    }
}
