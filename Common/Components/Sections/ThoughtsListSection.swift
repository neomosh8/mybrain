import SwiftUI

// MARK: - Thoughts List Section
struct ThoughtsListSection: View {
    @Binding var showSearchField: Bool
    @Binding var searchText: String
    let thoughts: [Thought]
    let selectedMode: ContentMode
    let onThoughtTap: (Thought) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with title and search
            if showSearchField {
                SearchFieldView(
                    searchText: $searchText,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSearchField = false
                            searchText = ""
                        }
                    }
                )
            } else {
                ThoughtsHeaderView(
                    onSearchTap: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSearchField = true
                        }
                    }
                )
            }
            
            // Thoughts List
            if thoughts.isEmpty {
                EmptyThoughtsView(isSearching: !searchText.isEmpty)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(thoughts) { thought in
                        ThoughtCard(thought: thought) {
                            onThoughtTap(thought)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Thoughts Header View
struct ThoughtsHeaderView: View {
    let onSearchTap: () -> Void
    
    var body: some View {
        HStack {
            Text("Your Thoughts")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: onSearchTap) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

// MARK: - Search Field View
struct SearchFieldView: View {
    @Binding var searchText: String
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search thoughts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

// MARK: - Empty Thoughts View
struct EmptyThoughtsView: View {
    let isSearching: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isSearching ? "magnifyingglass" : "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(isSearching ? "No thoughts found" : "No thoughts yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isSearching ? "Try adjusting your search terms" : "Add your first thought to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }
}
