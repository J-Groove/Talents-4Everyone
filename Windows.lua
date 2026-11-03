-- The addon's windows: the main window (saved builds), the import box, the export box and the talent check box.
-- Layouts follow docs\ui-design.md and the Figma screens 1 to 3. Every feature is a button here; /t4e only opens
-- the main window. Nothing here learns talents or changes Blizzard's frames.
local addonName, ns = ...
local Core, Data, Character, Builds = ns.Core, ns.Data, ns.Character, ns.Builds

local Windows = {}
ns.Windows = Windows

local GOLD, WHITE, GREY = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.5, 0.5, 0.5 }
local NOTE = {
  Info = { icon = "Interface\\FriendsFrame\\InformationIcon", color = WHITE },
  Success = { icon = "Interface\\RaidFrame\\ReadyCheck-Ready", color = { 0.1, 1, 0.1 } },
  Warning = { icon = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew", color = { 1, 0.6, 0.1 } },
  Error = { icon = "Interface\\RaidFrame\\ReadyCheck-NotReady", color = { 1, 0.13, 0.13 } },
}

local function db() return Talents4eDB end

local function player()
  local _, _, classId = UnitClass("player")
  local name, realm = UnitName("player"), GetRealmName()
  return classId, name .. "-" .. (realm or "")
end

local function classIcon(classId)
  local class = Data.classes[classId]
  return "Interface\\Icons\\" .. (class and class.icon or "inv_misc_questionmark")
end

-- A note line: an icon in front, coloured by kind. Each kind has its own icon, so colour is never the only sign.
local function noteText(kind, text)
  local n = NOTE[kind] or NOTE.Info
  local c = n.color
  return string.format("|T%s:14|t |cff%02x%02x%02x%s|r", n.icon,
    math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), text)
end

local function notesText(list)
  local lines = {}
  for i, note in ipairs(list) do lines[i] = noteText(note.kind, note.text) end
  return table.concat(lines, "\n")
end

-- A movable window with Blizzard's frame and a title, closed by Escape unless keepOnEscape.
local function window(name, title, width, height, keepOnEscape)
  local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  -- Our windows share a strata; raise the one that opens or is clicked so another's buttons never show through.
  f:SetToplevel(true)
  f:HookScript("OnShow", f.Raise)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()
  if not keepOnEscape then tinsert(UISpecialFrames, name) end
  local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("TOP", 0, -6)
  t:SetText(title)
  f.title = t
  return f
end

local function button(parent, label, width)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(label)
  return b
end

local function text(parent, font, width)
  local s = parent:CreateFontString(nil, "OVERLAY", font)
  s:SetJustifyH("LEFT")
  if width then s:SetWidth(width) end
  return s
end

-- A tooltip on a button, shown even while it is disabled (why it is disabled).
local function tooltip(widget, lines)
  widget:SetMotionScriptsWhileDisabled(true)
  widget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for i, line in ipairs(lines) do
      if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", GameTooltip_Hide)
end

-- A read-only text box: what is in it can be selected and copied, never changed.
local function readOnly(box, getText)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(getText())
      self:HighlightText()
    end
  end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
end

-- Shared with Talents.lua, Reminder.lua, Planner.lua and Settings.lua.
ns.UI = { player = player, classIcon = classIcon, noteText = noteText, text = text, button = button, tooltip = tooltip,
  window = window }

---------------------------------------------------------------------------------------------------------------
-- Export box (screen 1): the character as a wow-4e.com link, selected for Ctrl+C.

local exportFrame
local function getExportFrame()
  if exportFrame then return exportFrame end
  local f = window("Talents4eExportFrame", "Talents-4Everyone: export", 560, 170)
  local help = text(f, "GameFontNormal", 528)
  help:SetPoint("TOPLEFT", 16, -36)
  help:SetText("Press Ctrl+C to copy, then paste the link into your browser.")
  local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  box:SetSize(520, 24)
  box:SetPoint("TOPLEFT", 22, -58)
  box:SetAutoFocus(true)
  box:SetMaxLetters(0)
  box:SetFontObject(ChatFontNormal)
  box:SetScript("OnEscapePressed", function() f:Hide() end)
  readOnly(box, function() return f.link end)
  box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
  f.box = box
  local notes = text(f, "GameFontHighlightSmall", 528)
  notes:SetPoint("TOPLEFT", 16, -92)
  f.notes = notes
  exportFrame = f
  return f
end

