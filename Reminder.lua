-- The level-up reminder (docs\ui-design.md screen 5): a small toast near the talent button naming the talent the
-- followed build takes next. Clicking it opens the talent window, where that talent is highlighted. Never shown in
-- combat or a cinematic: it waits until they end. One at a time; a new level replaces it.
local _, ns = ...
local Builds, Order, Character, UI = ns.Builds, ns.Order, ns.Character, ns.UI

local Reminder = {}
ns.Reminder = Reminder

local SHOW_SECONDS = 20

local function db() return Talents4eDB end

local toast, waiting, shownAt

local function openTalents()
  if InCombatLockdown() then return end
  if PlayerSpellsUtil and PlayerSpellsUtil.OpenToClassTalentsTab then
    PlayerSpellsUtil.OpenToClassTalentsTab()
  elseif ToggleTalentFrame then
    ToggleTalentFrame()
  end
end

local function place(f)
  f:ClearAllPoints()
  local pos = db().reminderPos
  local micro = PlayerSpellsMicroButton or TalentMicroButton
  if pos then
    f:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
  elseif micro then
    f:SetPoint("BOTTOM", micro, "TOP", 0, 12)
  else
    f:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
end

local function getToast()
  if toast then return toast end
  local f = CreateFrame("Button", "Talents4eReminder", UIParent, "BackdropTemplate")
  f:SetSize(300, 58)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp")
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:SetBackdropBorderColor(1, 0.82, 0)
  end
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    db().reminderPos = { point = point, x = x, y = y }
  end)
  f:SetScript("OnClick", function(self)
    self:Hide()
    openTalents()
  end)
  f:Hide()
  tinsert(UISpecialFrames, "Talents4eReminder")

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(36, 36)
  f.icon:SetPoint("LEFT", 11, 0)
  f.heading = UI.text(f, "GameFontNormal", 220)
  f.heading:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -1)
  f.heading:SetWordWrap(false)
  f.body = UI.text(f, "GameFontHighlightSmall", 220)
  f.body:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -4)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() f:Hide() end)
  UI.tooltip(f, { "Talents-4Everyone", "Click to open your talents. Drag to move." })
  toast = f
  return f
end

-- Shows the reminder for this level, or nothing when there's nothing to say.
function Reminder.Show(level)
  local classId, who = UI.player()
  local entry = Builds.Followed(db(), who)
  local build = entry and Builds.Decode(entry)
  if not build or build.classId ~= classId or #build.order == 0 then return end
  local ranks, legacyRanks = Character.Ranks()
  if not ranks then return end
  local plan = Order.Plan(build, ranks, level, Order.FirstLevel(legacyRanks))
  local heading, body, icon = Order.Reminder(build, plan, level)
  if not heading then return end
  -- "Build complete" once per character and build.
  if not plan.next and #plan.offPlan == 0 then
    db().completed = db().completed or {}
    if db().completed[who] == entry.id then return end
    db().completed[who] = entry.id
  end
  local f = getToast()
  f.heading:SetText(heading)
  f.body:SetText(body)
  f.icon:SetTexture(icon and ("Interface\\Icons\\" .. icon) or UI.classIcon(classId))
  place(f)
  f:Show()
  local at = GetTime()
  shownAt = at
  C_Timer.After(SHOW_SECONDS, function()
    if shownAt == at and not f:IsMouseOver() then f:Hide() end
  end)
end

-- Settings: "Reset reminder position".
function Reminder.ResetPosition()
  db().reminderPos = nil
  if toast then place(toast) end
end

local function blocked()
  return InCombatLockdown() or (InCinematic and InCinematic()) or (IsInCinematicScene and IsInCinematicScene())
end

local function tryShow()
  if not waiting then return end
  if blocked() then
    C_Timer.After(3, tryShow)
    return
  end
  local level = waiting
  waiting = nil
  Reminder.Show(level)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, level)
  if event == "PLAYER_LEVEL_UP" then
    if db().settings and db().settings.reminder == false then return end
    waiting = level
    -- A moment later, so the new level's point is there; then out of combat.
    C_Timer.After(1, tryShow)
  else
    tryShow()
  end
end)
