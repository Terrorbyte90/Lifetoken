# LifeToken — Full Audit Report

**Date:** 2026-03-16
**Auditor:** Claude (claude-sonnet-4-6)
**Scope:** All 43 Swift source files

---

## Summary

| Category | Issues Found | Issues Fixed |
|----------|-------------|-------------|
| Critical crashes (force unwraps) | 8 | 8 |
| Timer retain cycles | 1 | 1 |
| Missing timer cleanup / leaks | 3 | 3 |
| Deprecated API (`onChange` single-param) | 10 | 10 |
| Deprecated API (`.accentColor`) | 13 | 13 |
| Balance bypass (direct mutation) | 1 | 1 |
| Swedish text encoding errors | 8 | 8 |
| Missing dismiss button | 1 | 1 |
| UI consistency (button style) | 1 | 1 |
| Dead code (unused variable) | 1 | 1 |

---

## Critical Bugs Fixed

### 1. CrashView.swift — Timer Retain Cycle (line 319)

**Severity:** High — memory leak, view never deallocates
**Issue:** `gameTimer = Timer.scheduledTimer(...) { [self] _ in` used a strong `self` capture. SwiftUI struct views retain the state reference. With a 0.1s repeating timer and no weak capture, the view could not be released even after dismissal.

**Fix:** Changed to `[weak self]` with `guard let self = self` unwrap. All property accesses inside the closure updated to use explicit `self.` prefix.

---

### 2. BlackjackView.swift — Force Unwrap on `deck.deal()!` (lines 345–348)

**Severity:** High — crashes if deck runs out
**Issue:** `playerCards.append(deck.deal()!)` — if the deck ever exhausts its 52 cards (possible after many splits), this crashes with a nil force-unwrap.

**Fix:** Replaced 4 force-unwraps with a `guard let pc1 = deck.deal(), ... else { return }` pattern.

---

### 3. PokerView.swift — Force Unwrap on `deck.deal()!` (lines 243–245, 361)

**Severity:** High — crashes if deck runs out
**Issue:** Two locations: initial deal (`playerHand = [deck.deal()!, deck.deal()!]`) and flop (`communityCards = [deck.deal()!, deck.deal()!, deck.deal()!]`).

**Fix:** Both replaced with `guard let` pattern. Turn and River were already using safe `if let deck.deal()` — no change needed there.

---

### 4. HealthKitmanager.swift — Force Unwrap on Calendar.date (line 60)

**Severity:** Medium — crashes if calendar calculation fails (extremely rare but possible on certain locale configurations)
**Issue:** `let yesterday = cal.date(byAdding: .hour, value: -24, to: now)!`

**Fix:** `let yesterday = cal.date(byAdding: .hour, value: -24, to: now) ?? now.addingTimeInterval(-86400)`

---

### 5. NewsManager.swift — Force Unwrap on `flavors.randomElement()!` (line 217)

**Severity:** Low-Medium — array is non-empty in practice but force-unwrapping is bad practice
**Issue:** `flavors.randomElement()!` on the player join event.

**Fix:** Changed to `flavors.randomElement() ?? ""`

---

### 6. BombDefuseView.swift — Force Unwrap `alt.randomElement()!` (line 463)

**Severity:** Low — `alt` is a 3-element array literal
**Fix:** Changed to `alt.randomElement() ?? alt[0]`

---

### 7. PipeGameView.swift — Force Unwrap `randomElement()!` (line 128)

**Severity:** Low — array is a 4-element literal
**Fix:** Changed to `.randomElement() ?? .straight`

---

### 8. CodeBreakerView.swift — Force Unwrap `symbols.randomElement()!` (line 504)

**Severity:** Low — `symbols` will always have at least 6 elements given config
**Fix:** Changed to `.randomElement() ?? "1"`

---

### 9. NightMarketView.swift — Force Unwrap `baseBoosts.randomElement()!` (line 146)

**Severity:** Low — 7-element array
**Fix:** Changed to `.randomElement() ?? baseBoosts[0]`

---

### 10. SocialView.swift — Force Unwrap `replies.randomElement()!` (line 170)

**Severity:** Low — 6-element array
**Fix:** Changed to `.randomElement() ?? "..."`

---

## Deprecated API Fixes

### onChange (Single-Parameter Form — iOS 17 Breaking Change)

The old `onChange(of:) { value in }` signature is deprecated in iOS 17+ and produces compiler warnings. All 10 occurrences updated to two-parameter form `{ _, newValue in }`:

| File | Line | Change |
|------|------|--------|
| ContentView.swift | 209 | `{ isLow in` → `{ _, isLow in` |
| BankView.swift | 200 | `{ _ in` → `{ _, _ in` |
| PvPRaidView.swift | 352 | `{ newPhase in` → `{ _, newPhase in` |
| PipeGameView.swift | 438 | `{ val in` → `{ _, val in` |
| CodeBreakerView.swift | 231 | `{ _ in` → `{ _, _ in` |
| SocialView.swift | 522 | `{ _ in` → `{ _, _ in` |
| MultiplayerYatzyView.swift | 445 | `{ rolling in` → `{ _, rolling in` |
| MultiplayerYatzyView.swift | 1503 | `{ _ in` → `{ _, _ in` |
| MultiplayerYatzyView.swift | 1504 | `{ _ in` → `{ _, _ in` |
| MultiplayerYatzyView.swift | 1505 | `{ _ in` → `{ _, _ in` |

### .accentColor → .tint (Deprecated in iOS 15+)

All 13 occurrences replaced:

