//  StarryTestView.swift
//
//  TEMPORARY smoke-test screen — delete this file to remove it.
//  Shows the StarryInside / StarryOutside backgrounds with a plain
//  14x10 visual grid on top, and nothing else: no Game Center auth,
//  no matchmaking, no game rules. GameState/CellState are deliberately
//  NOT used here, so this file deletes cleanly with nothing to unwind.
//
//  To revert: delete this file, and in MyApp.swift change the root
//  view back to ContentView().gameCenterConnection().

import SwiftUI

/// Swipe between the two starfields; each page carries the same 14x10 grid.
struct StarryTestView: View {
    var body: some View {
        TabView {
            starryPage(imageName: "StarryInside", label: "StarryInside")
            starryPage(imageName: "StarryOutside", label: "StarryOutside")
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .ignoresSafeArea()
    }

    private func starryPage(imageName: String, label: String) -> some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            BoardGridView()

            VStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            .padding()
        }
    }
}

/// Plain 14 columns x 10 rows visual grid. No rules, no state,
/// no tap handling — delete with StarryTestView.
private struct BoardGridView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 14)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<140, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                    )
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    StarryTestView()
}
