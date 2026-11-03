-- Following a talent order: which steps the character has taken, the next one, and points the build doesn't
-- plan. Pure logic, no game calls (Character.Ranks reads the ranks), so it can be tested outside the game.
--
-- Point rules follow the website's talents.ts: one point per level from the first talent level (10, sooner with
-- the Talented Legacy perk), never more than 51. Step k of an order is due at first level + k - 1.
local _, ns = ...
local Data = ns.Data

local Order = {}
ns.Order = Order

Order.FIRST_TALENT_LEVEL = 10
Order.MAX_TALENT_POINTS = 51

-- The first talent level for these Legacy ranks (talent-order.ts, firstTalentLevelWith).
function Order.FirstLevel(legacyRanks)
  local earlier = 0
  for t, tree in ipairs(Data.legacy) do
    for index, levels in pairs(tree.early or {}) do
      earlier = earlier + levels * ((legacyRanks and legacyRanks[t] and legacyRanks[t][index]) or 0)
    end
  end
  return Order.FIRST_TALENT_LEVEL - earlier
end

function Order.PointsAtLevel(level, firstLevel)
  return math.min(Order.MAX_TALENT_POINTS, math.max(0, level - (firstLevel or Order.FIRST_TALENT_LEVEL) + 1))
end

-- The talent at a position of a class's data: { name, icon, ranks, spell }, or a stand-in when unknown.
function Order.Talent(classId, tree, index)
  local class = Data.classes[classId]
  local info = class and class[tree] and class[tree].talents and class[tree].talents[index]
  return info or { name = "Talent " .. tree .. "." .. index, icon = "inv_misc_questionmark", ranks = 1, spell = 0 }
end

local function key(tree, index) return tree * 100 + index end

-- Where a character stands on a build's order.
--   build: a decoded build (its order and classId); ranks: the character's talent ranks per tree;
--   level: the character's level; firstLevel: from Order.FirstLevel.
-- Returns {
--   steps = { { tree, index, rank, level, taken } ... },  -- rank: which rank of that talent the step buys
--   next = the first step not taken (nil when all are), spent, points (at this level), toSpend,
--   talents = { [key] = { tree, index, planned, have, nextLevel, nextStep } },  -- talents in the plan
--   offPlan = { { tree, index, extra, have } ... },  -- ranks beyond what the plan has, in tree order
-- }
-- A step is taken while the character has a rank of that talent left to account for it, so talents taken in
-- another order still count, and the next step is always the earliest one not done.
function Order.Plan(build, ranks, level, firstLevel)
  local plan = { steps = {}, talents = {}, offPlan = {}, spent = 0 }
  for _, tree in ipairs(ranks) do
    for _, rank in ipairs(tree) do plan.spent = plan.spent + rank end
  end
  plan.points = Order.PointsAtLevel(level, firstLevel)
  plan.toSpend = math.max(0, plan.points - plan.spent)

  local used = {}
  for k, s in ipairs(build.order) do
    local id = key(s.tree, s.index)
    local talent = plan.talents[id]
    if not talent then
      local have = ranks[s.tree] and ranks[s.tree][s.index] or 0
      talent = { tree = s.tree, index = s.index, planned = 0, have = have }
      plan.talents[id] = talent
    end
    talent.planned = talent.planned + 1
    local u = used[id] or 0
    local taken = u < talent.have
    if taken then used[id] = u + 1 end
    local step = { tree = s.tree, index = s.index, rank = talent.planned, level = firstLevel + k - 1, taken = taken }
    plan.steps[k] = step
    if not taken then
      if not plan.next then plan.next = k end
      if not talent.nextStep then
        talent.nextStep = k
        talent.nextLevel = step.level
      end
    end
  end

  for t, tree in ipairs(ranks) do
    for i, have in ipairs(tree) do
      local talent = plan.talents[key(t, i)]
      local extra = have - (talent and talent.planned or 0)
      if extra > 0 then plan.offPlan[#plan.offPlan + 1] = { tree = t, index = i, extra = extra, have = have } end
    end
  end
  return plan
end

-- The talents a ranks-only build plans, for showing on the tree without levels: { [key] = { tree, index,
-- planned, have } }.
function Order.Ranks(build, ranks)
  local out = {}
  for t, tree in ipairs(build.talents) do
    for i, planned in ipairs(tree) do
      if planned > 0 then
        out[key(t, i)] = { tree = t, index = i, planned = planned, have = ranks[t] and ranks[t][i] or 0 }
      end
    end
  end
  return out
end

-- What a level-up reminder says, or nil for nothing to say. plan comes from Order.Plan at the new level.
-- Returns the heading, the body, and the icon of the talent it names.
function Order.Reminder(build, plan, level)
  if plan.next then
    local step = plan.steps[plan.next]
    if step.level > level then return nil end
    local talent = Order.Talent(build.classId, step.tree, step.index)
    local named = talent.name .. ", rank " .. step.rank .. " of " .. talent.ranks
    if plan.toSpend > 1 then
      return "Level " .. level .. ": " .. plan.toSpend .. " points to spend", "First: " .. named, talent.icon
    end
    return "Level " .. level .. ": " .. talent.name, "Rank " .. step.rank .. " of " .. talent.ranks, talent.icon
  end
  if #plan.offPlan > 0 then
    local off = plan.offPlan[1]
    local talent = Order.Talent(build.classId, off.tree, off.index)
    return "Off your build", talent.name .. " has points your build doesn't plan.", talent.icon
  end
  if #build.order > 0 and plan.toSpend == 0 then
    return "Build complete", "Every talent in your build is taken.", nil
  end
  return nil
end