-- Shows a build code's wow-4e.com link selected for Ctrl+C, with notes ({ kind, text }) under it.
function Windows.ShowLink(code, notes)
  local f = getExportFrame()
  f.link = Core.SITE_URL .. code
  f.box:SetText(f.link)
  f.notes:SetText(notesText(notes))
  f:Show()
  f.box:SetFocus()
  f.box:HighlightText()
end

function Windows.Export()
  local build, problems = Character.Read()
  local ok, code = pcall(Core.EncodeBuild, build)
  if not ok then
    local f = getExportFrame()
    f.link = ""
    f.box:SetText("")
    f.notes:SetText(noteText("Error", "Could not make a build code: " .. tostring(code))
      .. "\n" .. noteText("Info", "Use Check talents in the main window and send the lines with a bug report."))
    f:Show()
    return
  end
  local notes = {}
  for i, problem in ipairs(problems) do notes[i] = { kind = "Warning", text = problem } end
  if #notes == 0 then notes[1] = { kind = "Success", text = "Talents, Legacy perks and gear included." } end
  Windows.ShowLink(code, notes)
  db().lastExport = { code = code, time = time() }
end

---------------------------------------------------------------------------------------------------------------
-- Talent check box: what the game's talent APIs return, copyable for a bug report (was /t4e check).

local checkFrame
function Windows.Check()
  local lines = Character.Check()
  db().lastCheck = lines
  if not checkFrame then
    local f = window("Talents4eCheckFrame", "Talents-4Everyone: talent check", 560, 340)
    local help = text(f, "GameFontNormal", 528)
    help:SetPoint("TOPLEFT", 16, -34)
    help:SetText("Ctrl+A then Ctrl+C copies these lines for a bug report.")
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -56)
    scroll:SetPoint("BOTTOMRIGHT", -34, 12)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(500)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    readOnly(box, function() return f.content end)
    scroll:SetScrollChild(box)
    f.box = box
    checkFrame = f
  end
  checkFrame.content = table.concat(lines, "\n")
  checkFrame.box:SetText(checkFrame.content)
  checkFrame:Show()
end

---------------------------------------------------------------------------------------------------------------
-- Import box (screen 3): paste a link or code, see what it holds, name it, save it.

local importFrame
local refreshMain -- set below

