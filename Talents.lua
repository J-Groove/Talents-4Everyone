-- The talent order on Blizzard's talent window (docs\ui-design.md screen 4): a level badge on each planned talent,
-- a glow on the next one, and the order list docked to the window's right edge.
--
-- Everything here is our own frames, laid over Blizzard's or docked to them. Nothing changes Blizzard's buttons,
-- takes their clicks or calls anything that learns a talent: badges and glows don't take the mouse, so a click
-- there always reaches the game's own button.
local _, ns = ...
local Builds, Order, Character, Data, UI = ns.Builds, ns.Order, ns.Character, ns.Data, ns.UI

local Talents = {}
ns.Talents = Talents

-- Talent windows we know, newest first: the Blizzard addon that loads it, the window and its talents tab. Forever
-- uses PlayerSpellsFrame going by its addons (docs\design.md, "Open questions"); ClassTalentFrame is the 10.x one.
local WINDOWS = {
  { addon = "Blizzard_PlayerSpells", window = "PlayerSpellsFrame", tab = "TalentsFrame" },
  { addon = "Blizzard_ClassTalentUI", window = "ClassTalentFrame", tab = "TalentsTab" },
}

local LIST_WIDTH, ROW_HEIGHT = 250, 22
local GLOW = "Interface\\Buttons\\UI-ActionButton-Border"
local TICK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local WARN = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local function db() return Talents4eDB end
local function setting(name) return not (db().settings and db().settings[name] == false) end

---------------------------------------------------------------------------------------------------------------
-- What to show, worked out without the game's frames (tested in tests\talents.test.ts).

-- The character's state on the build it follows: { entry, build, plan, level, message } where message (with
-- kind) replaces the list when there is nothing to follow.
function Talents.State(level, ranks, legacyRanks)
  local classId, who = UI.player()
  local entry = Builds.Followed(db(), who)
  local state = { entry = entry, level = level }
  if not entry then
    state.message = { kind = "Info", text = "Follow a build in Talents-4Everyone to see its talent order here." }
    return state
  end
  local build, problem = Builds.Decode(entry)
  state.build = build
  if not build then
    state.message = { kind = "Error", text = problem }
  elseif build.classId ~= classId then
    state.message = { kind = "Warning", text = "The build you follow is for a " .. Builds.ClassName(build.classId)
      .. ". Follow one for this class." }
  elseif not ranks then
    state.message = { kind = "Error", text = "The game didn't give your talents. Check talents in the main window "
      .. "shows what it returns." }
  elseif #build.order == 0 then
    state.message = { kind = "Info", text = "This build has no talent order. Add one in the Build Calculator on "
      .. "wow-4e.com, then import it again." }
    state.ranksOnly = Order.Ranks(build, ranks)
  else
    state.plan = Order.Plan(build, ranks, level, Order.FirstLevel(legacyRanks))
  end
  return state
end

