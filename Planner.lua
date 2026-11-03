-- The talent planner (docs\ui-design.md screen 6, docs\design.md "Talent planner"): the class's three trees drawn by
-- the addon in its own window, where each click adds the next point of a talent order. Saved as a build, or copied
-- as a wow-4e.com link.
--
-- Never on Blizzard's talent window: a click there must always mean learning the talent for real. Nothing here
-- learns talents. The point rules are Rules.lua's (the site's talents.ts).
local _, ns = ...
local Builds, Order, Rules, Character, Core, Data, UI = ns.Builds, ns.Order, ns.Rules, ns.Character, ns.Core, ns.Data, ns.UI

local Planner = {}
ns.Planner = Planner

local function db() return Talents4eDB end

---------------------------------------------------------------------------------------------------------------
-- The plan being edited, without the game's frames (tested in tests\planner.test.ts).
--   classId, shapes (Rules.Shapes), order ({ tree, index } steps), firstLevel, points (the character's at its
--   level), limit (the most points the plan may hold), pool (ranks still to place, or nil), entry (the saved build
--   being edited, or nil), base (the build the code is made from), dirty, message ({ kind, text } after a refused
--   click).

local function copyRanks(ranks)
  local out = {}
  for t, tree in pairs(ranks or {}) do
    out[t] = {}
    for i, rank in pairs(tree) do out[t][i] = rank end
  end
  return out
end

local function poolTotal(pool)
  return pool and Rules.TotalSpent(pool) or 0
end

