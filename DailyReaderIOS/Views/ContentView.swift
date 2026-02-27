import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                OnboardingView()
            }
            .tabItem {
                Label("Plan", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                DailyFeedView()
            }
            .tabItem {
                Label("Daily", systemImage: "book.pages")
            }

            NavigationStack {
                WeeklyWrapView()
            }
            .tabItem {
                Label("Weekly", systemImage: "chart.bar.doc.horizontal")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .tint(Color("AccentColor"))
    }
}
