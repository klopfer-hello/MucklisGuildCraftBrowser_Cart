# Guild Craft Browser Cart

A companion plugin for **[MucklisGuildCraftBrowser](https://www.curseforge.com/wow/addons/mucklis-guild-craft-browser)** (Guild Craft Browser). It turns the orders you place on the guild craft board into a ready-to-trade shopping cart: pick your orders, see exactly which reagents you still need to buy (aware of your bags, bank and alts), and drop the right materials into the trade window with one click.

Built for **WoW Burning Crusade Classic – Anniversary (2.5.6)**.

## Features

- **Reads your Guild Craft Browser orders** — lists the open and accepted orders you placed on the board.
- **Any profession** — reagents are pulled from Guild Craft Browser's own recipe seeds, so it works for every profession, scaled by the order quantity.
- **Bank- and alt-aware shopping list** — shows how many of each reagent you still need to *buy* (needed minus what you already own). Cross-character counts come from **Syndicator** if it is installed.
- **One-click trade fill** — splits stacks to the exact amount and places one order's reagents into the trade window. Warns if you are trading someone other than the crafter who accepted the order.
- **Auction House helper** — shift-click a reagent to paste it into the Auctionator search box.
- **Opens automatically** when you view the order board and have orders (toggle with `/gcb cart autoopen`).
- **Guild Craft Browser look & feel** — uses the host addon's UI theme.
- **English & German** localization.
- Remembers its window position; minimap button; `/gcb cart` command integration.

## Requirements

- **[MucklisGuildCraftBrowser](https://www.curseforge.com/wow/addons/mucklis-guild-craft-browser)** — required.
- **Syndicator** — optional, enables cross-character (bank/alt) inventory counts.
- **Auctionator** — optional, enables the shift-click "search on AH" helper.

## Usage

1. Place your craft requests on the Guild Craft Browser **Order board**.
2. Open the cart (see commands below) — your orders are listed on the left.
3. **Left-click** an order to add it to the cart; **right-click** to make it the fill target.
4. Buy the reagents shown in the **Shopping list** (shift-click to search the AH).
5. Open a trade with the crafter and press **Fill** — the exact reagents for the selected order are placed automatically.

## Commands

| Command | Description |
|---|---|
| `/gcb cart` | Open / close the window |
| `/gcb cart fill` | Fill the trade window with the active order's reagents |
| `/gcb cart clear` | Clear the selection |
| `/gcb cart refresh` | Recount owned materials |
| `/gcb cart autoopen` | Toggle auto-open when viewing the order board |
| `/gcb cart apitest` | Diagnostics (checks the host APIs) |

Standalone aliases `/gcbcart` and `/mgcbcart` work as well.

## Download

[CurseForge](https://www.curseforge.com/wow/addons/guild-craft-browser-cart)

## License

See the repository for license details.