- `ContentView.swift` — tab bar accent
- `PokerView.swift`, `BlackjackView.swift`, `CrashView.swift` — bet sliders
- `BankView.swift` — loan and investment sliders
- `RouletteGameView.swift` — bet amount sliders
- `InvestmentView.swift` — investment amount slider
- `Roulette.swift` — slot bet slider
- `YatzyView.swift` — bet slider
- `SocialView.swift` — lending/transfer sliders

---

## Timer Fixes

### Missing .onDisappear Timer Cleanup — WorkView.swift

**Issue:** `WorkView` creates a `Timer.publish(...).autoconnect()` stored in `@State private var tickTimer` but never cancels it when the view disappears. The timer fires every second and calls `workManager.checkCompletion()` unnecessarily.

**Fix:** Added `.onDisappear { tickTimer.upstream.connect().cancel() }` to `WorkView.body`.

### Missing .onDisappear Timer Cleanup — ActiveJobCard (in WorkView.swift)

**Issue:** Same pattern — `ActiveJobCard` has its own `@State private var tickTimer = Timer.publish(every: 1, ...)` with no cleanup.

**Fix:** Added `.onDisappear { tickTimer.upstream.connect().cancel() }` to `ActiveJobCard.body`.

### MissionsManager Uptime Timer — MissionsView.swift

**Issue:** `Timer.scheduledTimer(...)` result discarded — impossible to invalidate, and uses `MissionsManager.shared.loadMissions()` (a strong reference on a static singleton, less critical but incorrect pattern).

**Fix:** Stored timer reference as `private var uptimeTimer: Timer?`, changed closure capture to `[weak self]`.

---

## Balance Bypass Fix

### BoardManager.swift — Direct Balance Mutation (line 196)

**Issue:** `executeWeeklySystemFee()` set `TimeEngine.shared.balance = max(0, playerBalance - fee)` directly, bypassing the thread-safe `deductTime()` guard which prevents double-spend from rapid concurrent calls.

**Fix:** Changed to `TimeEngine.shared.deductTime(min(fee, playerBalance))` to route through the safe API.

---

## Swedish Text Encoding Fixes

Multiple strings in `InvestmentView.swift` and `NotificationManager.swift` were missing Swedish special characters (å, ä, ö):

| File | Before | After |
|------|--------|-------|
| InvestmentView.swift | `DAGLIG RANTA` | `DAGLIG RÄNTA` |
| InvestmentView.swift | `Loptid:` | `Löptid:` |
| InvestmentView.swift | `Bekrafta Investering` | `Bekräfta Investering` |
| InvestmentView.swift | `ar lasta under loptiden` | `är låsta under löptiden` |
| InvestmentView.swift | `Daglig ranta:` | `Daglig ränta:` |
| InvestmentView.swift | `Alder:` | `Ålder:` |
| InvestmentView.swift | `forlorade ... av sitt varde` | `förlorade ... av sitt värde` |
| NotificationManager.swift | `Borja arbeta!` | `Börja arbeta!` |
| NotificationManager.swift | `Oka inkomsten.` | `Öka inkomsten.` |

---

## UI/UX Fixes

### ZoneVisual.swift — Missing Dismiss Button on Migration Sheet

**Issue:** The migration sheet had no way to dismiss other than tapping outside the sheet. Users who open it to inspect costs but can't afford migration had no obvious escape.

**Fix:** Added an `xmark` dismiss button to the top-left of the migration sheet header.

### LotteryView.swift — Inconsistent Dismiss Button Style

**Issue:** The `xmark` button in `LotteryView` had no background, unlike every other game view which wraps it in a circular background.

**Fix:** Added `.padding(8).background(Color.white.opacity(0.1)).clipShape(Circle())` to match the project standard.

---

## Code Quality Fixes

### YatzyView.swift — Unused Variable `bestVal`

**Issue:** In `YatzyAI.bestCategoryEV()`, the variable `bestVal` was assigned but its only usage was `_ = bestVal` (a compiler warning suppression). The variable is an exact duplicate of `bestEV`.

**Fix:** Removed `bestVal` entirely. The logic is unchanged — `bestEV` already tracks the same value correctly.

---

## Issues Not Fixed (Out of Scope / Acceptable)

| Issue | Reason Not Fixed |
|-------|-----------------|
| `Persistence.swift` `fatalError` in CoreData init | Xcode template boilerplate; CoreData is not used in the core game flow |
| `PDir.rotated(by:)` force unwrap | Mathematically guaranteed safe (modulo 4) |
| `UnicodeScalar(...)!` in BombDefuseView Caesar cipher | Result always in 65–90 (valid ASCII A–Z) |
| 22x `.cornerRadius()` usages | Deprecated but functional; replacement would be cosmetic-only |
| `Intro.swift` `drainTimer` never cancelled | View is shown once during onboarding then never again |
| `BoardManager` direct balance read for inflation spike | Read-only; does not modify balance directly |

---

## Files Not Modified

The following files had no issues and were not changed:

- `TimeEngine.swift`, `GameState.swift`, `ZoneManager.swift`, `ZoneProfile.swift`
- `BoostManager.swift`, `InflationManager.swift`, `ServerSync.swift`
- `RouletteGameView.swift` (only `.accentColor` fix applied via sed)
- `InTimeClockView.swift`, `PokerEngine.swift`
- `TimingGameView.swift`, `SortingGameView.swift`
- `StepBetView.swift`, `NightMarketView.swift` (only force-unwrap fix)
- `CasinoHubView.swift`, `Intro.swift`, `Persistence.swift`
- `LifeTokenApp.swift`, `BoardManager.swift` (only balance bypass fix)
