# Talents-4Everyone

A World of Warcraft: Forever addon that copies your character (class, body type, race, Legacy perks, talents and
gear) to the [wow-4e.com Build Calculator](https://wow-4e.com/builds/new), and shows a build from the site in game:
the level for each talent right on the talent window, with the next one to take highlighted and the whole order
listed beside it.

In development, not released yet. See [docs/design.md](docs/design.md).

## Install
From CurseForge: not released yet.

By hand: copy this folder into `World of Warcraft\_forever_\Interface\AddOns\Talents4e`. The folder name must be
`Talents4e` so it matches `Talents4e.toc`.

## Using it
`/t4e` (or `/talents4e`), or the minimap button, opens the main window. Everything else is a button there:
- **Import**: paste a build link or code from wow-4e.com, name it, and save it (up to 20 builds).
- **Follow**: the build this character follows. Open your talents and each planned talent shows the level its next
  rank is due, the next one to take glows, and the order is listed beside the window. A reminder names the next
  talent when you level up.
- **New plan**, **Edit**: the talent planner. Click talents in the order you'll take them, one point per level up to
  your level (Talented counts); right-click takes a point off. Start from my talents lists your current points to
  put in order. Save it as a build, or copy its wow-4e.com link.
- **Rename**, **Delete**: tidy your saved builds.
- **Export my character**: your character as a wow-4e.com Build Calculator link, ready to copy.
- **Check talents**: what the game's talent data looks like, to copy into a bug report.
- **Settings** (also Options > AddOns > Talents-4Everyone, or right-click the minimap button): turn the minimap
  button, the level numbers, the order list and the level-up reminder on or off.

## Saved data
- File: `WTF\Account\<account>\SavedVariables\Talents4e.lua`
- `Talents4eDB`: your saved builds, which build each character follows, your settings, where the reminder and the
  minimap button sit, your last export and last check

## Licence
Apache-2.0. See [LICENSE](LICENSE).
