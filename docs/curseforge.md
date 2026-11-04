# Putting Talents-4Everyone on CurseForge

How to publish the first release by hand, so players can install it from the CurseForge app. Later releases can be
automated (see "After the first release"). Written 2026-11-02; nothing here has been done yet.

## What we know about Forever on CurseForge
- Forever is its own game flavor on CurseForge, beside Retail and the Classic flavors. Forever Talents, a similar
  addon, files its releases under **Forever**, game version **1.60.1**, in the categories Class, Quests & Leveling
  and Miscellaneous (seen 2026-11-02).
- The CurseForge app decides which game a file is for from the TOC's `## Interface:` numbers. Forever's number is
  **16001** (1.60.1), and Talents4e's TOC lists only that (owner, 2026-11-02), as do the Forever-only addons in
  `_forever_` (EnhanceQoL's `_Camelot` TOCs, ForeverQuestTint). Any other number offers it to another game:
  `120100` and `120105` are Retail 12.1.0 and 12.1.5, `11509` Classic Era, `20506` Classic Anniversary, `50504`
  Mists. To try it on another client, add that number locally and never commit or upload it.

## 1. Before uploading
- [ ] Tried in game with no Lua errors on a fresh character: the main window, import, follow, the talent order,
      the planner, Settings and the minimap button. Forever itself if you can, otherwise Retail.
- [ ] `## Version:` in `Talents4e.toc` matches the top heading of `CHANGELOG.md` (both `0.1.0`), and that heading
      no longer says "(unreleased)".
- [x] The TOC's `## Interface:` line is `16001` only (above).
- [ ] `README.md` is current: it's in the zip, and its "Using it" section is a good source for the description.

## 2. Build the zip
From the addon folder:

```powershell
powershell -NoProfile -File tools\package.ps1
```

This writes `.release\Talents4e-0.1.0.zip`, which holds a single `Talents4e` folder: the TOC, the 13 Lua files,
`Media/Icon.tga`, `LICENSE`, `README.md` and `CHANGELOG.md`. Tests, tools, docs and `CLAUDE.md` stay out, as in `.pkgmeta`.
`.release\` is git-ignored. To be sure it works, unzip it into a game's `Interface\AddOns`, move the linked
folder out of the way first, and `/reload`.

## 3. Create the project
At [authors.curseforge.com](https://authors.curseforge.com), sign in, then Create Project:
- **Game:** World of Warcraft. **Class:** Addons.
- **Name:** Talents-4Everyone.
- **Summary:** the one line under "Description to paste" below.
- **Description:** the text under "Description to paste" (the editor takes Markdown or its own rich text).
- **Categories:** Class (main), Quests & Leveling, Miscellaneous.
- **Licence:** Apache License 2.0.
- **Source / issues:** the GitHub repo's address, once it exists (the repo is public, like VendEver).
- **Logo (avatar):** a square picture of our own. Never Blizzard art or an icon taken from the game; a
  wow-4e.com brand mark is fine: the site's `wow-4e\apps\web\public\icon-512.png` (the 4E crest, the same
  mark as the minimap button) fits. 400 by 400 px or larger is a safe size.

New projects are checked by CurseForge's moderators before they go public. That usually takes from a few hours to
a couple of days.

## 4. Upload the file
On the project's Files tab, choose Upload File:
- **File:** `.release\Talents4e-0.1.0.zip`.
- **Display name:** `Talents-4Everyone 0.1.0`.
- **Release type:** **Beta** until it has run on Forever itself; then **Release**.
- **Game version:** Forever, **1.60.1** (or whatever the newest Forever version in the list is; check
  `/dump select(4, GetBuildInfo())` in game, which should say 16001).
- **Changelog:** paste the `0.1.0` section of `CHANGELOG.md` (Markdown).

## 5. After it's approved
- Copy the **Project ID** from the project page's About box into the TOC, under `## Author:`:
  `## X-Curse-Project-ID: 123456`. That lets the CurseForge app match installed copies to the project.
- Commit and push it, then tag 0.1.0 (an annotated tag, which the packager wants):
  `git tag -a v0.1.0 -m "Talents-4Everyone 0.1.0"` and `git push --tags`. The release workflow runs and makes a
  GitHub release with the zip. With no CurseForge token saved yet it skips CurseForge, which is right: 0.1.0 is
  already there by hand. Add the token (below) only after this tag.
- Record what the first release taught (the exact game version label, how long approval took) in
  `..\CLAUDE.md`, "Releasing on CurseForge".
- Add the CurseForge address to the website's `docs\addons.md` (the website chat owns that file; leave it a
  note in `wow-4e\docs\status.md`).

