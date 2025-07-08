import SwiftUI

// MARK: - Color Palette Options
enum PickerColorPalette: Equatable {
    case system
    case custom(foreground: Color, titleBackground: Color, contentBackground: Color)
}

// MARK: - Bottom Sheet Picker Controller
class BottomSheetPickerController: ObservableObject {
    @Published private(set) var isPresented: Bool = false
    
    func open() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = true
        }
    }
    
    func close() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// MARK: - Bottom Sheet Picker Component
struct BottomSheetPicker<Content: View>: View {
    let title: String
    let colorPalette: PickerColorPalette
    let onDismiss: (() -> Void)?
    @ViewBuilder let content: Content
    @ObservedObject var controller: BottomSheetPickerController
    
    init(
        title: String,
        controller: BottomSheetPickerController,
        colorPalette: PickerColorPalette = .system,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.controller = controller
        self.colorPalette = colorPalette
        self.onDismiss = onDismiss
        self.content = content()
    }
    
    private var foregroundColor: Color {
        switch colorPalette {
        case .system:
            return .primary
        case .custom(let foreground, _, _):
            return foreground
        }
    }
    
    private var titleBackgroundColor: Color {
        switch colorPalette {
        case .system:
            return Color(.systemBackground).opacity(0.05)
        case .custom(_, let titleBg, _):
            return titleBg
        }
    }
    
    private var contentBackgroundColor: Color {
        switch colorPalette {
        case .system:
            return Color(.systemBackground)
        case .custom(_, _, let contentBg):
            return contentBg
        }
    }
    
    private var overlayBorderColor: Color {
        switch colorPalette {
        case .system:
            return Color.secondary.opacity(0.2)
        case .custom(let foreground, _, _):
            return foreground.opacity(0.2)
        }
    }
    
    private func handleDismiss() {
        controller.close()
        onDismiss?()
    }
    
    var body: some View {
        Group {
            if controller.isPresented {
                pickerView
            }
        }
    }
    
    private var pickerView: some View {
        ZStack {
            overlayBackground
            pickerContent
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
    }
    
    private var overlayBackground: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea(.all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture {
                handleDismiss()
            }
    }
    
    private var pickerContent: some View {
        VStack {
            Spacer()
            pickerContainer
        }
    }
    
    private var pickerContainer: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().background(overlayBorderColor)
            contentSection
        }
        .background(containerBackground)
        .padding(.horizontal, 16)
        .padding(.bottom, 34)
    }
    
    private var headerSection: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(foregroundColor)
            
            Spacer()
            
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
            .fill(titleBackgroundColor)
        )
    }
    
    private var closeButton: some View {
        Button(action: { handleDismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(foregroundColor)
                .padding(8)
                .background(closeButtonBackground)
        }
    }
    
    private var closeButtonBackground: some View {
        Circle().fill(
            colorPalette == .system ?
            Color.gray.opacity(0.2) :
                foregroundColor.opacity(0.2)
        )
    }
    
    private var contentSection: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(contentBackgroundColor)
            )
    }
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(contentBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(overlayBorderColor, lineWidth: 1)
            )
    }
}

// MARK: - Convenience Extensions
extension BottomSheetPicker {
    init(
        title: String,
        controller: BottomSheetPickerController,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            controller: controller,
            colorPalette: .system,
            onDismiss: onDismiss,
            content: content
        )
    }
}

// MARK: - Preview Helper Views
struct PreviewSystemPicker: View {
    @StateObject private var controller = BottomSheetPickerController()
    
    var body: some View {
        VStack {
            Button("Show System Color Picker") {
                controller.open()
            }
            .padding()
            
            BottomSheetPicker(
                title: "Select Gender",
                controller: controller
            ) {
                VStack(spacing: 0) {
                    ForEach([
                        ("M", "Male"),
                        ("F", "Female"),
                        ("O", "Other")
                    ], id: \.0) { value, label in
                        Button(action: {
                            controller.close()
                        }) {
                            HStack {
                                Text(label)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 16))
                                Spacer()
                                if value == "M" {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if value != "O" {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

struct PreviewCustomPicker: View {
    @StateObject private var controller = BottomSheetPickerController()
    
    var body: some View {
        VStack {
            Button("Show Custom Color Picker") {
                controller.open()
            }
            .padding()
            
            BottomSheetPicker(
                title: "Select Birthdate",
                controller: controller,
                colorPalette: .custom(
                    foreground: .white,
                    titleBackground: Color.white.opacity(0.05),
                    contentBackground: Color(red: 0.05, green: 0.05, blue: 0.1)
                )
            ) {
                DatePicker("", selection: .constant(Date()), displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .colorScheme(.dark)
                    .accentColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview
struct BottomSheetPicker_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewSystemPicker()
                .previewDisplayName("System Colors")
            
            PreviewCustomPicker()
                .previewDisplayName("Custom Colors")
        }
    }
}
