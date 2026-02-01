//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @State private var config = ModelConfiguration()
    @State private var presentedSheet: SheetType?
    @State private var session = LanguageModelSession()
    @State private var showHistoryView = false
    @State private var shouldSend = false

    var body: some View {
        NavigationStack {
            HomeContentView(
                shouldSend: $shouldSend,
                session: session
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarMenu
                }
            }
            .sheet(item: $presentedSheet) { sheet in
                sheet.view
            }
            .navigationDestination(isPresented: $showHistoryView) {
                HistoryView()
            }
        }
    }

    private var toolbarMenu: some View {
        GlassEffectContainer {
            MenuButtonView(
                showWhyAISheet: .init(
                    get: { presentedSheet == .whyAI },
                    set: { if $0 { presentedSheet = .whyAI } else { presentedSheet = nil } }
                ),
                showLanguageSupportSheet: .init(
                    get: { presentedSheet == .languageSupport },
                    set: { if $0 { presentedSheet = .languageSupport } else { presentedSheet = nil } }
                ),
                showHistoryView: $showHistoryView,
                showSettings: .init(
                    get: { presentedSheet == .settings($config) },
                    set: { if $0 { presentedSheet = .settings($config) } else { presentedSheet = nil } }
                ),
            )
        }
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
}
