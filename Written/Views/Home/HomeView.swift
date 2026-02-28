//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

struct HomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @State private var config = ModelConfiguration()
    @State private var responseType = ModelResponseType.standard
    @State private var presentedSheet: SheetType?
    @State private var session = AppLanguageModel.session()
    @State private var showChatHistoryView = false
    @State private var shouldSend = false

    var body: some View {
        NavigationStack {
            HomeContentView(
                shouldSend: $shouldSend,
                config: $config,
                responseType: $responseType,
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
            .onAppear {
                session = AppLanguageModel.session(instructions: config.instructions)
                session.prewarm(promptPrefix: .init(config.instructions))
            }
            .navigationDestination(isPresented: $showChatHistoryView) {
                ChatHistoryView(
                    config: $config,
                    responseType: $responseType
                )
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
                showChatHistoryView: $showChatHistoryView,
                showSettings: .init(
                    get: { presentedSheet == .settings($config, $responseType) },
                    set: {
                        if $0 {
                            presentedSheet = .settings($config, $responseType)
                        } else {
                            presentedSheet = nil
                        }
                    }
                ),
                showOnboarding: {
                    presentedSheet = nil
                    hasCompletedOnboarding = false
                }
            )
        }
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
}
