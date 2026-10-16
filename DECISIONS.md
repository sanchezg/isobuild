# IsoBuild — product decisions

A native app for drawing dungeon maps with Apple Pencil Pro on an 11-inch iPad
Air. Requested target device: M4, iPadOS 26.6. Build and install from the user's Mac.

## Confirmed decisions

- Draw by dragging the Pencil, one stroke per contact.
- Guided mode connects dots along the two diagonals or the vertical axis.
- Angles relative to horizontal: 30° by default, or 45°.
- Freehand mode preserves the path without snapping.
- Correct only endpoint regions. Preserve original samples and middle-stroke
  irregularities instead of replacing the path with a straight line.
- Releasing far from an eligible destination preserves the unsnapped endpoint.
  Crossing intermediate dots does not modify the stroke.
- Fixed width by default, with pressure-sensitive width available for new strokes.
- An expandable canvas with zoom and partial erasing. Gray sketch and black
  fiber are separate material channels; fiber always renders above the sketch.
- Three eraser sizes. Sketch erasing preserves fiber; full erasing also affects
  fiber and textures. The circular footprint is removed, not entire strokes.
- The bottom drawing bar includes Undo.
- Apple Pencil double-tap alternates the last two distinct tools, initially
  fiber and eraser, retaining tool settings. It respects system double-tap
  disabling and is ignored during an active stroke or fill.
- Texture fill by tapping an existing closed outline: stone, brick, wood,
  and tiles, with monochrome natural-looking vector marks. Previous textures
  and guide dots are excluded from boundary detection. Enclosed holes stay empty.
- Visible app credits and distributed derivatives that provide source under
  terms preserving those freedoms. GNU GPL version 3 with notice preservation
  under section 7(b), copyright gsanz.dev. See LICENSING.md and ATTRIBUTION.md.
- English source, comments, documentation, and filenames. Spanish app interface
  for now, with translations stored outside Swift source.

## Initial prototype values

- Dots spaced 40 world units along each diagonal; snapping within 14 screen
  points, independent of zoom. Local corrections fade over at most 18 screen
  points at each endpoint and never extend into the stroke's middle.
- Gray sketch pencil and black fiber pen, with the same three widths and
  optional pressure. Release 1 gray marks retain their width as sketch material.
- Eraser diameters: 12, 28, and 52 canvas units, displayed at the current zoom.
- Pencil draws or erases; fingers pan and zoom. No canvas rotation.
- Undo/redo for 100 actions and automatic local saving of one map.
- A hideable grid and full-drawing PNG export on white without dots.
- Angle and spacing may change only on an empty map, preventing distortion
  or misalignment of existing drawings.

## Outside this first prototype

A map gallery, general-purpose additional layers, automatic shapes, importing,
synchronization, PDF export, and Pencil Pro squeeze gestures.

## Essential iPad check

Compare freehand and guided strokes, including irregular paths, distant
endpoints, verticals, both diagonals, 30°/45°, zoom, and pressure. Confirm palm
rejection and restoration of the saved map after closing the app.

## Release 2 data compatibility

Document version 2 adds erasure sweeps and optional texture tags. Original
Pencil samples and endpoint anchors are preserved. Release 1 documents decode
without the new metadata and are backed up before editing. Release 1 apps must
not be used to reopen version 2 documents.

Style reference: https://www.wistedt.net/tutorials/tutorial-isometric-dungeon-map/
