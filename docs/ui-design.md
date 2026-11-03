# Talents-4Everyone: UI plan

How the addon looks and behaves in game, designed before the frames are built. `design.md` says what the addon
does; this file says how the player meets it. Mock the screens in Figma first (see "Designing in Figma"), agree
them, then build them.

## Principles
- **Looks like part of the game.** Blizzard's own frame chrome, fonts and colours, so it sits beside the talent and
  character windows without clashing. No custom skin.
- **Small and out of the way.** Nothing opens by itself except the level-up reminder, and that can be turned off.
  Every window closes with Escape and remembers where it was dragged.
- **Shows, never does.** It highlights and explains; the player clicks the talent, buys the item, equips the gear
  (`..\..\CLAUDE.md`, "Blizzard's rules").
- **Never touches Blizzard's frames.** Changing or hooking the talent or character window can taint them (break
  them in combat). The addon draws its own frames next to Blizzard's, anchored to them at most.
- **Readable.** Text at least the game's normal size, information never in colour alone (a rank number next to a
  coloured border, an icon next to "missing"), works at UI scale 0.64 to 1.15.
- **Fine in combat.** Its frames are plain (not secure), so they can open in combat, but the level-up reminder waits
  until combat ends.

## Ways in
| Entry | What it opens | When |
| --- | --- | --- |
| `/t4e` or `/talents4e` | The main window. No subcommands: every feature is a button (`design.md`, "Decisions") | Exists as help and subcommands for now |
| Minimap button (our own, can be hidden; right-click opens Settings) | The main window | Built 2026-11-02 |
| Opening the talent window | Level numbers, the next talent's highlight and the order list, when the character has an active build with an order | Talent order step |
| Level-up | The reminder | Talent order step |

No feature has a chat command: everything is a button in these windows.