local function readImport(f)
  local pasted = f.box:GetText()
  f.placeholder:SetShown(pasted == "")
  f.build = nil
  f.save:Disable()
  f.preview:Hide()
  if strtrim(pasted) == "" then
    f.notes:SetText("")
    return
  end
  local build, problem = Core.TryDecode(pasted)
  if not build then
    f.notes:SetText(noteText("Error", problem))
    return
  end
  local classId = player()
  f.build = build
  local trees, total = Builds.Trees(build)
  local perTree = {}
  for i, tree in ipairs(trees) do perTree[i] = tree.name .. " " .. tree.points end
  local slots = 0
  for _ in pairs(build.gear) do slots = slots + 1 end
  f.icon:SetTexture(classIcon(build.classId))
  f.line1:SetText(string.format("%s · %s · Body %d · level %d", Builds.ClassName(build.classId),
    Data.races[build.raceId] or ("race " .. build.raceId), build.sex + 1, build.level))
  f.line2:SetText(table.concat(perTree, " · ") .. " (" .. total .. " points)")
  f.line3:SetText((#build.order > 0 and "Talent order" or "Ranks only")
    .. (slots > 0 and (" · gear in " .. slots .. " slots") or ""))
  f.preview:Show()
  if not f.nameEdited then f.name:SetText(Builds.DefaultName(build)) end
  f.follow:SetChecked(build.classId == classId and #build.order > 0)
  f.follow:SetEnabled(build.classId == classId)
  local warnings = Builds.Warnings(build, classId)
  f.notes:SetText(#warnings > 0 and notesText(warnings) or noteText("Success", "Read. Name it and press Import."))
  f.save:Enable()
end

local function getImportFrame()
  if importFrame then return importFrame end
  local f = window("Talents4eImportFrame", "Talents-4Everyone: import", 560, 330)
  local help = text(f, "GameFontNormal", 528)
  help:SetPoint("TOPLEFT", 16, -36)
  help:SetText("Paste a build link or code from wow-4e.com (Ctrl+V).")

  local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  box:SetSize(520, 24)
  box:SetPoint("TOPLEFT", 22, -56)
  box:SetAutoFocus(true)
  box:SetMaxLetters(0)
  box:SetFontObject(ChatFontNormal)
  box:SetScript("OnEscapePressed", function() f:Hide() end)
  box:SetScript("OnTextChanged", function() readImport(f) end)
  f.box = box
  local placeholder = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  placeholder:SetPoint("LEFT", 2, 0)
  placeholder:SetText("Paste a wow-4e.com build link or code")
  f.placeholder = placeholder

  local preview = CreateFrame("Frame", nil, f)
  preview:SetPoint("TOPLEFT", 16, -90)
  preview:SetSize(528, 56)
  local icon = preview:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 0, -2)
  f.icon = icon
  f.line1 = text(preview, "GameFontHighlight", 480)
  f.line1:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
  f.line2 = text(preview, "GameFontNormalSmall", 480)
  f.line2:SetPoint("TOPLEFT", f.line1, "BOTTOMLEFT", 0, -4)
  f.line3 = text(preview, "GameFontNormalSmall", 480)
  f.line3:SetPoint("TOPLEFT", f.line2, "BOTTOMLEFT", 0, -3)
  preview:Hide()
  f.preview = preview

  local nameLabel = text(f, "GameFontNormal")
  nameLabel:SetPoint("TOPLEFT", 16, -158)
  nameLabel:SetText("Name")
  local name = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  name:SetSize(300, 24)
  name:SetPoint("LEFT", nameLabel, "RIGHT", 14, 0)
  name:SetAutoFocus(false)
  name:SetMaxLetters(Builds.MAX_NAME)
  name:SetScript("OnTextChanged", function(_, userInput) if userInput then f.nameEdited = true end end)
  name:SetScript("OnEscapePressed", function() f:Hide() end)
  f.name = name

  local follow = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  follow:SetSize(24, 24)
  follow:SetPoint("TOPLEFT", 12, -186)
  local followLabel = text(f, "GameFontHighlight")
  followLabel:SetPoint("LEFT", follow, "RIGHT", 2, 1)
  followLabel:SetText("Follow it on this character")
  f.follow = follow

  local notes = text(f, "GameFontHighlightSmall", 528)
  notes:SetPoint("TOPLEFT", 16, -218)
  notes:SetSpacing(3)
  f.notes = notes

  local cancel = button(f, "Cancel", 96)
  cancel:SetPoint("BOTTOMRIGHT", -12, 12)
  cancel:SetScript("OnClick", function() f:Hide() end)
  local save = button(f, "Import", 96)
  save:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
  save:SetScript("OnClick", function()
    local entry, problem = Builds.Add(db(), f.box:GetText(), f.name:GetText(), time())
    if not entry then
      f.notes:SetText(noteText("Error", problem))
      return
    end
    local classId, who = player()
    if f.follow:GetChecked() then Builds.Follow(db(), who, entry.id, classId) end
    f:Hide()
    Windows.ShowMain(entry.id)
  end)
  f.save = save
  importFrame = f
  return f
end

function Windows.Import()
  local f = getImportFrame()
  f.nameEdited = false
  f.name:SetText("")
  f.box:SetText("")
  readImport(f)
  f:Show()
  f.box:SetFocus()
end

---------------------------------------------------------------------------------------------------------------
-- Main window (screen 2): the saved builds, and the buttons to everything else.

local ROW_HEIGHT, LIST_WIDTH, LIST_HEIGHT = 40, 360, 184
local main

local function selectedEntry()
  return main.selected and Builds.Find(db(), main.selected) or nil
end

local function makeRow(parent, i)
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(LIST_WIDTH, ROW_HEIGHT)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_HEIGHT + 2))
  local bg = r:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.16)
  r.selectedBg = bg
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)
  local icon = r:CreateTexture(nil, "ARTWORK")
  icon:SetSize(30, 30)
  icon:SetPoint("LEFT", 6, 0)
  r.icon = icon
  r.name = text(r, "GameFontHighlight", 230)
  r.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
  r.name:SetWordWrap(false)
  r.detail = text(r, "GameFontDisableSmall", 230)
  r.detail:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.detail:SetWordWrap(false)
  r.following = text(r, "GameFontGreenSmall")
  r.following:SetPoint("RIGHT", -8, 0)
  r.following:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t Following")
  r:SetScript("OnClick", function(self)
    main.selected = self.id
    main.renaming = nil
    refreshMain()
  end)
  return r
end