-- The list's rows: steps, then the "Not in your build" section. Each { kind = "step" | "header" | "off", ... }.
function Talents.Rows(build, plan, level)
  local rows = {}
  for k, step in ipairs(plan.steps) do
    local t = Order.Talent(build.classId, step.tree, step.index)
    rows[#rows + 1] = {
      kind = "step", step = k, level = step.level, tree = step.tree, index = step.index,
      name = t.name, icon = t.icon, spell = t.spell, rank = step.rank .. " of " .. t.ranks,
      state = step.taken and "taken" or (k == plan.next and "next" or "later"), reached = step.level <= level,
    }
  end
  if #plan.offPlan > 0 then
    rows[#rows + 1] = { kind = "header", name = "Not in your build" }
    for _, off in ipairs(plan.offPlan) do
      local t = Order.Talent(build.classId, off.tree, off.index)
      local planned = off.have - off.extra
      rows[#rows + 1] = {
        kind = "off", tree = off.tree, index = off.index, name = t.name, icon = t.icon, spell = t.spell,
        rank = off.have .. " of " .. t.ranks .. (planned > 0 and (" (" .. planned .. " planned)") or ""),
      }
    end
  end
  return rows
end

-- The badge on each talent: { [key] = { tree, index, text, kind } }, kind "next", "due" (a level), "taken" or
-- "off" (points the build doesn't plan).
function Talents.Badges(state)
  local out = {}
  local function put(tree, index, text, kind) out[tree * 100 + index] = { tree = tree, index = index, text = text, kind = kind } end
  if state.plan then
    for _, t in pairs(state.plan.talents) do
      if t.nextLevel then
        put(t.tree, t.index, tostring(t.nextLevel), t.nextStep == state.plan.next and "next" or "due")
      else
        put(t.tree, t.index, nil, "taken")
      end
    end
    for _, off in ipairs(state.plan.offPlan) do put(off.tree, off.index, nil, "off") end
  elseif state.ranksOnly then
    for _, t in pairs(state.ranksOnly) do
      if t.have >= t.planned then put(t.tree, t.index, nil, "taken")
      else put(t.tree, t.index, t.have .. "/" .. t.planned, "due") end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------------------
-- The frames.

local win, tab, overlay, list, folded
local badges, glow, hoverGlow = {}, nil, nil
local current -- the last State
local scrollToNext = false

local function nodeId(classId, tree, index)
  local class = Data.classes[classId]
  return class and class[tree] and class[tree].nodes[index]
end

-- Blizzard's button for a talent node, or nil. Only read: never changed.
local function talentButton(nodeID)
  if not nodeID or not tab then return nil end
  if tab.GetTalentButtonByNodeID then
    local ok, button = pcall(tab.GetTalentButtonByNodeID, tab, nodeID)
    if ok and button then return button end
  end
  if tab.EnumerateAllTalentButtons then
    for button in tab:EnumerateAllTalentButtons() do
      local id = button.GetNodeID and button:GetNodeID() or button.nodeID
      if id == nodeID then return button end
    end
  end
  return nil
end

local function makeGlow(r, g, b)
  local f = CreateFrame("Frame", nil, overlay)
  local tex = f:CreateTexture(nil, "OVERLAY")
  tex:SetTexture(GLOW)
  tex:SetBlendMode("ADD")
  tex:SetVertexColor(r, g, b)
  tex:SetAllPoints()
  local anim = f:CreateAnimationGroup()
  anim:SetLooping("BOUNCE")
  local fade = anim:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.3)
  fade:SetDuration(0.6)
  f.anim = anim
  f:Hide()
  return f
end

local function placeGlow(f, button, pulse)
  if not button then
    f:Hide()
    return
  end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", button, "TOPLEFT", -14, 14)
  f:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 14, -14)
  f:Show()
  if pulse then f.anim:Play() else f.anim:Stop() end
end

local function makeBadge()
  local b = CreateFrame("Frame", nil, overlay)
  b:SetSize(22, 15)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  b.bg = bg
  local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("CENTER", 0, 0)
  b.label = label
  local icon = b:CreateTexture(nil, "OVERLAY")
  icon:SetSize(14, 14)
  icon:SetPoint("CENTER")
  b.icon = icon
  return b
end

local function drawBadge(b, badge, button)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -3)
  b.label:SetShown(badge.text ~= nil)
  b.icon:SetShown(badge.text == nil)
  if badge.kind == "next" then
    b.bg:SetColorTexture(1, 0.82, 0, 1)
    b.label:SetTextColor(0, 0, 0)
  elseif badge.kind == "due" then
    b.bg:SetColorTexture(0, 0, 0, 0.85)
    b.label:SetTextColor(1, 0.82, 0)
  else
    b.bg:SetColorTexture(0, 0, 0, 0.6)
    b.icon:SetTexture(badge.kind == "off" and WARN or TICK)
  end
  if badge.text then b.label:SetText(badge.text) end
  b:Show()
end

local function drawTree(state)
  for _, b in pairs(badges) do b:Hide() end
  local classId = state.build and state.build.classId
  if setting("numbers") then
    for id, badge in pairs(Talents.Badges(state)) do
      local button = talentButton(nodeId(classId, badge.tree, badge.index))
      if button then
        badges[id] = badges[id] or makeBadge()
        drawBadge(badges[id], badge, button)
      end
    end
  end
  local plan = state.plan
  local step = plan and plan.next and plan.steps[plan.next]
  placeGlow(glow, step and talentButton(nodeId(classId, step.tree, step.index)), plan and plan.toSpend > 0)
end

---------------------------------------------------------------------------------------------------------------
-- The order list.

