import SwiftUI

struct PreferencesView: View {
    @Bindable var store: AppStore
    var body: some View {
        Form {
            Section("浮动分支图") {
                Toggle("置顶显示", isOn: $store.preferences.widgetPinned)
                    .onChange(of: store.preferences.widgetPinned) { store.save(); WindowCoordinator.shared.updateWidget() }
                Button("显示小组件", systemImage: "pip.enter") { WindowCoordinator.shared.showWidget() }
            }
            Section("仓库") {
                Button("添加本地仓库…", systemImage: "folder.badge.plus") { store.chooseRepository() }
                LabeledContent("自动刷新", value: "当前仓库与浮窗每 5 秒")
                LabeledContent("其他仓库", value: "约每 60 秒")
                Text("远程引用由 Fetch 更新。Branchlet 不会自动提交、合并或推送代码。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("关于") {
                LabeledContent("Branchlet", value: "0.1.0")
                Link("GitHub · pj-workspace/Branchlet", destination: URL(string: "https://github.com/pj-workspace/Branchlet")!)
                Text("设置与仓库路径只保存在本机。玻璃材质与动效跟随系统辅助功能设置。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).frame(width: 480, height: 440)
    }
}
