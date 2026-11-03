-- Pure logic for Talents4e: no game API calls here, so it can be tested outside the game.
--
-- Build codes are the website's (wow-4e\packages\core\src\build-code.ts), and this file must write and read them
-- exactly as it does. The current form, fields joined by ".":
--   3.<gameBuild>.<classId>.<raceId>.<sex>.<level>.<talents>.<order>.<gear>.<legacy>
-- See build-code.ts for what each field holds. Older forms ("1.", "2." and "<gameBuild>.") are read, never written.
--
-- A build here is a table:
--   { gameBuild, classId, raceId, sex (0 Body 1, 1 Body 2), level,
--     talents = { {ranks of tree 1 in its talent order}, {tree 2}, {tree 3} },
--     order = { {tree = 1, index = 4}, ... },   -- the points in the order taken; {} when not planned
--     gear = { [slotId] = { item = id, enchant = id or nil, suffix = id or nil } },
--     legacy = { {ranks of Legacy tree 1}, ... } }
-- Trees and indexes are 1-based here and 0-based in the code. Bad input raises an error; use Core.TryDecode to get
-- nil and a message instead.
local _, ns = ...

local Core = {}
ns.Core = Core

Core.SITE_URL = "https://wow-4e.com/builds/new#b="
Core.MIN_GAME_BUILD = 10000
Core.MAX_LEVEL = 60
Core.MAX_CODE_LENGTH = 512
local MAX_TALENT_RANK = 9
local MAX_TREES = 3
local MAX_TALENTS_PER_TREE = 40
local MAX_ORDER = 51
local MAX_GEAR_SLOTS = 19
local ID_MAX = 2147483647
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function fail(message)
  error(message, 0)
end

