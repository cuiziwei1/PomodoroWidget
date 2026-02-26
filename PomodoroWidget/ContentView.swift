//
//  ContentView.swift
//  PomodoroWidget
//
//  Created by 崔紫微 on 2026/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var pomodoro: PomodoroModel = .init()
    @State private var newTaskTitle = ""
    @FocusState private var isTaskFieldFocused: Bool
    @State private var showCustomDuration = false
    @State private var customMinutesText = ""
    @State private var addingSubTaskFor: UUID? = nil
    @State private var newSubTaskTitle = ""
    @State private var draggingTaskId: UUID? = nil
    
    @State private var currentTime = ""
    
    private var isCustomDuration: Bool {
        ![25, 30, 45].contains(pomodoro.durationMinutes)
    }
    
    private func applyCustomDuration() {
        if let mins = Int(customMinutesText), mins > 0 {
            pomodoro.setDuration(minutes: mins)
        }
        showCustomDuration = false
    }
    
    // 颜色
    private let primaryText = Color.white
    private let lightGrayBg = Color.white.opacity(0.2)
    private let lightGrayBgLow = Color.white.opacity(0.15)
    private let systemGreen = Color.green
    private let systemBlue = Color.accentColor
    private let systemRed = Color.red
    
    private func updateTime() {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        currentTime = fmt.string(from: Date())
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .cornerRadius(20)
            
            VStack(spacing: 8) {
                HStack {
                    Text("今天也要开心吖")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(primaryText)
                    Spacer()
                    Text("\(pomodoro.formattedTodayFocus)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(systemGreen)
                    Text(currentTime)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(primaryText)
                }
                .padding(.horizontal, 4)
                .onAppear {
                    updateTime()
                    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        updateTime()
                    }
                }
                
                // 时长选择
                HStack(spacing: 10) {
                    ForEach([25, 30, 45], id: \.self) { mins in
                        Button("\(mins)m") {
                            pomodoro.setDuration(minutes: mins)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(pomodoro.durationMinutes == mins ? systemGreen.opacity(0.6) : lightGrayBgLow)
                        .cornerRadius(8)
                        .font(.system(size: 12, weight: pomodoro.durationMinutes == mins ? .bold : .regular))
                        .foregroundColor(primaryText)
                    }
                    
                    // 自定义时长
                    Button(action: { showCustomDuration = true }) {
                        Text(isCustomDuration ? "\(pomodoro.durationMinutes)m" : "...")
                            .font(.system(size: 12, weight: isCustomDuration ? .bold : .regular))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(isCustomDuration ? systemGreen.opacity(0.6) : lightGrayBgLow)
                    .cornerRadius(8)
                    .foregroundColor(primaryText)
                    .popover(isPresented: $showCustomDuration) {
                        HStack(spacing: 6) {
                            TextField("分钟", text: $customMinutesText)
                                .textFieldStyle(.plain)
                                .frame(width: 50)
                                .padding(6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                                .onSubmit { applyCustomDuration() }
                            Button("确定") { applyCustomDuration() }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(systemGreen.opacity(0.3))
                                .cornerRadius(6)
                        }
                        .padding(10)
                    }
                }
                
                // 圆形倒计时
                ZStack {
                    Circle()
                        .fill(lightGrayBg)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: pomodoro.progress)
                        .stroke(systemGreen, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: pomodoro.progress)
                    Text(pomodoro.formattedTime)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(primaryText)
                }
                
                // 控制按钮
                if let taskName = pomodoro.selectedTaskTitle {
                    Text("专注: \(taskName)")
                        .font(.system(size: 11))
                        .foregroundColor(primaryText.opacity(0.5))
                        .lineLimit(1)
                } else {
                    Text("专注: 请选择任务")
                        .font(.system(size: 11))
                        .foregroundColor(primaryText.opacity(0.5))
                }
                
                HStack(spacing: 24) {
                    Button("开始") { pomodoro.start() }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(pomodoro.activeAction == "start" ? systemGreen.opacity(0.6) : lightGrayBgLow)
                        .cornerRadius(12)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    
                    Button("暂停") { pomodoro.pause() }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(pomodoro.activeAction == "pause" ? systemGreen.opacity(0.6) : lightGrayBgLow)
                        .cornerRadius(12)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    
                    Button("重置") { pomodoro.reset() }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(pomodoro.activeAction == "reset" ? systemGreen.opacity(0.6) : lightGrayBgLow)
                        .cornerRadius(12)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }
                
                // 任务区域
                VStack(spacing: 8) {
                    // 日期切换
                    HStack(spacing: 8) {
                        Button(action: { pomodoro.previousDay() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11))
                                .foregroundColor(primaryText.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { pomodoro.goToToday() }) {
                            Text(pomodoro.selectedDateString)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(primaryText)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { pomodoro.nextDay() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundColor(primaryText.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 6) {
                        TextField("输入任务…", text: $newTaskTitle)
                            .focused($isTaskFieldFocused)
                            .onSubmit {
                                pomodoro.addTask(title: newTaskTitle)
                                newTaskTitle = ""
                            }
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(lightGrayBgLow)
                            .cornerRadius(8)
                            .font(.system(size: 12))
                            .foregroundColor(primaryText)
                            .frame(maxWidth: 200)
                            .onTapGesture { isTaskFieldFocused = true }
                        
                        Button(action: {
                            pomodoro.addTask(title: newTaskTitle)
                            newTaskTitle = ""
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(systemGreen)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTaskTitle.isEmpty)
                        
                        Button(action: {
                            pomodoro.hideCompletedTasks.toggle()
                        }) {
                            Image(systemName: pomodoro.hideCompletedTasks ? "eye.slash" : "eye")
                                .font(.system(size: 16))
                                .foregroundColor(primaryText.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    let visibleTasks = pomodoro.tasks.filter {
                        !pomodoro.hideCompletedTasks || !$0.isCompleted
                    }
                    
                    if !visibleTasks.isEmpty {
                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(visibleTasks) { task in
                                    VStack(spacing: 2) {
                                        // 主任务行
                                        HStack {
                                            Button(action: { pomodoro.toggleTask(id: task.id) }) {
                                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(task.isCompleted ? systemGreen : primaryText.opacity(0.4))
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Text(task.title)
                                                .font(.system(size: 13))
                                                .strikethrough(task.isCompleted)
                                                .foregroundColor(task.isCompleted ? primaryText.opacity(0.8) : primaryText)
                                                .padding(4)
                                                .background(pomodoro.selectedTaskId == task.id ? systemGreen.opacity(0.2) : lightGrayBgLow)
                                                .cornerRadius(4)
                                                .onTapGesture { pomodoro.selectTask(id: task.id) }
                                            
                                            if !task.focusedTimeString.isEmpty {
                                                Text(task.focusedTimeString)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(systemGreen.opacity(0.8))
                                            }
                                            
                                            Spacer()
                                            
                                            // 添加子任务按钮
                                            Button(action: {
                                                addingSubTaskFor = addingSubTaskFor == task.id ? nil : task.id
                                                newSubTaskTitle = ""
                                            }) {
                                                Image(systemName: "plus")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(primaryText.opacity(0.4))
                                                    .padding(3)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: {
                                                if let i = pomodoro.tasks.firstIndex(where: { $0.id == task.id }) {
                                                    pomodoro.deleteTask(at: IndexSet(integer: i))
                                                }
                                            }) {
                                                Image(systemName: "xmark")
                                                    .foregroundColor(systemRed)
                                                    .font(.system(size: 14))
                                                    .padding(3)
                                                    .background(lightGrayBgLow)
                                                    .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 4)
                                        .onDrag {
                                            draggingTaskId = task.id
                                            return NSItemProvider(object: task.id.uuidString as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: TaskDropDelegate(
                                            targetId: task.id,
                                            draggingId: $draggingTaskId,
                                            tasks: $pomodoro.tasks,
                                            onDrop: { pomodoro.saveTasks() }
                                        ))
                                        
                                        // 子任务输入框
                                        if addingSubTaskFor == task.id {
                                            HStack(spacing: 4) {
                                                TextField("子任务…", text: $newSubTaskTitle)
                                                    .textFieldStyle(.plain)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(lightGrayBgLow)
                                                    .cornerRadius(4)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(primaryText)
                                                    .onSubmit {
                                                        pomodoro.addSubTask(parentId: task.id, title: newSubTaskTitle)
                                                        newSubTaskTitle = ""
                                                        addingSubTaskFor = nil
                                                    }
                                                Button(action: {
                                                    pomodoro.addSubTask(parentId: task.id, title: newSubTaskTitle)
                                                    newSubTaskTitle = ""
                                                    addingSubTaskFor = nil
                                                }) {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(systemGreen)
                                                }
                                                .buttonStyle(.plain)
                                                .disabled(newSubTaskTitle.isEmpty)
                                            }
                                            .padding(.leading, 28)
                                            .padding(.trailing, 4)
                                        }
                                        
                                        // 子任务列表
                                        ForEach(task.subTasks) { sub in
                                            HStack {
                                                Button(action: { pomodoro.toggleSubTask(parentId: task.id, subId: sub.id) }) {
                                                    Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                                        .font(.system(size: 13))
                                                        .foregroundColor(sub.isCompleted ? systemGreen : primaryText.opacity(0.4))
                                                }
                                                .buttonStyle(.plain)
                                                
                                                Text(sub.title)
                                                    .font(.system(size: 11))
                                                    .strikethrough(sub.isCompleted)
                                                    .foregroundColor(sub.isCompleted ? primaryText.opacity(0.6) : primaryText.opacity(0.8))
                                                
                                                Spacer()
                                                
                                                Button(action: { pomodoro.deleteSubTask(parentId: task.id, subId: sub.id) }) {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(systemRed.opacity(0.7))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.leading, 28)
                                            .padding(.trailing, 4)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 0)
        }
        .accentColor(systemGreen)
        .onDisappear {
            pomodoro.saveTasks()
        }
        .contextMenu {
            Button("退出番茄钟") {
                pomodoro.saveTasks()
                NSApp.terminate(nil)
            }
        }
    }
}

struct TaskDropDelegate: DropDelegate {
    let targetId: UUID
    @Binding var draggingId: UUID?
    @Binding var tasks: [TaskItem]
    let onDrop: () -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        onDrop()
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragId = draggingId, dragId != targetId else { return }
        guard let from = tasks.firstIndex(where: { $0.id == dragId }),
              let to = tasks.firstIndex(where: { $0.id == targetId }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
