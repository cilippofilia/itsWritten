//
//  HomeView.swift
//  itsWritten
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import PrivateAds
import SwiftData
import SwiftUI

/// The app's root once onboarding is done.
///
/// The composer is always the main view. In wide windows (iPad, iPhone Duo's inner
/// display) history is a sidebar beside it; in narrow ones it's pushed from the menu, as on
/// iPhone. One `NavigationSplitView` serves every width, so opening or closing iPhone Duo,
/// or resizing a window, changes the layout without resetting the conversation.
struct HomeView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel
    @Environment(CrossPromoSignal.self) private var crossPromoSignal
    @Environment(RemoveAdsStore.self) private var removeAdsStore
    @Environment(PubMedToolStore.self) private var pubMedStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var config = ModelConfiguration()
    @State private var responseType = ModelResponseType.standard
    @State private var presentedSheet: SheetType?
    @State private var conversationViewModel = ConversationViewModel()
    @State private var interstitialAd: Ad?
    @State private var isInterstitialPending = false
    @State private var showNewChatConfirmation = false
    @State private var newChatTransition = NewChatTransition()

    /// The sidebar starts hidden so wide windows open on the composer, like iPhone.
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    /// Narrow windows always show the composer column; the sidebar is never shown there.
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail
    /// History pushed on top of the composer in narrow windows.
    @State private var isHistoryPushed = false

    private var isWide: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            preferredCompactColumn: $preferredCompactColumn
        ) {
            ChatHistoryView(onSelect: resume)
        } detail: {
            NavigationStack {
                HomeContentView(
                    config: $config,
                    responseType: $responseType
                )
                // When collapsed, SwiftUI would otherwise add a back button (and swipe) to
                // the sidebar. The composer is the main view, so history is reached from
                // the menu instead.
                .navigationBarBackButtonHidden(isWide == false)
                .background {
                    if #available(iOS 27.1, *) {
                        ToolbarVerticalEdgeReader { edge in
                            newChatTransition.toolbarVerticalEdge = edge
                        }
                    }
                }
                .navigationDestination(isPresented: $isHistoryPushed) {
                    ChatHistoryView(onSelect: resume)
                }
                .toolbar {
                    if conversationViewModel.mode == .chatting {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("New Chat", systemImage: "plus", action: confirmNewChat)
                                .disabled(newChatTransition.isActive)
                                .keyboardShortcut("n", modifiers: .command)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        MenuButtonView(
                            showWhyAI: showWhyAI,
                            showOnboarding: showOnboarding,
                            showHistory: showHistory,
                            showSettings: showSettings,
                            deliveryCount: newChatTransition.deliveryCount
                        )
                    }
                }
            }
        }
        .onGeometryChange(for: ContainerGeometry.self) { proxy in
            ContainerGeometry(frame: proxy.frame(in: .global), safeAreaInsets: proxy.safeAreaInsets)
        } action: { geometry in
            newChatTransition.containerFrame = geometry.frame
            newChatTransition.containerSafeAreaInsets = geometry.safeAreaInsets
        }
        .overlay {
            if newChatTransition.isActive {
                FoldingLetterView(transition: newChatTransition)
            }
        }
        .alert("Start a new chat?", isPresented: $showNewChatConfirmation) {
            Button("Cancel", role: .cancel) {}
            // The preferred action is drawn as the alert's prominent, tinted button.
            Button("New Chat", action: startNewChat)
                .keyboardShortcut(.defaultAction)
        } message: {
            Text("This conversation is saved in History.")
        }
        .sheet(item: $presentedSheet) { sheet in
            HomeSheetView(sheet: sheet, config: $config, responseType: $responseType)
        }
        .onAppear(perform: configureConversation)
        .onChange(of: horizontalSizeClass) { _, newSizeClass in
            // Unfolding iPhone Duo (or widening a window) while history is pushed moves it
            // into the sidebar instead of leaving a pushed copy behind.
            guard newSizeClass == .regular, isHistoryPushed else { return }
            isHistoryPushed = false
            columnVisibility = .all
        }
        .environment(conversationViewModel)
        .environment(newChatTransition)
        // A PrivateAds cross-promo ad every 3rd new chat started (see `CrossPromoSignal`,
        // bumped from `ConversationViewModel.persistCurrentTurn` when a brand-new thread is
        // first saved). The interstitial waits for the user to return to the composer
        // (`mode == .composing`) before showing, so it never interrupts an in-progress
        // conversation.
        .fullScreenCover(item: $interstitialAd) { ad in
            AdView(advert: ad, config: .crossPromo) {
                CrossPromoRemoveAdsInfoView()
            }
        }
        .onChange(of: crossPromoSignal.count) { _, newValue in
            guard removeAdsStore.isAdsRemoved == false, newValue > 0, newValue.isMultiple(of: 3) else { return }
            isInterstitialPending = true
        }
        .onChange(of: conversationViewModel.mode) { _, newMode in
            guard newMode == .composing, isInterstitialPending else { return }
            isInterstitialPending = false
            Task { await refreshInterstitialAd() }
        }
        // Dismiss an ad the user is mid-way through if they buy "Remove Ads" from its own paywall.
        .onChange(of: removeAdsStore.isAdsRemoved) { _, isAdsRemoved in
            guard isAdsRemoved else { return }
            interstitialAd = nil
        }
    }

    private func configureConversation() {
        conversationViewModel.configure(
            modelContext: modelContext,
            pubMedStore: pubMedStore,
            crossPromoSignal: crossPromoSignal
        )
        conversationViewModel.prewarmIdleSession(config: config)
    }

    private func resume(_ thread: ChatThread) {
        conversationViewModel.resume(thread: thread, config: config)
        isHistoryPushed = false
        preferredCompactColumn = .detail
    }

    private func confirmNewChat() {
        showNewChatConfirmation = true
    }

    /// Folds the conversation into a letter and posts it into the menu button, resetting
    /// the conversation underneath once the paper covers it.
    private func startNewChat() {
        newChatTransition.layoutDirection = layoutDirection
        newChatTransition.start(
            messages: conversationViewModel.messages,
            title: conversationViewModel.title,
            reduceMotion: reduceMotion
        ) {
            conversationViewModel.reset(config: config)
        }
    }

    private func showHistory() {
        if isWide {
            columnVisibility = .all
        } else {
            isHistoryPushed = true
        }
    }

    private func showWhyAI() {
        presentedSheet = .whyAI
    }

    private func showSettings() {
        presentedSheet = .settings
    }

    private func showOnboarding() {
        presentedSheet = nil
        hasCompletedOnboarding = false
    }

    private func refreshInterstitialAd() async {
        guard removeAdsStore.isAdsRemoved == false else { return }
        guard let url = AdConfiguration.crossPromo.adsJSONURL else { return }
        interstitialAd = try? await AdStore.fetchRandomAd(
            from: url,
            excludedIDs: AdConfiguration.crossPromo.excludedIDs
        )
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
        .environment(CrossPromoSignal())
        .environment(RemoveAdsStore())
        .environment(PubMedToolStore.shared)
        .modelContainer(for: [ChatThread.self, ChatMessage.self], inMemory: true)
}
