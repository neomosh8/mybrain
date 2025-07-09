import SwiftUI
import SwiftData
import Charts

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var showLogoutError = false
    @State private var logoutErrorMessage = ""
    
    @State private var showMenu = false
    @State private var showingEditProfileSheet = false
    
    var onNavigateToHome: (() -> Void)?
    
    init(onNavigateToHome: (() -> Void)? = nil) {
        self.onNavigateToHome = onNavigateToHome
    }
    
    private func performLogout() {
        isLoggingOut = true
        
        authVM.logout(context: modelContext) { result in
            DispatchQueue.main.async {
                isLoggingOut = false
                
                switch result {
                case .success:
                    print("Logout successful")
                case .failure(let error):
                    logoutErrorMessage = error.localizedDescription
                    showLogoutError = true
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    ProfileHeaderView()
                    
                    VStack(spacing: 24) {
                        AttentionCapacityCard(
                            currentPercentage: 78,
                            yesterdayChange: 5,
                            activeHours: 2.5,
                            totalThoughts: 12
                        )
                        
                        PerformanceOverviewSection()
                        
                        InsightsRecommendationsSection()
                        
                        WeeklyTrendsSection()
                        
                        ThoughtHistorySection()
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
            }
            .customNavigationBar(
                title: "Profile",
                onBackTap: {
                    onNavigateToHome?()
                }
            ) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showMenu.toggle()
                    }
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            // Popup Menu
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { showMenu = false }
                            showingEditProfileSheet = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 20)
                                Text("Edit Profile")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        Divider().padding(.horizontal, 8)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) { showMenu = false }
                            showingLogoutAlert = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(width: 20)
                                Text("Logout")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .frame(width: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
                    .scaleEffect(x: 1, y: showMenu ? 1 : 0, anchor: .top)
                    .animation(.easeInOut(duration: 0.2), value: showMenu)
                    .padding(.trailing, 16)
                    .padding(.top, 60)
                }
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showingEditProfileSheet) {
            EditProfileView()
        }
        .onTapGesture {
            if showMenu {
                withAnimation {
                    showMenu = false
                }
            }
        }
        .alert("Logout", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Logout Error", isPresented: $showLogoutError) {
            Button("OK") { }
        } message: {
            Text(logoutErrorMessage)
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                avatarSection
                userInfoSection
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
    }
    
    private let memberSinceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private let dateJoinedInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()
    
    private var memberSinceText: String {
        guard let dateJoinedString = authVM.profileManager.currentProfile?.dateJoined else {
            return "Member since unknown"
        }
        
        if let date = dateJoinedInputFormatter.date(from: dateJoinedString) {
            return "Member since \(memberSinceDateFormatter.string(from: date))"
        }
        
        return "Member since unknown"
    }
    
    private var avatarSection: some View {
        CachedAvatarView(
            avatarUrl: authVM.profileManager.currentProfile?.avatarUrl,
            size: 80,
            initials: getInitials()
        )
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(getDisplayName())
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(authVM.profileManager.currentProfile?.email ?? "")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(memberSinceText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // Helper functions
    private func getDisplayName() -> String {
        let profile = authVM.profileManager.currentProfile
        let firstName = profile?.firstName ?? ""
        let lastName = profile?.lastName ?? ""
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        if !fullName.isEmpty {
            return fullName
        }
        
        return profile?.email?.components(separatedBy: "@").first?.capitalized ?? "User"
    }
    
    private func getInitials() -> String {
        let profile = authVM.profileManager.currentProfile
        let firstName = profile?.firstName ?? ""
        let lastName = profile?.lastName ?? ""
        
        if !firstName.isEmpty || !lastName.isEmpty {
            let firstInitial = firstName.isEmpty ? "" : String(firstName.prefix(1)).uppercased()
            let lastInitial = lastName.isEmpty ? "" : String(lastName.prefix(1)).uppercased()
            return "\(firstInitial)\(lastInitial)"
        }
        
        if let email = profile?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        
        return "U"
    }
}


// MARK: - Analytics Components
struct AttentionCapacityCard: View {
    let currentPercentage: Int
    let yesterdayChange: Int
    let activeHours: Double
    let totalThoughts: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your Current Attention Capacity")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Main circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(currentPercentage) / 100)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.5), value: currentPercentage)
                
                VStack(spacing: 2) {
                    Text("\(currentPercentage)%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Excellent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.vertical, 24)
            
            // Bottom stats
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(yesterdayChange >= 0 ? "+\(yesterdayChange)%" : "\(yesterdayChange)%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("vs yesterday")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1fh", activeHours))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("active today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 4) {
                    Text("\(totalThoughts)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("thoughts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue,
                            Color.blue.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct PerformanceOverviewSection: View {
    @State private var selectedPeriod: String = "Today"
    let periods = ["Today", "Week", "Month"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Overview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Period selector
            HStack(spacing: 8) {
                ForEach(periods, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                    }) {
                        Text(period)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedPeriod == period ? .white : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedPeriod == period ? Color.blue : Color.blue.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            
            Text(
                "Below is a representation your attention capacity for the first minute of typical listening."
            )
            .font(.body)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.bottom, 42)
            
            
            Text("Your Average Attention Capacity Per Minutes")
                .font(.subheadline)
                .padding(.bottom, 8)
            
            
            AnimatedLineChartView()
                .frame(height: 300)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
            
            // Legend
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    
                    Text("Utilized Attention")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text("Usual Attention")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}


struct InsightsRecommendationsSection: View {
    let insights: [InsightItem] = [
        InsightItem(
            icon: "timer",
            iconColor: .blue,
            title: "Enhanced Attention",
            subtitle: "Focus development",
            description: "Your attention span has improved from 12 to 19 seconds, increasing your capacity to stay engaged in tasks longer."
        ),
        InsightItem(
            icon: "moon.fill",
            iconColor: .indigo,
            title: "Optimal Focus Time",
            subtitle: "Timing optimization",
            description: "You're most attentive after 11 PM. Prioritize deep work or creative tasks during this period."
        ),
        InsightItem(
            icon: "bolt.fill",
            iconColor: .yellow,
            title: "Energy Peaks",
            subtitle: "Energy management",
            description: "Your energy levels spike in the early afternoon—ideal for critical thinking and high-effort tasks."
        ),
        InsightItem(
            icon: "leaf.arrow.circlepath",
            iconColor: .green,
            title: "Relaxation Reminder",
            subtitle: "Stress recovery",
            description: "Incorporate short, mindful pauses throughout your day to reset focus and prevent burnout."
        ),
        InsightItem(
            icon: "checkmark.seal.fill",
            iconColor: .teal,
            title: "Routine Strength",
            subtitle: "Consistency building",
            description: "Sustain your performance improvements by sticking to regular habits and schedules."
        ),
        InsightItem(
            icon: "chart.bar.fill",
            iconColor: .purple,
            title: "Milestone Tracking",
            subtitle: "Goal motivation",
            description: "Track progress toward your goals and celebrate achievements to reinforce momentum and commitment."
        )
    ]

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights & Recommendations")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(insights) { insight in
                        InsightCardView(insight: insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct InsightItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

struct WeeklyTrendsSection: View {
    let trends: [TrendItem] = [
        TrendItem(percentage: 85, label: "Weekly Goal", change: "+12% this week", color: .green),
        TrendItem(percentage: 67, label: "Consistency", change: "5 days streak", color: .blue),
        TrendItem(percentage: 92, label: "Retention", change: "Excellent", color: .orange)
    ]
    
    let badges = ["Focus Master", "5 Day Streak"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Trends")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                ForEach(trends) { trend in
                    TrendCircleView(trend: trend)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Badges
            HStack(spacing: 12) {
                ForEach(badges, id: \.self) { badge in
                    HStack(spacing: 6) {
                        Image(systemName: badge == "Focus Master" ? "brain.head.profile" : "calendar.badge.plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(badge)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(badge == "Focus Master" ? Color.blue : Color.green)
                    )
                }
                
                Spacer()
            }
        }
    }
}

struct TrendCircleView: View {
    let trend: TrendItem
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(trend.color.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? CGFloat(trend.percentage) / 100 : 0)
                    .stroke(trend.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.2), value: animateProgress)
                
                Text("\(trend.percentage)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 2) {
                Text(trend.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(trend.change)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(trend.color)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animateProgress = true
            }
        }
    }
}

struct TrendItem: Identifiable {
    let id = UUID()
    let percentage: Int
    let label: String
    let change: String
    let color: Color
}

struct ThoughtHistorySection: View {
    @State private var showFilter = false
    
    let thoughts: [ThoughtItem] = [
        ThoughtItem(
            title: "Productivity Mastery",
            subtitle: "Chapter 8 • Today 2:30 PM",
            score: 89,
            scoreType: "Focus score",
            progress: 1.0,
            color: .green
        ),
        ThoughtItem(
            title: "Deep Work Principles",
            subtitle: "Audio • Today 10:15 AM",
            score: 76,
            scoreType: "Attention",
            progress: 0.75,
            color: .blue
        ),
        ThoughtItem(
            title: "Neuroscience Basics",
            subtitle: "Chapter 3 • Yesterday 4:45 PM",
            score: 82,
            scoreType: "Retention",
            progress: 0.82,
            color: .orange
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Thought History")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    showFilter.toggle()
                }) {
                    Text("Filter")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            LazyVStack(spacing: 12) {
                ForEach(thoughts) { thought in
                    ThoughtRowView(thought: thought)
                }
            }
        }
    }
}

struct ThoughtRowView: View {
    let thought: ThoughtItem
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(thought.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(thought.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(thought.color)
                            .frame(width: geometry.size.width * thought.progress, height: 4)
                    }
                }
                .frame(height: 4)
                
                Text("\(Int(thought.progress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(thought.score)%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(thought.scoreType)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}

struct ThoughtItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let score: Int
    let scoreType: String
    let progress: Double
    let color: Color
}



// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthViewModel
    
    @StateObject private var genderPicker = BottomSheetPickerController()
    @StateObject private var birthdatePicker = BottomSheetPickerController()
    @StateObject private var avatarPicker = BottomSheetPickerController()
    
    @State private var editedFirstName = ""
    @State private var editedLastName = ""
    @State private var editedBirthdate = ""
    @State private var editedGender = ""
    @State private var editedDate = Date()
    
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUpdatingAvatar = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private let serverDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private func loadProfileData() {
        editedFirstName = authVM.profileManager.currentProfile?.firstName ?? ""
        editedLastName = authVM.profileManager.currentProfile?.lastName ?? ""
        editedBirthdate = authVM.profileManager.currentProfile?.birthdate ?? ""
        editedGender = authVM.profileManager.currentProfile?.gender ?? ""
        
        if let birthdateString = authVM.profileManager.currentProfile?.birthdate,
           let date = serverDateFormatter.date(from: birthdateString) {
            editedDate = date
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Edit Profile")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Save") {
                            saveProfile()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color.secondary.opacity(0.3))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Avatar Section
                            avatarSection
                            
                            // Form Fields
                            VStack(spacing: 20) {
                                textField(title: "First Name", text: $editedFirstName, icon: "person")
                                textField(title: "Last Name", text: $editedLastName, icon: "person.badge.plus")
                                
                                // Birthdate Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Birthdate")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        birthdatePicker.open()
                                    }) {
                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.secondary.opacity(0.7))
                                                .frame(width: 20)
                                            
                                            Text(editedBirthdate.isEmpty ? "Select birthdate" : dateFormatter.string(from: editedDate))
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(editedBirthdate.isEmpty ? .secondary.opacity(0.6) : .primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.secondary.opacity(0.6))
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.secondary.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                // Gender Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Gender")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Button(action: {
                                        genderPicker.open()
                                    }) {
                                        HStack {
                                            Image(systemName: "person.2")
                                                .foregroundColor(.secondary.opacity(0.7))
                                                .frame(width: 20)
                                            
                                            Text(getGenderDisplayText())
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(editedGender.isEmpty ? .secondary.opacity(0.6) : .primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.secondary.opacity(0.6))
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.secondary.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                    }
                }
                
                
                // Date Picker
                BottomSheetPicker(
                    title: "Select Birthdate",
                    controller: birthdatePicker,
                    colorPalette: .system
                ) {
                    DatePicker("", selection: $editedDate, displayedComponents: .date)
                        .datePickerStyle(WheelDatePickerStyle())
                        .colorScheme(.light)
                        .accentColor(.blue)
                        .onChange(of: editedDate) { _, newValue in
                            editedBirthdate = serverDateFormatter.string(from: newValue)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                        )
                }
                
                // Gender Picker
                BottomSheetPicker(
                    title: "Select Gender",
                    controller: genderPicker,
                    colorPalette: .system
                ) {
                    VStack(spacing: 0) {
                        ForEach([
                            ("M", "Male"),
                            ("F", "Female"),
                            ("O", "Other"),
                            ("P", "Prefer not to say")
                        ], id: \.0) { value, label in
                            Button(action: {
                                editedGender = value
                                genderPicker.close()
                            }) {
                                HStack {
                                    Text(label)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                    
                                    if editedGender == value {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.primary)
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemBackground))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if value != "P" {
                                Divider()
                            }
                        }
                    }
                }
                
                // Avatar Picker
                BottomSheetPicker(
                    title: "Change Profile Photo",
                    controller: avatarPicker,
                    colorPalette: .system
                ) {
                    VStack(spacing: 0) {
                        Button(action: {
                            imagePickerSourceType = .camera
                            showImagePicker = true
                            avatarPicker.close()
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                
                                Text("Camera")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        Button(action: {
                            imagePickerSourceType = .photoLibrary
                            showImagePicker = true
                            avatarPicker.close()
                        }) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                
                                Text("Photo Library")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if authVM.profileManager.hasAvatar {
                            Divider()
                            
                            Button(action: {
                                removeAvatar()
                                avatarPicker.close()
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    
                                    Text("Remove Photo")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemBackground))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .onAppear {
            loadProfileData()
        }
        // Image Picker
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: imagePickerSourceType) { image in
                uploadProfileImage(image)
            }
        }
    }
    
    // MARK: - Avatar Section
    private var avatarSection: some View {
        VStack(spacing: 16) {
            ZStack {
                CachedAvatarView(
                    avatarUrl: authVM.profileManager.currentProfile?.avatarUrl,
                    size: 120,
                    initials: getInitials()
                )
                
                if isUpdatingAvatar {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 120, height: 120)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
                
                Button(action: {
                    avatarPicker.open()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.blue.opacity(0.4), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isUpdatingAvatar)
                .opacity(isUpdatingAvatar ? 0.6 : 1.0)
                .offset(x: 40, y: 40)
            }
            .frame(width: 120, height: 120)
        }
    }
    
    // MARK: - Text Field Component
    private func textField(title: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary.opacity(0.7))
                    .frame(width: 20)
                
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text("Enter \(title.lowercased())")
                            .foregroundColor(.secondary.opacity(0.6))
                            .font(.system(size: 16))
                    }
                    
                    TextField("", text: text)
                        .autocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .foregroundColor(.primary)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func getInitials() -> String {
        let profile = authVM.profileManager.currentProfile
        let firstName = profile?.firstName ?? ""
        let lastName = profile?.lastName ?? ""
        
        if !firstName.isEmpty || !lastName.isEmpty {
            let firstInitial = firstName.isEmpty ? "" : String(firstName.prefix(1)).uppercased()
            let lastInitial = lastName.isEmpty ? "" : String(lastName.prefix(1)).uppercased()
            return "\(firstInitial)\(lastInitial)"
        }
        
        if let email = profile?.email, !email.isEmpty {
            return String(email.prefix(1)).uppercased()
        }
        
        return "U"
    }
    
    private func getGenderDisplayText() -> String {
        switch editedGender {
        case "M": return "Male"
        case "F": return "Female"
        case "O": return "Other"
        case "P": return "Prefer not to say"
        default: return "Select gender"
        }
    }
    
    // MARK: - Profile Actions
    private func saveProfile() {
        guard authVM.profileManager.currentProfile != nil else { return }
        
        authVM.updateProfile(
            firstName: editedFirstName.isEmpty ? "" : editedFirstName,
            lastName: editedLastName.isEmpty ? "" : editedLastName,
            birthdate: editedBirthdate.isEmpty ? "" : editedBirthdate,
            gender: editedGender.isEmpty ? nil : editedGender,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dismiss()
                    }
                case .failure(let error):
                    print("Error updating profile: \(error)")
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUpdatingAvatar = true
        
        authVM.profileManager.uploadAvatarWithCache(
            imageData: imageData,
            context: modelContext
        ) { result in
            DispatchQueue.main.async {
                isUpdatingAvatar = false
                switch result {
                case .success(let userProfile):
                    if let newAvatarUrl = userProfile.avatarUrl {
                        AvatarImageCache.shared.updateAvatarCache(with: newAvatarUrl)
                    }
                    print("Profile image updated successfully")
                case .failure(let error):
                    print("Error uploading profile image: \(error)")
                }
            }
        }
    }
    
    private func removeAvatar() {
        isUpdatingAvatar = true
        
        authVM.profileManager.deleteAvatarWithCache(context: modelContext) { result in
            DispatchQueue.main.async {
                isUpdatingAvatar = false
                switch result {
                case .success:
                    AvatarImageCache.shared.updateAvatarCache(with: nil)
                    print("Profile image removed successfully")
                case .failure(let error):
                    print("Error removing profile image: \(error)")
                }
            }
        }
    }
}


// MARK: - Image Picker
struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
