local ADDON, ns = ...

-- Localization. Keys are the English source strings; add a locale table with
-- overrides. ns.T(key) returns the translation for the active client locale, or
-- the key itself (English) as fallback. "Guild Craft Browser" is a proper name
-- and stays untranslated.
local translations = {}

translations.deDE = {
  -- Title / chrome
  ["Cart"] = "Warenkorb",
  ["My Orders"] = "Meine Aufträge",
  ["Shopping List"] = "Einkaufsliste",
  ["Filter my orders"] = "Meine Aufträge filtern",
  ["%d selected"] = "%d ausgewählt",
  ["Clear"] = "Leeren",
  ["Refresh"] = "Aktualisieren",
  ["Next order to fill"] = "Nächster Auftrag zum Füllen",

  -- Fill button states
  ["Fill Trade"] = "Handel füllen",
  ["Fill Trade (no order)"] = "Handel füllen (kein Auftrag)",
  ["Fill: %s"] = "Füllen: %s",
  ["Fill: %s (open trade)"] = "Füllen: %s (Handel öffnen)",

  -- Order rows / tooltips
  ["(no mats)"] = "(keine Mats)",
  ["Quantity"] = "Menge",
  ["Status"] = "Status",
  ["Accepted by"] = "Angenommen von",
  ["No recipe reagents for this order."] = "Keine Rezept-Materialien für diesen Auftrag.",
  ["Left-click: select"] = "Linksklick: auswählen",
  ["Left-click: deselect"] = "Linksklick: abwählen",
  ["Right-click: set as fill target"] = "Rechtsklick: als Füllziel setzen",

  -- Shopping tooltips
  ["buy %d"] = "kaufe %d",
  ["have all"] = "alles da",
  ["Needed"] = "Benötigt",
  ["Owned"] = "Vorhanden",
  ["To buy"] = "Zu kaufen",
  ["Where you have it:"] = "Wo du es hast:",
  ["On this character:"] = "Auf diesem Charakter:",

  -- Chat messages
  ["loaded. %s to open. Drives mats from your Guild Craft Browser orders."] =
    "geladen. %s zum Öffnen. Nutzt Materialien aus deinen Guild Craft Browser Aufträgen.",
  ["open the Auction House first."] = "öffne zuerst das Auktionshaus.",
  ["no supported Auction House search box found."] = "kein unterstütztes Auktionshaus-Suchfeld gefunden.",
  ["open a trade window first."] = "öffne zuerst ein Handelsfenster.",
  ["no orders selected."] = "keine Aufträge ausgewählt.",
  ["this order has no recipe reagents to trade."] = "dieser Auftrag hat keine Rezept-Materialien zum Handeln.",
  ["note: accepted by %s, but you're trading %s."] = "Hinweis: angenommen von %s, aber du handelst mit %s.",
  ["filled reagents for %s (%d stack(s))."] = "Materialien für %s gefüllt (%d Stapel).",
  ["not enough free trade slots (max 6). Trade these, then Fill again."] =
    "nicht genug freie Handelsplätze (max. 6). Handle diese, dann erneut füllen.",
  ["some items were busy — click Fill again in a moment."] =
    "einige Gegenstände waren belegt — klicke gleich erneut auf Füllen.",
  ["missing from bags:"] = "fehlt in Taschen:",
  ["traded order — removed from selection."] = "Auftrag gehandelt — aus Auswahl entfernt.",
  ["selection cleared."] = "Auswahl geleert.",
  ["refreshed."] = "aktualisiert.",
  ["auto-open on new order: %s"] = "Automatisch öffnen bei neuem Auftrag: %s",
  ["on"] = "an",
  ["off"] = "aus",
  ["usage: %s [fill | clear | refresh | autoopen | apitest]  (no arg = open/close)"] =
    "Verwendung: %s [fill | clear | refresh | autoopen | apitest]  (ohne Argument = öffnen/schließen)",
  ["diagnostics:"] = "Diagnose:",
  ["you have %d open/accepted order(s) placed."] = "du hast %d offene/angenommene Aufträge erstellt.",

  -- Minimap
  ["%d open/accepted order(s)"] = "%d offene/angenommene Aufträge",
  ["Left-click: open  |  Drag: move"] = "Linksklick: öffnen  |  Ziehen: verschieben",
}

local active = translations[GetLocale()] or {}

function ns.T(key)
  return active[key] or key
end
