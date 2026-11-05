# Astroship — High-Level Architecture Choices

**Date:** 2026-11-05
**Sources checked:** `Sol-X-LLC/Astroship-Apple-Apps` at `7927567` ("Copied in iPhoneDuoTest files from Astroship repo", 1 commit in the shallow clone, 3 commits on GitHub) and `Sol-X-LLC/Astroship-Product-Requirements-Document` at `346d736`, README vB (2026-10-30).
**Scope:** architecture only. No code was changed in either repo, nothing was committed or pushed.

**How this was checked:** the two public repos were cloned and every Swift file was read. There is no Swift toolchain on this machine, so this is a read-through, not a build. The compile errors below are visible in the source; confirm them with one Xcode build on a Mac before acting on anything else.

---

## 1. Where the code actually is

The Apps repo is a very early copy of the old `iPhoneDuoTest` project, not a working game yet.

| File | Lines | State |
|---|---|---|
| `MyApp.swift` | 9 | Entry point only. Shows `ContentView()`, wires nothing. |
| `ContentView.swift` (root) + `Views/ContentView.swift` | 17 + 17 | **Identical "Hello, world!" files.** Duplicate `struct ContentView`. |
| `Models/Grid.swift` | 61 | `GridAsset` sketch. Invalid 2D-array syntax, see §2. |
| `Models/Ship.swift` | 61 | `ShipAsset` sketch. References a `Grid` type that does not exist. |
| `Models/GameAI.swift` | 60 | Broken. Duplicate `ShipAsset`, top-level assignment, bad import. |
| `Models/GameCenterSDK.swift` | 128 | **The most complete file.** Game Center auth, well structured. |
| `Models/MatchMaking.swift` | 218 | **Second most complete.** Live 2-player `GKMatch`, lobby view, disconnect handling. No move encoding or game rules yet. |
| `Models/User.swift` | 160 | `UserAsset` + phone-number validators for US/CA/MX/JP/DE. Unrelated to the game. |
| `ViewModels/ControlGameViewModel.swift` | 27 | Entirely commented out, copied from DMuffler / EV Customs. Wrong header, no game VM. |
| Tests | 0 | No test target, no test files. |

Project facts: one app target, `PBXFileSystemSynchronizedRootGroup` (every `.swift` file in the folder is auto-included in the build — that is why the duplicate `ContentView` matters), iOS deployment target 27.0, `TARGETED_DEVICE_FAMILY = "1,2,7"` (iPhone, iPad, Apple TV), Swift 5.0, bundle ID still a placeholder (`devplaceholder.…`), team `VHW35K267T`, Xcode 26.3 project format. README says iOS + tvOS, iPadOS & macOS coming 2028 — there is no separate tvOS target yet.

The PRD repo is the README only (plus Kickstarter script, SWOT, ad read). Current PRD dates, vB: TestFlight Dec 12, 2026; Kickstarter Jan 12, 2027; App Store Apr 14, 2026 in the text (that year reads as a typo for 2027 — see open questions); Kickstarter $4.00, release free + $4.69 Pro with a two-week trial, Jan 2028 $8/year.

---

## 2. Fix the build first — Phase 0, before any feature work

Nothing else is meaningful until the project compiles. These are not style nits; they are duplicate symbols and invalid Swift as read:

1. **Duplicate `ContentView`.** Delete one. Keep `Views/ContentView.swift`, delete the root `Astroship-Apple-Apps/ContentView.swift`. Because the project uses a synchronized folder group, both are in the target automatically — this is the same duplicate-symbol cause as the Nov 4 Xcode duplicate-build report.
2. **Duplicate `ShipAsset`.** `Ship.swift` defines `ShipAsset`; `GameAI.swift` defines a second, different `ShipAsset: Identifiable` that references undefined `SHIP_PHYSICAL_SHAPE`, `SHIP_SKIN`, `xAxislength`, `myGridState`, etc. Delete the copy in `GameAI.swift`.
3. **`GameAI.swift` top level.** `AI_SKILL_LEVEL = 5` has no `let`/`var`, and `import Random` is not a module. Both need removing/replacing with a real type (see §4).
4. **`Grid.swift` 2D state.** `var myGridState = [String][String]` and `var myShipLayout = [GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS]` are not 2D arrays and not a 7-element array. The intended types are `[[CellState]]` and `[ShipAsset]` (see §3).
5. **`Ship.swift` location.** `gridLocation = [Grid.GRID_CONSTANTS.NOT_A_NUMBER][Grid.GRID_CONSTANTS.MIN_VALUE][Grid.GRID_CONSTANTS.ONLY_2D]` references a `Grid` type that does not exist (`GridAsset` is the struct, `GRID_CONSTANTS` lives in `Grid.swift`) and a `MIN_VALUE` that is never defined. Replace with a plain value type, e.g. `gridLocation: GridPoint` / `[GridPoint]`.
6. **`ControlGameViewModel.swift`.** Delete the DMuffler commented-out file and replace it with a real game view model (§3). Do not keep dead, wrong-product code in the tree.
7. **Wire the entry point.** `MyApp.swift` must become `ContentView().gameCenterConnection()` (the exact step `GameCenterSDK.swift` already documents) and the lobby must actually present `MatchMakingView()`. Right now neither is called anywhere.

