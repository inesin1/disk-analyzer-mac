# Disk Analyzer

A small WizTree-style disk usage viewer for macOS. Scans a folder (or the whole disk), shows
where the space actually went as a squarified treemap next to a sortable list, and can move
things to the trash straight from either pane.

Written because every free macOS equivalent is either nagware or reports sizes that don't add
up to what the disk says is used.

## Download & Install (Pre-built)

You can download a pre-built ready-to-run app (no Xcode required) from the **[Releases](../../releases)** page.

1. Download the `DiskAnalyzer-vX.X.X.zip` from the latest release.
2. Unzip it and move `Disk Analyzer.app` to your Applications folder.
3. Open it!

*Note:* Because the app is not currently signed with an Apple Developer certificate, macOS might show a warning ("can't be opened because it is from an unidentified developer"). To bypass this, right-click (or Control-click) on `Disk Analyzer.app` and choose **Open**.

Scanning `/` needs Full Disk Access, otherwise large parts of the tree silently come back
empty: System Settings → Privacy & Security → Full Disk Access, then add the `Disk Analyzer.app`.

## Build and run from source

If you prefer to build from source:

```sh
./build_app.sh
open "Disk Analyzer.app"
```

Or `swift run` for a debug build. Requires macOS 14+ and a Swift 6 toolchain (Xcode 16 or the
matching command line tools). The package opens directly in Xcode if you'd rather run it there.

## Sizes

Sizes are `st_blocks * 512` — the space a file actually occupies — rather than the logical
length. That matters on APFS:

- iCloud placeholders report gigabytes of logical size while holding no blocks at all.
- APFS clones (what Finder's "Duplicate" makes) share blocks with the original, so a clone
  costs almost nothing.
- Hard links are counted once, for whichever copy the scan reaches first. The rest show 0.

Symlinks are never followed. A handful of paths are skipped because they'd be counted twice or
aren't real storage: `/System/Volumes/Data` and friends (already visible through firmlinks at
the top level), `/private/var/vm`, `/dev`, `/.vol`, and `/Volumes`.

## Controls

| | |
|---|---|
| Double click, Return, Space | Open the selected folder |
| Command-Up | Go up one level |
| Command-click | Add to / remove from selection |
| Shift-click (list) | Select a range |
| Delete, Command-Delete | Move selection to trash |
| Right click | Open, reveal in Finder, copy path, trash |

Deleting acts on the whole selection when you right-click something that's already selected,
otherwise only on the item under the cursor. There's one confirmation dialog per batch.

## Layout

```
Sources/DiskAnalyzer/
  DiskAnalyzerApp.swift        entry point, dock icon setup for the bundle-less binary
  Models/FSNode.swift          tree node
  Scanning/DiskScanner.swift   the walk, dedup and size accounting
  Treemap/                     squarified layout, no UI dependencies
  Views/                       treemap, list, shared node actions
  Utilities/                   app-wide double click monitor
```

## Known rough edges

- The whole tree is built in memory before anything is drawn. A full `/` scan takes a while and
  holds on to a node per file.
- Nothing is recomputed after a trash operation beyond subtracting sizes up the parent chain —
  rescan if you want exact numbers.
- The scan can't be cancelled once started.
