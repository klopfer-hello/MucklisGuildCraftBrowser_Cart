local ADDON, ns = ...

ns.PREFIX = "|cff66ccffGCB Cart|r: "
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. msg) end
ns.Print = Print
local T = ns.T

-- MucklisGuildCraftBrowser handle (hard dependency; guaranteed loaded first).
local function GCB() return _G.MucklisGuildCraftBrowser end
ns.GCB = GCB

--------------------------------------------------------------------------------
-- Saved state (per character)
--------------------------------------------------------------------------------
local function EnsureDB()
  MGCBCartDB = MGCBCartDB or {}
  MGCBCartDB.selected = MGCBCartDB.selected or {}   -- [orderId] = true
  MGCBCartDB.minimap = MGCBCartDB.minimap or {}
  if MGCBCartDB.minimap.shown == nil then MGCBCartDB.minimap.shown = true end
  MGCBCartDB.minimap.angle = tonumber(MGCBCartDB.minimap.angle) or 210
  if MGCBCartDB.autoOpen == nil then MGCBCartDB.autoOpen = true end
  return MGCBCartDB
end
ns.EnsureDB = EnsureDB

-- Friendly item name (async: refreshed via GET_ITEM_INFO_RECEIVED).
function ns.ItemName(id)
  local n = GetItemInfo(id)
  return n or ("item:" .. tostring(id))
end