Acceptance for Phase 0: one clean Xcode build + the app launches to a lobby that shows Game Center status. No gameplay yet.

---

## 3. Proposed architecture

```
Views (SwiftUI, Duo-aware)
  LobbyView · PlacementView · BattleView · Settings / ProView
        ↓  @Observable view models, one per screen
ViewModels
  LobbyViewModel · PlacementViewModel · BattleViewModel
        ↓  pure value types + one transport protocol
Core (pure Swift — no SwiftUI, no GameKit, no SwiftData)
  GameState · Grid · Ship · CellState · Move · MoveCodec · GameAI (protocol)
        ↓
Services (Apple frameworks, replaceable)
  GameCenterSDK (auth) · MatchMaking (GKMatch transport)
  StoreKit Pro · Persistence (SwiftData, history/settings only)
  TelemetryDeck (only if/when added — AVL)
```

### Decision 1 — A pure game Core, separate from SwiftUI and GameKit

**Choice:** all rules live in `Core` as value types (`struct`, `enum`, `Codable`): `CellState` (`.empty`, `.ship`, `.hit`, `.miss`, `.radar`, `.fog`), `Grid`, `Ship`, `GameState`, `Move`, and a `GameAI` protocol. Views and view models observe it; GameKit never sees it directly.

**Why:** this is what makes the rest testable and portable. The same Core runs local solo, Game Center multiplayer, tvOS later, and — if SYSA-005 ever happens — a Python FastAPI backend, because the backend only needs to speak the same `Move` JSON. It also makes SYSA-001 testing possible: placement, hit/sink, win, and invalid-move rejection are pure functions, no device needed.

**Alternatives rejected:** putting rules in the view model (untestable, Duo/tvOS duplication), or putting rules in `GKMatch` callbacks (peer-trust bug: a remote player could send a winning move).

**Rule that follows:** never trust a peer. Every incoming move is decoded, then validated against the local `GameState` (is it their turn? is the cell in bounds and unshot? does the move type exist in this version?). Invalid moves are rejected and logged, never applied.

### Decision 2 — Keep GameKit, keep the two good files, move them

**Choice:** keep `GameCenterSDK.swift` (auth) and `MatchMaking.swift` (`GKMatch`, lobby, disconnect handling) almost as-is. Move them from `Models/` to `Services/`, and add one missing piece: a versioned `MoveCodec`.

**Why:** they are the only production-shaped code in the repo. Auth correctly uses `GKLocalPlayer.authenticateHandler`, never uses `displayName` as an ID (it uses `gamePlayerID`), and matchmaking correctly uses a live 2-player `GKMatch` with `.reliable` sends. Rewriting them would lose that.

**What to add:** `MoveCodec` — `Codable`, versioned (`protocolVersion: 1`), tiny payloads. Message kinds for v2026.1: `placement`, `shot`, `radar`, `surrender`, `heartbeat`. Moves are well under 200 bytes, so the PRD's 0.5 Mbps requirement (SOFT-003) is ample; the risk is not bandwidth, it is latency and disconnects, which `GKMatch` already surfaces. Do **not** build the SYSA-005 Linux VPS / FastAPI backend for v2026.1 — keep the transport behind a `MatchTransport` protocol so a FastAPI transport can be swapped in for v2028.0 without touching Core.

**What to wire:** `MatchMaking.onDataReceived` is currently an unwired callback. The `BattleViewModel` owns it, decodes via `MoveCodec`, validates via Core, and applies.

### Decision 3 — SwiftData for history/settings only; Core stays in memory

**Choice:** SwiftData (`@Model`) for match history, settings, and a cached Pro-entitlement flag. Live game state stays as in-memory value types. Do **not** adopt GRDB now.

**Why:** SwiftData is already imported everywhere, is Apple-native, and is enough for "what did I play, what are my settings". GRDB is more powerful for SQLite, but it is a second dependency, a second persistence model, and the PRD does not need its query power yet. If analytics ever need it (SYSA-005, v2028.0), revisit — the decision is recorded here so it is not re-litigated silently.