local function showTalentTooltip(row)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if row.data.spell and row.data.spell > 0 and GameTooltip.SetSpellByID then
    GameTooltip:SetSpellByID(row.data.spell)
  else
    GameTooltip:SetText(row.data.name)
  end
  GameTooltip:Show()
  local classId = current and current.build and current.build.classId
  placeGlow(hoverGlow, talentButton(nodeId(classId, row.data.tree, row.data.index)), true)
end

local function makeRow(i)
  local r = CreateFrame("Button", nil, list.content)
  r:SetSize(LIST_WIDTH - 40, ROW_HEIGHT)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.18)
  r.bg = bg
  r.level = UI.text(r, "GameFontNormalSmall", 30)
  r.level:SetPoint("LEFT", 4, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 36, 0)
  r.name = UI.text(r, "GameFontHighlightSmall", 100)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  r.name:SetWordWrap(false)
  r.rank = UI.text(r, "GameFontHighlightSmall")
  r.rank:SetPoint("RIGHT", -4, 0)
  r.rank:SetJustifyH("RIGHT")
  r:SetScript("OnEnter", function(self) if self.data and self.data.kind ~= "header" then showTalentTooltip(self) end end)
  r:SetScript("OnLeave", function()
    GameTooltip:Hide()
    hoverGlow:Hide()
  end)
  return r
end

local function drawRow(r, data)
  r.data = data
  r.bg:SetShown(data.state == "next")
  r:SetAlpha(data.state == "taken" and 0.5 or 1)
  r.icon:SetShown(data.kind ~= "header")
  if data.kind == "header" then
    r.level:SetText("")
    r.name:SetText("|cffff9919" .. data.name .. "|r")
    r.rank:SetText("")
  else
    r.icon:SetTexture("Interface\\Icons\\" .. data.icon)
    r.name:SetText(data.name)
    if data.kind == "off" then
      r.level:SetText("|T" .. WARN .. ":12|t")
      r.rank:SetText(data.rank)
    else
      local grey = not data.reached and data.state ~= "taken"
      r.level:SetText((grey and "|cff808080" or "") .. data.level .. (grey and "|r" or ""))
      r.rank:SetText(data.state == "taken" and ("|T" .. TICK .. ":12|t Taken") or data.rank)
    end
  end
  r:Show()
end

