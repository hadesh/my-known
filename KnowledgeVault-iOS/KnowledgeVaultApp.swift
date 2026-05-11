import SwiftUI
import KnowledgeVaultCore

@main
struct KnowledgeVaultApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.knowledgeVaultFileManager, appState.fileManager)
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            InboxView(fileManager: appState.fileManager)
                .tabItem { Label("收件箱", systemImage: "tray.and.arrow.down") }

            BrowseView()
                .tabItem { Label("浏览", systemImage: "books.vertical") }

            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }

            NavigationStack {
                ChatView(viewModel: ChatViewModel(ragPipeline: appState.ragPipeline))
            }
            .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gear") }
        }
    }
}