**Consequence:** `GridAsset` / `ShipAsset` must **not** become SwiftData entities. Make them `Codable` value types. Only a small `MatchRecord` is a `@Model`.

### Decision 4 — One view model per screen, `@Observable`, no DMuffler copy

**Choice:** `LobbyViewModel`, `PlacementViewModel`, `BattleViewModel`, each `@Observable` (Observation, iOS 17+ — trivially satisfied by the 27.0 deployment target), each owning exactly one screen's state. Delete `ControlGameViewModel.swift`.

**Why:** the commented-out file holds audio/dongle state for a different product. A single god view model would also be wrong: placement and battle have different lifecycles (placement is local and undoable; battle is turn-locked and networked).

### Decision 5 — Duo layout is two panes + the starry backgrounds you already made

**Choice:** landscape-first, two-pane layout — one pane is my fleet, the other is the hunt — using the 1.4:1 starry backgrounds already produced (1792×1280 PNGs, no grid lines, in the goal files). The SwiftUI grid is laid **over** the background, never baked into it.

**Why:** that is the PRD's own Duo pitch ("one screen for your fleet, one for the hunt") and the background decision already made on Oct 29–30. No Duo-specific SDK is in the repo, so treat Duo as a large landscape iPhone with two panes until Apple documents a fold API; do not invent a Duo API.

**Grid size — decided 2026-11-05 by the user: 14×10 everywhere.** The board is **14 columns (x) by 10 rows (y)** — 140 cells per grid, two grids per match (my fleet + opponent hunt). `GRID_CONSTANTS` is the single source of truth (`WIDTH = 14`, `HEIGHT = 10`); `GridAsset` defaults, the SwiftUI grid, the AI, `MoveCodec` bounds checks, and all art/copy must read those constants, never a hardcoded 10×10. The earlier 10×10 references (wrapper art footer, the Oct 18 screenshots showing twin 10-column grids) are superseded by this decision. Note the coincidence, not a conflict: the starry backgrounds are also 1.4:1 (1792×1280, filenames `…-14x10.png`), which is the board's aspect ratio — the background stays grid-free and the SwiftUI grid is laid over it.

### Decision 6 — Accessibility is a v2026.1 gate, not polish (INTE-001)

**Choice:** build the accessibility encoding into `CellState` from the start: every cell is distinguished by **shape + text label**, never by colour alone — hit = X, miss = O, ship = outline shape, radar = R, fog = F (the codes already sketched in `Grid.swift`). Add VoiceOver labels per cell ("Row 3, Column 4, hit"), Dynamic Type, Reduce Motion, high-contrast mode, and visual-only alerts (no audio-only cues) for deaf players.

**Why:** INTE-001 requires colour-blind and deaf support in v2026.1. Retrofitting it after the grid is drawn is the expensive path; encoding it in the model is cheap. This also covers the PRD's "colourblind-friendly from day one" line in the Kickstarter script.

**Deferred, by design:** INTE-002 (blind play via Siri / voice-command engine, v2027.X) is not built now. Keep a `VoiceCommand` seam in the view model so it can be added without rewriting BattleView.

### Decision 7 — AI is a protocol with named strategies, not a pile of stubs

**Choice:** `protocol GameAI { func nextShot(on: GameState, rng: inout some RandomNumberGenerator) -> GridPoint }` with strategies:
- `DumbScanAI` — random / checkerboard, for SOFT-002 basic AI and debugging.
- `CrissCrossAI` — hunt-and-target (the `AiCrissCross` stub, renamed), the default v2026.0 opponent.
- `LocalFoundationModelAI` — v2026.2 only (SOFT-004), gated behind on-device Apple Foundation Models, same protocol so it is a drop-in.
- Difficulty is a single `skillLevel: 0…10`, default 5, minimum shown to the player 1 (the numbers already in `GameAI.swift`).

**Why:** the current file has five empty functions (`AiCrissCross`, `AiDumbScan`, `AiLocalFoundationModel`, `AiServerFoundationModel`, `AiCarey`, `AiBlaze`) and no interface. A protocol makes each one independently testable — including determinism with a seeded RNG, which is the only sane way to test an AI.

**Note:** `AiCarey` / `AiBlaze` as named personalities are fine as difficulty presets, not as separate types. Do not ship a "server foundation model" in v2026.x; that is SYSA-005 territory.

### Decision 8 — Pro and no-ads in one place

