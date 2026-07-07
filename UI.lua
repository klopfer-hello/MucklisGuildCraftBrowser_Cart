local ADDON, ns = ...

local WIN_W, WIN_H = 760, 520
local ROWH = 20
local LEFT_W = 430
local PANEL_TOP = 84   -- window-top inset where the panels begin
local PANEL_BOT = 52   -- window-bottom inset where the panels end
local LIST_TOP = 28    -- inset inside a panel below its header, where rows begin

local frame
local ordersScroll, orderRows = nil, {}
local shopScroll, shopRows = nil, {}
local titleFS, fillBtn, cycleBtn
local searchText = ""

-- GCB style handles, resolved at BuildUI (MGCB is a hard dependency).
local Style, C
local T = ns.T

local function col(name) return (C and C[name]) or { 1, 1, 1 } end

--------------------------------------------------------------------------------
-- Data helpers
--------------------------------------------------------------------------------
local function GetFilteredOrders()
  local q = searchText:lower()
  local out = {}
  for _, o in ipairs(ns.GetMyOrders()) do
    local hay = ((o.title or "") .. " " .. (o.professionName or "")):lower()
    if q == "" or hay:find(q, 1, true) then out[#out + 1] = o end
  end
  return out
end

local function ClassColorStr(className)
  local c = className and RAID_CLASS_COLORS and RAID_CLASS_COLORS[className]
  return c and c.colorStr or "ffffffff"
end

--------------------------------------------------------------------------------
-- Orders list (left)
--------------------------------------------------------------------------------
local function UpdateOrders()
  local data = GetFilteredOrders()
  local active = ns.GetActiveOrder()
  local offset = FauxScrollFrame_GetOffset(ordersScroll)
  for i = 1, #orderRows do
    local row = orderRows[i]
    local o = data[i + offset]
    if o then
      row.order = o
      local selected = ns.IsSelected(o.id)
      local isActive = active and active.id == o.id
      row.check:SetShown(selected)
      row.activeBg:SetShown(isActive)
      row.selBg:SetShown(selected and not isActive)

      local reagents = ns.OrderReagents(o)
      local title = o.title or o.recipeName or "(order)"
      if not reagents then title = title .. " |cff888888" .. T("(no mats)") .. "|r" end
      row.name:SetText(title)
      Style.SetTextColor(row.name, selected and col("GREEN") or col("WHITE"))

      local status = ns.OrderStatus(o)
      local qty = tonumber(o.quantity) or 1
      local statusColor = (status == "accepted") and "ff4dd24d" or "ffd9c76a"
      local meta = "x" .. qty .. "  |c" .. statusColor .. ns.OrderStatusLabel(o) .. "|r"
      row.meta:SetText(meta)
      row:Show()
    else
      row.order = nil
      row:Hide()
    end
  end
  FauxScrollFrame_Update(ordersScroll, #data, #orderRows, ROWH)
end

local function MakeOrderRow(parent, i)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROWH)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -LIST_TOP - (i - 1) * ROWH)
  row:SetPoint("RIGHT", parent, "RIGHT", -26, 0)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  row.activeBg = Style.MakeSolid(row, "BACKGROUND", col("BLUE"), 0.16)
  row.activeBg:SetAllPoints()
  row.activeBg:Hide()
  row.selBg = Style.MakeSolid(row, "BACKGROUND", col("GREEN"), 0.08)
  row.selBg:SetAllPoints()
  row.selBg:Hide()

  local hover = Style.MakeSolid(row, "HIGHLIGHT", col("GOLD"), 0.12)
  hover:SetAllPoints()

  row.check = row:CreateTexture(nil, "OVERLAY")
  row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  row.check:SetSize(16, 16)
  row.check:SetPoint("LEFT", 2, 0)
  row.check:Hide()

  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", 22, 0)
  row.name:SetWidth(230)
  row.name:SetJustifyH("LEFT")
  Style.SetNoWrap(row.name, 1)

  row.meta = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.meta:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  row.meta:SetPoint("RIGHT", -4, 0)
  row.meta:SetJustifyH("RIGHT")
  Style.SetNoWrap(row.meta, 1)

  row:SetScript("OnClick", function(self, button)
    if not self.order then return end
    if button == "RightButton" then
      if ns.IsSelected(self.order.id) then ns.SetActiveOrder(self.order.id) end
    else
      ns.ToggleSelect(self.order.id)
    end
  end)
  row:SetScript("OnEnter", function(self)
    if not self.order then return end
    local o = self.order
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(o.title or o.recipeName or "(order)")
    if o.professionName then GameTooltip:AddLine(o.professionName, 0.7, 0.7, 0.7) end
    GameTooltip:AddDoubleLine(T("Quantity"), "x" .. (tonumber(o.quantity) or 1), 1, 1, 1, 1, 0.82, 0)
    GameTooltip:AddDoubleLine(T("Status"), ns.OrderStatusLabel(o), 1, 1, 1, 0.7, 0.9, 0.7)
    local by = ns.OrderAcceptedBy(o)
    if by and by ~= "" then GameTooltip:AddDoubleLine(T("Accepted by"), by, 1, 1, 1, 0.6, 0.8, 1) end
    local reagents = ns.OrderReagents(o)
    if reagents then
      GameTooltip:AddLine(" ")
      for _, m in ipairs(reagents) do
        GameTooltip:AddDoubleLine(ns.ItemName(m.id), m.count .. "x", 1, 1, 1, 1, 0.82, 0)
      end
    else
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(T("No recipe reagents for this order."), 0.8, 0.5, 0.5)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(ns.IsSelected(o.id) and ("|cff88ff88" .. T("Left-click: deselect") .. "|r") or ("|cffaaaaaa" .. T("Left-click: select") .. "|r"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine("|cffaaaaaa" .. T("Right-click: set as fill target") .. "|r", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

--------------------------------------------------------------------------------
-- Shopping list (right)
--------------------------------------------------------------------------------
local function UpdateShop()
  local data = ns.Aggregate()
  local offset = FauxScrollFrame_GetOffset(shopScroll)
  for i = 1, #shopRows do
    local row = shopRows[i]
    local item = data[i + offset]
    if item then
      row.item = item
      row.icon:SetTexture(GetItemIcon(item.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetText(item.name)
      if item.toBuy > 0 then
        Style.SetTextColor(row.name, col("GOLD"))
        row.qty:SetText("|cffff6666" .. string.format(T("buy %d"), item.toBuy) .. "|r  |cff888888(" .. item.owned .. "/" .. item.needed .. ")|r")
      else
        Style.SetTextColor(row.name, col("GREEN"))
        row.qty:SetText("|cff66ff66" .. T("have all") .. "|r  |cff888888(" .. item.owned .. "/" .. item.needed .. ")|r")
      end
      row:Show()
    else
      row.item = nil
      row:Hide()
    end
  end
  FauxScrollFrame_Update(shopScroll, #data, #shopRows, ROWH)
end

local function MakeShopRow(parent, i)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROWH)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -LIST_TOP - (i - 1) * ROWH)
  row:SetPoint("RIGHT", parent, "RIGHT", -26, 0)

  local hover = Style.MakeSolid(row, "HIGHLIGHT", col("GOLD"), 0.1)
  hover:SetAllPoints()

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ROWH - 4, ROWH - 4)
  row.icon:SetPoint("LEFT", 2, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(150)
  row.name:SetJustifyH("LEFT")
  Style.SetNoWrap(row.name, 1)

  row.qty = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.qty:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  row.qty:SetPoint("RIGHT", -4, 0)
  row.qty:SetJustifyH("RIGHT")
  Style.SetNoWrap(row.qty, 1)

  row:SetScript("OnClick", function(self)
    if self.item and IsShiftKeyDown() then ns.SearchAH(self.item.id) end
  end)
  row:SetScript("OnEnter", function(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.item.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(T("Needed"), tostring(self.item.needed), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(T("Owned"), tostring(self.item.owned), 1, 1, 1, 0.6, 1, 0.6)
    GameTooltip:AddDoubleLine(T("To buy"), tostring(self.item.toBuy), 1, 1, 1, 1, 0.4, 0.4)
    if self.item.sources and #self.item.sources > 0 then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(self.item.viaSyn and T("Where you have it:") or T("On this character:"), 0.6, 0.8, 1)
      for _, s in ipairs(self.item.sources) do
        GameTooltip:AddDoubleLine("|c" .. ClassColorStr(s.className) .. (s.name or "?") .. "|r", tostring(s.count), 1, 1, 1, 1, 0.82, 0)
      end
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

--------------------------------------------------------------------------------
-- Refresh + trade controls
--------------------------------------------------------------------------------
local function UpdateTradeControls()
  local active = ns.GetActiveOrder()
  local title = active and (active.title or active.recipeName or "order") or nil
  if fillBtn then
    if not active then
      fillBtn:SetTone("muted"); fillBtn:SetText(T("Fill Trade (no order)"))
    elseif not ns.TradeOpen() then
      fillBtn:SetTone("ghost"); fillBtn:SetText(string.format(T("Fill: %s (open trade)"), title))
    else
      fillBtn:SetTone("green"); fillBtn:SetText(string.format(T("Fill: %s"), title))
    end
  end
  if cycleBtn then
    if #ns.SelectedOrderList() > 1 then cycleBtn:Show() else cycleBtn:Hide() end
  end
end

function ns.Refresh()
  if not frame or not frame:IsShown() then return end
  UpdateOrders()
  UpdateShop()
  if titleFS then
    titleFS:SetText("Guild Craft Browser " .. T("Cart") .. "  |cff888888(" .. string.format(T("%d selected"), ns.SelectionCount()) .. ")|r")
  end
  UpdateTradeControls()
end

function ns.OnTradeStateChanged()
  UpdateTradeControls()
end

--------------------------------------------------------------------------------
-- Build the window (GCB.Style themed)
--------------------------------------------------------------------------------
local function StyledScroll(name, parent)
  local s = CreateFrame("ScrollFrame", name, parent, "FauxScrollFrameTemplate")
  s:SetPoint("TOPLEFT", 0, -(LIST_TOP - 4))
  s:SetPoint("BOTTOMRIGHT", -24, 4)
  return s
end

-- Header placed INSIDE a panel (child of the panel) so it draws above the
-- panel's backdrop instead of behind sibling frames.
local function PanelHeader(panel, text)
  local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -7)
  fs:SetText(text)
  Style.SetTextColor(fs, C.SOFT)
  return fs
end

local function VisibleRows()
  return math.floor(((WIN_H - PANEL_TOP - PANEL_BOT) - LIST_TOP - 4) / ROWH)
end

function ns.BuildUI()
  if frame then return end
  local g = ns.GCB()
  Style = g and g.Style
  if not Style then
    ns.Print("|cffff5555MucklisGuildCraftBrowser style not found|r; cannot build UI.")
    return
  end
  C = Style.colors

  frame = CreateFrame("Frame", "MGCBCartFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WIN_W, WIN_H)
  Style.ApplyBackdrop(frame, C.BG_FRAME, C.BR_FRAME, 0.98)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.SavePosition()
  end)
  frame:SetClampedToScreen(true)
  ns.RestorePosition()
  frame:SetFrameStrata("HIGH")
  frame:Hide()
  tinsert(UISpecialFrames, "MGCBCartFrame")

  local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  titleBar:SetPoint("TOPLEFT", 4, -4)
  titleBar:SetPoint("TOPRIGHT", -4, -4)
  titleBar:SetHeight(28)
  Style.ApplyBackdrop(titleBar, C.BG_PANEL, C.BR_SOFT, 0.98)

  titleFS = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleFS:SetPoint("LEFT", 10, 0)
  titleFS:SetText("Guild Craft Browser " .. T("Cart"))
  Style.SetTextColor(titleFS, C.GOLD)

  local close = Style.MakeButton(frame, 24, 24, "X", "close")
  close:SetPoint("TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() frame:Hide() end)

  -- Filter label (below the title bar, above the search box; nothing overlaps it)
  local sLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sLbl:SetPoint("TOPLEFT", 14, -40)
  sLbl:SetText(T("Filter my orders"))
  Style.SetTextColor(sLbl, C.MUTED)

  -- Search box
  local search = Style.MakeEditBox(frame, 240, 22)
  search:SetPoint("TOPLEFT", 12, -54)
  search:SetScript("OnTextChanged", function(self) searchText = self:GetText() or ""; UpdateOrders() end)
  search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  -- Left panel: orders
  local left = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  left:SetPoint("TOPLEFT", 12, -PANEL_TOP)
  left:SetPoint("BOTTOMLEFT", 12, PANEL_BOT)
  left:SetWidth(LEFT_W)
  Style.ApplyBackdrop(left, C.BG_PANEL, C.BR_SOFT, 0.96)
  PanelHeader(left, T("My Orders"))

  ordersScroll = StyledScroll("MGCBCartOrdersScroll", left)
  ordersScroll:SetScript("OnVerticalScroll", function(self, delta)
    FauxScrollFrame_OnVerticalScroll(self, delta, ROWH, UpdateOrders)
  end)
  for i = 1, VisibleRows() do orderRows[i] = MakeOrderRow(left, i) end

  -- Right panel: shopping list
  local right = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
  right:SetPoint("BOTTOMRIGHT", -12, PANEL_BOT)
  Style.ApplyBackdrop(right, C.BG_PANEL, C.BR_SOFT, 0.96)
  PanelHeader(right, T("Shopping List"))

  shopScroll = StyledScroll("MGCBCartShopScroll", right)
  shopScroll:SetScript("OnVerticalScroll", function(self, delta)
    FauxScrollFrame_OnVerticalScroll(self, delta, ROWH, UpdateShop)
  end)
  for i = 1, VisibleRows() do shopRows[i] = MakeShopRow(right, i) end

  -- Bottom bar
  local clearBtn = Style.MakeButton(frame, 96, 24, T("Clear"), "ghost")
  clearBtn:SetPoint("BOTTOMLEFT", 12, 16)
  clearBtn:SetScript("OnClick", function() ns.ClearSelection() end)

  local refreshBtn = Style.MakeButton(frame, 80, 24, T("Refresh"), "ghost")
  refreshBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
  refreshBtn:SetScript("OnClick", function() ns.Refresh() end)

  fillBtn = Style.MakeButton(frame, 240, 26, T("Fill Trade"), "green")
  fillBtn:SetPoint("BOTTOMRIGHT", -12, 15)
  fillBtn:SetScript("OnClick", function() ns.FillTrade() end)

  cycleBtn = Style.MakeButton(frame, 28, 26, ">", "ghost")
  cycleBtn:SetPoint("RIGHT", fillBtn, "LEFT", -6, 0)
  cycleBtn:SetScript("OnClick", function() ns.CycleActiveOrder() end)
  cycleBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(T("Next order to fill"))
    GameTooltip:Show()
  end)
  cycleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  cycleBtn:Hide()

  ns.OnTradeStateChanged()
end

function ns.ToggleUI()
  if not frame then ns.BuildUI() end
  if not frame then return end
  if frame:IsShown() then frame:Hide() else frame:Show(); ns.Refresh() end
end

function ns.ShowUI()
  if not frame then ns.BuildUI() end
  if not frame then return end
  frame:Show()
  ns.Refresh()
end

-- Window position persistence (MGCBCartDB.window, per character).
function ns.SavePosition()
  if not frame then return end
  local point, _, relPoint, x, y = frame:GetPoint()
  if not point then return end
  MGCBCartDB.window = { point = point, relPoint = relPoint, x = x, y = y }
end

function ns.RestorePosition()
  if not frame then return end
  frame:ClearAllPoints()
  local w = MGCBCartDB and MGCBCartDB.window
  if w and w.point then
    frame:SetPoint(w.point, UIParent, w.relPoint or w.point, w.x or 0, w.y or 0)
  else
    frame:SetPoint("CENTER")
  end
end