## Screens
Built in the order of `design.md`, "What it does". The gear guide is left out for now (`design.md`, "Left out for
now"), so there is no Gear tab.

### 1. Export box (exists, to restyle)
- **For:** copying your character to the website.
- **Shows:** title, one line of help, the link selected for Ctrl+C, notes on anything left out.
- **States:** all read; something left out (notes in yellow, each with what to do); could not make a code (error).
- **Opened by:** the main window's Export button.

### 2. Main window (import step)
What `/t4e` and the minimap button open: the saved builds. One movable window, about 420 by 480 at UI scale 1;
the talent order itself lives beside the talent window (screen 4), not here.
- **Saved builds:** one row each: class icon, name, "Talent order" or "Ranks only", game build. The character's
  active build is marked; an order-less build can be saved but not followed.
- **Buttons:** Import (screen 3), New plan and Edit (screen 6), Follow (makes the selected build this character's
  active one), Stop following, Rename, Delete (asks first), Export my character (screen 1).
- **Empty state:** no build imported yet: a short explanation, an "Import a build" button, and where to get links
  (wow-4e.com/builds).
- **Footer:** "Check talents" (what the game's talent APIs return, in a copyable box for bug reports) and the version
  with the game data's build.
- **States:** empty; following a build (the first button reads Stop following); another build selected (Follow;
  a ranks-only build says Edit can put its points in order); a build for another class (account-wide builds show
  on every character; Follow and Edit disabled, "Log in on a Warrior to follow or edit this build"); renaming
  (the row becomes a text box; Enter saves, Escape cancels); delete asks first (a StaticPopup-style prompt;
  deleting the followed build stops following it).

### 3. Import box
- **For:** pasting a link or code from the website.
- **Shows:** a text box with a placeholder ("Paste a wow-4e.com build link or code"), Import and Cancel buttons, and
  a preview of what was read (class, race, level, points per tree) before saving.
- **States:** empty; reading; preview; can't be read (the reason, in plain words); wrong class for this character
  (allowed, with a warning); build from an older game version (warning, the site's wording).
- **Saving:** name it (defaults to class and the tree with most points, "Mage, Frost"), keep up to 20 builds.
  Import offers "Follow it now" (checked when the build's class is the character's).

### 4. Talent order on the talent window (talent order step)
The heart of the addon. Shown whenever Blizzard's talent window (`PlayerSpellsFrame`, Talents tab: on Forever the
three trees side by side) is open and the character follows a build with an order. All of it is our own frames
laid over or docked to Blizzard's, never changes to Blizzard's buttons.
- **Level numbers on the talents:** a small badge on each planned talent's corner with the level its next rank is
  due ("24"). Fully taken talents show a tick; talents not in the plan show nothing; a talent with points the plan
  doesn't have shows a warning mark.
- **The next talent is highlighted on the tree:** the talent of the list's next step gets a bright animated glow
  (the game's own proc-glow look) and its badge turns black on gold (white on gold is too faint to read). When the character has a point to spend the
  glow pulses; when the next point is still levels away it stays steady and the badge reads the level. The list row
  and the tree glow always point at the same step.
- **Order list docked to the window's right edge:** a header (build name, "Level 23 · 14 of 51 points", a Change
  build button to the main window) and one row per step: level, talent icon, name, rank ("3 of 5").
  - **Taken:** dimmed, with a tick and "Taken".
  - **Next:** highlighted row (gold border, lighter background), scrolled into view when the window opens.
  - **Coming:** normal text; levels the character hasn't reached in grey.
  - **Off plan:** a section at the bottom, "Not in your build", listing talents with points the plan doesn't have.
  - Hovering a row shows the talent's tooltip and briefly glows that talent on the tree, so any step can be found.
  - A collapse button folds the list to a thin tab on the window's edge; the numbers and highlight stay.
- **No order:** if the followed build has ranks only, the list says "This build has no talent order. Add one in
  the Build Calculator on wow-4e.com, then import it again", and the tree shows the planned ranks without levels.
- **Wrong class:** a followed build for another class shows nothing on the tree and says so in the list.

### 5. Level-up reminder (talent order step)
On level-up, out of combat (or when combat ends), a small toast near the talent micro button: "Level 24: Improved
Fireball, rank 3 of 5", with the icon. Clicking it opens the talent window, where the talent is already
highlighted; the toast closes itself after 20 seconds, on Escape or with its X. Can be turned off, and dragged
(Settings resets its position).
- **States:** next talent; several points to spend ("Level 25: 2 points to spend", naming the first); off your
  build (a point the build doesn't plan); build complete (once, at the last step). One toast at a time; a new level
  replaces it. Never in combat or during a cinematic.

### 6. Talent planner (planner step)
Its own movable window (built with `BasicFrameTemplateWithInset` like the other boxes, 876 by 540), opened by New
plan or Edit in the main window or Edit on the order list's header (`design.md`, "Talent planner"). Escape doesn't
close it; its X and Cancel ask first when something changed. As built, prerequisite lines are straight bars (no
arrowheads), and Place the rest sits beside Start from my talents while points remain.
- **Header:** "Editing: Mage, Frost" (or "New build"), "14 of 14 points · level 23 · first point at level 10
  (Talented 0/5)", Start from my talents, Clear.
- **Trees:** the class's three trees side by side, like Forever's talent window: talent icons on the 4 by 7 grid,
  rank on each ("2/5"), prerequisite arrows, locked talents greyed. Each placed point shows its level as a badge
  (the talent's first planned level; the tooltip lists every rank's level).
- **Order list:** down the right side, the same rows as screen 4 (level, icon, name, rank); the newest at the
  bottom. Hovering a row glows its talent.
- **Message line:** under the trees, why a click was refused, or "Points from your talents still to place: 3".
- **Buttons:** Save, Copy link (opens the export box with the planned link), Cancel.
- **States:** empty (no points yet: "Click a talent to take it at level 10"); in progress; full (all points
  placed: talents still open dim, Save highlighted); refused click; unsaved changes on Cancel (asks); character
  below level 10 with no Talented ("Talents start at level 10", trees shown read-only).

### 7. Settings
Blizzard's Settings panel (AddOns tab), a vertical-layout category, so the addon needs no settings window of its
own. Check boxes, each with a line of help: minimap button, level numbers on the talent window (with the glow),
order list beside the talent window, level-up reminder. Buttons: Reset reminder position (disabled while the
reminder is off) and Open Talents-4Everyone. The version and game data build at the foot. Changes apply at once and
are saved account-wide. With the minimap button off, `/t4e` still opens the main window.

## Building blocks
Blizzard's templates where they exist, so the look follows the game:

| Need | Use |
| --- | --- |
| Window chrome | `ButtonFrameTemplate` or `PortraitFrameTemplate` (main window), `BasicFrameTemplateWithInset` (small boxes) |
| Highlight on a talent | Our own frame over the talent: the action-button border texture (`UI-ActionButton-Border`, additive, gold) with an alpha pulse. Blizzard's proc glow changed name between clients, so the addon doesn't depend on it |
| Buttons | `UIPanelButtonTemplate` |
| Text box | `InputBoxTemplate` (one line, `ChatFontNormal`), a `ScrollFrame` with an `EditBox` (several lines) |
| Lists | `ScrollBox` and `ScrollUtil` (the modern client's list API) |
| Tooltips | `GameTooltip` |
| Minimap button | Our own button on `Minimap` (the tracking-border look), dragged round the edge. LibDBIcon if collectors are wanted later |
| Settings | `Settings.RegisterVerticalLayoutCategory` |
Check every template name in the Forever client with `/fstack` and `/dump` before using it; Forever's UI is the
modern one, but some Retail templates may be missing.

## Colours and fonts (from the game, for mockups)
| Use | Colour |
| --- | --- |
| Normal text (`GameFontNormal`) | gold #FFD100 |
| Highlight text | white #FFFFFF |
| Disabled | grey #808080 |
| Error, too low | red #FF2020 |
| Done, OK | green #19FF19 |
| Item quality | poor #9D9D9D, common #FFFFFF, uncommon #1EFF00, rare #0070DD, epic #A335EE, legendary #FF8000 |
| Class colours | as the website's `classes.json` (`color`) |

Fonts: the game uses Friz Quadrata (`FRIZQT__.TTF`) for most text and Arial Narrow for numbers, both in the
client's `Fonts\` folder. They are licensed to Blizzard: use them for private mockups only, never ship or publish
them. The addon itself uses the game's font objects (`GameFontNormal` and friends), never its own font files.

## Designing in Figma
**File:** [WoW 4-Everyone Base Design, page "Addon - Build Calculator"](https://www.figma.com/design/TRKTamdWowRDEpaFgTIXe9/WoW--4-Everyone-Base-Design?node-id=105-855).
The "Design Systems" page there is the website's (`4E/` styles); the addon's styles are under `Addon/WoW/` and only
the doc labels borrow `4E/` styles. On the addon page, as of 2026-11-01:
- **Foundations:** 33 colour styles (frame, buttons and inputs, text, item quality, class) and 6 text styles.
  Marcellus stands in for Friz Quadrata, PT Sans Narrow for Arial Narrow; `Addon/WoW/Type/Chat` (text typed into
  boxes) uses PT Sans Narrow, because Marcellus's old-style figures make codes hard to read.
- **Components:** Close button, Title bar (Title), Button (Default, Hover, Disabled; Label), Text box (Default,
  Focused, Placeholder, Error; Value), Note (Info, Success, Warning, Error; Text), Level badge (Due, Next, Taken,
  Off plan; Level), Talent button (Locked, Available, Partial, Maxed; Rank; a stand-in for Blizzard's buttons),
  Talent glow (Pulsing, Steady), Order row (Taken, Next, Later, Off plan; Level, Talent, Rank), Build row
  (Default, Selected; Name, Detail, Following), Reminder toast (Next talent, Off plan; Heading, Body), Check box
  (On, Off, Disabled; Label, Help).
- **Screens:** 1. Export box (all read, something left out, could not make a code); 2. Main window (empty,
  following a build, another build selected, a build for another class, renaming, delete asks first); 3. Import box (empty,
  preview, can't be read, read with warnings); 4. talent order on the talent window (a point to spend, next point
  at a later level, off plan, list folded, no talent order and wrong class); 6. talent planner (empty, in
  progress, refused click, start from my talents, full, cancel with unsaved changes). Example for 4 and 6: a level
  23 Gnome Mage on a 51-point Frost order, drawn from the site's Mage data and icons.
- **Stand-in talent window:** screens 4 and 6 draw Forever's talent window from the site's data (three 4 by 7
  trees, prerequisite lines), not from a screenshot. Swap in a real screenshot of Forever's window once there is
  one, and check where the badges sit on Blizzard's buttons.
  5. Level-up reminder (where it shows, next talent, several points, off your build, build complete); 7. Settings
  (defaults; reminder and minimap button off), on a stand-in of Blizzard's Settings panel.
- Every screen is drawn. Still to do: redraw screens 4 and 7 over real screenshots of Forever's talent window and
  Settings panel.

No ready-made World of Warcraft UI kit for Figma was found (2026-11-01). The plan is a small kit of our own, in a
private Figma file:
- **Pages:** Foundations (colours, fonts, frame chrome), Components (window, button, text box, level badge, talent
  glow, order row in each state, planner talent button, toast), Screens (the seven above, each state), Flows (export, import, level-up).
- **Art:** screenshots of the real game windows at UI scale 1, 1920 by 1080, for chrome and spacing; icons from
  the website's own copies (`wow-4e\apps\web\public\img\icons\`, 56 by 56); other textures from the client through
  wago.tools (as `wow-4e\tools\game-data\README.md` does for race portraits). Blizzard's art stays in the private
  file: never publish the kit to Figma Community.
- **Size:** design at 1x (one Figma pixel is one UI pixel at scale 1); check the main window at 1366 by 768.
- **Handover:** each screen names the template and font object it maps to, so building is translation, not
  guessing.

## Tools for building and checking
- **In game:** `/fstack` (which frame is under the mouse, its textures and names), `/etrace` (events as they fire),
  `/tinspect` (look inside a table or frame), `/console scriptErrors 1` (show Lua errors).
- **TextureAtlasViewer** (`/tav`) and **TextureViewer** (`/texview`): find atlas names and texture paths for
  Blizzard art. Developer addons; install on the test client only.
- **Blizzard's UI code:** the client's own `Interface\AddOns\Blizzard_*` files show how Blizzard builds a window;
  read them for template and API names (exporting them from the client through wago.tools, as the site does for
  textures).
- **Visual addon editors** (WoW UI Designer, AddOn Studio) exist but are old Windows tools aimed at XML layouts and
  aren't clearly open source. Not used: frames are built in Lua, laid out from the Figma screens.
