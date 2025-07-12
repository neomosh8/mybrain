import SwiftUI

// MARK: - PopupMenu
struct PopupMenu: View {
    @Binding var isPresented: Bool
    let menuItems: [PopupMenuItem]
    let menuWidth: CGFloat
    let topOffset: CGFloat
    let trailingOffset: CGFloat
    
    init(
        isPresented: Binding<Bool>,
        menuItems: [PopupMenuItem],
        menuWidth: CGFloat = 180,
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
    let action: () -> Void
    
    init(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
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
    let menuWidth: CGFloat
    let topOffset: CGFloat
    let trailingOffset: CGFloat
    let content: Content
    
    init(
        isPresented: Binding<Bool>,
        menuItems: [PopupMenuItem],
        menuWidth: CGFloat = 180,
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
    @State private var showingEditSheet = false
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        PopupMenuContainer(
            isPresented: $showMenu,
            menuItems: [
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
                },
                PopupMenuItem(
                    icon: "trash",
                    title: "Delete Account",
                    isDestructive: true
                ) {
                    showingDeleteAlert = true
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
                
                Text("Your content here")
                    .font(.title)
                
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
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // Handle delete
            }
        }
    }
}
