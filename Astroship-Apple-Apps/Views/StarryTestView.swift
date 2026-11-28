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
//
//  One related option for the real game, from your own architecture: when unfolded, show both at once
//  two panes side by side — an HStack(spacing: 0) with a starryPage in each half, no TabView. That's the
//  "two-pane" layout your design calls for, and each pane keeps its 1.4:1 ratio.

/**

 Inner Display (Unfolded)

 • Pixel Resolution: 1878-by-2670 pixels at 430 ppi (7.6-inch diagonal OLED)
 • Logical Points (@3x scale factor): 626 × 890 points (or 951 × 669 points held sideways / 669 × 951 upright)
 • Additional Specs: ProMotion 120Hz, Nano-texture finish, 1.41:1 aspect ratio

 Outer Display (Folded)

 • Pixel Resolution: 1398-by-2034 pixels at 460 ppi (5.4-inch diagonal OLED)
 • Logical Points (@3x scale factor): 466 × 678 points
 
 
 The Scale Factor (@1x, @2x, @3x)

 The relationship between points and physical pixels is bridged by a scale factor (multiplier):
 • @1x (Legacy): 1 point = 1 pixel (e.g., original iPhone).
 • @2x (Retina): 1 point = 2 × 2 pixels (4 total pixels per point).
 • @3x (Modern Retina): 1 point = 3 × 3 pixels (9 total pixels per point).
 */

import SwiftUI


/// Fold posture of the Duo. No public API reports this —
/// feed it from your Duo detection layer, and flip it
/// manually in the preview while testing.
enum DuoPosture {
    case flat    // fully open, or folded shut — one screen in use
    case lShape  // half-folded like a laptop — both halves in use
}


/// Swipe between the two starfields in the Xcode "Assets" catalog
struct StarryTestView: View {
    /// Set by your Duo detection: true on the cover (outside) screen.
    var isOutsideScreen: Bool = false

    var body: some View {
        starryPage(
            imageName: isOutsideScreen ? "StarryBackground" : "StarryBackground",
            label: isOutsideScreen ? "Opponent Grid" : "My Grid"
        )
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
        //.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Plain 14 columns x 10 rows visual grid. No rules, no state,
/// no tap handling — delete with StarryTestView.
///
/// Sizing is explicit, not negotiated: a GeometryReader measures
/// the real safe area on this screen (inner or outer Duo screen,
/// either orientation) and the cell is the largest square that
/// fits 14 columns by 10 rows inside it. Nothing here relies on
/// `.aspectRatio(.fit)` — a LazyVGrid with `.flexible()` columns
/// has no ideal size to scale from, so the fit never shrank it
/// and the grid overflowed the safe area on the narrower screen.
private struct BoardGridView: View {
    private let columns = 14
    private let rows = 10
    private let spacing: CGFloat = 2
    /// Clear space kept around the grid inside the safe area.
    private let margin: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let availW = proxy.size.width - insets.leading - insets.trailing - margin * 2
            let availH = proxy.size.height - insets.top - insets.bottom - margin * 2
            let cell = max(
                1,
                floor(min(
                    (availW - CGFloat(columns - 1) * spacing) / CGFloat(columns),
                    (availH - CGFloat(rows - 1) * spacing) / CGFloat(rows)
                ))
            )
            let gridW = cell * CGFloat(columns) + CGFloat(columns - 1) * spacing
            let gridH = cell * CGFloat(rows) + CGFloat(rows - 1) * spacing

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cell), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(0..<columns * rows, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.08))
                        )
                        .frame(width: cell, height: cell)
                }
            }
            .frame(width: gridW, height: gridH)
            .position(
                x: insets.leading + margin + availW / 2,
                y: insets.top + margin + availH / 2
            )
        }
    }
}

#Preview("Inside screen") {
    StarryTestView(isOutsideScreen: false)
}

#Preview("Outside screen") {
    StarryTestView(isOutsideScreen: true)
}
