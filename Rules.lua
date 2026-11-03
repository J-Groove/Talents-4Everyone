-- Talent point rules for the planner, copied from the website's talents.ts. Pure logic, no game calls.
--
-- - A talent in row r needs 5 * (r - 1) points spent in the rows above it, in the same tree (rows are 1-based).
-- - A talent with a prerequisite needs that talent at the stated rank.
-- - No more points than a talent's ranks, and no more than the character has (Order.PointsAtLevel).
-- - A talent order is the same points as a list, one per level; every step must be allowed at its turn.
--
-- Trees and indexes are 1-based, as in Data.lua. Ranks are { [tree] = { [index] = rank } }; missing means 0.
-- Legacy perks have a gate rule on the site; the planner only plans class talents, so it isn't copied.
-- Tests run these against talents.ts on random cases: change the two together.
local _, ns = ...
local Data = ns.Data

local Rules = {}
ns.Rules = Rules

Rules.POINTS_PER_ROW = 5

-- The class's trees as rule shapes: { [tree] = { [index] = { row, max, req = { index, rank } } } }.
function Rules.Shapes(classId)
  local shapes = {}
  for t, tree in ipairs(Data.classes[classId] or {}) do
    local shape = {}
    for i, talent in ipairs(tree.talents) do
      shape[i] = { row = talent.row, max = talent.ranks, req = talent.req }
    end
    shapes[t] = shape
  end
  return shapes
end

local function rankAt(ranks, tree, index)
  return (ranks[tree] and ranks[tree][index]) or 0
end
Rules.RankAt = rankAt

function Rules.TreeSpent(ranks, tree)
  local sum = 0
  for _, rank in pairs(ranks[tree] or {}) do sum = sum + rank end
  return sum
end

function Rules.TotalSpent(ranks)
  local sum = 0
  for tree in pairs(ranks) do sum = sum + Rules.TreeSpent(ranks, tree) end
  return sum
end

-- Points spent in rows above `row` of one tree.
function Rules.SpentAbove(shape, treeRanks, row)
  local sum = 0
  for index, talent in ipairs(shape) do
    if talent.row < row then sum = sum + (treeRanks[index] or 0) end
  end
  return sum
end

local function opens(shape, treeRanks, index)
  local row = shape[index].row
  return Rules.SpentAbove(shape, treeRanks, row) >= (row - 1) * Rules.POINTS_PER_ROW
end

-- Why a point cannot go into this talent ("max-rank", "no-points", "row-locked", "needs-prereq"), or nil.
-- available: the points the character has; nil means no limit.
function Rules.AddBlock(shapes, ranks, available, tree, index)
  local talent = shapes[tree][index]
  local treeRanks = ranks[tree] or {}
  if rankAt(ranks, tree, index) >= talent.max then return "max-rank" end
  if available and Rules.TotalSpent(ranks) >= available then return "no-points" end
  if not opens(shapes[tree], treeRanks, index) then return "row-locked" end
  if talent.req and (treeRanks[talent.req.index] or 0) < talent.req.rank then return "needs-prereq" end
  return nil
end

-- Why a point cannot come out of this talent ("empty", "prereq-of", "holds-row"), or nil.
function Rules.RemoveBlock(shapes, ranks, tree, index)
  local shape = shapes[tree]
  local treeRanks = {}
  for i, rank in pairs(ranks[tree] or {}) do treeRanks[i] = rank end
  if (treeRanks[index] or 0) == 0 then return "empty" end
  treeRanks[index] = treeRanks[index] - 1
  for i, talent in ipairs(shape) do
    if (treeRanks[i] or 0) > 0 then
      if talent.req and talent.req.index == index and treeRanks[index] < talent.req.rank then return "prereq-of" end
      if not opens(shape, treeRanks, i) then return "holds-row" end
    end
  end
  return nil
end

-- The ranks an order holds.
function Rules.RanksOf(order)
  local ranks = {}
  for _, s in ipairs(order) do
    ranks[s.tree] = ranks[s.tree] or {}
    ranks[s.tree][s.index] = (ranks[s.tree][s.index] or 0) + 1
  end
  return ranks
end

local function exists(shapes, s)
  return shapes[s.tree] ~= nil and shapes[s.tree][s.index] ~= nil
end