**Choice:** StoreKit 2, one `ProGate` / `EntitlementService`: free game, $4.69 Pro unlock (Kickstarter backers via App Store offer codes, $4 tier), two-week trial per the PRD, $8/year from Jan 2028 as a **separate** subscription product — do not conflate the one-time unlock with the subscription. No ad SDK is added, ever (SYSA-006: "shall never place ads anywhere on the screen").

**Why:** the pricing story is already confusing in the PRD ($1 in the old repo text, $4 Kickstarter, $4.69 release, $8/year in 2028). A single entitlement check is the only way the UI, the multiplayer gate, and the level gate agree with each other.

### Decision 9 — Tests before features, starting with Core

**Choice:** add an XCTest target now (there is none). First tests, in order: placement validation, shot → hit / miss / sink, win detection, `MoveCodec` round-trip + invalid-move rejection, AI determinism with a seeded RNG, and VoiceOver label coverage for every `CellState`.

**Why:** SYSA-001 explicitly requires test reports demonstrating validation for INTE-001, INTE-002, and "SOFT-034" — and SOFT-034 does not exist in the PRD (see §6). Tests are also the only way to prove the 0.5 Mbps / turn / disconnect behaviour without two physical Duos.

---

## 4. Requirement → code map

| Requirement | What it needs | Current state | Decision |
|---|---|---|---|
| SOFT-001 — Swift open source, PRs until v2027.0 | Public repo, Unlicense, PR workflow | Done (public, Unlicense) | Keep. No change. |
| SOFT-002 — v2026.0 local single player + basic AI | Core + `DumbScanAI` / `CrissCrossAI` + Placement/Battle views | Stubs only, no game loop | Phase 1. Core first. |
| SOFT-003 — v2026.1 two humans, anywhere, ≥0.5 Mbps | `GKMatch` + `MoveCodec` + turn validation | Transport exists, codec + validation missing | Phase 2. Keep GameKit. |
| SOFT-004 — v2026.2 on-device Foundation Model AI + 2-human | `LocalFoundationModelAI` behind `GameAI` protocol | Stub only | Phase 4. Protocol now, model later. |
| SOFT-005 — logs / test data preserved | `MatchRecord` (SwiftData) + test reports | Nothing | Phase 1, with tests. |
| INTE-001 — v2026.1 colour-blind + deaf | Shape+label encoding, VoiceOver, visual alerts | Codes sketched, no UI | Phase 3 gate. Build into Core now. |
| INTE-002 — v2027.X blind via Siri / voice engine | `VoiceCommand` seam | Nothing | Deferred. Seam only. |
| SYSA-001 — tests for INTE-001/002 + SOFT-034 | XCTest target, Core tests | No target; SOFT-034 missing | Phase 0/1. Fix PRD ref first. |
| SYSA-002 — calendar versioning (v2026.1…) | `MARKETING_VERSION` / build scheme | Not set in project | Phase 0. Set `2026.0` for MVP. |
| SYSA-003 — AVL is TelemetryDeck only | No other third-party libs | No dependencies | Enforce: no new lib without AVL note. |
| SYSA-004 — Game Center ranking / profiles / SSO | Auth + leaderboards / achievements | Auth done; leaderboards not | Phase 2/3. Auth is the base. |
| SYSA-005 — v2028.0 may use 32 GB VPS + FastAPI | `MatchTransport` protocol | Not started | **Do not build.** Protocol seam only. |
| SYSA-006 — never place ads | No ad SDK, code-review rule | No ads | Enforce. |
| MECH-001 — run on iPhone Duo / Apple TV / macOS 27+ / iPhone 17+ | Deployment 27.0, Duo two-pane, tvOS target later | Target 27.0 set; one target only | Keep one target for v2026.x; split tvOS when its UI diverges. |
| MECH-004 — may support Apple Pencil (USB-C), v2026.1+ | PencilKit / touch handling in PlacementView | Nothing | Phase 4. Placement is the Pencil surface. |
| MECH-005 — Pencil wrapper sold Dec 2026 | Store, not code | Wrapper art exists in goal files | Not a code task. |
| ELEC-001/002 — 480 VAC rack, Cisco switches | — | Copy-paste from a rack PRD | **PRD defect.** Delete or rewrite for an iOS app. |

---

## 5. Proposed file layout