--------------------------------------------------------------------------------
-- Orders (from MGCB's Order Board) — only ones I placed, open or accepted
--------------------------------------------------------------------------------
local function myCharKey()
  local g = GCB()
  return g and g.DB and g.DB.GetCharacterKey and g.DB.GetCharacterKey() or nil
end

function ns.IsMine(order)
  local key = myCharKey()
  if key and order.requesterKey and order.requesterKey ~= "" then
    return order.requesterKey == key
  end
  local me = UnitName("player")
  return order.requesterName ~= nil and me ~= nil and order.requesterName == me
end

-- All my open/accepted orders, in Board sort order.
function ns.GetMyOrders()
  local g = GCB()
  if not g or not g.Board or not g.Board.GetOrders then return {} end
  local ok, all = pcall(g.Board.GetOrders, { includeClosed = false, includeArchived = false })
  if not ok or type(all) ~= "table" then return {} end
  local mine = {}
  for _, o in ipairs(all) do
    if ns.IsMine(o) then mine[#mine + 1] = o end
  end
  return mine
end

function ns.OrderStatus(order)
  local g = GCB()
  if g and g.Board and g.Board.GetStatus then return g.Board.GetStatus(order) end
  return order.status or "?"
end

-- Localized status label (inherits MGCB's own localization).
function ns.OrderStatusLabel(order)
  local g = GCB()
  local s = ns.OrderStatus(order)
  if g and g.Board and g.Board.GetStatusLabel then
    local lbl = g.Board.GetStatusLabel(s)
    if lbl and lbl ~= "" then return lbl end
  end
  return s
end

function ns.OrderAcceptedBy(order)
  local g = GCB()
  if g and g.Board and g.Board.GetAcceptedByDisplayName then
    local n = g.Board.GetAcceptedByDisplayName(order)
    if n and n ~= "" then return n end
  end
  return order.acceptedByName
end

--------------------------------------------------------------------------------
-- Reagents for an order (from the profession seed, scaled by quantity)
--------------------------------------------------------------------------------
local reagentIndexCache = {} -- canonProfession -> { byKey = {...}, bySpell = {...} }

local function professionIndex(professionKey)
  local g = GCB()
  if not g or not professionKey then return nil end
  local canon = professionKey
  if g.Util and g.Util.CanonicalProfessionKey then
    canon = g.Util.CanonicalProfessionKey(professionKey) or professionKey
  end
  if reagentIndexCache[canon] then return reagentIndexCache[canon] end
  if g.LoadSeedProfession then pcall(g.LoadSeedProfession, canon, "GCB Cart") end
  local recipes = g.Seed and g.Seed.recipes and g.Seed.recipes[canon]
  if type(recipes) ~= "table" then return nil end
  local idx = { byKey = {}, bySpell = {} }
  for _, r in ipairs(recipes) do
    if r.recipeKey then idx.byKey[r.recipeKey] = r.reagents end
    if r.spellId then idx.bySpell[r.spellId] = r.reagents end
  end
  reagentIndexCache[canon] = idx
  return idx
end

-- Returns list of { id, count } (scaled by order quantity), or nil if the order
-- has no resolvable recipe reagents (e.g. a plain text order).
function ns.OrderReagents(order)
  if not order or not order.professionKey then return nil end
  local idx = professionIndex(order.professionKey)
  if not idx then return nil end
  local reagents = (order.recipeKey and idx.byKey[order.recipeKey])
    or (order.spellId and idx.bySpell[order.spellId])
  if type(reagents) ~= "table" then return nil end
  local qty = tonumber(order.quantity) or 1
  if qty < 1 then qty = 1 end
  local out = {}
  for _, r in ipairs(reagents) do
    if r.itemId then
      out[#out + 1] = { id = r.itemId, count = (tonumber(r.count) or 0) * qty }
    end
  end
  return out
end

--------------------------------------------------------------------------------
-- Selection + active order
--------------------------------------------------------------------------------
function ns.IsSelected(id) return MGCBCartDB.selected[id] == true end
function ns.ToggleSelect(id)
  if MGCBCartDB.selected[id] then MGCBCartDB.selected[id] = nil else MGCBCartDB.selected[id] = true end
  ns.Refresh()
end
function ns.ClearSelection()
  wipe(MGCBCartDB.selected)
  ns.Refresh()
end
function ns.SelectionCount()
  local n = 0
  for _ in pairs(MGCBCartDB.selected) do n = n + 1 end
  return n
end

-- Selected orders that still exist among my open/accepted orders (Board order).
function ns.SelectedOrderList()
  local out = {}
  for _, o in ipairs(ns.GetMyOrders()) do
    if MGCBCartDB.selected[o.id] then out[#out + 1] = o end
  end
  return out
end

ns.activeOrder = nil -- runtime orderId that Fill targets
function ns.GetActiveOrder()
  local sel = ns.SelectedOrderList()
  if #sel == 0 then ns.activeOrder = nil; return nil end
  if ns.activeOrder then
    for _, o in ipairs(sel) do if o.id == ns.activeOrder then return o end end
  end
  ns.activeOrder = sel[1].id
  return sel[1]
end
function ns.SetActiveOrder(id)
  if MGCBCartDB.selected[id] then ns.activeOrder = id; ns.Refresh() end
end
function ns.CycleActiveOrder()
  local sel = ns.SelectedOrderList()
  if #sel < 2 then return end
  local cur = ns.GetActiveOrder()
  local at = 1
  for i, o in ipairs(sel) do if o.id == (cur and cur.id) then at = i break end end
  ns.activeOrder = sel[(at % #sel) + 1].id
  ns.Refresh()
end

--------------------------------------------------------------------------------
-- Inventory: current bags (live) + cross-alt via Syndicator
--------------------------------------------------------------------------------
function ns.ScanBagStacks(itemID)
  local stacks = {}
  for bag = 0, NUM_BAG_SLOTS do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      if C_Container.GetContainerItemID(bag, slot) == itemID then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local cnt = info and info.stackCount or 0
        if cnt > 0 then stacks[#stacks + 1] = { bag = bag, slot = slot, count = cnt } end
      end
    end
  end
  return stacks
end

local BANK = BANK_CONTAINER or -1
local LOCAL_CONTAINERS
local function LocalCount(itemID)
  if not LOCAL_CONTAINERS then
    LOCAL_CONTAINERS = { 0, 1, 2, 3, 4, BANK }
    local last = (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7)
    for b = (NUM_BAG_SLOTS or 4) + 1, last do LOCAL_CONTAINERS[#LOCAL_CONTAINERS + 1] = b end
  end
  local total = 0
  for _, bag in ipairs(LOCAL_CONTAINERS) do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      if C_Container.GetContainerItemID(bag, slot) == itemID then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        total = total + (info and info.stackCount or 0)
      end
    end
  end
  return total
end

function ns.HasSyndicator()
  return Syndicator and Syndicator.API and Syndicator.API.GetInventoryInfoByItemID and true or false
end

-- total, sources[]={name,count,className}, usedSyndicator
function ns.GetOwned(itemID)
  if ns.HasSyndicator() then
    local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, itemID)
    if ok and type(info) == "table" and info.characters then
      local total, sources = 0, {}
      for _, c in ipairs(info.characters) do
        local cnt = (c.bags or 0) + (c.bank or 0) + (c.mail or 0)
        if cnt > 0 then
          total = total + cnt
          sources[#sources + 1] = { name = c.character, count = cnt, className = c.className }
        end
      end
      table.sort(sources, function(a, b) return a.count > b.count end)
      return total, sources, true
    end
  end
  local total = LocalCount(itemID)
  local sources = {}
  if total > 0 then sources[1] = { name = UnitName("player"), count = total } end
  return total, sources, false
end

--------------------------------------------------------------------------------
-- Aggregate selected orders into a shopping list
--------------------------------------------------------------------------------
-- { id, name, needed, owned, toBuy, sources, viaSyn }
function ns.Aggregate()
  local needed = {}
  for _, o in ipairs(ns.SelectedOrderList()) do
    local reagents = ns.OrderReagents(o)
    if reagents then
      for _, m in ipairs(reagents) do needed[m.id] = (needed[m.id] or 0) + m.count end
    end
  end
  local list = {}
  for id, need in pairs(needed) do
    local owned, sources, viaSyn = ns.GetOwned(id)
    list[#list + 1] = {
      id = id, name = ns.ItemName(id), needed = need, owned = owned,
      toBuy = math.max(0, need - owned), sources = sources, viaSyn = viaSyn,
    }
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

--------------------------------------------------------------------------------
-- Auction House search (paste into Auctionator shopping search box)
--------------------------------------------------------------------------------
function ns.AHOpen()
  return (AuctionHouseFrame and AuctionHouseFrame:IsShown())
      or (AuctionFrame and AuctionFrame:IsShown()) or false
end

function ns.SearchAH(itemID)
  if not ns.AHOpen() then Print(T("open the Auction House first.")) return end
  local name = GetItemInfo(itemID) or ns.ItemName(itemID)
  local so = AuctionatorShoppingFrame and AuctionatorShoppingFrame.SearchOptions
  if so and so.SetSearchTerm then
    if AuctionatorTabs_Shopping then AuctionatorTabs_Shopping:Click() end
    so:SetSearchTerm('"' .. name .. '"')
    if so.FocusSearchBox then so:FocusSearchBox() end
  elseif BrowseName then
    if AuctionFrameTab1 then AuctionFrameTab1:Click() end
    BrowseName:SetText(name)
    BrowseName:SetFocus()
  else
    Print(T("no supported Auction House search box found."))
  end
end

--------------------------------------------------------------------------------
-- Fill the trade window with the active order's reagents
--------------------------------------------------------------------------------
local MAX_TRADE_SLOTS = 6
local PickupItem = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
local SplitItem  = (C_Container and C_Container.SplitContainerItem) or SplitContainerItem

local function FirstEmptyTradeSlot()
  for i = 1, MAX_TRADE_SLOTS do
    if not GetTradePlayerItemLink(i) then return i end
  end
  return nil
end

function ns.TradeOpen()
  return TradeFrame and TradeFrame:IsShown()
end

local function stripRealm(name)
  name = tostring(name or "")
  return (name:match("^([^%-]+)")) or name
end

function ns.TradePartnerName()
  if C_TradeInfo and C_TradeInfo.GetTradeTargetName then
    local ok, n = pcall(C_TradeInfo.GetTradeTargetName)
    if ok and n and n ~= "" then return n end
  end
  if GetTradeTargetInfo then
    local ok, n = pcall(GetTradeTargetInfo)
    if ok and n and n ~= "" then return n end
  end
  return nil
end

function ns.FillTrade()
  if not ns.TradeOpen() then Print(T("open a trade window first.")) return end
  local order = ns.GetActiveOrder()
  if not order then Print(T("no orders selected.")) return end
  local reagents = ns.OrderReagents(order)
  if not reagents or #reagents == 0 then
    Print(T("this order has no recipe reagents to trade."))
    return
  end

  local acceptedBy = ns.OrderAcceptedBy(order)
  local partner = ns.TradePartnerName()
  if acceptedBy and acceptedBy ~= "" and partner and stripRealm(partner) ~= stripRealm(acceptedBy) then
    Print("|cffffcc00" .. string.format(T("note: accepted by %s, but you're trading %s."), acceptedBy, partner) .. "|r")
  end

  local placed, missing, overflow, anyLocked = 0, {}, false, false
  for _, item in ipairs(reagents) do
    local stacks = ns.ScanBagStacks(item.id)
    local haveBags = 0
    for _, s in ipairs(stacks) do haveBags = haveBags + s.count end
    if haveBags < item.count then
      missing[#missing + 1] = string.format("%s (%d/%d in bags)", ns.ItemName(item.id), haveBags, item.count)
    end
    local toPlace = math.min(item.count, haveBags)
    for _, s in ipairs(stacks) do
      if toPlace <= 0 then break end
      local slot = FirstEmptyTradeSlot()
      if not slot then overflow = true break end
      local take = math.min(s.count, toPlace)
      local locked = false
      if C_Item and ItemLocation then
        local loc = ItemLocation:CreateFromBagAndSlot(s.bag, s.slot)
        if C_Item.DoesItemExist(loc) and C_Item.IsLocked(loc) then locked = true end
      end
      if locked then
        anyLocked = true
      else
        ClearCursor()
        if take >= s.count then PickupItem(s.bag, s.slot) else SplitItem(s.bag, s.slot, take) end
        ClickTradeButton(slot)
        if CursorHasItem() then ClearCursor() end
        toPlace = toPlace - take
        placed = placed + 1
      end
    end
    if overflow then break end
  end

  if placed > 0 then
    ns.lastFilledOrder = order.id
    Print(string.format(T("filled reagents for %s (%d stack(s))."), "|cffffff00" .. (order.title or "order") .. "|r", placed))
  end
  if overflow then
    Print("|cffff5555" .. T("not enough free trade slots (max 6). Trade these, then Fill again.") .. "|r")
  end
  if anyLocked then
    Print("|cffffcc00" .. T("some items were busy — click Fill again in a moment.") .. "|r")
  end
  if #missing > 0 then
    Print("|cffffcc00" .. T("missing from bags:") .. "|r " .. table.concat(missing, ", "))
  end
  ns.Refresh()
end

--------------------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------------------
function ns.ApiTest()
  local g = GCB()
  Print(T("diagnostics:"))
  local function line(ok, label)
    DEFAULT_CHAT_FRAME:AddMessage("   " .. (ok and "|cff44ff44OK|r  " or "|cffff4444MISSING|r  ") .. label)
  end
  line(g ~= nil, "MucklisGuildCraftBrowser loaded")
  line(g and g.Board and type(g.Board.GetOrders) == "function", "Board.GetOrders")
  line(g and type(g.LoadSeedProfession) == "function", "LoadSeedProfession")
  line(type(ClickTradeButton) == "function", "ClickTradeButton")
  line(C_Container and type(C_Container.SplitContainerItem) == "function", "C_Container.SplitContainerItem")
  Print(string.format(T("you have %d open/accepted order(s) placed."), #ns.GetMyOrders()))
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRADE_SHOW")
f:RegisterEvent("TRADE_CLOSED")
f:RegisterEvent("UI_INFO_MESSAGE")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("MAIL_INBOX_UPDATE")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MAIL_CLOSED")
f:RegisterEvent("PLAYER_MONEY")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "PLAYER_LOGIN" then
    EnsureDB()
    if ns.BuildUI then ns.BuildUI() end
    if ns.MinimapInit then ns.MinimapInit() end
    ns.HookCommands()
    ns.HookBoardCreate()
    ns.HookBrowserWindow()
    Print(string.format(T("loaded. %s to open. Drives mats from your Guild Craft Browser orders."), "|cffffff00/gcb cart|r"))
  elseif event == "TRADE_SHOW" then
    ns.tradeCompleted, ns.lastFilledOrder = false, nil
    ns.OnTradeStateChanged()
  elseif event == "TRADE_CLOSED" then
    if ns.tradeCompleted and ns.lastFilledOrder then
      local id = ns.lastFilledOrder
      MGCBCartDB.selected[id] = nil -- trade done -> drop from selection/list
      Print(T("traded order — removed from selection."))
    end
    ns.tradeCompleted, ns.lastFilledOrder = false, nil
    ns.OnTradeStateChanged()
  elseif event == "UI_INFO_MESSAGE" then
    if arg1 == ERR_TRADE_COMPLETE or arg2 == ERR_TRADE_COMPLETE then
      ns.tradeCompleted = true
    end
  elseif event == "GET_ITEM_INFO_RECEIVED" then
    ns.Refresh()
  else
    ns.Refresh()
  end
end)

ns.Refresh = ns.Refresh or function() end
ns.OnTradeStateChanged = ns.OnTradeStateChanged or function() end

-- Shared handler for both "/gcb cart <sub>" and the standalone slash aliases.
function ns.HandleCartCommand(rest)
  rest = tostring(rest or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if rest == "clear" then ns.ClearSelection(); Print(T("selection cleared."))
  elseif rest == "fill" then ns.FillTrade()
  elseif rest == "refresh" then ns.Refresh(); Print(T("refreshed."))
  elseif rest == "apitest" then ns.ApiTest()
  elseif rest == "autoopen" then
    MGCBCartDB.autoOpen = not (MGCBCartDB.autoOpen ~= false)
    local state = MGCBCartDB.autoOpen and ("|cff44ff44" .. T("on") .. "|r") or ("|cffff5555" .. T("off") .. "|r")
    Print(string.format(T("auto-open on new order: %s"), state))
  elseif rest == "help" then
    Print(string.format(T("usage: %s [fill | clear | refresh | autoopen | apitest]  (no arg = open/close)"), "|cffffff00/gcb cart|r"))
  else ns.ToggleUI() end
end

-- Auto-open the cart when I book a new order in MGCB. Wraps Board.CreateOrder
-- (no edits to MGCB); only fires for orders I placed, and only if enabled.
function ns.HookBoardCreate()
  local g = GCB()
  if not g or not g.Board or type(g.Board.CreateOrder) ~= "function" then return false end
  if g.Board.__mgcbCartCreateHook then return true end
  local orig = g.Board.CreateOrder
  g.Board.CreateOrder = function(order, broadcast)
    local normalized = orig(order, broadcast)
    if normalized and MGCBCartDB and MGCBCartDB.autoOpen ~= false and ns.IsMine(normalized) then
      MGCBCartDB.selected = MGCBCartDB.selected or {}
      MGCBCartDB.selected[normalized.id] = true
      ns.activeOrder = normalized.id
      if ns.ShowUI then ns.ShowUI() end
    end
    return normalized
  end
  g.Board.__mgcbCartCreateHook = true
  return true
end

-- Auto-open the cart when the MGCB Order Board is being viewed and I have orders.
-- Wraps BrowserWindow:SetView / :Show / :Toggle (no edits to MGCB).
function ns.HookBrowserWindow()
  local g = GCB()
  local bw = g and g.BrowserWindow
  if not bw then return false end
  if bw.__mgcbCartViewHook then return true end

  local function maybeAutoOpen()
    if not (MGCBCartDB and MGCBCartDB.autoOpen ~= false) then return end
    if bw.frame and bw.frame:IsShown() and bw.currentView == "board" then
      if #ns.GetMyOrders() > 0 and ns.ShowUI then ns.ShowUI() end
    end
  end
  ns._maybeAutoOpen = maybeAutoOpen

  for _, method in ipairs({ "SetView", "Show", "Toggle" }) do
    if type(bw[method]) == "function" then
      local orig = bw[method]
      bw[method] = function(self, ...)
        local r = orig(self, ...)
        maybeAutoOpen()
        return r
      end
    end
  end
  bw.__mgcbCartViewHook = true
  return true
end

-- Register a "cart" subcommand on MGCB's /gcb by wrapping its dispatcher.
-- No edits to MGCB: GCB.Commands.Handle is a global we hook, and both of MGCB's
-- registration paths call it by table lookup, so the wrap is always picked up.
function ns.HookCommands()
  local g = GCB()
  if not g or not g.Commands or type(g.Commands.Handle) ~= "function" then return false end
  if g.Commands.__mgcbCartHooked then return true end
  local orig = g.Commands.Handle
  g.Commands.Handle = function(message)
    local cmd, sub = tostring(message or ""):match("^(%S*)%s*(.*)$")
    if (cmd or ""):lower() == "cart" then
      ns.HandleCartCommand(sub)
      return
    end
    return orig(message)
  end
  g.Commands.__mgcbCartHooked = true
  return true
end

-- Standalone aliases (in case you prefer a direct slash).
SLASH_MGCBCART1 = "/gcbcart"
SLASH_MGCBCART2 = "/mgcbcart"
SlashCmdList["MGCBCART"] = function(msg) ns.HandleCartCommand(msg) end
