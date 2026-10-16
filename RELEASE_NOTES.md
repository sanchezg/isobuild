# Release 2 — 0.2.0 (build 3)

## Drawing tools

- Gray sketch pencil and black fiber pen replace the earlier ink/shadow pair.
- Both share three widths and optional pressure. Fiber stays above the draft.
- Undo is available in the bottom drawing toolbar as well as the header.
- Double-tap the Apple Pencil barrel to alternate between the last two distinct
  tools. Initially, fiber alternates with eraser. Eraser mode/size and pen/texture
  settings are retained. Repeated selection of the current tool does not change
  the pair. Double-taps during a stroke or fill are ignored. Disabling double-tap
  in iPad settings disables it in the app as well.

## Partial erasing

- Erase only the pixels inside the displayed circle, with three available sizes.
- Sketch eraser affects gray pencil only, preserving fiber and texture.
- Fiber eraser affects everything under its footprint, including texture.
- Fast sweeps remain continuous; repeated passes never restore erased pixels.
- Each eraser gesture is one undo/redo action. Original samples, pressure, and
  endpoint anchors remain available beneath the masks until fully erased.

## Texture bucket

Select Texture fill, choose Stone, Brick, Wood, or Tiles, then tap a closed
region with the Pencil. Visible pencil/fiber outlines define the region;
guide dots and texture marks do not. Enclosed holes remain empty. After erasing
a gap in an outline, close it again before filling. Tap away from the boundary.

Textures use monochrome, slightly irregular vector marks on the isometric
grid. They can be erased partially with the full eraser and replaced by another
texture. Each fill is one undo action. Oversized fills ask you to divide the
region instead of allocating unbounded memory.

## Existing maps and installation

Release 1 maps remain readable, including the earlier gray marker and its width.
The original map is backed up as `map-release1-backup.json` in Documents.
New edits use document version 2, preserving masks and texture metadata.

Install as an update with the same bundle identifier and Team. Avoid deleting
the existing app because its map lives in the application container. The
generator preserves signing settings and the shared scheme. Source and docs
remain English; the app remains Spanish. GPLv3 and gsanz.dev notices are unchanged.

Physical Pencil double-tap, latency, pressure, palm rejection, and erasing feel still need
verification on the iPad.
