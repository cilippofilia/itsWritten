//
//  HomeView.swift
//  written
//
//  Created by Filippo Cilia on 03/09/2025.
//

import FoundationModels
import SwiftUI

struct HomeView: View {
    @AppStorage("selectedPromptID") private var selectedModelID: String = ""

    @Environment(HomeViewModel.self) private var viewModel
    @Environment(CountdownViewModel.self) private var countDownViewModel

    @State private var presentedSheet: SheetType?
    @State private var showHistoryView = false
    @State private var shouldSend = false

    var body: some View {
        NavigationStack {
            HomeContentView(shouldSend: $shouldSend)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HomeToolbarMenu(
                            selectedModel: .init(
                                get: { viewModel.selectedAIModel },
                                set: { viewModel.updateSelection(to: $0) }
                            ),
                            aiModels: viewModel.aiModelList,
                            presentedSheet: $presentedSheet,
                            showHistoryView: $showHistoryView
                        )
                        .onChange(of: viewModel.selectedAIModel) { _, newModel in
                            selectedModelID = newModel.id
                        }
                    }
                }
                .sheet(item: $presentedSheet) { sheet in
                    sheet.view
                }
                .navigationDestination(isPresented: $showHistoryView) {
                    HistoryView()
                }
                .onAppear {
                    viewModel.prepareInitialState(storedModelID: selectedModelID)
                }
        }
    }
}

#Preview {
    HomeView()
        .environment(HomeViewModel())
        .environment(CountdownViewModel())
}
