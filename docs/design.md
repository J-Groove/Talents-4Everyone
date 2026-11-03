# Talents-4Everyone: design

Written before the code. Keep it current while building; when a question is settled, move the answer into the
section it belongs to and delete the question.

## The problem
Planning a character on wow-4e.com means typing in your class, race, talents and gear by hand. Following a plan
while levelling means alt-tabbing to the site every level to see which talent comes next.

## What it does
Everything is in the addon's own windows and buttons; `/t4e` only opens the main window ("Decisions"). Built in
this order:
1. **Export.** Reads the character: class, body type, race, level, talents, Legacy perks, and gear (items,
   enchants, random suffixes). Turns it into the site's build code and shows the full
   `https://wow-4e.com/builds/new#b=...` link in a box, selected, ready for Ctrl+C. Pasting it in a browser opens
   the build in the Build Calculator.
2. **Import.** The player pastes a build link or code from the site into the main window. The addon shows what it
   read, saves it with a name and makes it the character's active build.
3. **Talent order.** The heart of the addon: with an active build that has a talent order, the talent window
   shows the player what to take, level by level (see "Talent order" below).
4. **Talent planner (edit mode).** Pick talents in order in the addon's own window, save the result as a build, and
   copy its wow-4e.com link (see "Talent planner" below).

The gear guide (what gear is missing and where it comes from) is left out for now (owner, 2026-11-01); what was
found about its data is under "Left out for now". Export still carries the character's gear, because the site's
build code holds it.

## Talent order
**Where the order comes from.** A build made in the site's Build Calculator with a talent order carries it in its
code: one step per talent point, in the order taken (`order` in the build code). Step 1 is taken at the
character's first talent level (10, or earlier with the Talented Legacy perk), step 2 a level later, and so on to
51 points at 60. The level is worked out from the character's own Talented rank, not the build's, so it matches
when the character really gets each point. A build without an order (a plain export, or a site build with ranks
only) can't be followed: the addon says so and points to the site's order editor.

**What the player sees** whenever the talent window (Blizzard's `PlayerSpellsFrame`, Talents tab) is open:
- **Level numbers on the talents.** A small number on each talent in the plan: the level at which its next rank is
  due ("24"). A talent whose planned ranks are all taken shows a tick instead; talents not in the plan show
  nothing. The next talent to take also gets a glow. These are our own frames laid over Blizzard's buttons, never
  changes to the buttons themselves.
- **A list beside the window.** A panel docked to the talent window's right edge: one row per step, "Level 24 ·
  icon · Improved Fireball · 3 of 5". Taken steps are dimmed with "Taken"; the next step is highlighted and
  scrolled into view; steps for levels not reached yet read normally. The panel can be collapsed to a tab.
- **Off plan.** A point in a talent the plan doesn't have (or more ranks than planned) is flagged in the list
  ("Not in your build: Frostbite 1 of 3"), so the player can reset talents if they want; the addon never does.

**How "taken" is worked out.** Walk the order step by step against the character's ranks: a step is taken while
the character has a rank left in that talent to account for it. The first step that isn't is the next one. So
taking talents in a different order than planned still ticks them off, and the next step is always the earliest
one not yet done. Updated on `TRAIT_CONFIG_UPDATED`, `PLAYER_LEVEL_UP` and when the talent window opens.

**Level-up reminder** (optional, on by default): after a level-up, out of combat, a small note near the talent
button: "Level 24: Improved Fireball, rank 3 of 5". Clicking it opens the talent window.

## Talent planner
Owner, 2026-11-01. The game can't tell the addon in which order a character's talents were learned, so a plain
export has ranks only. The planner fills that gap, and lets a player plan in game without the website.

**What the player does.** "Edit" (main window, or the order list's header) opens the planner: the character's
class trees drawn by the addon, each talent clicked in the order it was (or will be) taken.
- Left-click adds the next point to a talent; right-click takes the talent's last point off. Each point gets the
  next level: the first at the character's first talent level, one per level after.
- **How many points:** up to what the character has at its current level, counting the Talented Legacy perk the
  character really has (read from the game, as export does): level 23 with no Talented is 14 points, with
  Talented 5/5 it is 19. The header says so: "14 of 14 points (level 23, from level 10)".
- **Start from my talents** (button): loads the character's current ranks as a pool to put in order, so a player
  can write down how they got here; points not yet ordered are listed until placed.
- The site's talent rules apply: a row needs 5 points above it in that tree, a prerequisite needs its rank first,
  no more than a talent's ranks. A refused click says why in a line under the trees, in the site's words
  ("Arcane Subtlety needs 5 points in Arcane above it first").
- Taking a point off from the middle of the order keeps the rest in order and shifts it a level earlier, refusing
  when that would break a rule, as the site's order editor does.

**When done.**
- **Save:** names it and stores it as a build (with its order) in `Talents4eDB`, followed by this character unless
  unticked. Saving over the build being edited asks first.
- **Copy link:** the export box with `https://wow-4e.com/builds/new#b=<code>`: the planned order plus the
  character's class, race, body type, level, gear and Legacy perks. In the browser the Build Calculator opens it,
  where the player saves it to their account when signed in or to the browser's local storage when not (the site
  already does both; nothing to build there).
- **Cancel:** leaves without saving (asks first if anything changed).

**Never on Blizzard's window.** The planner is its own window, never click-catching frames over Blizzard's talent
buttons: a click there must always mean learning the talent for real, so the two can't be confused. Learning stays
the player's own click in Blizzard's window.

**What it needs that the addon doesn't have yet.**
- `Data.lua` grows from node ids to each talent's row, column, rank count and prerequisite (from the site's
  `talents\<class>.json`, by `tools\make-data.mjs`). Names, icons and tooltips come from the game at runtime
  (`C_Traits.GetDefinitionInfo` to the spell, then `C_Spell` and `GameTooltip:SetSpellByID`), so they stay in the
  player's language and nothing is copied.
