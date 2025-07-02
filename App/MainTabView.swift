import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    @State private var thoughtsViewModel: ThoughtsViewModel?
    
    var body: some View {
        ZStack {
            if let thoughtsViewModel = thoughtsViewModel {
                currentTabContent(thoughtsViewModel: thoughtsViewModel)
            } else {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            VStack {
                Spacer()
                floatingTabBar
            }
        }
        .onAppear {
            if thoughtsViewModel == nil {
                setupServices()
            }
        }
    }
    
    private func setupServices() {
        self.thoughtsViewModel = ThoughtsViewModel()
    }
    
    @ViewBuilder
    private func currentTabContent(thoughtsViewModel: ThoughtsViewModel) -> some View {
        switch selectedTab {
        case 0:
            NavigationStack {
                HomeView(
                    onNavigateToDevice: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 2
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        case 1:
            NavigationStack {
                ProfileView(
                    onNavigateToHome: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = 0
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        case 2:
            NavigationStack {
                DeviceView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        case 3:
            NavigationStack {
                SettingsView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        default:
            NavigationStack {
                HomeView(
                    onNavigateToDevice: {
                        selectedTab = 2
                    }
                )
            }
        }
    }
    
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab.rawValue
                    }
                }) {
                    VStack(spacing: 4) {
                        Group {
                            if tab == .device {
                                Image("Neurolink")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 20, weight: .medium))
                            }
                        }
                        .foregroundColor(selectedTab == tab.rawValue ? .white : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .scaleEffect(selectedTab == tab.rawValue ? 1.1 : 1.0)
                        
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedTab == tab.rawValue ? .white : .white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.8))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
}

enum TabItem: Int, CaseIterable {
    case home = 0
    case profile = 1
    case device = 2
    case settings = 3
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .profile: return "Profile"
        case .device: return "Device"
        case .settings: return "Settings"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house"
        case .profile: return "person"
        case .device: return ""
        case .settings: return "gearshape"
        }
    }
}
