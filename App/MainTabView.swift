import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: TabItem = .home
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
        case TabItem.home:
            NavigationStack {
                HomeView(
                    thoughtsViewModel: thoughtsViewModel,
                    onNavigateToDevice: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = TabItem.device
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        case TabItem.profile:
            NavigationStack {
                ProfileView(
                    onNavigateToHome: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = TabItem.home
                        }
                    })
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        case TabItem.device:
            NavigationStack {
                DeviceView(
                    onNavigateToHome: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = TabItem.home
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        case TabItem.settings:
            NavigationStack {
                SettingsView(
                    onNavigateToHome: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = TabItem.home
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
    }
    
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = TabItem(rawValue: tab.rawValue) ?? .home
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
                        .foregroundColor(selectedTab == TabItem(rawValue: tab.rawValue) ? .white : .white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .scaleEffect(selectedTab == TabItem(rawValue: tab.rawValue) ? 1.1 : 1.0)
                        
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedTab == TabItem(rawValue: tab.rawValue) ? .white : .white.opacity(0.6))
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