-- opts: classId, level, legacyRanks (the character's), entry and build (a saved build to edit), base (the
-- character's own build, for a new plan).
function Planner.New(opts)
  local plan = {
    classId = opts.classId,
    shapes = Rules.Shapes(opts.classId),
    firstLevel = Order.FirstLevel(opts.legacyRanks),
    entry = opts.entry,
    base = opts.build or opts.base,
    order = {},
    dirty = false,
  }
  plan.points = Order.PointsAtLevel(opts.level, plan.firstLevel)
  local build = opts.build
  if build and #build.order > 0 then
    plan.order = Rules.LegalOrder(plan.shapes, build.order)
  elseif build then
    -- A ranks-only build: its points become the pool to put in order.
    plan.pool = copyRanks(build.talents)
    if poolTotal(plan.pool) == 0 then plan.pool = nil end
  end
  -- A saved build may plan past the character's level; all of it can still be edited.
  plan.limit = math.max(plan.points, #plan.order, poolTotal(plan.pool))
  return plan
end

-- The ranks the order holds.
function Planner.Ranks(plan)
  return Rules.RanksOf(plan.order)
end

-- The level a step is taken at.
function Planner.StepLevel(plan, step)
  return plan.firstLevel + step - 1
end

-- Ranks of the pool not yet in the order, and how many points that is.
function Planner.PoolLeft(plan)
  if not plan.pool then return nil, 0 end
  local have = Planner.Ranks(plan)
  local left, count = {}, 0
  for t, tree in pairs(plan.pool) do
    for i, rank in pairs(tree) do
      local n = rank - Rules.RankAt(have, t, i)
      if n > 0 then
        left[t] = left[t] or {}
        left[t][i] = n
        count = count + n
      end
    end
  end
  return left, count
end

-- Left-click adds a point at the next level; right-click (remove) takes the talent's latest point off. Returns
-- whether the order changed; a refusal is left in plan.message.
function Planner.Click(plan, tree, index, remove)
  plan.message = nil
  if remove then
    local at = Rules.LastStep(plan.order, tree, index)
    if not at then return false end
    return Planner.RemoveAt(plan, at)
  end
  local order, block = Rules.AddStep(plan.shapes, plan.order, plan.limit, tree, index)
  if not order then
    plan.message = { kind = "Warning", text = Rules.BlockText(plan.classId, tree, index, block) }
    return false
  end
  plan.order = order
  plan.dirty = true
  return true
end

-- Takes one step out of the order; the steps after it each move a level earlier. Refused when one of them would
-- then come too early.
function Planner.RemoveAt(plan, step)
  plan.message = nil
  local order, problem = Rules.RemoveStep(plan.shapes, plan.order, step)
  if not order then
    plan.message = { kind = "Warning", text = Rules.BlockText(plan.classId, problem.tree, problem.index,
      problem.block, Planner.StepLevel(plan, problem.step)) }
    return false
  end
  plan.order = order
  plan.dirty = true
  return true
end

-- Starts again from the character's ranks: the order empties and the ranks become the pool to place.
function Planner.StartFrom(plan, ranks)
  plan.message = nil
  plan.order = {}
  plan.pool = copyRanks(ranks)
  if poolTotal(plan.pool) == 0 then plan.pool = nil end
  plan.limit = math.max(plan.limit, poolTotal(plan.pool))
  plan.dirty = true
end

-- Puts the pool's remaining points at the end of the order, top rows first, as far as the rules allow.
function Planner.PlaceRest(plan)
  plan.message = nil
  local left = Planner.PoolLeft(plan)
  if not left then return end
  local steps = {}
  for i, s in ipairs(plan.order) do steps[i] = s end
  for _, s in ipairs(Rules.DefaultSteps(plan.shapes, left)) do steps[#steps + 1] = s end
  local order = Rules.LegalOrder(plan.shapes, steps)
  while #order > plan.limit do table.remove(order) end
  plan.order = order
  plan.dirty = true
end

function Planner.Clear(plan)
  plan.message = nil
  plan.order = {}
  plan.dirty = true
end

-- The build to save or copy: the base build's class, race, body type, gear and Legacy perks with the planned
-- order. The level is raised to the order's last step when the order goes past it.
function Planner.Build(plan)
  local base = plan.base or {}
  local talents = Core.RanksFromOrder(plan.order)
  local level = math.max(base.level or 1, #plan.order > 0 and Planner.StepLevel(plan, #plan.order) or 1)
  return {
    gameBuild = Core.GameBuildNumber(Data.build),
    classId = plan.classId,
    raceId = base.raceId or 1,
    sex = base.sex or 0,
    level = math.min(Core.MAX_LEVEL, level),
    talents = talents,
    order = plan.order,
    gear = base.gear or {},
    legacy = base.legacy or {},
  }
end

-- The header's points line: "14 of 14 points · level 23 · first point at level 10".
function Planner.Summary(plan, level)
  local line = #plan.order .. " of " .. plan.limit .. " points · level " .. level .. " · first point at level "
    .. plan.firstLevel
  if plan.firstLevel < Order.FIRST_TALENT_LEVEL then line = line .. " (Talented)" end
  return line
end

-- The line under the trees: a refusal, or what to do next.
function Planner.Hint(plan)
  if plan.message then return plan.message end
  if plan.limit == 0 then
    return { kind = "Info", text = "Talents start at level " .. plan.firstLevel .. "." }
  end
  local _, left = Planner.PoolLeft(plan)
  if left > 0 then
    return { kind = "Info", text = "Points from your talents still to place: " .. left
      .. ". Click them in the order you took them, or Place the rest." }
  end
  if #plan.order == 0 then
    return { kind = "Info", text = "Click a talent to take it at level " .. plan.firstLevel .. "." }
  end
  if #plan.order >= plan.limit then
    return { kind = "Success", text = "Every point to level " .. Planner.StepLevel(plan, plan.limit)
      .. " is placed. Save it, or copy the link." }
  end
  return { kind = "Info", text = "Left-click adds a point at level " .. Planner.StepLevel(plan, #plan.order + 1)
    .. ". Right-click takes a talent's last point off." }
end

-- The order list's rows: { step, level, tree, index, name, icon, spell, rank = "2 of 5" }, newest at the bottom.
function Planner.Rows(plan)
  local rows, seen = {}, {}
  for step, s in ipairs(plan.order) do
    local key = s.tree * 100 + s.index
    seen[key] = (seen[key] or 0) + 1
    local talent = Order.Talent(plan.classId, s.tree, s.index)
    rows[step] = { step = step, level = Planner.StepLevel(plan, step), tree = s.tree, index = s.index,
      name = talent.name, icon = talent.icon, spell = talent.spell, rank = seen[key] .. " of " .. talent.ranks }
  end
  return rows
end

-- The levels each planned rank of a talent is taken at.
function Planner.Levels(plan, tree, index)
  local levels = {}
  for step, s in ipairs(plan.order) do
    if s.tree == tree and s.index == index then levels[#levels + 1] = Planner.StepLevel(plan, step) end
  end
  return levels
end

---------------------------------------------------------------------------------------------------------------
-- The window.

local CELL, ICON = 46, 36
local TREE_WIDTH, TREE_HEIGHT = 4 * CELL + 16, 7 * CELL + 30
local LIST_WIDTH, ROW_HEIGHT = 236, 22
local TOP = -80
local GOLD_HEX, GREEN_HEX, GREY_HEX = "ffd100", "40ff40", "808080"

local frame, plan, playerLevel, hovered
local refresh -- set below

local function talentInfo(tree, index)
  return Order.Talent(plan.classId, tree, index)
end

local talentTooltip -- set below

local function setColor(tex, r, g, b, a) tex:SetColorTexture(r, g, b, a or 1) end

-- A talent's button: coloured frame (gold full, green partly taken, grey locked), icon, rank, first level.
local function makeTalent(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(ICON, ICON)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.frame = b:CreateTexture(nil, "BACKGROUND")
  b.frame:SetPoint("TOPLEFT", -2, 2)
  b.frame:SetPoint("BOTTOMRIGHT", 2, -2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b.hover = b:CreateTexture(nil, "OVERLAY")
  b.hover:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  b.hover:SetBlendMode("ADD")
  b.hover:SetVertexColor(0.4, 0.75, 1)
  b.hover:SetPoint("TOPLEFT", -13, 13)
  b.hover:SetPoint("BOTTOMRIGHT", 13, -13)
  b.hover:Hide()
  b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.rank:SetPoint("BOTTOMRIGHT", 4, -3)
  b.level = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.level:SetPoint("TOPLEFT", -3, 3)
  b.levelBg = b:CreateTexture(nil, "OVERLAY", nil, -1)
  b.levelBg:SetPoint("TOPLEFT", b.level, "TOPLEFT", -2, 1)
  b.levelBg:SetPoint("BOTTOMRIGHT", b.level, "BOTTOMRIGHT", 2, -1)
  setColor(b.levelBg, 0, 0, 0, 0.8)
  b.pool = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.pool:SetPoint("TOPRIGHT", 3, 3)
  b.pool:SetTextColor(0.4, 0.75, 1)
  b:SetScript("OnClick", function(self, mouse)
    Planner.Click(plan, self.tree, self.index, mouse == "RightButton" or IsShiftKeyDown())
    refresh()
    if hovered == self then talentTooltip(self) end
  end)
  b:SetScript("OnEnter", function(self)
    hovered = self
    talentTooltip(self)
  end)
  b:SetScript("OnLeave", function()
    hovered = nil
    GameTooltip:Hide()
  end)
  return b
end

talentTooltip = function(b)
  local info = talentInfo(b.tree, b.index)
  GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
  if info.spell and info.spell > 0 and GameTooltip.SetSpellByID then
    GameTooltip:SetSpellByID(info.spell)
  else
    GameTooltip:SetText(info.name)
  end
  local ranks = Planner.Ranks(plan)
  local rank = Rules.RankAt(ranks, b.tree, b.index)
  GameTooltip:AddLine("Rank " .. rank .. "/" .. info.ranks, 1, 1, 1)
  local levels = Planner.Levels(plan, b.tree, b.index)
  if #levels > 0 then GameTooltip:AddLine("Taken at level " .. table.concat(levels, ", "), 1, 0.82, 0) end
  local block = rank < info.ranks and Rules.AddBlock(plan.shapes, ranks, nil, b.tree, b.index)
  if block == "row-locked" or block == "needs-prereq" then
    GameTooltip:AddLine(Rules.BlockText(plan.classId, b.tree, b.index, block), 1, 0.3, 0.3, true)
  end
  local left = Planner.PoolLeft(plan)
  local fromPool = left and Rules.RankAt(left, b.tree, b.index) or 0
  if fromPool > 0 then GameTooltip:AddLine(fromPool .. " from your talents to place", 0.4, 0.75, 1) end
  GameTooltip:AddLine("Left-click: add a point. Right-click: take the last one off.", 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end

local function makeTree(t)
  local panel = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
  panel:SetSize(TREE_WIDTH, TREE_HEIGHT)
  panel:SetPoint("TOPLEFT", 12 + (t - 1) * (TREE_WIDTH + 6), TOP)
  panel.title = UI.text(panel, "GameFontNormal", TREE_WIDTH - 16)
  panel.title:SetPoint("TOPLEFT", 8, -8)
  panel.buttons, panel.lines = {}, {}
  return panel
end

-- A prerequisite line between two talents in the same row or column, under the buttons.
local function drawLine(panel, i, from, to, met)
  local line = panel.lines[i] or panel:CreateTexture(nil, "ARTWORK")
  panel.lines[i] = line
  line:ClearAllPoints()
  if from.col == to.col then
    line:SetWidth(4)
    line:SetPoint("TOP", panel.buttons[from.i], "BOTTOM", 0, -2)
    line:SetPoint("BOTTOM", panel.buttons[to.i], "TOP", 0, 2)
  else
    line:SetHeight(4)
    line:SetPoint("LEFT", panel.buttons[from.i], "RIGHT", 2, 0)
    line:SetPoint("RIGHT", panel.buttons[to.i], "LEFT", -2, 0)
  end
  if met then setColor(line, 1, 0.82, 0, 0.9) else setColor(line, 0.4, 0.4, 0.4, 0.9) end
  line:Show()
end

local function drawTrees()
  local trees = Data.classes[plan.classId] or {}
  local ranks = Planner.Ranks(plan)
  local left = Planner.PoolLeft(plan)
  for t, tree in ipairs(trees) do
    local panel = frame.trees[t] or makeTree(t)
    frame.trees[t] = panel
    panel.title:SetText(tree.name .. "  |cffffffff" .. Rules.TreeSpent(ranks, t) .. "|r")
    for i, info in ipairs(tree.talents) do
      local b = panel.buttons[i] or makeTalent(panel)
      panel.buttons[i] = b
      b.tree, b.index = t, i
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 8 + (info.col - 1) * CELL + (CELL - ICON) / 2, -28 - (info.row - 1) * CELL)
      b.icon:SetTexture("Interface\\Icons\\" .. info.icon)
      local rank = Rules.RankAt(ranks, t, i)
      local open = rank > 0 or not Rules.AddBlock(plan.shapes, ranks, nil, t, i)
      b.icon:SetDesaturated(not open)
      if rank >= info.ranks then
        setColor(b.frame, 1, 0.82, 0)
      elseif rank > 0 then
        setColor(b.frame, 0.25, 1, 0.25)
      else
        setColor(b.frame, 0.3, 0.3, 0.3)
      end
      local hex = rank >= info.ranks and GOLD_HEX or (rank > 0 and GREEN_HEX or (open and "ffffff" or GREY_HEX))
      b.rank:SetText("|cff" .. hex .. rank .. "/" .. info.ranks .. "|r")
      local levels = Planner.Levels(plan, t, i)
      b.level:SetText(levels[1] or "")
      b.level:SetShown(levels[1] ~= nil)
      b.levelBg:SetShown(levels[1] ~= nil)
      local fromPool = left and Rules.RankAt(left, t, i) or 0
      b.pool:SetText(fromPool > 0 and ("+" .. fromPool) or "")
      b:Show()
    end
    for i = #tree.talents + 1, #panel.buttons do panel.buttons[i]:Hide() end
    local n = 0
    for i, info in ipairs(tree.talents) do
      local req = info.req and tree.talents[info.req.index]
      if req and (req.row == info.row or req.col == info.col) then
        n = n + 1
        drawLine(panel, n, { i = info.req.index, col = req.col }, { i = i, col = info.col },
          Rules.RankAt(ranks, t, info.req.index) >= info.req.rank)
      end
    end
    for i = n + 1, #panel.lines do panel.lines[i]:Hide() end
    panel:Show()
  end
  for t = #trees + 1, #frame.trees do frame.trees[t]:Hide() end
end

local function hoverTalent(row, on)
  local panel = row and frame.trees[row.tree]
  local b = panel and panel.buttons[row.index]
  if b then b.hover:SetShown(on) end
end

local function makeRow(i)
  local r = CreateFrame("Button", nil, frame.content)
  r:SetSize(LIST_WIDTH - 34, ROW_HEIGHT)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
  r:RegisterForClicks("RightButtonUp")
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  setColor(hl, 1, 1, 1, 0.08)
  r.level = UI.text(r, "GameFontNormalSmall", 26)
  r.level:SetPoint("LEFT", 4, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", 32, 0)
  r.name = UI.text(r, "GameFontHighlightSmall", 100)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
  r.name:SetWordWrap(false)
  r.rank = UI.text(r, "GameFontHighlightSmall")
  r.rank:SetPoint("RIGHT", -4, 0)
  r.rank:SetJustifyH("RIGHT")
  r:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.data.spell and self.data.spell > 0 and GameTooltip.SetSpellByID then
      GameTooltip:SetSpellByID(self.data.spell)
    else
      GameTooltip:SetText(self.data.name)
    end
    GameTooltip:AddLine("Level " .. self.data.level .. ", rank " .. self.data.rank, 1, 0.82, 0)
    GameTooltip:AddLine("Right-click to take this step out; the steps after it move a level earlier.",
      0.5, 0.5, 0.5, true)
    GameTooltip:Show()
    hoverTalent(self.data, true)
  end)
  r:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
    hoverTalent(self.data, false)
  end)
  r:SetScript("OnClick", function(self)
    hoverTalent(self.data, false)
    Planner.RemoveAt(plan, self.data.step)
    refresh()
  end)
  return r
end

local function drawList()
  local rows = Planner.Rows(plan)
  for i, data in ipairs(rows) do
    local r = frame.rows[i] or makeRow(i)
    frame.rows[i] = r
    r.data = data
    r.level:SetText(data.level)
    r.icon:SetTexture("Interface\\Icons\\" .. data.icon)
    r.name:SetText(data.name)
    r.rank:SetText(data.rank)
    r:Show()
  end
  for i = #rows + 1, #frame.rows do frame.rows[i]:Hide() end
  frame.content:SetHeight(math.max(1, #rows * ROW_HEIGHT))
  frame.empty:SetShown(#rows == 0)
end

refresh = function()
  if not frame or not plan then return end
  frame.heading:SetText(plan.entry and ("Editing: " .. plan.entry.name) or "New build")
  frame.summary:SetText(Planner.Summary(plan, playerLevel))
  drawTrees()
  drawList()
  local hint = Planner.Hint(plan)
  frame.hint:SetText(UI.noteText(hint.kind, hint.text))
  local _, left = Planner.PoolLeft(plan)
  frame.placeRest:SetShown(left > 0)
  frame.save:SetEnabled(#plan.order > 0)
  frame.copy:SetEnabled(#plan.order > 0)
  frame.clear:SetEnabled(#plan.order > 0)
end

local function close()
  plan, hovered = nil, nil
  frame:Hide()
end

-- Saves the plan: over the build being edited (replace) or as a new one. Follows it when ticked.
local function save(replace)
  local code = Core.EncodeBuild(Planner.Build(plan))
  -- A name left as the planner filled it in follows the build's points.
  local name = frame.nameEdited and frame.name:GetText()
    or (plan.entry and plan.entry.name or Builds.DefaultName(Planner.Build(plan)))
  local entry, problem
  if replace and plan.entry then
    entry, problem = Builds.Replace(db(), plan.entry.id, code, name)
  else
    entry, problem = Builds.Add(db(), code, name, time())
  end
  if not entry then
    plan.message = { kind = "Error", text = problem }
    refresh()
    return
  end
  local classId, who = UI.player()
  if frame.follow:GetChecked() then Builds.Follow(db(), who, entry.id, classId) end
  close()
  ns.Windows.ShowMain(entry.id)
end
Planner.Save = save

StaticPopupDialogs.TALENTS4E_SAVE_OVER = {
  text = "Save over \"%s\"?",
  button1 = "Save over it",
  button2 = "Cancel",
  button3 = "Save as new",
  OnAccept = function() save(true) end,
  OnAlt = function() save(false) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs.TALENTS4E_LEAVE_PLANNER = {
  text = "Leave the planner without saving?",
  button1 = "Leave",
  button2 = "Keep editing",
  OnAccept = function() close() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function cancel()
  if plan and plan.dirty then StaticPopup_Show("TALENTS4E_LEAVE_PLANNER") else close() end
end
Planner.Cancel = cancel

local function getFrame()
  if frame then return frame end
  -- Not closed by Escape: unsaved work would go without asking. Its X and Cancel ask first.
  local f = UI.window("Talents4ePlannerFrame", "Talents-4Everyone: talent planner",
    12 + 3 * (TREE_WIDTH + 6) + LIST_WIDTH + 10, 540, true)
  if type(f.CloseButton) == "table" then f.CloseButton:SetScript("OnClick", cancel) end
  f.trees, f.rows = {}, {}
  frame = f

  f.heading = UI.text(f, "GameFontNormalLarge", 420)
  f.heading:SetPoint("TOPLEFT", 16, -32)
  f.heading:SetWordWrap(false)
  f.summary = UI.text(f, "GameFontHighlightSmall", 460)
  f.summary:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -6)

  f.clear = UI.button(f, "Clear", 80)
  f.clear:SetPoint("TOPRIGHT", -12, -34)
  f.clear:SetScript("OnClick", function() Planner.Clear(plan); refresh() end)
  local mine = UI.button(f, "Start from my talents", 160)
  mine:SetPoint("RIGHT", f.clear, "LEFT", -8, 0)
  mine:SetScript("OnClick", function()
    local ranks = Character.Ranks()
    if not ranks then
      plan.message = { kind = "Error", text = "The game didn't give your talents. Check talents in the main window "
        .. "shows what it returns." }
    else
      Planner.StartFrom(plan, ranks)
    end
    refresh()
  end)
  UI.tooltip(mine, { "Start from my talents", "Empties the order and lists your talents' points, to click in the "
    .. "order you took them." })
  f.placeRest = UI.button(f, "Place the rest", 120)
  f.placeRest:SetPoint("RIGHT", mine, "LEFT", -8, 0)
  f.placeRest:SetScript("OnClick", function() Planner.PlaceRest(plan); refresh() end)
  UI.tooltip(f.placeRest, { "Place the rest", "Adds your remaining points at the end, top rows first." })

  -- The order list, right of the trees.
  local listX = 12 + 3 * (TREE_WIDTH + 6)
  local inset = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
  inset:SetPoint("TOPLEFT", listX, TOP)
  inset:SetSize(LIST_WIDTH, TREE_HEIGHT)
  local listTitle = UI.text(inset, "GameFontNormal", LIST_WIDTH - 16)
  listTitle:SetPoint("TOPLEFT", 8, -8)
  listTitle:SetText("Order")
  local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -26)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(LIST_WIDTH - 34, 1)
  scroll:SetScrollChild(content)
  f.scroll, f.content = scroll, content
  f.empty = UI.text(inset, "GameFontDisableSmall", LIST_WIDTH - 24)
  f.empty:SetPoint("TOPLEFT", 12, -34)
  f.empty:SetText("Each point you place is listed here with its level.")

  f.hint = UI.text(f, "GameFontHighlightSmall", 12 + 3 * (TREE_WIDTH + 6) + LIST_WIDTH - 20)
  f.hint:SetPoint("TOPLEFT", 16, TOP - TREE_HEIGHT - 10)

  local nameLabel = UI.text(f, "GameFontNormal")
  nameLabel:SetPoint("BOTTOMLEFT", 16, 18)
  nameLabel:SetText("Name")
  local name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  name:SetSize(240, 24)
  name:SetPoint("LEFT", nameLabel, "RIGHT", 14, 0)
  name:SetAutoFocus(false)
  name:SetMaxLetters(Builds.MAX_NAME)
  name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  name:SetScript("OnTextChanged", function(_, userInput) if userInput then f.nameEdited = true end end)
  f.name = name
  local follow = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  follow:SetSize(24, 24)
  follow:SetPoint("LEFT", name, "RIGHT", 12, 0)
  local followLabel = UI.text(f, "GameFontHighlight")
  followLabel:SetPoint("LEFT", follow, "RIGHT", 2, 1)
  followLabel:SetText("Follow it on this character")
  f.follow = follow

  local cancelButton = UI.button(f, "Cancel", 96)
  cancelButton:SetPoint("BOTTOMRIGHT", -12, 14)
  cancelButton:SetScript("OnClick", cancel)
  f.copy = UI.button(f, "Copy link", 110)
  f.copy:SetPoint("RIGHT", cancelButton, "LEFT", -8, 0)
  f.copy:SetScript("OnClick", function()
    ns.Windows.ShowLink(Core.EncodeBuild(Planner.Build(plan)),
      { { kind = "Info", text = "Your planned order, with this character's race, gear and Legacy perks." } })
  end)
  f.save = UI.button(f, "Save", 96)
  f.save:SetPoint("RIGHT", f.copy, "LEFT", -8, 0)
  f.save:SetScript("OnClick", function()
    if plan.entry then
      StaticPopup_Show("TALENTS4E_SAVE_OVER", plan.entry.name)
    else
      save(false)
    end
  end)
  return f
end

-- Opens the planner on a saved build (entry), or on a new plan when entry is nil. Only for the character's class.
function Planner.Open(entry)
  local classId = UI.player()
  local build
  if entry then
    local problem
    build, problem = Builds.Decode(entry)
    if not build then return false, problem end
    if build.classId ~= classId then
      return false, "Log in on a " .. Builds.ClassName(build.classId) .. " to edit this build."
    end
  end
  local _, legacyRanks = Character.Ranks()
  playerLevel = UnitLevel("player")
  local base = not entry and Character.Read() or nil
  plan = Planner.New({ classId = classId, level = playerLevel, legacyRanks = legacyRanks, entry = entry,
    build = build, base = base })
  local f = getFrame()
  f.nameEdited = false
  f.name:SetText(entry and entry.name or "")
  f.follow:SetChecked(true)
  f:Show()
  refresh()
  return true
end

-- The plan being edited, for tests.
function Planner.Current() return plan end
