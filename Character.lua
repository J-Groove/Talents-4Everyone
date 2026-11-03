-- Reads the player's character from the game into a build (see Core.lua for its shape). Read only: nothing here
-- learns, spends or equips anything.
--
-- Forever keeps talents and Legacy perks in trait trees. Talents come from the active class talent config,
-- Legacy perks from the Legacy system's config (system 45). Each node is read by the TraitNode id the website's
-- data lists for that position (Data.lua), so a talent lands at the same place in the code as on the site.
local _, ns = ...
local Core, Data = ns.Core, ns.Data

local Character = {}
ns.Character = Character

local LEGACY_SYSTEM_ID = 45
local GEAR_SLOTS = 19

-- Ranks bought in one node, or nil when the game doesn't know the node.
local function nodeRank(configID, nodeID)
  local ok, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)
  if not ok or not info or not info.ID or info.ID == 0 then return nil end
  return info.ranksPurchased or info.currentRank or 0
end

-- Ranks per tree for one config, plus how many nodes the game didn't know.
local function readTrees(configID, trees)
  local ranks, missing = {}, 0
  for t, tree in ipairs(trees) do
    ranks[t] = {}
    for i, nodeID in ipairs(tree.nodes) do
      local rank = nodeRank(configID, nodeID)
      if rank == nil then
        missing = missing + 1
        rank = 0
      end
      ranks[t][i] = math.min(rank, 9)
    end
  end
  return ranks, missing
end

local function activeTalentConfig()
  return C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
end

local function legacyConfig()
  return C_Traits and C_Traits.GetConfigIDBySystemID and C_Traits.GetConfigIDBySystemID(LEGACY_SYSTEM_ID)
end

-- The character as a build, and a list of problems to show the player (empty when all went well).
function Character.Read()
  local problems = {}
  local _, _, classId = UnitClass("player")
  local _, _, raceId = UnitRace("player")
  local build = {
    -- The code's positions follow Data.lua, so it records the build that data came from, not the client's.
    gameBuild = Core.GameBuildNumber(Data.build),
    classId = classId,
    raceId = raceId,
    sex = Core.SexFromUnitSex(UnitSex("player")),
    level = UnitLevel("player"),
    talents = {},
    order = {},
    gear = {},
    legacy = {},
  }

  -- Only outside Forever (testing on Retail): build codes stop at level 60.
  if build.level > Core.MAX_LEVEL then
    problems[#problems + 1] = "Level " .. build.level .. " is above Forever's " .. Core.MAX_LEVEL .. ", so the code says "
      .. Core.MAX_LEVEL .. "."
    build.level = Core.MAX_LEVEL
  end

  local clientBuild = Core.GameBuildNumber(select(2, GetBuildInfo()))
  if clientBuild ~= 0 and clientBuild ~= build.gameBuild then
    problems[#problems + 1] = "This addon's talent data is from game build " .. build.gameBuild .. ", the game is "
      .. clientBuild .. ". If talents moved since, update the addon."
  end

  local classData = Data.classes[classId]
  local talentConfig = activeTalentConfig()
  if not classData then
    problems[#problems + 1] = "No talent data for this class."
  elseif not talentConfig or not C_Traits then
    problems[#problems + 1] = "The game didn't give talents (no active talent config). Talents left out."
  else
    local missing
    build.talents, missing = readTrees(talentConfig, classData)
    if missing > 0 then
      problems[#problems + 1] = missing .. " talents weren't found in the game. Talents may be incomplete."
    end
  end

  local legacyConfigID = legacyConfig()
  if not legacyConfigID then
    problems[#problems + 1] = "The game didn't give Legacy perks. Legacy perks left out."
  else
    local missing
    build.legacy, missing = readTrees(legacyConfigID, Data.legacy)
    if missing > 0 then
      problems[#problems + 1] = missing .. " Legacy perks weren't found in the game. Legacy perks may be incomplete."
    end
  end

  for slot = 1, GEAR_SLOTS do
    local item, enchant, suffix = Core.ParseItemLink(GetInventoryItemLink("player", slot))
    if item then build.gear[slot] = { item = item, enchant = enchant, suffix = suffix } end
  end

  return build, problems
end

-- Just the character's talent ranks and Legacy ranks per tree, for following a talent order. Either is nil when
-- the game doesn't give it.
function Character.Ranks()
  local _, _, classId = UnitClass("player")
  local classData = Data.classes[classId]
  local talentConfig = activeTalentConfig()
  local talents = classData and talentConfig and C_Traits and readTrees(talentConfig, classData) or nil
  local legacyConfigID = legacyConfig()
  local legacy = legacyConfigID and readTrees(legacyConfigID, Data.legacy) or nil
  return talents, legacy
end

-- What the game's talent APIs return, for checking a new client build. Saved in Talents4eDB.lastCheck too.
function Character.Check()
  local lines = {}
  local function add(text) lines[#lines + 1] = text end
  add("Client: " .. table.concat({ GetBuildInfo() }, " / ", 1, 2) .. "; data: " .. Data.build)
  add("WOW_PROJECT_ID: " .. tostring(WOW_PROJECT_ID))
  add("C_Traits: " .. tostring(C_Traits ~= nil) .. ", C_ClassTalents: " .. tostring(C_ClassTalents ~= nil))
  local talentConfig = activeTalentConfig()
  add("Active talent config: " .. tostring(talentConfig))
  local legacyConfigID = legacyConfig()
  add("Legacy config (system " .. LEGACY_SYSTEM_ID .. "): " .. tostring(legacyConfigID))
  local _, _, classId = UnitClass("player")
  local classData = Data.classes[classId]
  if talentConfig and classData then
    local ranks, missing = readTrees(talentConfig, classData)
    add("Talents: " .. Core.EncodeRanks(ranks) .. " (" .. missing .. " nodes not found)")
  end
  if legacyConfigID then
    local ranks, missing = readTrees(legacyConfigID, Data.legacy)
    add("Legacy: " .. Core.EncodeRanks(ranks) .. " (" .. missing .. " nodes not found)")
  end
  -- What the game itself lists, whatever Data.lua holds: on Retail this shows the trait API works even though
  -- Forever's node ids aren't there.
  for _, config in ipairs({ { "Talent", talentConfig }, { "Legacy", legacyConfigID } }) do
    local name, configID = config[1], config[2]
    local info = configID and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
    for _, treeID in ipairs(info and info.treeIDs or {}) do
      local nodes = C_Traits.GetTreeNodes and C_Traits.GetTreeNodes(treeID) or {}
      local spent, bought = 0, 0
      for _, nodeID in ipairs(nodes) do
        local rank = nodeRank(configID, nodeID)
        if rank and rank > 0 then
          spent = spent + rank
          bought = bought + 1
        end
      end
      add(name .. " tree " .. treeID .. ": " .. #nodes .. " nodes, " .. bought .. " with points (" .. spent .. " points)")
    end
  end
  return lines
end
