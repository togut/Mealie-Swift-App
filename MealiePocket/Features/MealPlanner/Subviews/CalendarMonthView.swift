import SwiftUI

struct CalendarMonthView: View {
    let days: [Date]
    let mealPlanEntries: [Date: [ReadPlanEntry]]
    let selectedMonthDate: Date
    let baseURL: URL?
    
    private let daysOfWeek = ["L", "M", "M", "J", "V", "S", "D"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(daysOfWeek.indices, id: \.self) { index in
                    Text(daysOfWeek[index])
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 5)
            
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(days, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        entries: mealPlanEntries[Calendar.current.startOfDay(for: date)] ?? [],
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedMonthDate, toGranularity: .month)
                    )
                    .frame(minHeight: 100, alignment: .topLeading)
                }
            }
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let entries: [ReadPlanEntry]
    let isCurrentMonth: Bool

    private var hasEntries: Bool {
        !entries.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.day()))
                .font(.callout.bold())
                .fontWeight(Calendar.current.isDateInToday(date) ? .heavy : .regular)
                .foregroundColor(foregroundColorForDate)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 5)
            
            if hasEntries {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
            } else {
                Spacer().frame(height: 5)
            }
            
            Spacer()
        }
        .padding(2)
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var foregroundColorForDate: Color {
        if Calendar.current.isDateInToday(date) {
            return .red
        } else if isCurrentMonth {
            return .primary
        } else {
            return .secondary
        }
    }
}
