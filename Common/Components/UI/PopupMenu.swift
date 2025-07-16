import SwiftUI

// MARK: - PopupMenu
struct PopupMenu: View {
    @Binding var isPresented: Bool
    let menuItems: [PopupMenuItem]
    let menuWidth: CGFloat?
    let topOffset: CGFloat
    let trailingOffset: CGFloat
    
    init(
        isPresented: Binding<Bool>,
        menuItems: [PopupMenuItem],
        menuWidth: CGFloat? = nil,
        topOffset: CGFloat = 60,
        trailingOffset: CGFloat = 16
    ) {
        self._isPresented = isPresented
        self.menuItems = menuItems
        self.menuWidth = menuWidth
        self.topOffset = topOffset
        self.trailingOffset = trailingOffset
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 0) {
                    ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPresented = false
                            }
                            item.action()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(item.isDestructive ? .red : .primary)
                                    .frame(width: 20)
                                
                                Text(item.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(item.isDestructive ? .red : .primary)
                                
                                Spacer()
                                
                                if case .toggle(let isOn) = item.type {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                        .opacity(isOn ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.15), value: isOn)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        if index < menuItems.count - 1 {
                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .fixedSize(horizontal: menuWidth == nil, vertical: false)
                .frame(width: menuWidth)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(x: 1, y: isPresented ? 1 : 0, anchor: .top)
                .animation(.easeInOut(duration: 0.2), value: isPresented)
                .padding(.trailing, trailingOffset)
                .padding(.top, topOffset)
            }
            Spacer()
        }
    }
}

// MARK: - PopupMenuItem
struct PopupMenuItem {
    let icon: String
    let title: String
    let isDestructive: Bool
    let type: PopupMenuItemType
    let action: () -> Void
    
    // Convenience initializer for regular button
    init(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.type = .button
        self.action = action
    }
    
    // Convenience initializer for toggle button
    init(
        icon: String,
        title: String,
        isOn: Bool,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.type = .toggle(isOn)
        self.action = action
    }
}

// MARK: - PopupMenuItemType
enum PopupMenuItemType {
    case button
    case toggle(Bool)
}

// MARK: - PopupMenuButton
struct PopupMenuButton: View {
    @Binding var isPresented: Bool
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let size: CGFloat
    let cornerRadius: CGFloat
    
    init(
        isPresented: Binding<Bool>,
        icon: String = "ellipsis",
        iconColor: Color = .primary,
        backgroundColor: Color = Color(.systemGray6),
        size: CGFloat = 40,
        cornerRadius: CGFloat = 8
    ) {
        self._isPresented = isPresented
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresented.toggle()
            }
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                )
        }
    }
}

// MARK: - PopupMenuContainer
struct PopupMenuContainer<Content: View>: View {
    @Binding var isPresented: Bool
    let menuItems: [PopupMenuItem]
    let menuWidth: CGFloat?
    let topOffset: CGFloat
    let trailingOffset: CGFloat
    let content: Content
    
    init(
        isPresented: Binding<Bool>,
        menuItems: [PopupMenuItem],
        menuWidth: CGFloat? = nil,
        topOffset: CGFloat = 60,
        trailingOffset: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.menuItems = menuItems
        self.menuWidth = menuWidth
        self.topOffset = topOffset
        self.trailingOffset = trailingOffset
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
            
            if isPresented {
                PopupMenu(
                    isPresented: $isPresented,
                    menuItems: menuItems,
                    menuWidth: menuWidth,
                    topOffset: topOffset,
                    trailingOffset: trailingOffset
                )
            }
        }
        .onTapGesture {
            if isPresented {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
            }
        }
    }
}

// MARK: - Usage Example
struct PopupMenuExample: View {
    @State private var showMenu = false
    @State private var showProgress = true
    @State private var showFocusChart = true
    @State private var showSpeedSlider = true
    @State private var showingEditSheet = false
    @State private var showingLogoutAlert = false
    
    var body: some View {
        PopupMenuContainer(
            isPresented: $showMenu,
            menuItems: [
                // Toggle items
                PopupMenuItem(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress",
                    isOn: showProgress
                ) {
                    showProgress.toggle()
                },
                PopupMenuItem(
                    icon: "brain.head.profile",
                    title: "Focus Chart",
                    isOn: showFocusChart
                ) {
                    showFocusChart.toggle()
                },
                PopupMenuItem(
                    icon: "speedometer",
                    title: "Speed Slider",
                    isOn: showSpeedSlider
                ) {
                    showSpeedSlider.toggle()
                },
                // Regular button items
                PopupMenuItem(
                    icon: "pencil",
                    title: "Edit Profile"
                ) {
                    showingEditSheet = true
                },
                PopupMenuItem(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Logout",
                    isDestructive: true
                ) {
                    showingLogoutAlert = true
                }
            ]
        ) {
            VStack {
                HStack {
                    Spacer()
                    
                    PopupMenuButton(isPresented: $showMenu)
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 20) {
                    Text("Your content here")
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Toggle States:")
                            .font(.headline)
                        Text("Progress: \(showProgress ? "On" : "Off")")
                        Text("Focus Chart: \(showFocusChart ? "On" : "Off")")
                        Text("Speed Slider: \(showSpeedSlider ? "On" : "Off")")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            Text("Edit Profile Sheet")
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                // Handle logout
            }
        }
    }
}