- `Core.lua` gets the talent rules, mirroring `wow-4e\packages\core\src\talents.ts` (`pointsAtLevel`,
  `addBlock`, `removeBlock`, `orderProblem` and friends). Like the build code, the tests run both on the same random
  cases and fail when they disagree; a rule change is made in both repos together.

## What it never does
Checked against "Blizzard's rules" in `..\..\CLAUDE.md`.
- Never learns talents, spends Legacy points or equips gear. It highlights and the player clicks.
- Never reaches the website: export is text the player copies, import is text the player pastes.
- Never reads other players' characters beyond what the game shows (inspecting someone is a later question, not
  part of the first version).

## In game
The screens, their states, the Blizzard templates behind them and the Figma plan are in `docs\ui-design.md`. In
short: `/t4e` or a minimap button opens the main window (saved builds with Import and Export buttons); the talent
window gets level numbers on its talents and the order list beside it; level-ups show a small reminder.

## Game API and events
Forever runs on the modern client (interface 16001; 120100 is Retail 12.1.0, not Forever; its project id is `WOW_PROJECT_CAMELOT`,
which addons expect to be renamed). What the export uses, found 2026-11-01 from the site's data and from addons
installed in `_forever_` (Questie, EnhanceQoL), **not yet confirmed in game** (Check talents in the main window does that):
- Talents are trait trees. The site's talent `id` is the `TraitNode` id, and a tree's talents are in row-then-column
  order, so the addon reads each position's node with `C_Traits.GetNodeInfo(configID, nodeID)` (`ranksPurchased`).
  The config is `C_ClassTalents.GetActiveConfigID()`; EnhanceQoL tries this first and falls back to the classic
  `GetNumTalentTabs` / `C_SpecializationInfo.GetTalentInfo`, so which one Forever answers is the first thing to
  check.
- Legacy perks: `C_Traits.GetConfigIDBySystemID(45)` gives the Legacy config (Questie reads the Diplomat perk this
  way); its trees are 1188, 1189 and 1187, the site's ids.
- Class, race, sex, level: `UnitClass`, `UnitRace` (third returns are Blizzard's ids, as in the code), `UnitSex`
  (2 / 3, written as 0 / 1), `UnitLevel`.
- Gear: `GetInventoryItemLink("player", 1..19)`; the link's second field is the enchant and its seventh the random
  suffix. Negative suffixes (ItemRandomSuffix) can't be written in a code and are dropped.
- `GetBuildInfo` gives the client build, compared with the data's build to warn when talents may have moved.
- For the talent order: `PLAYER_LEVEL_UP`, `TRAIT_CONFIG_UPDATED`, and the talent window loading
  (`ADDON_LOADED` for `Blizzard_PlayerSpells`) and showing.

## Saved data
- `Talents4eDB` (account-wide): settings and imported builds as build codes, with a name for each (up to 20), and
  each character's active build (keyed by realm and name).
- Nothing is read by a PC tool or the website: builds travel as copied text.

## Website link
The heart of the addon. Both directions use the build code from `wow-4e\packages\core\src\build-code.ts`:
`3.<gameBuild>.<classId>.<raceId>.<sex>.<level>.<talents>.<order>.<gear>.<legacy>`, URL-safe, under 512
characters. A Lua copy of the encoder and decoder must agree with it exactly; tests check one against the other.
Possible site work later: a "Copy for Talents-4Everyone" button on build pages, and a Download link on the Builds hub.

## Left out for now: gear guide
Not being built (owner, 2026-11-01). Kept here in case it comes back, possibly as its own addon. Found 2026-11-01 (build 1.60.1.70707):
- **In the client's files (wago.tools, product `wowf`):** items (`ItemSparse`, 19,269 rows: name, slot, quality,
  item level, required level) and crafting (spells that create an item, and the profession and skill they need).
  The game also answers item questions live (`GetItemInfo`, `C_Item`).
