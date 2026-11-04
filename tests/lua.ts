// Runs Talents4e's Lua files in a Lua VM (wasmoon, Lua 5.4) so they can be tested without the game.
// The game uses Lua 5.1, so addon code sticks to the common subset.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { LuaFactory, type LuaEngine } from 'wasmoon';

export const ADDON_DIR = join(import.meta.dirname, '..');
const factory = new LuaFactory();

/** The Lua files the TOC loads, in order. */
/** Data.lua's game build ("1.60.1.70755") and its build number, which build codes record. */
export const DATA_BUILD = /build = "([^"]+)"/.exec(readFileSync(join(ADDON_DIR, 'Data.lua'), 'utf8'))![1];
export const DATA_BUILD_NUMBER = DATA_BUILD.split('.').pop()!;
export const TOC_FILES = readFileSync(join(ADDON_DIR, 'Talents4e.toc'), 'utf8').split(String.fromCharCode(10)).map((line) => line.trim()).filter((line) => line.endsWith('.lua'));

/** A stand-in for the game's UI and unit functions, enough to build the windows (a Mage, Jeff-Realm). */
export const UI_STUB = `
  function strtrim(s) return (string.gsub(s, "^%s*(.-)%s*$", "%1")) end
  tinsert = table.insert
  UISpecialFrames, SlashCmdList, UIParent, StaticPopupDialogs, GameTooltip = {}, {}, {}, {}, {}
  function UnitClass() return "Mage", "MAGE", 8 end
  function UnitName() return "Jeff" end
  function GetRealmName() return "Realm" end
  function time() return 1000 end
  C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
  C_Timer = { After = function(_, f) f() end }
  function hooksecurefunc() end
  function UnitLevel() return 13 end
  function IsShiftKeyDown() return false end
  -- A frame, texture or font string: it remembers text, shown state, checks and scripts (Show runs OnShow); any
  -- other method (a capitalised name, like the game's) does nothing and returns the object.
  local methods = {
    SetText = function(self, t) self._text = t end, GetText = function(self) return self._text or "" end,
    Show = function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end,
    Hide = function(self) self._shown = false end, IsShown = function(self) return self._shown end,
    SetShown = function(self, s) if s then self:Show() else self:Hide() end end,
    SetChecked = function(self, c) self._checked = c end, GetChecked = function(self) return self._checked end,
    SetEnabled = function(self, e) self._enabled = e and true or false end,
    Enable = function(self) self._enabled = true end, Disable = function(self) self._enabled = false end,
    IsEnabled = function(self) return self._enabled end,
    SetScript = function(self, name, f) self._scripts[name] = f end, GetFrameLevel = function() return 1 end,
    HookScript = function(self, name, f) self._scripts[name] = f end, GetVerticalScrollRange = function() return 0 end,
    RegisterEvent = function(self, e) self._events[e] = true end,
  }
  local function object(name)
    local o = setmetatable({ _scripts = {}, _events = {}, _shown = true, _enabled = true }, { __index = function(_, key)
      if methods[key] then return methods[key] end
      if key:match("^%u") then return function(self) return self end end
    end })
    o.CreateFontString = function() return object() end
    o.CreateTexture = function() return object() end
    if name then _G[name] = o end
    return o
  end
  frames = {}
  function CreateFrame(_, name) local f = object(name); frames[#frames + 1] = f; return f end
  -- Sends a game event to every frame that registered it.
  function fire(event, ...)
    for _, f in ipairs(frames) do
      if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
  end`;


/** A Lua VM with the given addon files loaded the way the game loads them: each a chunk called with (name, ns). */
export async function addon(files: string[], setup = ''): Promise<LuaEngine> {
  const lua = await factory.createEngine();
  await lua.doString(`ns = {}\n${setup}`);
  for (const file of files) {
    lua.global.set('__source', readFileSync(join(ADDON_DIR, file), 'utf8'));
    await lua.doString(`assert(load(__source, "@${file}"))("Talents4e", ns)`);
  }
  // A build as one line, the same shape as canonical() in the tests: trees and indexes 1-based.
  await lua.doString(`
    function canonical(b)
      local function trees(list)
        local out = {}
        for i, tree in ipairs(list) do out[i] = table.concat(tree, ",") end
        return table.concat(out, "/")
      end
      local order = {}
      for i, s in ipairs(b.order) do order[i] = s.tree .. ":" .. s.index end
      local slots = {}
      for slot in pairs(b.gear) do slots[#slots + 1] = slot end
      table.sort(slots)
      local gear = {}
      for i, slot in ipairs(slots) do
        local p = b.gear[slot]
        gear[i] = slot .. ":" .. p.item .. ":" .. (p.enchant or "") .. ":" .. (p.suffix or "")
      end
      return table.concat({ b.gameBuild, b.classId, b.raceId, b.sex, b.level, trees(b.talents),
        table.concat(order, " "), table.concat(gear, " "), trees(b.legacy) }, "|")
    end`);
  return lua;
}

/** Runs a Lua expression and returns its first value. */
export async function evaluate<T = unknown>(lua: LuaEngine, expression: string): Promise<T> {
  return (await lua.doString(`return ${expression}`)) as T;
}

/**
 * Runs many Lua expressions in one call and returns each result as a string, or "ERROR <message>". wasmoon's
 * engine loses its globals after a few dozen separate doString calls, so tests that make many calls batch them.
 */
export async function evaluateAll(lua: LuaEngine, expressions: string[]): Promise<string[]> {
  const body = expressions
    .map((e, i) => `do local ok, v = pcall(function() return ${e} end); out[${i + 1}] = ok and tostring(v) or ("ERROR " .. tostring(v)) end`)
    .join('\n');
  // Results are joined by character 30 (record separator): wasmoon cuts strings at a NUL.
  const joined = (await lua.doString(`local out = {}\n${body}\nreturn table.concat(out, string.char(30))`)) as string;
  return expressions.length === 0 ? [] : joined.split(String.fromCharCode(30));
}
