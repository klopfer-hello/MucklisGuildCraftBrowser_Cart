# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2026-07-08

### Changed

- **TBC Anniversary 2.5.6 compatibility** — bumped the `.toc` interface version to `20506` so the addon is no longer flagged out of date on patch 2.5.6. No functional changes.

## [2.0.0] - 2026-07-07

Initial public release as a MucklisGuildCraftBrowser plugin.

### Added
- Reads your open/accepted Guild Craft Browser board orders and turns them into a cart.
- Aggregated, bank- and alt-aware shopping list (cross-character counts via Syndicator when present).
- One-click trade fill: splits stacks to the exact amount and places one order's reagents into the trade window; warns when the trade partner differs from the crafter who accepted the order.
- Reagents resolved from the host addon's per-profession seeds (works for every profession, scaled by order quantity).
- Shift-click a reagent to paste it into the Auctionator search box.
- Auto-open when viewing the order board (toggle with `/gcb cart autoopen`).
- `/gcb cart` subcommand integration plus `/gcbcart` and `/mgcbcart` aliases.
- Minimap button, remembered window position, and MucklisGuildCraftBrowser UI theming.
- English and German localization.
