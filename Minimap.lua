-- The minimap button: left-click opens or closes the main window, right-click opens the Settings page, drag moves it
-- round the minimap. Hidden by the Minimap button setting. Our own small button, no libraries (docs\design.md,
-- "Decisions"); its place is saved in Talents4eDB.minimapAngle (degrees).
local _, ns = ...

local Minimap_ = {}
ns.Minimap = Minimap_

local DEFAULT_ANGLE = 200
-- The site's 4E monogram on a round disc (Media\Icon.tga, made by tools\make-icon.mjs).
local ICON = "Interface\\AddOns\\Talents4e\\Media\\Icon"

local function db() return Talents4eDB end

local button

-- The button's offset from the minimap's centre for an angle in degrees, just outside a round minimap's edge.
function Minimap_.Offset(angle, radius)
  local a = math.rad(angle)
  return math.cos(a) * radius, math.sin(a) * radius
end

local function radius()
  return (Minimap:GetWidth() or 140) / 2 + 10
end

local function place()
  local x, y = Minimap_.Offset(db().minimapAngle or DEFAULT_ANGLE, radius())
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- While dragged, the button follows the cursor round the minimap.
local function follow()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
  db().minimapAngle = math.floor(angle + 0.5) % 360
  place()
end

local function make()
  button = CreateFrame("Button", "Talents4eMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(20, 20)
  icon:SetPoint("TOPLEFT", 7, -5)
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then ns.Settings.Open() else ns.Windows.ToggleMain() end
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", follow)
    GameTooltip:Hide()
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Talents-4Everyone")
    GameTooltip:AddLine("Click: your saved builds", 1, 1, 1)
    GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Shows or hides the button by the setting, making it the first time it shows.
function Minimap_.Refresh()
  local on = ns.Settings.Get("minimap")
  if not on then
    if button then button:Hide() end
    return
  end
  if not Minimap then return end
  if not button then make() end
  place()
  button:Show()
end

function Minimap_.Button() return button end