## After the first release: automatic uploads
`.github\workflows\release.yml` runs the BigWigs packager whenever a tag starting with `v` is pushed. The tag is the version CurseForge shows:
tag `v0.2.0` uploads as "Talents-4Everyone v0.2.0" (the workflow's `-n` sets that name). It builds the
zip by `.pkgmeta` (the same files as `tools\package.ps1`), files it under Forever because the TOC's Interface is
16001 (the packager knows `16xxx` as Forever), uploads it to the project named by `X-Curse-Project-ID` with
`CHANGELOG.md` as the notes, and makes a GitHub release with the same zip.

Switching it on, once, after the v0.1.0 tag above:
1. Make a CurseForge API token: on [authors.curseforge.com](https://authors.curseforge.com) look for **API
   Tokens** under your account (older guides point to `legacy.curseforge.com/account/api-tokens`). Name it, say,
   "GitHub Talents4e", and copy it; it is shown once.
2. On GitHub, the repo's **Settings > Secrets and variables > Actions > New repository secret**: name `CF_API_KEY`,
   value the token. Never put the token in a file.
3. Same repo, **Settings > Actions > General > Workflow permissions**: Read and write permissions (the release step
   needs them).

Each release after that:
1. Raise `## Version:` in `Talents4e.toc`, and add a `## <version>` section at the top of `CHANGELOG.md`.
2. Commit and push.
3. `git tag -a v0.2.0 -m "Talents-4Everyone 0.2.0"` and `git push --tags`.
4. Watch the repo's **Actions** tab; the file appears on CurseForge a few minutes later. A plain tag such as
   `v0.2.0` uploads as Release; `v0.2.0-beta1` as Beta and `v0.2.0-alpha1` as Alpha.

The notes CurseForge shows are the whole `CHANGELOG.md`, newest first.

---

## Description to paste

**Summary (one line):**
Follow a wow-4e.com talent build while you level: level numbers on your talents, the next one highlighted, and an
in-game planner.

**Description:**

> # Talents-4Everyone
>
> Plan your talents on [wow-4e.com](https://wow-4e.com/builds), then follow the plan in game while you level.
>
> ## Follow a build on your talent window
> Import any build link from the wow-4e.com Build Calculator and follow it. Open your talents and every talent in
> the build shows the level its next point is due. The next one to take glows, talents you've taken get a tick,
> and the whole order is listed beside the window. When you level up, a small reminder names the talent to take.
>
> ## Plan in game
> The talent planner draws your class's three trees in its own window. Click talents in the order you'll take
> them, one point per level, with the same rules as the website (and Talented counted). Start from your current
> talents to write down how you got here. Save it, or copy a link that opens it in the Build Calculator.
>
> ## Share your character
> Export my character gives you a wow-4e.com link with your class, race, talents, Legacy perks and gear, ready to
> paste into your browser.
>
> ## Features
> - Up to 20 saved builds, shared by all your characters. Each character follows its own.
> - Level badges, a glow on the next talent, and a docked order list on the talent window.
> - Level-up reminder, held back until combat ends.
> - Talent planner with the site's talent rules.
> - Import and export as wow-4e.com links.
> - Settings in Options > AddOns, and a minimap button. `/t4e` opens it too.
>
> It shows and highlights; you click. Talents-4Everyone never learns talents or spends points for you.
>
> Free and open source (Apache-2.0).

---

## Screenshots to take
CurseForge shows them in a gallery on the project's Images tab. Take them in game with **Print Screen**: they're
saved to the game folder's `Screenshots\` (`_forever_` or `_retail_`). Crop them in any image editor.

Tips:
- Use a clean scene (a city, no other addons' frames), UI scale around 0.8 to 1, and turn off nameplates
  (Ctrl+V).
- For every shot, use a character that follows a build with an order, mid-levelling (say level 23), so the badges
  show a mix of taken, next and coming.
- **Retail screenshots will show Retail's talent tree, not Forever's.** Shots 2 and 3 are best taken on Forever;
  the rest look the same on either.

| # | Shot | How to set it up | Caption |
| --- | --- | --- | --- |
| 1 | **Talent window with the order** (the headline image) | Follow a build, open the Talents tab, with a point to spend so the next talent pulses. Crop to the window plus the list. | Every talent in your build shows the level it's due; the next one glows and the order is listed beside it. |
| 2 | **Close-up of the badges** | The same window, cropped to one tree, with a gold next badge, a few due levels and a tick or two. | Taken, next and coming at a glance. |
| 3 | **Level-up reminder** | Level up (or wait for the toast after a level), crop to the toast and the micro buttons. | When you level up, it names the talent to take. |
| 4 | **Talent planner** | Main window > New plan (or Edit a saved build), place 15 to 20 points across two trees. Hover a talent so its tooltip shows "Taken at level ...". | Plan your order in game, with the website's talent rules. |
| 5 | **Main window** | Three or four saved builds, one selected and one marked Following. | Save up to 20 builds and choose one for each character. |
| 6 | **Import box with a preview** | Paste a wow-4e.com link into Import so the preview shows the class, race and points per tree. | Paste a wow-4e.com link to import a build. |
| 7 | **Export box** | Export my character. | Share your character as a wow-4e.com link. |
| 8 | **Settings** (optional) | Options > AddOns > Talents-4Everyone. | Turn each part on or off. |

Taken so far (owner, 2026-11-02, on Classic Anniversary after the rename), kept in `docs\screenshots\` (left out
of the zip with the rest of `docs`): shot 4 `talent-planner.png`, shot 5 `main-window.png` (also
`main-window-empty.png` and `delete-confirm.png`, which shows two builds), shot 6 `import-box.png` (with a
Shaman preview), shot 7 `export-box.png`, shot 8 `settings.png`, and `minimap-button.png`. The export shot shows
Anniversary's warnings (another game build, no talents), and the planner shot has a few grey squares where
Anniversary lacks a Forever icon; retake both on Forever if you can. Still to take on Forever once it is live: shots
1 to 3, the talent window with the order, the badges and the reminder.

Shots 1, 4 and 5 matter most; the first one is the gallery's cover. Wide crops (about 16:9) look best on the
project page.
