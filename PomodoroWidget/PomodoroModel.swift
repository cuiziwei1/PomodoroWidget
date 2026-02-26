//
//  PomodoroModel.swift
//  PomodoroWidget
//
//  Created by 崔紫微 on 2026/2/26.
//

import Foundation
import Combine
import SwiftUI
import UserNotifications

class PomodoroModel: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var formattedTime: String = "25:00"
    @Published var status: String = "准备就绪"
    @Published var activeAction: String = "reset"
    @Published var soundEnabled: Bool = true
    @Published var selectedTaskId: UUID? = nil
    @Published var hideCompletedTasks: Bool = false
    @Published var tasks: [TaskItem] = []
    @Published var durationMinutes: Int = 25
    @Published var selectedDate: Date = Date()
    @Published var isResting: Bool = false
    @Published var todayFocusSeconds: Int = 0
    
    private var timer: AnyCancellable?
    private var totalSeconds: Int = 25 * 60
    private var remainingSeconds: Int = 25 * 60
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    private var storageDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroWidget/tasks")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    init() {
        loadTasks(for: selectedDate)
        loadFocusTime(for: selectedDate)
        NotificationCenter.default.addObserver(forName: .saveTasksNotification, object: nil, queue: .main) { [weak self] _ in
            self?.saveTasks()
        }
        // 请求通知权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    // MARK: - 日期切换
    func switchDate(to date: Date) {
        saveTasks()
        selectedDate = date
        selectedTaskId = nil
        loadTasks(for: date)
        loadFocusTime(for: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var selectedDateString: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f.string(from: selectedDate)
    }
    
    func previousDay() { switchDate(to: Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!) }
    func nextDay() { switchDate(to: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!) }
    func goToToday() { switchDate(to: Date()) }
    
    var formattedTodayFocus: String {
        let h = todayFocusSeconds / 3600
        let m = (todayFocusSeconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
    
    private func focusFileURL(for date: Date) -> URL {
        storageDir.appendingPathComponent(Self.dateFormatter.string(from: date) + "_focus.txt")
    }
    
    private func saveFocusTime() {
        let data = "\(todayFocusSeconds)".data(using: .utf8)
        try? data?.write(to: focusFileURL(for: selectedDate))
    }
    
    private func loadFocusTime(for date: Date) {
        guard let data = try? Data(contentsOf: focusFileURL(for: date)),
              let str = String(data: data, encoding: .utf8),
              let seconds = Int(str) else {
            todayFocusSeconds = 0
            return
        }
        todayFocusSeconds = seconds
    }
    
    // MARK: - 持久化
    private func fileURL(for date: Date) -> URL {
        storageDir.appendingPathComponent(Self.dateFormatter.string(from: date) + ".json")
    }
    
    func saveTasks() {
        let items = tasks.map { $0.toCodable() }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL(for: selectedDate))
        }
    }
    
    private func loadTasks(for date: Date) {
        let url = fileURL(for: date)
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CodableTask].self, from: data) else {
            tasks = []
            return
        }
        tasks = items.map { TaskItem.fromCodable($0) }
    }
    
    // MARK: - 计时器
    func setDuration(minutes: Int) {
        timer?.cancel()
        durationMinutes = minutes
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        updateProgress()
        updateFormattedTime()
    }
    
    func start() {
        timer?.cancel()
        if isResting {
            startRest()
            return
        }
        status = "正在专注"
        activeAction = "start"
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.remainingSeconds -= 1
                self.updateProgress()
                self.updateFormattedTime()
                if self.remainingSeconds <= 0 {
                    self.timer?.cancel()
                    if self.isResting {
                        // 休息结束
                        self.isResting = false
                        self.status = "休息结束"
                        self.sendNotification(title: "☕ 休息结束", body: "开始下一轮专注吧")
                        self.activeAction = "reset"
                        self.totalSeconds = self.durationMinutes * 60
                        self.remainingSeconds = self.totalSeconds
                        self.updateProgress()
                        self.updateFormattedTime()
                    } else {
                        // 专注结束，记录时间到选中任务
                        if let taskId = self.selectedTaskId,
                           let i = self.tasks.firstIndex(where: { $0.id == taskId }) {
                            self.tasks[i].focusedSeconds += self.totalSeconds
                            self.saveTasks()
                        }
                        self.status = "🍅 专注完成"
                        self.todayFocusSeconds += self.durationMinutes * 60
                        self.saveFocusTime()
                        self.sendNotification(title: "🍅 专注完成", body: self.selectedTaskTitle ?? "休息5分钟吧")
                        self.prepareRest()
                    }
                }
            }
    }
    
    func pause() {
        timer?.cancel()
        status = "已暂停"
        activeAction = "pause"
    }
    
    func reset() {
        timer?.cancel()
        isResting = false
        totalSeconds = durationMinutes * 60
        remainingSeconds = totalSeconds
        updateProgress()
        updateFormattedTime()
        status = "准备就绪"
        activeAction = "reset"
    }
    
    func addTask(title: String) {
        guard !title.isEmpty else { return }
        tasks.append(TaskItem(title: title))
        saveTasks()
    }
    
    func addSubTask(parentId: UUID, title: String) {
        guard !title.isEmpty else { return }
        if let i = tasks.firstIndex(where: { $0.id == parentId }) {
            tasks[i].subTasks.append(TaskItem(title: title))
            saveTasks()
        }
    }
    
    func toggleSubTask(parentId: UUID, subId: UUID) {
        if let pi = tasks.firstIndex(where: { $0.id == parentId }),
           let si = tasks[pi].subTasks.firstIndex(where: { $0.id == subId }) {
            tasks[pi].subTasks[si].isCompleted.toggle()
            saveTasks()
        }
    }
    
    func deleteSubTask(parentId: UUID, subId: UUID) {
        if let pi = tasks.firstIndex(where: { $0.id == parentId }) {
            tasks[pi].subTasks.removeAll { $0.id == subId }
            saveTasks()
        }
    }
    
    func moveTask(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
        saveTasks()
    }
    
    func selectTask(id: UUID?) {
        selectedTaskId = (selectedTaskId == id) ? nil : id
    }
    
    var selectedTaskTitle: String? {
        tasks.first(where: { $0.id == selectedTaskId })?.title
    }
    
    func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
        saveTasks()
    }
    
    func toggleTask(id: UUID) {
        if let i = tasks.firstIndex(where: { $0.id == id }) {
            tasks[i].isCompleted.toggle()
            saveTasks()
        }
    }
    
    private func updateProgress() {
        progress = 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
    
    private func updateFormattedTime() {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        formattedTime = String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func prepareRest() {
        isResting = true
        totalSeconds = 5 * 60
        remainingSeconds = totalSeconds
        updateProgress()
        updateFormattedTime()
        status = "🍅 专注完成"
        activeAction = "reset"
    }
    
    private func startRest() {
        isResting = true
        status = "休息中"
        activeAction = "start"
        
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.remainingSeconds -= 1
                self.updateProgress()
                self.updateFormattedTime()
                if self.remainingSeconds <= 0 {
                    self.timer?.cancel()
                    self.isResting = false
                    self.status = "休息结束"
                    self.sendNotification(title: "☕ 休息结束", body: "开始下一轮专注吧")
                    self.activeAction = "reset"
                    self.totalSeconds = self.durationMinutes * 60
                    self.remainingSeconds = self.totalSeconds
                    self.updateProgress()
                    self.updateFormattedTime()
                }
            }
    }
}

// 可序列化的任务
struct CodableTask: Codable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let focusedSeconds: Int
    let subTasks: [CodableTask]
}

struct TaskItem: Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var focusedSeconds: Int
    var subTasks: [TaskItem]
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, focusedSeconds: Int = 0, subTasks: [TaskItem] = []) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.focusedSeconds = focusedSeconds
        self.subTasks = subTasks
    }
    
    var focusedTimeString: String {
        let h = focusedSeconds / 3600
        let m = (focusedSeconds % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        if m > 0 { return "\(m)m" }
        return ""
    }
    
    func toCodable() -> CodableTask {
        CodableTask(id: id, title: title, isCompleted: isCompleted, focusedSeconds: focusedSeconds, subTasks: subTasks.map { $0.toCodable() })
    }
    
    static func fromCodable(_ c: CodableTask) -> TaskItem {
        TaskItem(id: c.id, title: c.title, isCompleted: c.isCompleted, focusedSeconds: c.focusedSeconds, subTasks: c.subTasks.map { TaskItem.fromCodable($0) })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 300)
            .background(Color.clear)
    }
}
