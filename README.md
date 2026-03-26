# LifeToken

A dystopian iOS life-management RPG where your life balance is measured in seconds. Your health generates income, your choices determine your zone, and the clock never stops.

## Concept

You are born with 24 hours (86,400 seconds). Every real second that passes costs you one second of balance. The only way to earn more time is through:

- **Health activity** — steps, sleep, exercise, standing, mindfulness, HRV
- **Work** — time-locked jobs that pay out on completion
- **Mini-jobs** — skill-based instant earning (pipe puzzle, code-breaking, bomb defusal, sorting, timing)
- **Casino** — Crash, Blackjack, Poker, Roulette, Slots, Lottery, Yatzy
- **Investments** — time-locked deposits with daily compound interest
- **Night Market** — hidden boosts available 00:00–05:00 Stockholm time
- **Step Betting** — wager against friends on daily step counts

Run out of time and you die.

## Architecture

### Core Engine

| File | Role |
|------|------|
| `TimeEngine.swift` | Singleton source of truth. Keychain-persisted balance, 1s drain tick, NTP anti-cheat, background drain on re-open |
| `GameState.swift` | Login streak, zone tracking, total earnings |
| `ZoneManager.swift` | 14-zone migration with hysteresis |
| `ZoneProfile.swift` | Static zone definitions (Askan → Evigheten), tax rates, work multipliers |
| `InflationManager.swift` | Zone-based daily inflation applied to earnings |
| `ServerSync.swift` | Backend sync (register/login, balance push) |

### Income Sources

| File | Role |
|------|------|
| `IncomeManager.swift` | Midnight HealthKit payout, projected income, job title |
| `HealthKitmanager.swift` | Steps, calories, exercise, sleep, stand hours, HRV |
| `WorkView.swift` + `WorkManager.swift` | 14-zone job queue, time-locked completions |
| `MiniJobsView.swift` | Hub for 5 mini-games |
| `InvestmentView.swift` + `InvestmentManager.swift` | Time-bank with zone-based daily rates and crash risk |

### Casino

| File | Role |
|------|------|
| `CasinoHubView.swift` | Entry hub, zone-locked |
| `CrashView.swift` | Exponential multiplier crash game |
| `BlackjackView.swift` | Blackjack with split and double-down |
| `PokerView.swift` | Texas Hold'em with 3 AI opponents |
| `RouletteGameView.swift` | European roulette (0–36) |
| `Roulette.swift` | 3-reel slot machine |
| `LotteryView.swift` | Weekly jackpot lottery |
| `YatzyView.swift` | Yatzy vs Monte Carlo AI (~82% win rate) |
| `MultiplayerYatzyView.swift` | Multiplayer Yatzy variant |

### Mini-Jobs

| File | Role |
|------|------|
| `PipeGameView.swift` | Pipe puzzle (rotate to connect inlet→outlet) |
| `CodeBreakerView.swift` | Mastermind-style code breaking (terminal aesthetic) |
| `SortingGameView.swift` | Falling object sorter with combo multiplier |
| `BombDefuseView.swift` | Wire-cutting with clue reveal timer |
| `TimingGameView.swift` | Precision timing calibrator |

### Social & World

| File | Role |
|------|------|
| `SocialView.swift` | Zone chat, NPC loans, P2P time transfers |
| `PvPRaidView.swift` | Reaction-test PvP raids |
| `StepBetView.swift` | Step-count duels |
| `BoardManager.swift` | NPC board (Gregor/Arvid/Leon) with weekly fees and inflation spikes |
| `NewsManager.swift` | Auto-generated dystopian news feed |
| `NightMarketView.swift` | Secret market open 00:00–05:00 Stockholm |
| `MissionsView.swift` | Achievement system |

### UI

| File | Role |
|------|------|
| `ContentView.swift` | DashboardView + MainTabView (5 tabs) |
| `InTimeClockView.swift` | YY:DDD:HH:MM:SS clock display (neon green) |
| `ZoneVisual.swift` | Zone map with migration sheet |
| `TimeMarketView.swift` | In-game store (boosts, drain reducers, etc.) |
| `Intro.swift` | 7-step dystopian onboarding |

### Infrastructure

| File | Role |
|------|------|
| `BoostManager.swift` | Active boost multipliers |
| `NotificationManager.swift` | Low-balance push notifications |
| `Persistence.swift` | CoreData container (unused in core flow) |
| `LifeTokenApp.swift` | App entry, AppDelegate, singleton boot |

## Anti-Cheat

- Balance stored in Keychain (not UserDefaults)
- NTP verification via `worldtimeapi.org` every 5 minutes
- Clock rollback detection: if device time < server time, extra drain applied
- Background drain: elapsed time since last save applied on foreground

## Zone System

14 zones from lowest to highest:

1. Askan (0% tax)
2. Grundskiftet
3. Krypdalen
4. Gråbotten
5. Skymring
6. Halvmörker
7. Stigarnas Dal
8. Tröskelzonen
9. Duskline
10. Midgrey
11. Risefield
12. Aetherpoint
13. Novalux
14. Vaultum / Solara (highest tax, highest income)

Higher zones = higher tax, higher work multiplier, better passive income.

## Build Notes

- iOS 17+ (uses two-parameter `onChange` closure form)
- Swift 5.9+
- HealthKit entitlement required
- Backend: `https://209.38.98.107:4000/api` (TLS 1.2+ required)
- Swedish-language UI throughout
