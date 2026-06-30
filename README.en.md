🇬🇧 English · [🇷🇺 Русский](README.md)

# ScoreMaster — card game score counter

A Flutter app for keeping score in card games — and beyond. From Conquian and
Durak to President and Phase 10, plus a smart volleyball scoreboard. Rounds,
player avatars, game history, deep statistics and achievements. Material 3
Expressive, 7 languages, fully offline, no trackers.

## Install (Android)

[![Latest release](https://img.shields.io/github/v/release/THET1ME-1/Card-Score-Counter?label=release&style=for-the-badge)](https://github.com/THET1ME-1/Card-Score-Counter/releases/latest)

**Option 1 — plain APK.** Download `ScoreMaster-*.apk` from the
[latest release](https://github.com/THET1ME-1/Card-Score-Counter/releases/latest)
and install it (allow installs from this source).

**Option 2 — Obtainium (recommended, with auto-updates).**
[Obtainium](https://github.com/ImranR98/Obtainium) installs and updates the app
straight from GitHub releases.

1. Install Obtainium.
2. On your phone, open the one-tap add link:
   **[Add ScoreMaster to Obtainium](https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/THET1ME-1/Card-Score-Counter)**
   — or in Obtainium → “Add App” paste the repo URL:
   `https://github.com/THET1ME-1/Card-Score-Counter`
3. Done — new versions arrive automatically.

> Release signing: `CN=ScoreMaster`. All APKs are signed with the same key, so
> updates install over the top without reinstalling.

## Features

- **Many games, multiple scoring rules** — race-to-out (101), race-to-target
  (Thousand, Spades…), lowest-at-cap (Hearts), Durak, President (finish order),
  Phase 10, manual scoring (King, Bridge). Create your own games. Built-in rules.
- **Smart volleyball scoreboard** — two big tap-to-score tiles, sets, serve,
  set/match points, timeline; standard / short / free formats; portrait & landscape.
- **Scoreboard** — round-by-round entry with a custom numeric keypad, current-player
  highlight and animations, undo and edit of rounds, game/turn timer.
- **Luck dice (d4–d20)** — long-press a player’s score tile to roll a die right
  on the scoreboard (doesn’t affect the score).
- **“Who’s first?”** — a spinning wheel that picks a random player + a coin flip.
- **Players** — profiles with name, colour, photo and avatar shape; reorder turn
  order, shuffle, random first. Import players from contacts.
- **Player folders (companies)** — group players into folders; a player can be in
  several folders. Full add/remove/rename.
- **Statistics** — win-rate ring, leaders podium, analytics: round-by-round race
  chart, “when we play” heatmap, records, kings by game, head-to-head matrix and
  an **Elo power rating**. Per-game-type stats screen. CSV export.
- **Share** — a branded result card as an image, via the system share sheet.
- **Achievements** — for games, wins, streaks, modes tried and more.
- **Optional features (toggle in Settings)** — game notes, player folders,
  a money kitty (“who owes whom”), team mode (combined team score).
- **Security** — app lock with PIN and/or fingerprint, with a grace period.
- **Appearance** — Material You (dynamic colour), AMOLED black, colour palettes,
  light / dark / system / auto-by-time theme, text size.
- **Backups** — JSON export/import and sending a copy to the cloud (Google Drive,
  Dropbox, Telegram…) via the share sheet.
- **Languages** — Russian, English, German, French, Spanish, Italian, Portuguese.
  Auto-detected from the phone language/country on first launch.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## License

GNU GPL v3.0 — see [LICENSE](LICENSE).