```
Astroship-Apple-Apps/
  MyApp.swift                     // .gameCenterConnection() on root
  App/
    ProGate.swift                 // StoreKit 2 entitlement, single check
  Core/                           // pure Swift, no Apple UI frameworks
    CellState.swift
    Grid.swift                    // GridAsset → Grid, [[CellState]]
    Ship.swift                    // ShipAsset, shapes I/X/T/Y, lengths 2–5, skins
    GameState.swift               // turn, placement, shots, win
    Move.swift                    // Move + MoveCodec, protocolVersion 1
    GameAI.swift                  // protocol + DumbScan / CrissCross
    Themes.swift                  // naval → deep-space, every 3 levels
  Services/
    GameCenterSDK.swift           // moved from Models/, unchanged logic
    MatchMaking.swift             // moved from Models/ + MatchTransport protocol
    Persistence.swift             // SwiftData MatchRecord, settings
    Telemetry.swift               // TelemetryDeck only, if added
  ViewModels/
    LobbyViewModel.swift
    PlacementViewModel.swift
    BattleViewModel.swift
  Views/
    ContentView.swift             // the ONE ContentView — lobby root
    LobbyView.swift               // MatchMakingView() lives here
    PlacementView.swift           // Pencil surface, v2026.1+
    BattleView.swift              // twin grids, Duo two-pane
    Components/
      GridView.swift              // SwiftUI grid OVER the starry background
      CellView.swift              // shape+label, VoiceOver
  Assets.xcassets/
    StarryInside / StarryOutside // 1792×1280 PNGs, 1.4:1, no grid lines
Tests/
  AstroshipTests/
    CoreTests.swift
    MoveCodecTests.swift
    AITests.swift
    AccessibilityTests.swift
```

---

## 6. Sequencing

1. **Phase 0 — Build green (days, not weeks).** Delete duplicate `ContentView`, fix `Grid`/`Ship`/`GameAI`, delete the DMuffler VM, wire `MyApp` → Game Center → lobby, set version `2026.0`. Exit: clean build, lobby shows auth status.
2. **Phase 1 — Solo MVP (v2026.0).** Core + placement + `CrissCrossAI` + local BattleView + `MatchRecord` + Core tests. Exit: a full local game can be played start to finish on one phone.
3. **Phase 2 — Online (v2026.1).** `MoveCodec`, turn validation, `BattleViewModel` ↔ `MatchMaking`, disconnect/rejoin handling, Game Center leaderboards. Exit: two phones can finish a game over a real network.
4. **Phase 3 — Accessibility + Pro (v2026.1 gate).** INTE-001 encoding, VoiceOver audit, StoreKit Pro + offer codes, no-ads check. Exit: INTE-001 test report (SYSA-001).
5. **Phase 4 — Foundation Model AI + Pencil (v2026.2).** `LocalFoundationModelAI`, Pencil placement. Exit: on-device AI plays a full game.
6. **Phase 5 — tvOS / 2028 (later).** Separate tvOS target when its focus UI diverges; FastAPI transport only if/when SYSA-005 is actually approved.

---

## 7. Open questions / PRD defects to resolve before Phase 1

1. **Board size — decided 2026-11-05: 14×10 everywhere** (14 columns × 10 rows, 140 cells). Former open question, now closed. See Decision 5.
2. **Ship count and shapes:** `MAX_NUMBER_OF_SHIPS = 7`, lengths 2–5, shapes I/X/T/Y. Classic Battleship is 5 ships, straight lines only. Are the T/X/Y shapes and 7 ships intentional differentiators? Confirm with Carey (PROJ-005: UX reviewed by Carey before public release).
3. **App Store date:** PRD says "Coming April 14, 2026" — that date is in the past; the Kickstarter script in the same repo says Mar 5, 2027. Which is right?
4. **SYSA-001 references SOFT-034**, which does not exist. Which requirement was meant?
5. **ELEC-001/002** are rack requirements, not iOS requirements. Delete them from the PRD or rewrite them.
6. **Pricing:** $1 (old repo text) vs $4 (Kickstarter) vs $4.69 (release) vs $8/year (Jan 2028). The architecture assumes $4.69 Pro + offer codes + a separate $8/year subscription — confirm that is the intended ladder.
7. **Apple TV stretch goal:** README says iOS + tvOS now; the term sheet (V4) had Apple TV as a paid stretch goal. Is tvOS in v2026.1 scope or not?
8. **Duo API:** is there an actual iPhone Duo fold API / simulator to target, or is "Duo" a large landscape iPhone for now? This decides whether the two-pane layout is a layout choice or a platform feature.

## 8. What was deliberately not decided here

- No VPS, no FastAPI, no cross-platform backend (SYSA-005, v2028.0).
- No blind/voice play (INTE-002, v2027.X) — seam only.
- No new third-party library (SYSA-003: TelemetryDeck only).
- No monetisation change beyond the single `ProGate` — pricing questions above go to the user, not to code.