-- Splits on a plain separator, keeping empty pieces: split("_5", "_") is { "", "5" }.
local function split(text, sep)
  local pieces, start = {}, 1
  while true do
    local at = string.find(text, sep, start, true)
    if not at then
      pieces[#pieces + 1] = string.sub(text, start)
      return pieces
    end
    pieces[#pieces + 1] = string.sub(text, start, at - 1)
    start = at + 1
  end
end

local function isInt(value)
  return type(value) == "number" and value == math.floor(value)
end

local function assertInt(value, what, min, max)
  if not isInt(value) or value < min or value > max then
    fail(what .. " must be a whole number from " .. min .. " to " .. max .. ", got " .. tostring(value))
  end
end

function Core.ToBase36(n)
  n = math.floor(n)
  if n == 0 then return "0" end
  local out = ""
  while n > 0 do
    local digit = n % 36
    out = string.sub(DIGITS, digit + 1, digit + 1) .. out
    n = math.floor(n / 36)
  end
  return out
end

local function int(n)
  return string.format("%d", n)
end

local function checkRanks(trees, what)
  if #trees > MAX_TREES then fail("at most " .. MAX_TREES .. " " .. what .. " trees") end
  for _, tree in ipairs(trees) do
    if #tree > MAX_TALENTS_PER_TREE then fail("at most " .. MAX_TALENTS_PER_TREE .. " " .. what .. "s per tree") end
    for _, rank in ipairs(tree) do assertInt(rank, what .. " rank", 0, MAX_TALENT_RANK) end
  end
end

-- One digit run per tree, trailing zeros trimmed, empty trees at the end dropped, trees joined by "_".
function Core.EncodeRanks(trees)
  local runs = {}
  for i, tree in ipairs(trees) do
    runs[i] = (string.gsub(table.concat(tree), "0+$", ""))
  end
  while #runs > 0 and runs[#runs] == "" do runs[#runs] = nil end
  return table.concat(runs, "_")
end

local function decodeRanks(text, what)
  local trees = {}
  if text == "" then return trees end
  for i, run in ipairs(split(text, "_")) do
    if not string.find(run, "^[0-9]*$") then fail("bad " .. what .. " tree: \"" .. run .. "\"") end
    local ranks = {}
    for j = 1, #run do ranks[j] = tonumber(string.sub(run, j, j)) end
    trees[i] = ranks
  end
  return trees
end

-- The build number from a client version ("1.60.1.70532") or a bare build ("70532"); 0 when there is none.
function Core.GameBuildNumber(version)
  local last = tonumber(string.match(tostring(version or ""), "(%d+)$"))
  if last and last >= Core.MIN_GAME_BUILD then return last end
  return 0
end

-- The ranks an order adds up to.
function Core.RanksFromOrder(order)
  local ranks = {}
  for _, step in ipairs(order) do
    for t = #ranks + 1, step.tree do ranks[t] = {} end
    local tree = ranks[step.tree]
    for i = #tree + 1, step.index do tree[i] = 0 end
    tree[step.index] = tree[step.index] + 1
  end
  return ranks
end

-- Whether an order is planned and adds up to exactly these ranks.
function Core.OrderMatches(order, talents)
  return #order > 0 and Core.EncodeRanks(Core.RanksFromOrder(order)) == Core.EncodeRanks(talents)
end

local function sortedSlots(gear)
  local slots = {}
  for slot in pairs(gear) do slots[#slots + 1] = slot end
  table.sort(slots)
  return slots
end

local function checkBuild(build)
  if build.gameBuild ~= 0 then assertInt(build.gameBuild, "gameBuild", Core.MIN_GAME_BUILD, ID_MAX) end
  assertInt(build.classId, "classId", 1, 99)
  assertInt(build.raceId, "raceId", 1, 99)
  if build.sex ~= 0 and build.sex ~= 1 then fail("sex must be 0 or 1, got " .. tostring(build.sex)) end
  assertInt(build.level, "level", 1, Core.MAX_LEVEL)
  checkRanks(build.talents, "talent")
  checkRanks(build.legacy, "Legacy")
  if #build.order > MAX_ORDER then fail("at most " .. MAX_ORDER .. " points in a talent order") end
  for _, step in ipairs(build.order) do
    assertInt(step.tree, "order tree", 1, MAX_TREES)
    assertInt(step.index, "order talent", 1, MAX_TALENTS_PER_TREE)
  end
  checkRanks(Core.RanksFromOrder(build.order), "talent")
  local slots = sortedSlots(build.gear)
  if #slots > MAX_GEAR_SLOTS then fail("at most " .. MAX_GEAR_SLOTS .. " gear slots") end
  for _, slot in ipairs(slots) do
    assertInt(slot, "gear slot", 1, 99)
    local piece = build.gear[slot]
    assertInt(piece.item, "item id", 1, ID_MAX)
    if piece.enchant ~= nil then assertInt(piece.enchant, "enchant id", 1, ID_MAX) end
    if piece.suffix ~= nil then assertInt(piece.suffix, "suffix id", 1, ID_MAX) end
  end
end

local function encodeGear(gear)
  local entries = {}
  for _, slot in ipairs(sortedSlots(gear)) do
    local piece = gear[slot]
    local parts = { Core.ToBase36(slot), Core.ToBase36(piece.item),
      piece.enchant and Core.ToBase36(piece.enchant) or "", piece.suffix and Core.ToBase36(piece.suffix) or "" }
    while parts[#parts] == "" do parts[#parts] = nil end
    entries[#entries + 1] = table.concat(parts, "~")
  end
  return table.concat(entries, "_")
end

-- Writes the build in the current ("3.") form. An order that no longer adds up to the talents is left out.
function Core.EncodeBuild(build)
  checkBuild(build)
  local ordered = Core.OrderMatches(build.order, build.talents)
  local order = {}
  if ordered then
    for i, step in ipairs(build.order) do
      local text = Core.ToBase36((step.tree - 1) * MAX_TALENTS_PER_TREE + step.index - 1)
      order[i] = #text < 2 and "0" .. text or text
    end
  end
  return table.concat({
    "3", int(build.gameBuild), int(build.classId), int(build.raceId), int(build.sex), int(build.level),
    ordered and "" or Core.EncodeRanks(build.talents), table.concat(order), encodeGear(build.gear),
    Core.EncodeRanks(build.legacy),
  }, ".")
end

local function parseIntField(text, what, radix)
  local ok
  if radix == 36 then
    ok = #text >= 1 and #text <= 7 and string.find(text, "^[0-9a-z]+$")
  else
    ok = #text >= 1 and #text <= 10 and string.find(text, "^[0-9]+$")
  end
  if not ok then fail("bad " .. what .. ": \"" .. text .. "\"") end
  return tonumber(text, radix or 10)
end

-- Gear entries; rich allows the enchant and suffix of the "3." form.
local function decodeGear(text, rich)
  local gear = {}
  if text == "" then return gear end
  for _, entry in ipairs(split(text, "_")) do
    local parts = split(entry, "~")
    if #parts < 2 or #parts > (rich and 4 or 2) then fail("bad gear entry: \"" .. entry .. "\"") end
    local slot = parseIntField(parts[1], "gear slot", 36)
    if gear[slot] then fail("gear slot " .. slot .. " appears twice") end
    local piece = { item = parseIntField(parts[2], "item id", 36) }
    if parts[3] and parts[3] ~= "" then piece.enchant = parseIntField(parts[3], "enchant id", 36) end
    if parts[4] and parts[4] ~= "" then piece.suffix = parseIntField(parts[4], "suffix id", 36) end
    gear[slot] = piece
  end
  return gear
end

local function decodeOrder(text)
  if #text % 2 ~= 0 or not string.find(text, "^[0-9a-z]*$") then fail("bad talent order: \"" .. text .. "\"") end
  local steps = {}
  for i = 1, #text, 2 do
    local n = tonumber(string.sub(text, i, i + 1), 36)
    steps[#steps + 1] = { tree = math.floor(n / MAX_TALENTS_PER_TREE) + 1, index = n % MAX_TALENTS_PER_TREE + 1 }
  end
  return steps
end

function Core.DecodeBuild(code)
  if #code > Core.MAX_CODE_LENGTH then fail("build code is too long") end
  local fields = split(code, ".")
  local first = fields[1]
  local firstNumber = (#first >= 1 and #first <= 10 and string.find(first, "^[0-9]+$")) and tonumber(first) or nil
  local expected = 0
  if first == "1" then
    expected = 6
  elseif first == "2" or (firstNumber and firstNumber >= Core.MIN_GAME_BUILD) then
    expected = 7
  elseif first == "3" then
    expected = 10
  end
  if expected == 0 then fail("unknown build code version \"" .. first .. "\"") end
  if #fields ~= expected then fail("expected " .. expected .. " fields, got " .. #fields) end

  local build
  if first == "3" then
    if fields[7] ~= "" and fields[8] ~= "" then fail("a code has talents or an order, not both") end
    local order = decodeOrder(fields[8])
    build = {
      gameBuild = parseIntField(fields[2], "game build"),
      classId = parseIntField(fields[3], "class id"),
      raceId = parseIntField(fields[4], "race id"),
      sex = parseIntField(fields[5], "sex"),
      level = parseIntField(fields[6], "level"),
      talents = #order > 0 and Core.RanksFromOrder(order) or decodeRanks(fields[7], "talent"),
      order = order,
      gear = decodeGear(fields[9], true),
      legacy = decodeRanks(fields[10], "Legacy"),
    }
  else
    build = {
      gameBuild = (firstNumber and firstNumber >= Core.MIN_GAME_BUILD) and firstNumber or 0,
      classId = parseIntField(fields[2], "class id"),
      raceId = parseIntField(fields[3], "race id"),
      sex = 0,
      level = parseIntField(fields[4], "level"),
      talents = decodeRanks(fields[5], "talent"),
      order = {},
      gear = decodeGear(fields[6], false),
      legacy = decodeRanks(fields[7] or "", "Legacy"),
    }
  end
  checkBuild(build)
  return build
end

-- The build code in pasted text: a bare code, "#b=<code>", or a whole link. Nil when there is none.
function Core.CodeFromText(text)
  text = string.gsub(text or "", "%%7[Ee]", "~")
  local code = string.match(text, "[#&?]b=([0-9a-z._~]+)")
  if code then return code end
  return string.match(text, "^%s*([0-9][0-9a-z._~]*)%s*$")
end

-- Reads pasted text into a build: build, or nil and a message for the player.
function Core.TryDecode(text)
  local code = Core.CodeFromText(text)
  if not code then return nil, "No build code found. Paste a code or a wow-4e.com build link." end
  local ok, result = pcall(Core.DecodeBuild, code)
  if not ok then return nil, "That build code could not be read: " .. tostring(result) end
  return result
end

-- Item, enchant and random suffix ids from an item link ("|Hitem:16914:1503:0:0:0:0:87:...|h").
-- Negative suffix ids (ItemRandomSuffix) are not ItemRandomProperties ids, so the site can't hold them: dropped.
function Core.ParseItemLink(link)
  local itemString = link and string.match(link, "item:([%-%d:]+)")
  if not itemString then return nil end
  local fields = split(itemString, ":")
  local item = tonumber(fields[1])
  if not item or item < 1 then return nil end
  local enchant, suffix = tonumber(fields[2]), tonumber(fields[7])
  return item, (enchant and enchant > 0) and enchant or nil, (suffix and suffix > 0) and suffix or nil
end

-- UnitSex gives 2 for Body 1 and 3 for Body 2 (1 is unknown); build codes use 0 and 1.
function Core.SexFromUnitSex(unitSex)
  return unitSex == 3 and 1 or 0
end
