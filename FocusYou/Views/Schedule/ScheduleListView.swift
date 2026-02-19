import SwiftUI
import SwiftData

// MARK: - 스케줄 목록 (v1.3)

struct ScheduleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \BlockSchedule.createdAt)
    private var schedules: [BlockSchedule]
    @Query(sort: \BlockProfile.createdAt)
    private var profiles: [BlockProfile]
    @State private var showEditor = false
    @State private var editingSchedule: BlockSchedule?

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingMD) {
            HStack {
                Text("스케줄")
                    .font(.headline)
                Spacer()
                Button {
                    editingSchedule = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeManager.primary)
                }
                .buttonStyle(.plain)
            }

            if schedules.isEmpty {
                ContentUnavailableView(
                    "스케줄 없음",
                    systemImage: "calendar.badge.clock",
                    description: Text("요일별 자동 집중 스케줄을 추가하세요")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(schedules) { schedule in
                    scheduleRow(schedule)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ScheduleEditorView(
                schedule: editingSchedule,
                profiles: profiles,
                onSave: { name, weekdays, start, end, profile in
                    saveSchedule(
                        name: name,
                        weekdays: weekdays,
                        startMinute: start,
                        endMinute: end,
                        profile: profile
                    )
                }
            )
        }
    }

    private func scheduleRow(_ schedule: BlockSchedule) -> some View {
        HStack(spacing: Constants.Design.spacingMD) {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(schedule.isEnabled ? .primary : .secondary)

                HStack(spacing: 4) {
                    Text(schedule.weekdayDisplayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(schedule.startTimeFormatted)–\(schedule.endTimeFormatted)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                if let profile = schedule.profile {
                    HStack(spacing: 4) {
                        Image(systemName: profile.icon)
                            .font(.caption2)
                        Text(profile.name)
                            .font(.caption)
                    }
                    .foregroundStyle(Color(hex: profile.color))
                }
            }

            Spacer()

            Toggle("", isOn: Bindable(schedule).isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(themeManager.primary)

            Button(role: .destructive) {
                withAnimation(.quickEase) {
                    modelContext.delete(schedule)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Constants.Design.spacingXS)
        .contentShape(Rectangle())
        .onTapGesture {
            editingSchedule = schedule
            showEditor = true
        }
        .contextMenu {
            Button("삭제", role: .destructive) {
                modelContext.delete(schedule)
            }
        }
    }

    private func saveSchedule(
        name: String,
        weekdays: String,
        startMinute: Int,
        endMinute: Int,
        profile: BlockProfile?
    ) {
        if let existing = editingSchedule {
            existing.name = name
            existing.weekdays = weekdays
            existing.startMinuteOfDay = startMinute
            existing.endMinuteOfDay = endMinute
            existing.profile = profile
        } else {
            let schedule = BlockSchedule(
                name: name,
                weekdays: weekdays,
                startMinuteOfDay: startMinute,
                endMinuteOfDay: endMinute
            )
            schedule.profile = profile
            modelContext.insert(schedule)
        }
        showEditor = false
    }
}

#Preview {
    ScheduleListView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [
            BlockSchedule.self, BlockProfile.self,
            BlockedSite.self, BlockedApp.self, FocusSession.self,
        ], inMemory: true)
}