-- The first step of an order that can't be taken at its turn: { step, tree, index, block }, or nil.
function Rules.OrderProblem(shapes, order)
  local ranks = {}
  for step, s in ipairs(order) do
    if not exists(shapes, s) then return { step = step, tree = s.tree, index = s.index, block = "max-rank" } end
    local block = Rules.AddBlock(shapes, ranks, nil, s.tree, s.index)
    if block then return { step = step, tree = s.tree, index = s.index, block = block } end
    ranks[s.tree] = ranks[s.tree] or {}
    ranks[s.tree][s.index] = rankAt(ranks, s.tree, s.index) + 1
  end
  return nil
end

-- The order with every step legal at its turn: steps keep their places where they can, one taken too early moves
-- to the first turn it fits, and steps that never fit are dropped (talents.ts, legalOrder).
function Rules.LegalOrder(shapes, order)
  local pending = {}
  for i, s in ipairs(order) do pending[i] = s end
  local taken, ranks = {}, {}
  while #pending > 0 do
    local found
    for i, s in ipairs(pending) do
      if exists(shapes, s) and not Rules.AddBlock(shapes, ranks, nil, s.tree, s.index) then found = i; break end
    end
    if not found then break end
    local s = table.remove(pending, found)
    ranks[s.tree] = ranks[s.tree] or {}
    ranks[s.tree][s.index] = rankAt(ranks, s.tree, s.index) + 1
    taken[#taken + 1] = { tree = s.tree, index = s.index }
  end
  return taken
end

-- Ranks as steps, top rows first, trees left to right, each talent's ranks together; not yet checked against the
-- rules (Rules.LegalOrder does that).
function Rules.DefaultSteps(shapes, ranks)
  local steps = {}
  for tree, shape in ipairs(shapes) do
    for index, talent in ipairs(shape) do
      for _ = 1, math.min(rankAt(ranks, tree, index), talent.max) do
        steps[#steps + 1] = { tree = tree, index = index, row = talent.row }
      end
    end
  end
  -- table.sort isn't stable, so the sort key carries the whole position.
  table.sort(steps, function(a, b)
    if a.row ~= b.row then return a.row < b.row end
    if a.tree ~= b.tree then return a.tree < b.tree end
    return a.index < b.index
  end)
  return steps
end

-- A sensible order for ranks without one (talents.ts, defaultOrder). Always legal for ranks the rules allow.
function Rules.DefaultOrder(shapes, ranks)
  return Rules.LegalOrder(shapes, Rules.DefaultSteps(shapes, ranks))
end

-- The order with one more point in a talent at the end, or nil and the block.
function Rules.AddStep(shapes, order, available, tree, index)
  local block = Rules.AddBlock(shapes, Rules.RanksOf(order), available, tree, index)
  if block then return nil, block end
  local out = {}
  for i, s in ipairs(order) do out[i] = s end
  out[#out + 1] = { tree = tree, index = index }
  return out
end

-- The order without step `at`; the steps after it each move a level earlier. Returns nil and the problem
-- (Rules.OrderProblem) when a later step would then come too early.
function Rules.RemoveStep(shapes, order, at)
  local out = {}
  for i, s in ipairs(order) do
    if i ~= at then out[#out + 1] = s end
  end
  local problem = Rules.OrderProblem(shapes, out)
  if problem then return nil, problem end
  return out
end

-- The step holding a talent's latest rank, or nil.
function Rules.LastStep(order, tree, index)
  for i = #order, 1, -1 do
    if order[i].tree == tree and order[i].index == index then return i end
  end
  return nil
end

-- Why a click was refused, in the site's words. level: when the step would be taken (for an order problem).
function Rules.BlockText(classId, tree, index, block, level)
  local trees = Data.classes[classId] or {}
  local info = trees[tree] and trees[tree].talents[index]
  local name = info and info.name or "That talent"
  local when = level and (" cannot be taken at level " .. level .. ": it") or ""
  if block == "needs-prereq" and info and info.req then
    local needed = trees[tree].talents[info.req.index]
    return name .. when .. " needs " .. (needed and needed.name or "its prerequisite") .. " at rank "
      .. info.req.rank .. " first."
  elseif block == "row-locked" and info then
    return name .. when .. " needs " .. ((info.row - 1) * Rules.POINTS_PER_ROW) .. " points in "
      .. trees[tree].name .. " above it first."
  elseif block == "max-rank" then
    return name .. " has all its ranks."
  elseif block == "no-points" then
    return "Every point you have at this level is placed."
  elseif block == "prereq-of" or block == "holds-row" then
    return "Other talents depend on these points."
  end
  return "That would put a talent before it can be taken."
end