- **Not in the client:** where things drop, what vendors sell and what quests reward. Those live on Blizzard's
  servers. Forever has no Encounter Journal tables (`JournalInstance`, `JournalEncounterItem`: "Table not found"),
  and `QuestV2` only holds ids and flags.
- **QuestieDB** (installed in `_forever_` with Questie) ships a Forever database: for each item its NPC drops,
  object drops, vendors, quest rewards and required level. Its drops are Classic Era's data plus Forever
  corrections, so Forever-only items and changed loot may be missing. Licence: GPLv3 for new work, "all rights
  reserved" for older contributions, so its data can't be copied into an Apache-2.0 addon. It has a public API for
  other addons (`ItemDB`, `NpcDB`, `QuestDB` globals and a documented schema), so Talents4e could read it at runtime
  when the player has it installed (`## OptionalDeps: QuestieDB`) without copying anything.
- **AtlasLoot**: not installed on Forever; not checked.

Scope options, smallest first (owner to choose):
1. **Status only:** each slot's planned item, what's worn, "Equipped", "In bags" or "Missing", and whether its
   required level fits now. Game API only, no data to ship.
2. **Plus crafted:** which profession and skill make a missing item, generated from the client's files like
   `Data.lua` (small).
3. **Plus drops, vendors and quests from QuestieDB** when installed; "Source unknown, install QuestieDB" when not.
4. **Our own loot database:** not possible under the site's rule (client files only, never scraped), and Questie's
   licence rules out copying theirs.
A full levelling route (zones, quest order) is out of scope: Questie, Guidelime and RestedXP do that.

## Other addons
Names to check (from memory, not yet checked on Forever or CurseForge): **AtlasLoot** (loot tables),
**Questie** and levelling guides such as **Guidelime** or **RestedXP** (where things are, quest routes),
**Talented** (talent templates in game). Note what each covers, so Talents4e adds what's missing instead of copying.
- **Forever Talents** (Crowsy, CurseForge `forever-talents`, about 7.5K downloads, updated 2026-10-21; seen
  2026-11-01): plans and saves builds on Forever's talent window, glows planned talents and shows "ghost ranks"
  ahead, copies an inspected player's talents, imports and exports its own strings, and can spend available
  points from a plan. No levels per point and no wow-4e.com links. Talents4e differs by following the site's talent
  order (a level on each talent and a list) and by never spending points for the player. It also shows that an
  addon can draw over Forever's talent window.

## Decisions
- No chat commands for features (owner, 2026-11-01). `/t4e` and `/talents4e` only open the main window; export,
  import and everything else are buttons in the addon. The `/t4e export` and `/t4e check` subcommands are gone (2026-11-01):
  export and Check talents are buttons in the main window.
- Export gives the whole `https://wow-4e.com/builds/new#b=...` link: pasting it in a browser opens the build.
  Import will accept a bare code too.
- The export carries talent ranks, not an order: the game doesn't record when each talent was learned.
- Planner, as built (2026-11-02): points up to the character's level, but a saved build that plans further (an
  imported level-60 build) can be edited in full. Ranks-only builds and Start from my talents become a pool of
  points to click in order; Place the rest puts what's left at the end, top rows first. Legacy perks are read, not
  planned. Owner to confirm.
- Minimap button: our own small button rather than LibDBIcon (2026-11-02), so nothing third-party has to be
  embedded. Switch to LibDBIcon if players ask for minimap-button collectors to pick it up. Owner to confirm.

## Open questions
- Planner: should it also allow planning past the character's level (to 60, like the site), or only up to it as
  decided for now? And should it plan Legacy perks too, or only read the character's?
- Recording the order as it happens: from install on, the addon could note which talent gained a rank at which
  level (`TRAIT_CONFIG_UPDATED`), so later exports carry a real order without the planner. Worth doing?
- Do `C_ClassTalents.GetActiveConfigID()` and `C_Traits.GetConfigIDBySystemID(45)` answer on Forever, and does
  every node id in `Data.lua` come back? (Check talents in game; mapping to the site's order is settled.)
- The talent window: Forever's is `PlayerSpellsFrame` (`Blizzard_PlayerSpells`, load on demand), the same family
  as Retail's, going by Forever addons (EnhanceQoL, WhatsTraining). Check in game with `/fstack`: does the Talents
  tab have Retail's `GetTalentButtonByNodeID`, or how else to find a talent's button? Can our numbers and glow sit
  over the buttons without tainting the window (try learning a talent in and out of combat)? Retail can test this
  part, since the window is the same.
- Does Forever stage talent picks until an "Apply" click like Retail? If so, should a staged pick count as taken?
- Does every talent node's own button show on Forever's window at its grid position (so a number can be placed on
  it), or do the three trees scroll?
- Should import also accept a saved build's address (`/builds/public/<slug>`)? That would need the site to give
  out the code, since the addon can't fetch it.
