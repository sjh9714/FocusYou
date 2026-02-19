import SwiftUI

// MARK: - 스케줄 편집기 (v1.3)

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    let schedule: BlockSchedule?
    let profiles: [BlockProfile]
    let onSave: (String, String, Int, Int, BlockProfile?) -> Void

    @State private var name = ""
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 12
    @State private var endMinute = 0
    @State private var selectedProfileIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle().fill(.quaternary).frame(height: 0.5)

            ScrollView {
                VStack(spacing: Constants.Design.spacingXL) {
                    nameSection
                    weekdaySection
                    timeSection
                    profileSection
                }
                .padding()
            }
        }
        .frame(width: 380, height: 440)
        .onAppear { loadSchedule() }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            Button("취소") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Spacer()

            Text(schedule == nil ? "새 스케줄" : "스케줄 편집")
                .font(.headline)

            Spacer()

            Button("저장") { save() }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.primary)
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    // MARK: - 이름

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("스케줄 이름")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("예: 오전 딥워크", text: $name)
                .textFieldStyle(.plain)
                .padding(.horizontal, Constants.Design.spacingMD)
                .padding(.vertical, Constants.Design.spacingSM)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Constants.Design.cornerMD))
        }
    }

    // MARK: - 요일 선택

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("요일")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let isSelected = selectedWeekdays.contains(day)
                    Button {
                        if isSelected {
                            selectedWeekdays.remove(day)
                        } else {
                            selectedWeekdays.insert(day)
                        }
                    } label: {
                        Text(Constants.Schedule.weekdaySymbols[day - 1])
                            .font(.caption.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(
                                isSelected
                                    ? themeManager.primary.opacity(0.15)
                                    : Color.secondary.opacity(0.06),
                                in: Circle()
                            )
                            .foregroundStyle(isSelected ? themeManager.primary : .secondary)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected ? themeManager.primary.opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 시간

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("시간")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Design.spacingXL) {
                timePicker(label: "시작", hour: $startHour, minute: $startMinute)
                timePicker(label: "종료", hour: $endHour, minute: $endMinute)
            }
        }
    }

    private func timePicker(
        label: String,
        hour: Binding<Int>,
        minute: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                Picker("", selection: hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .labelsHidden()
                .frame(width: 56)

                Text(":")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Picker("", selection: minute) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .labelsHidden()
                .frame(width: 56)
            }
        }
    }

    // MARK: - 프로필 선택

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.spacingSM) {
            Text("프로필")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if profiles.isEmpty {
                Text("프로필을 먼저 생성해주세요")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: Constants.Design.spacingSM) {
                    ForEach(Array(profiles.enumerated()), id: \.element.persistentModelID) { index, profile in
                        let isSelected = selectedProfileIndex == index
                        Button {
                            selectedProfileIndex = index
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: profile.icon)
                                    .font(.caption2)
                                Text(profile.name)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, Constants.Design.spacingSM)
                            .padding(.vertical, 5)
                            .background(
                                Color(hex: profile.color).opacity(isSelected ? 0.2 : 0.08),
                                in: Capsule()
                            )
                            .foregroundStyle(Color(hex: profile.color))
                            .overlay(
                                Capsule()
                                    .stroke(
                                        Color(hex: profile.color).opacity(isSelected ? 0.55 : 0),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 저장/로드

    private func loadSchedule() {
        guard let schedule else { return }
        name = schedule.name
        selectedWeekdays = Set(schedule.weekdayArray)

        startHour = schedule.startMinuteOfDay / 60
        startMinute = schedule.startMinuteOfDay % 60
        endHour = schedule.endMinuteOfDay / 60
        endMinute = schedule.endMinuteOfDay % 60

        if let profile = schedule.profile,
           let index = profiles.firstIndex(where: { $0.persistentModelID == profile.persistentModelID }) {
            selectedProfileIndex = index
        }
    }

    private func save() {
        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute

        let weekdayString = selectedWeekdays.sorted().map(String.init).joined(separator: ",")
        let profile = selectedProfileIndex.flatMap { profiles.indices.contains($0) ? profiles[$0] : nil }

        onSave(name, weekdayString, startTotal, endTotal, profile)
    }
}

#Preview {
    ScheduleEditorView(
        schedule: nil,
        profiles: [],
        onSave: { _, _, _, _, _ in }
    )
    .environment(ThemeManager.shared)
}
