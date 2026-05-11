import SwiftUI
import KnowledgeVaultCore
import UIKit

// 创建新条目的视图
struct CreateEntryView: View {
    // 保存回调，返回创建条目所需的参数
    let onSave: (String, EntryType, EntrySource) -> Void
    
    // 关闭回调
    @Environment(\.dismiss) private var dismiss
    
    // 内容输入
    @State private var content: String = ""
    
    // 条目类型选择
    @State private var selectedType: EntryType = .note
    
    // 条目来源选择
    @State private var selectedSource: EntrySource = .manual
    
    // 相机和文件选择器状态
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    
    // 相机捕获的图片
    @State private var capturedImage: UIImage?
    
    // 选择的文件 URL
    @State private var selectedFileURL: URL?
    
    var body: some View {
        NavigationStack {
            Form {
                // 内容输入区域
                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    // 如果有捕获的图片，显示预览
                    if let image = capturedImage {
                        HStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button("清除") {
                                capturedImage = nil
                                // 切换回文本类型
                                selectedType = .note
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // 如果有选择的文件，显示文件名
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: "doc")
                                .foregroundStyle(.blue)
                            
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button("清除") {
                                selectedFileURL = nil
                                // 切换回文本类型
                                selectedType = .note
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // 快捷操作按钮
                Section("快捷操作") {
                    // 相机拍摄按钮
                    Button {
                        showCamera = true
                    } label: {
                        Label("拍照", systemImage: "camera")
                    }
                    
                    // 文件选择按钮
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("选择文件", systemImage: "doc")
                    }
                }
                
                // 条目类型选择
                Section("类型") {
                    Picker("条目类型", selection: $selectedType) {
                        ForEach(EntryType.allCases, id: \.self) { type in
                            Label(typeName(type), systemImage: typeIcon(type))
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 条目来源选择
                Section("来源") {
                    Picker("条目来源", selection: $selectedSource) {
                        ForEach(EntrySource.allCases, id: \.self) { source in
                            Text(sourceName(source))
                                .tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("新建条目")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveEntry()
                    }
                    .disabled(!canSave)
                }
            }
            // 相机弹窗
            .sheet(isPresented: $showCamera) {
                CameraCapture(onCapture: { image in
                    capturedImage = image
                    // 自动切换为截图类型
                    selectedType = .screenshot
                    selectedSource = .camera
                })
            }
            // 文件选择弹窗
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(onPick: { url in
                    selectedFileURL = url
                    // 自动切换为文件类型
                    selectedType = .file
                })
            }
        }
    }
    
    // 是否可以保存
    private var canSave: Bool {
        // 有文本内容，或者有捕获的图片，或者有选择的文件
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
               capturedImage != nil ||
               selectedFileURL != nil
    }
    
    // 保存条目
    private func saveEntry() {
        var finalContent = content
        
        // 如果有捕获的图片，将图片信息添加到内容
        if let image = capturedImage {
            finalContent = "[Screenshot captured at \(Date().formatted())]\n\(content)"
        }
        
        // 如果有选择的文件，将文件信息添加到内容
        if let url = selectedFileURL {
            finalContent = "[File: \(url.lastPathComponent)]\n\(content)"
        }
        
        // 调用保存回调
        onSave(finalContent, selectedType, selectedSource)
        
        // 关闭视图
        dismiss()
    }
    
    // 条目类型名称（中文）
    private func typeName(_ type: EntryType) -> String {
        switch type {
        case .note: return "笔记"
        case .screenshot: return "截图"
        case .voice: return "语音"
        case .link: return "链接"
        case .file: return "文件"
        }
    }
    
    // 条目类型图标
    private func typeIcon(_ type: EntryType) -> String {
        switch type {
        case .note: return "note.text"
        case .screenshot: return "camera"
        case .voice: return "waveform"
        case .link: return "link"
        case .file: return "doc"
        }
    }
    
    // 条目来源名称（中文）
    private func sourceName(_ source: EntrySource) -> String {
        switch source {
        case .manual: return "手动"
        case .camera: return "相机"
        case .share: return "分享"
        case .clipboard: return "剪贴板"
        }
    }
}

// EntryType 和 EntrySource 的 allCases 扩展
extension EntryType: CaseIterable {
    public static var allCases: [EntryType] {
        [.note, .screenshot, .voice, .link, .file]
    }
}

extension EntrySource: CaseIterable {
    public static var allCases: [EntrySource] {
        [.manual, .camera, .share, .clipboard]
    }
}

// 预览
#Preview {
    CreateEntryView(onSave: { content, type, source in
        print("保存: \(content), 类型: \(type), 来源: \(source)")
    })
}