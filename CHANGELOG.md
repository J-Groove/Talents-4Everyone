# Changelog

## 0.1.1
- Talent data updated to game build 1.60.1.70753, the same as wow-4e.com: Paladin loses One-Handed Weapon
  Specialization, so Paladin builds made on the site now import with every talent in the right place, and a few
  Druid talent requirements in the planner match the game again.
- Import warns about an old game version only when that class's talents really moved since (as the site does), so
  most builds made before this update import without a warning.
- Import warns when a build was made for a newer game version than the addon knows: update the addon.

## 0.1.0
- Main window, opened with `/t4e` or `/talents4e`: your saved builds, with buttons for everything else.
- Import: paste a wow-4e.com build link or code, see what it holds, name it and save it (up to 20). Warns when the
  build is for another class, made for an older game version, or has no talent order.
- Follow a saved build on a character of its class; rename and delete builds.
- Talent order on the talent window: the level each planned talent's next rank is due, a tick on taken talents, a
  glow on the next talent to take, and the order list beside the window (taken, next, coming, and points that
  aren't in your build). Talented's earlier first level counts.
- Level-up reminder naming the next talent; click it to open your talents.
- Talent planner (New plan, Edit): click talents in order, one point per level up to your level, with the site's
  talent rules and its wording when a click is refused. Start from my talents, Place the rest, Clear. Save it as a
  build (or over the one being edited), or copy its wow-4e.com link.
- Settings page in the game's Settings panel: minimap button, level numbers, order list and reminder on or off;
  reset the reminder's position.
- Minimap button: click for your builds, right-click for settings, drag to move it.
- Export my character: class, body type, race, level, talents, Legacy perks and gear as a wow-4e.com Build
  Calculator link to copy.
- Check talents: what the game's talent APIs return, in a box to copy.
