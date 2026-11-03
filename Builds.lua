-- Saved builds: the list in the main window, and which build each character follows. No game API calls here
-- (the windows pass in the player's class and name), so it can be tested outside the game.
--
-- Talents4eDB (account-wide) holds:
--   builds = { { id, name, code, classId, added }, ... }   -- up to Builds.MAX, oldest first; code is the site's
--   following = { ["Name-Realm"] = id }                      -- each character's followed build
--   nextId                                                   -- the next build's id (ids never come back)
local _, ns = ...
local Core, Data = ns.Core, ns.Data

local Builds = {}
ns.Builds = Builds

Builds.MAX = 20
Builds.MAX_NAME = 40

local function trim(text)
  return (string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
end

function Builds.Init(db)
  db.builds = db.builds or {}
  db.following = db.following or {}
  db.nextId = db.nextId or 1
  return db
end

-- The saved build with this id, and its place in the list.
function Builds.Find(db, id)
  for i, entry in ipairs(db.builds) do
    if entry.id == id then return entry, i end
  end
  return nil
end

-- Points per tree for a decoded build: { { name = "Arcane", points = 10 }, ... }, the total, and the tree with the
-- most points (nil when none leads).
function Builds.Trees(build)
  local class = Data.classes[build.classId] or {}
  local trees, total, main, best, tie = {}, 0, nil, 0, false
  for t, ranks in ipairs(build.talents) do
    local points = 0
    for _, rank in ipairs(ranks) do points = points + rank end
    local name = class[t] and class[t].name or ("Tree " .. t)
    trees[t] = { name = name, points = points }
    total = total + points
    if points > best then
      main, best, tie = name, points, false
    elseif points == best and points > 0 then
      tie = true
    end
  end
  return trees, total, (not tie) and main or nil
end

function Builds.ClassName(classId)
  local class = Data.classes[classId]
  return class and class.name or ("class " .. tostring(classId))
end

-- "Mage, Frost", or just "Mage" while no tree leads.
function Builds.DefaultName(build)
  local _, _, main = Builds.Trees(build)
  local class = Builds.ClassName(build.classId)
  return main and (class .. ", " .. main) or class
end

-- The line under a saved build's name: "Talent order · 51 points · game build 70707".
function Builds.Detail(build, playerClassId)
  local _, total = Builds.Trees(build)
  local parts = {}
  if playerClassId and build.classId ~= playerClassId then
    parts[#parts + 1] = "For a " .. Builds.ClassName(build.classId)
  end
  parts[#parts + 1] = #build.order > 0 and "Talent order" or "Ranks only"
  parts[#parts + 1] = total .. (total == 1 and " point" or " points")
  if build.gameBuild and build.gameBuild > 0 then parts[#parts + 1] = "game build " .. build.gameBuild end
  return table.concat(parts, " · ")
end

-- What to tell the player about a build before saving or following it: a list of { kind, text }, where kind is
-- "Info" or "Warning".
function Builds.Warnings(build, playerClassId)
  local out = {}
  if playerClassId and build.classId ~= playerClassId then
    out[#out + 1] = { kind = "Warning", text = "This build is for a " .. Builds.ClassName(build.classId)
      .. ". You can save it, and follow it on a character of that class." }
  end
  local dataBuild = Core.GameBuildNumber(Data.build)
  if build.gameBuild and build.gameBuild > 0 and build.gameBuild < dataBuild then
    out[#out + 1] = { kind = "Warning", text = "Made for an older game version (" .. build.gameBuild
      .. "). Some talents may have moved since; check it in the Build Calculator." }
  end
  if #build.order == 0 then
    out[#out + 1] = { kind = "Info", text = "This build has ranks only, no talent order. Add an order in the "
      .. "Build Calculator on wow-4e.com, then import it again to follow it level by level." }
  end
  return out
end

-- Saves a build from pasted text. Returns the new entry, or nil and a message for the player.
function Builds.Add(db, text, name, now)
  if #db.builds >= Builds.MAX then
    return nil, "You have " .. Builds.MAX .. " saved builds. Delete one to make room."
  end
  local build, problem = Core.TryDecode(text)
  if not build then return nil, problem end
  name = string.sub(trim(name), 1, Builds.MAX_NAME)
  if name == "" then name = Builds.DefaultName(build) end
  local entry = {
    id = db.nextId,
    name = name,
    code = Core.EncodeBuild(build),
    classId = build.classId,
    added = now,
  }
  db.nextId = db.nextId + 1
  db.builds[#db.builds + 1] = entry
  return entry
end

-- The decoded build of a saved entry, or nil and a message when its code no longer reads.
function Builds.Decode(entry)
  return Core.TryDecode(entry.code)
end

-- Puts a new code (from the talent planner) in a saved build, keeping its id and who follows it, and renames it
-- when given a name. Returns the entry, or nil and a message.
function Builds.Replace(db, id, text, name)
  local entry = Builds.Find(db, id)
  if not entry then return nil, "That build is no longer saved." end
  local build, problem = Core.TryDecode(text)
  if not build then return nil, problem end
  entry.code = Core.EncodeBuild(build)
  entry.classId = build.classId
  Builds.Rename(db, id, name)
  return entry
end

-- Renames a saved build. An empty name keeps the old one. Returns whether the name changed.
function Builds.Rename(db, id, name)
  local entry = Builds.Find(db, id)
  name = string.sub(trim(name), 1, Builds.MAX_NAME)
  if not entry or name == "" or name == entry.name then return false end
  entry.name = name
  return true
end

-- Deletes a saved build; characters that followed it follow nothing.
function Builds.Delete(db, id)
  local _, index = Builds.Find(db, id)
  if not index then return false end
  table.remove(db.builds, index)
  for who, followed in pairs(db.following) do
    if followed == id then db.following[who] = nil end
  end
  return true
end

-- Makes a character follow a saved build of its own class. Returns true, or false and a message.
function Builds.Follow(db, who, id, playerClassId)
  local entry = Builds.Find(db, id)
  if not entry then return false, "That build is no longer saved." end
  if entry.classId ~= playerClassId then
    return false, "Log in on a " .. Builds.ClassName(entry.classId) .. " to follow this build."
  end
  db.following[who] = id
  return true
end

function Builds.Unfollow(db, who)
  db.following[who] = nil
end

-- The saved build a character follows, or nil.
function Builds.Followed(db, who)
  local id = db.following[who]
  return id and Builds.Find(db, id) or nil
end
