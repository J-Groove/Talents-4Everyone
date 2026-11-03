# Work in progress (Talents-4Everyone)

The shared notebook for every Claude chat working on this addon. `CLAUDE.md` holds what stays true; this file holds
what is happening now. Keep it short.

## How chats use this file
- Read it at the start of a chat, before editing anything.
- Claim your work under "In progress": the area, the files you will touch, and the date. If what you need is
  claimed, tell the owner instead of editing it.
- When you finish, clear your claim, add a line to "Done lately", and record anything another chat must know.
- The owner commits. Nothing here changes that.

## In progress
<!-- One line per chat: area · files/folders · since (date) · what is left. -->

## Waiting on someone
- Owner, in game (Retail works for all of this except Forever's own talents): `/reload`, then
  - **Planner:** main window > New plan. Do the three trees draw with icons, ranks and prerequisite bars? Left-click
    adds a point, right-click takes the last off, a locked talent says why under the trees. Start from my talents,
    Place the rest, Clear, Save (then Edit it and Save again: it asks to save over), Copy link (paste it in a
    browser). The X and Cancel ask before dropping changes. On Retail the trees are a Forever class's, drawn from
    `Data.lua`, so the icons and names are right but don't match Retail's talents.
  - **Settings:** Options > AddOns > Talents-4Everyone, or the Settings link in the main window's footer. Four check
    boxes, Reminder position (Reset) and Open Talents-4Everyone. Turning the minimap button off hides it at once.
  - **Minimap button:** shows the 4E disc inside the round border; click, right-click, drag it round the edge; it
    stays put after `/reload`. The 4E also shows beside Talents-4Everyone in the AddOns list.
  - Any Lua error, and whether `UICheckButtonTemplate`, `InsetFrameTemplate` and `NumberFontNormal` look right.
- Owner: `git init` and a GitHub repo when you are happy with it.
- Owner: confirm the two calls in `design.md`, "Decisions" (planner limits, our own minimap button).

## Next up
- Owner: review screens 2 and 4 to 7 in Figma. Redraw screens 4, 6 and 7 over real screenshots now that they exist.
- The first CurseForge release: `docs\curseforge.md` has the steps, the description and the screenshots to take.
- The order list's talent window checks on Forever itself once it is out (`/fstack` names, taint, the Apply step).

## Done lately (newest first)
- 2026-11-02 · Renamed Talents-4Everyone (owner): code name Talents4e, folder `addons	alents4e`, `Talents4e.toc`,
  `Talents4e.lua`, `Talents4eDB`, `/t4e` and `/talents4e`, frame and popup names. Retail and Anniversary relinked as
  `Talents4e`; Retail's saved builds copied to `Talents4e.lua` (the old `Build4e.lua` left in place). Screenshots to retake.
- 2026-11-02 · Settings labels shortened (they were cut off in game). Linked into `_anniversary_` (the Classic Era link
  removed); TOC has 20506 for screenshots there. Forever only: no code for other clients (owner).
- 2026-11-02 · Minimap button and addon list icon: the site's 4E monogram (Figma 13:3) as `Media\Icon.tga`, made by
  `tools\make-icon.mjs`; in the CurseForge zip. Not seen in game yet.
- 2026-11-02 · Talent planner, Settings page, minimap button. `Rules.lua` (the site's `talents.ts` rules, checked
  against it on random builds and orders for all 9 classes), `Planner.lua` (plan state and its own window; Edit and
  New plan in the main window, Edit on the order list), `Settings.lua`, `Minimap.lua`, `Builds.Replace`,
  `Windows.ShowLink`. `Data.lua` now has rows, columns and prerequisites. Tests: 38 passing. Not tried in game.
- 2026-11-02 · The import, export and check boxes no longer let the main window show through (top-level windows).
- 2026-11-02 · Owner: the main window, import, export and the talent order look right on Retail.
- 2026-11-01 · Talent order: `Order.lua` (taken steps, next step, off-build ranks, Talented's earlier first level,
  reminder words), `Talents.lua` (level badges, glow on the next talent, docked order list that folds to a tab),
  `Reminder.lua` (level-up toast, held back in combat). `Data.lua` now has talent names, icons, ranks and spells,
  and Talented's `early`. Tests: 28 passing, the list against a stand-in talent window. Not tried in game.
- 2026-11-01 · Main window and import: `Builds.lua` (saved builds, 20 at most, follow per character), `Windows.lua`
  (main window, import box, export box, Check talents box), `/t4e` now only toggles the main window. `Data.lua`
  carries class, tree and race names and icons. Tests: 23 passing. Not tried in game.
- 2026-11-01 · Figma: Reminder toast and Check box components; screen 5, the level-up reminder (5 states), and
  screen 7, settings (2 states). Every screen in `ui-design.md` is now drawn.
- 2026-11-01 · Figma: Build row component and screen 2, the main window (6 states).
- 2026-11-01 · Figma: components Level badge, Talent button, Talent glow, Order row; screen 4 (talent order on the
  talent window, 5 states) and screen 6 (talent planner, 6 states), on a stand-in talent window drawn from the
  site's Mage data. Screens 1 and 3 retitled without chat commands.
- 2026-11-01 · Plan refocused (owner): no chat commands for features, gear guide left out, talent order on the
  talent window with level numbers, the next talent highlighted and a docked list; a talent planner (edit mode)
  that saves a build and copies its wow-4e.com link. `design.md`, `ui-design.md`.
- 2026-11-01 · Figma: `Addon/WoW` foundations, 5 components, export and import screens in every state.
- 2026-11-01 · Loads and answers `/t4e` on Retail (owner's screenshot). UI plan written: `docs\ui-design.md`.
- 2026-11-01 · Export, first version: `Core.lua` (build codes, checked against the site's `build-code.ts`),
  `Data.lua` and `tools\make-data.mjs`, `Character.lua`, `Talents4e.lua` (`/t4e export`, `/t4e check`), `tests\`
  (17 passing). Not tried in game. Linked into `_retail_` for testing on 2026-11-01.
- 2026-11-01 · Planned: folder from `..\_template\`, `CLAUDE.md`, `README.md`, `docs\design.md`. No repo yet.

## Decisions to keep
- `/t4e` only opens the main window; every feature is a button. The gear guide is left out for now (2026-11-01).