local function drawList(state)
  local entry = state.entry
  list.name:SetText(entry and entry.name or "Talents-4Everyone")
  list.change:SetText(entry and "Change build" or "Open Talents-4Everyone")
  -- Edit only for a build of this class that reads.
  list.edit:SetShown(state.build ~= nil and state.build.classId == UI.player())
  local plan = state.plan
  if plan then
    list.summary:SetText("Level " .. state.level .. " · " .. plan.spent .. " of " .. #state.build.order .. " points")
  else
    list.summary:SetText("")
  end
  list.message:SetShown(state.message ~= nil)
  list.scroll:SetShown(plan ~= nil)
  if state.message then list.message:SetText(UI.noteText(state.message.kind, state.message.text)) end

  local rows = plan and Talents.Rows(state.build, plan, state.level) or {}
  for i, data in ipairs(rows) do
    list.rows[i] = list.rows[i] or makeRow(i)
    drawRow(list.rows[i], data)
  end
  for i = #rows + 1, #list.rows do list.rows[i]:Hide() end
  list.content:SetHeight(math.max(1, #rows * ROW_HEIGHT))

  if scrollToNext and plan and plan.next then
    scrollToNext = false
    local wanted = math.max(0, (plan.next - 4) * ROW_HEIGHT)
    list.scroll:SetVerticalScroll(math.min(wanted, list.scroll:GetVerticalScrollRange()))
  end
end

local function setFolded(isFolded)
  db().listFolded = isFolded or nil
  Talents.Refresh()
end

local function makeList()
  list = CreateFrame("Frame", "Talents4eOrderList", tab, "BasicFrameTemplateWithInset")
  list:SetWidth(LIST_WIDTH)
  list:SetPoint("TOPLEFT", win, "TOPRIGHT", 2, 0)
  list:SetPoint("BOTTOMLEFT", win, "BOTTOMRIGHT", 2, 0)
  list:EnableMouse(true)
  local title = list:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -6)
  title:SetText("Talent order")
  -- The frame's X folds the list to a tab; the badges and glow stay.
  if type(list.CloseButton) == "table" then
    list.CloseButton:SetScript("OnClick", function() setFolded(true) end)
    UI.tooltip(list.CloseButton, { "Fold the list", "The level numbers and highlight stay on the talents." })
  end

  list.name = UI.text(list, "GameFontNormal", LIST_WIDTH - 24)
  list.name:SetPoint("TOPLEFT", 12, -32)
  list.name:SetWordWrap(false)
  list.summary = UI.text(list, "GameFontHighlightSmall", LIST_WIDTH - 24)
  list.summary:SetPoint("TOPLEFT", list.name, "BOTTOMLEFT", 0, -4)
  list.change = UI.button(list, "Change build", 140)
  list.change:SetPoint("TOPLEFT", list.summary, "BOTTOMLEFT", -2, -6)
  list.change:SetScript("OnClick", function()
    ns.Windows.ShowMain(current and current.entry and current.entry.id)
  end)
  list.edit = UI.button(list, "Edit", 80)
  list.edit:SetPoint("LEFT", list.change, "RIGHT", 6, 0)
  list.edit:SetScript("OnClick", function()
    if current and current.entry then ns.Planner.Open(current.entry) end
  end)
  UI.tooltip(list.edit, { "Edit", "Change this build's order in the talent planner." })

  list.message = UI.text(list, "GameFontHighlightSmall", LIST_WIDTH - 24)
  list.message:SetPoint("TOPLEFT", 12, -100)
  list.message:SetSpacing(3)

  local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -100)
  scroll:SetPoint("BOTTOMRIGHT", -30, 10)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(LIST_WIDTH - 40, 1)
  scroll:SetScrollChild(content)
  list.scroll, list.content, list.rows = scroll, content, {}

  folded = CreateFrame("Button", nil, tab)
  folded:SetSize(28, 28)
  folded:SetPoint("TOPLEFT", win, "TOPRIGHT", 0, -40)
  folded:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  folded:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  folded:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  folded:SetScript("OnClick", function() setFolded(false) end)
  UI.tooltip(folded, { "Talent order", "Show the Talents-4Everyone order list." })
end

---------------------------------------------------------------------------------------------------------------
-- Hooking the window. Only HookScript and hooksecurefunc (post-hooks): Blizzard's code runs as it would without us.

local function attach(known)
  if win then return true end
  local w = _G[known.window]
  local t = w and w[known.tab]
  if not t then return false end
  win, tab = w, t
  overlay = CreateFrame("Frame", nil, tab)
  overlay:SetAllPoints(tab)
  overlay:SetFrameStrata(win:GetFrameStrata())
  overlay:SetFrameLevel(math.min(9000, win:GetFrameLevel() + 500))
  glow = makeGlow(1, 0.82, 0)
  hoverGlow = makeGlow(0.5, 0.8, 1)
  makeList()
  tab:HookScript("OnShow", function()
    scrollToNext = true
    Talents.Refresh()
  end)
  -- The tree's buttons are made again when it loads; place the badges after Blizzard has.
  if tab.LoadTalentTree then hooksecurefunc(tab, "LoadTalentTree", function() Talents.Refresh() end) end
  return true
end

local function tryAttach(addonName)
  for _, known in ipairs(WINDOWS) do
    if (addonName == nil or addonName == known.addon) and attach(known) then return end
  end
end

local pending = false
local levelNow -- set by PLAYER_LEVEL_UP, since UnitLevel can lag a moment behind it

-- Redraws on the next frame, so several events at once draw once and Blizzard's tree has laid out first.
function Talents.Refresh()
  if not tab or pending then return end
  pending = true
  C_Timer.After(0, function()
    pending = false
    if not tab:IsShown() then return end
    local ranks, legacyRanks = Character.Ranks()
    current = Talents.State(math.max(levelNow or 0, UnitLevel("player")), ranks, legacyRanks)
    drawTree(current)
    local showList = setting("list") and not db().listFolded
    list:SetShown(showList)
    folded:SetShown(not showList)
    if showList then drawList(current) end
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" then
    tryAttach(arg)
  elseif event == "PLAYER_LOGIN" then
    tryAttach(nil) -- already loaded by another addon
  elseif event == "PLAYER_LEVEL_UP" then
    levelNow = arg
    Talents.Refresh()
  else
    Talents.Refresh()
  end
end)