refreshMain = function()
  if not main or not main:IsShown() then return end
  local builds = db().builds
  local classId, who = player()
  local followed = Builds.Followed(db(), who)
  if main.selected and not Builds.Find(db(), main.selected) then main.selected = nil end

  main.count:SetText(#builds .. " of " .. Builds.MAX)
  main.empty:SetShown(#builds == 0)
  main.scroll:SetShown(#builds > 0)
  for i, entry in ipairs(builds) do
    local r = main.rows[i] or makeRow(main.list, i)
    main.rows[i] = r
    r.id = entry.id
    r.icon:SetTexture(classIcon(entry.classId))
    r.name:SetText(entry.name)
    local build = Builds.Decode(entry)
    r.detail:SetText(build and Builds.Detail(build, classId) or "Can't be read any more")
    r.following:SetShown(followed and followed.id == entry.id or false)
    r.selectedBg:SetShown(main.selected == entry.id)
    r:Show()
  end
  for i = #builds + 1, #main.rows do main.rows[i]:Hide() end
  main.list:SetHeight(math.max(1, #builds * (ROW_HEIGHT + 2)))

  local entry = selectedEntry()
  local build = entry and Builds.Decode(entry)
  local ownClass = entry and entry.classId == classId
  local isFollowed = entry and followed and followed.id == entry.id
  main.follow:SetText(isFollowed and "Stop following" or "Follow")
  main.follow:SetEnabled(entry and (isFollowed or ownClass) or false)
  main.edit:SetEnabled(ownClass and build ~= nil or false)
  main.rename:SetEnabled(entry ~= nil)
  main.delete:SetEnabled(entry ~= nil)

  local notes = {}
  if entry and not ownClass then
    notes[1] = { kind = "Warning", text = "Log in on a " .. Builds.ClassName(entry.classId)
      .. " to follow or edit this build." }
  elseif build and #build.order == 0 then
    notes[1] = { kind = "Info", text = "Ranks only: no talent order to follow. Edit puts its points in order." }
  end
  main.notes:SetText(notesText(notes))

  if main.renaming and entry then
    local r
    for _, row in ipairs(main.rows) do if row.id == entry.id then r = row end end
    main.renameBox:ClearAllPoints()
    main.renameBox:SetPoint("LEFT", r, "LEFT", 46, 0)
    main.renameBox:SetText(entry.name)
    main.renameBox:Show()
    main.renameBox:SetFocus()
    main.renameBox:HighlightText()
  else
    main.renameBox:Hide()
  end
  if ns.Talents then ns.Talents.Refresh() end -- following may have changed
end

StaticPopupDialogs.TALENTS4E_DELETE = {
  text = "Delete \"%s\"? This can't be undone.",
  button1 = "Delete",
  button2 = "Keep it",
  OnAccept = function(_, id)
    Builds.Delete(db(), id)
    refreshMain()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function getMain()
  if main then return main end
  local f = window("Talents4eMainFrame", "Talents-4Everyone", 420, 420)
  f:HookScript("OnShow", function() refreshMain() end)
  f.rows = {}

  local heading = text(f, "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", 16, -34)
  heading:SetText("Saved builds")
  f.count = text(f, "GameFontDisableSmall")
  f.count:SetPoint("TOPRIGHT", -16, -38)

  local inset = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
  inset:SetPoint("TOPLEFT", 12, -56)
  inset:SetSize(396, LIST_HEIGHT + 8)

  local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local list = CreateFrame("Frame", nil, scroll)
  list:SetSize(LIST_WIDTH, 1)
  scroll:SetScrollChild(list)
  f.scroll, f.list = scroll, list

  local empty = CreateFrame("Frame", nil, inset)
  empty:SetAllPoints()
  local e1 = empty:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  e1:SetPoint("TOP", 0, -42)
  e1:SetText("No builds yet.")
  local e2 = empty:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  e2:SetPoint("TOP", e1, "BOTTOM", 0, -10)
  e2:SetWidth(340)
  e2:SetText("Import a link from wow-4e.com/builds. Copy one there with Share, or export your own character.")
  local importFirst = button(empty, "Import a build", 140)
  importFirst:SetPoint("TOP", e2, "BOTTOM", 0, -12)
  importFirst:SetScript("OnClick", Windows.Import)
  f.empty = empty

  local renameBox = CreateFrame("EditBox", nil, list, "InputBoxTemplate")
  renameBox:SetSize(250, 22)
  renameBox:SetAutoFocus(false)
  renameBox:SetMaxLetters(Builds.MAX_NAME)
  renameBox:SetFrameLevel(list:GetFrameLevel() + 5)
  renameBox:SetScript("OnEnterPressed", function(self)
    Builds.Rename(db(), main.selected, self:GetText())
    main.renaming = nil
    refreshMain()
  end)
  renameBox:SetScript("OnEscapePressed", function()
    main.renaming = nil
    refreshMain()
  end)
  renameBox:SetScript("OnEditFocusLost", function()
    if main.renaming then
      main.renaming = nil
      refreshMain()
    end
  end)
  f.renameBox = renameBox

  f.notes = text(f, "GameFontHighlightSmall", 392)
  f.notes:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 2, -8)

  local width = 93
  f.follow = button(f, "Follow", width)
  f.follow:SetPoint("TOPLEFT", inset, "BOTTOMLEFT", 0, -34)
  f.follow:SetScript("OnClick", function()
    local entry = selectedEntry()
    if not entry then return end
    local classId, who = player()
    local followed = Builds.Followed(db(), who)
    if followed and followed.id == entry.id then
      Builds.Unfollow(db(), who)
    else
      Builds.Follow(db(), who, entry.id, classId)
    end
    refreshMain()
  end)
  f.edit = button(f, "Edit", width)
  f.edit:SetPoint("LEFT", f.follow, "RIGHT", 8, 0)
  f.edit:SetScript("OnClick", function()
    local entry = selectedEntry()
    if not entry then return end
    local ok, problem = ns.Planner.Open(entry)
    if ok then f:Hide() else f.notes:SetText(noteText("Warning", problem)) end
  end)
  tooltip(f.edit, { "Edit", "Put this build's talents in order, or change its order, in the talent planner." })
  f.rename = button(f, "Rename", width)
  f.rename:SetPoint("LEFT", f.edit, "RIGHT", 8, 0)
  f.rename:SetScript("OnClick", function()
    main.renaming = true
    refreshMain()
  end)
  f.delete = button(f, "Delete", width)
  f.delete:SetPoint("LEFT", f.rename, "RIGHT", 8, 0)
  f.delete:SetScript("OnClick", function()
    local entry = selectedEntry()
    if entry then StaticPopup_Show("TALENTS4E_DELETE", entry.name, nil, entry.id) end
  end)

  local divider = f:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.37, 0.37, 0.37, 1)
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", f.follow, "BOTTOMLEFT", 0, -10)
  divider:SetPoint("RIGHT", inset, "RIGHT", 0, 0)

  local import = button(f, "Import", 120)
  import:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)
  import:SetScript("OnClick", Windows.Import)
  local newPlan = button(f, "New plan", 120)
  newPlan:SetPoint("LEFT", import, "RIGHT", 8, 0)
  newPlan:SetScript("OnClick", function()
    local ok, problem = ns.Planner.Open(nil)
    if ok then f:Hide() else f.notes:SetText(noteText("Warning", problem)) end
  end)
  tooltip(newPlan, { "New plan", "Plan a talent order for this character, one point per level, in the talent "
    .. "planner." })
  local export = button(f, "Export my character", 148)
  export:SetPoint("LEFT", newPlan, "RIGHT", 8, 0)
  export:SetScript("OnClick", Windows.Export)

  local check = CreateFrame("Button", nil, f)
  check:SetSize(90, 16)
  check:SetPoint("BOTTOMLEFT", 16, 10)
  local checkText = text(check, "GameFontNormalSmall")
  checkText:SetPoint("LEFT")
  checkText:SetText("Check talents")
  check:SetFontString(checkText)
  check:SetHighlightFontObject(GameFontHighlightSmall)
  check:SetScript("OnClick", Windows.Check)
  tooltip(check, { "Check talents", "What the game's talent data looks like, to copy into a bug report." })

  local settings = CreateFrame("Button", nil, f)
  settings:SetSize(60, 16)
  settings:SetPoint("LEFT", check, "RIGHT", 12, 0)
  local settingsText = text(settings, "GameFontNormalSmall")
  settingsText:SetPoint("LEFT")
  settingsText:SetText("Settings")
  settings:SetFontString(settingsText)
  settings:SetHighlightFontObject(GameFontHighlightSmall)
  settings:SetScript("OnClick", function()
    f:Hide()
    ns.Settings.Open()
  end)
  tooltip(settings, { "Settings", "The minimap button, the talent window's numbers and list, and the reminder." })

  local version = text(f, "GameFontDisableSmall")
  version:SetPoint("BOTTOMRIGHT", -16, 12)
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  version:SetText("v" .. tostring(getMeta and getMeta(addonName, "Version") or "?") .. " · data " .. Data.build)

  main = f
  return f
end

-- Opens the main window, selecting a build when given its id.
function Windows.ShowMain(selectId)
  local f = getMain()
  if selectId then f.selected = selectId end
  f.renaming = nil
  if f:IsShown() then refreshMain() else f:Show() end
end

function Windows.ToggleMain()
  local f = getMain()
  if f:IsShown() then f:Hide() else Windows.ShowMain() end
end
