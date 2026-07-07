local ADDON, ns = ...

local BUTTON_SIZE, ICON_SIZE, BORDER_SIZE = 31, 20, 54
local DEFAULT_ANGLE = 210
local ICON_PATH = "Interface\\Icons\\Trade_Engraving" -- enchanting rod / craft icon
local button

local function settings()
  ns.EnsureDB()
  return MGCBCartDB.minimap
end

local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  return math.atan(y, x)
end

local function Position()
  if not button or not Minimap then return end
  local angle = tonumber(settings().angle) or DEFAULT_ANGLE
  local r = (math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2) + 10
  local rad = math.rad(angle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * r, math.sin(rad) * r)
end

local function UpdateDrag()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  if not mx or not cx or scale <= 0 then return end
  cx, cy = cx / scale, cy / scale
  settings().angle = math.deg(atan2(cy - my, cx - mx))
  Position()
end

function ns.MinimapInit()
  if button then return end
  if not Minimap then return end
  button = CreateFrame("Button", "MGCBCartMinimapButton", Minimap)
  button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:SetClampedToScreen(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetMovable(true)
  button:EnableMouse(true)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON_PATH)
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(BORDER_SIZE, BORDER_SIZE)
  border:SetPoint("TOPLEFT", 0, 0)

  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnClick", function() ns.ToggleUI() end)
  button:SetScript("OnEnter", function()
    if border.SetVertexColor then border:SetVertexColor(1, 0.82, 0.2, 1) end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:AddLine("Guild Craft Browser " .. ns.T("Cart"), 1, 0.82, 0.2)
    GameTooltip:AddLine(string.format(ns.T("%d open/accepted order(s)"), #ns.GetMyOrders()), 0.75, 0.78, 0.83)
    GameTooltip:AddLine(ns.T("Left-click: open  |  Drag: move"), 0.6, 0.63, 0.7)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if border.SetVertexColor then border:SetVertexColor(1, 1, 1, 1) end
    GameTooltip:Hide()
  end)
  button:SetScript("OnDragStart", function()
    button:LockHighlight()
    button:SetScript("OnUpdate", UpdateDrag)
  end)
  button:SetScript("OnDragStop", function()
    button:UnlockHighlight()
    button:SetScript("OnUpdate", nil)
    Position()
  end)

  Position()
  if settings().shown == false then button:Hide() else button:Show() end
end
