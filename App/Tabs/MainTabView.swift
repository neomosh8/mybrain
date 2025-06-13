import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Tab content
            TabView(selection: $selectedTab) {
                NavigationStack { HomeView() }
                    .tag(0)
                
                NavigationStack { AnalyticsView() }
                    .tag(1)
                
                NavigationStack { DeviceView() }
                    .tag(2)
                
                NavigationStack { ProfileView() }
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                Spacer()
                floatingTabBar
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
                        // Icon
                        Group {
                            if tab == .device {
                                Image("Neurolink")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 22, weight: .medium))
                            }
                        }
                        .foregroundColor(selectedTab == tab.rawValue ? .white : .white.opacity(0.6))
                        .frame(width: 26, height: 26)
                        .padding(.bottom, 2)
                        .scaleEffect(selectedTab == tab.rawValue ? 1.1 : 1.0)
                        
                        // Title
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedTab == tab.rawValue ? .white : .white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
    case analytics = 1
    case device = 2
    case profile = 3
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .analytics: return "Analytics"
        case .device: return "Device"
        case .profile: return "Profile"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .device: return ""
        case .profile: return "person.crop.circle.fill"
        }
    }
}

#Preview {
    MainTabView()
}
