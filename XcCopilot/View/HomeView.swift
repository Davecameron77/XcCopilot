//
//  HomeView.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2023-12-04.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var vm = XcCopilotViewModel()
    
    var body: some View {
        TabView {
            MapView()
                .environmentObject(vm)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag("map")

            InstrumentView()
                .environmentObject(vm)
                .tabItem {
                    Label("Instrumenrts", systemImage: "gauge")
                }
                .tag("instruments")

            LogbookView()
                .environmentObject(vm)
                .tabItem {
                    Label("Logbook", systemImage: "book")
                }
                .tag("logbook")
            
            AnalysisView()
                .environmentObject(vm)
                .tabItem {
                    Label("Analysis", systemImage: "compass.drawing")
                }
                .tag("analysis")

            SettingsView()
                .environmentObject(vm)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag("settings")
        }
        .onAppear {
            // correct the transparency bug for Tab bars
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            // correct the transparency bug for Navigation bars
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithOpaqueBackground()
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        }
        .alert(vm.alertText, isPresented: $vm.alertShowing) {
            Button("OK", role: .cancel) { }
        }
    }
}

#Preview {
    HomeView()
}
