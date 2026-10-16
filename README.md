# IsoBuild

A native isometric drawing app for iPad and Apple Pencil. Release 2: version 0.2.0,
build 3. See [RELEASE_NOTES.md](RELEASE_NOTES.md).
The interface currently runs in Spanish. No accounts, external dependencies,
or network services are required.

## Project language

Source identifiers, comments, documentation, build scripts, and filenames use
English. Interface strings use English keys through `AppStrings.text` and live
in `Resources/en.lproj/Localizable.strings` and
`Resources/es.lproj/Localizable.strings`. The prototype explicitly selects the
Spanish bundle regardless of the device language. See `AGENTS.md` for project
conventions and `DECISIONS.md` for confirmed requirements.

## License and credits

Copyright © 2026 **gsanz.dev**. GNU GPL version 3 only, with the notice-preservation
term in [ATTRIBUTION.md](ATTRIBUTION.md). The full license is in [LICENSE](LICENSE);
[LICENSING.md](LICENSING.md) explains how it applies.

Distributed derivative versions must provide their corresponding source under
GPLv3 and preserve applicable notices in the app. Commercial use and private
modifications are allowed.

The **Credits and license** information button opens **About**, which displays
the gsanz.dev notice, legal texts, and an option to save or share the source for
that build. Each build generates and bundles its source ZIP automatically.
User-created maps are not subject to GPL merely because they were drawn here.

## Open and install on iPad

1. Open `IsoBuild.xcodeproj` in Xcode and select the **IsoBuild** scheme.
2. Add your Apple account in **Xcode → Settings → Apple Accounts**.
3. Select your **Team** in **IsoBuild → Signing & Capabilities**. Keep automatic
   signing enabled. Replace `net.gonzalo.IsoBuild` with your own identifier if
   the existing identifier is unavailable.
4. Connect the iPad to your Mac, unlock it, and accept the trust prompt if shown.
5. Enable **Developer Mode** on the iPad when required by Xcode.
6. Select the iPad as the run destination and click **Run** (⌘R).

The minimum deployment target is iPadOS 26.0, including the requested 26.6.
The development build must be signed with your Team before installation.
The unsigned verification build is not an installer.

Apple documentation: [running on a device](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
and [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

## Drawing

- **Guided:** start near a dot and drag toward another. Eligible destinations
  on the two diagonals and vertical axis are highlighted. Releasing near a
  valid destination connects the endpoint; releasing farther away keeps it raw.
- **Freehand:** draw curves, cracks, and details without snapping.
- Each Pencil contact creates one stroke. Crossing intermediate dots does not
  split or adjust it.
- Endpoint corrections fade locally. Original Pencil samples and the middle
  of the stroke remain unchanged, without straightening or artificial wobble.
- Choose one of three fixed widths. Enable **Pressure-sensitive width** in
  **Settings** to apply pressure to new strokes. Existing strokes keep their width.
- **Sketch pencil** draws gray drafts; **Fiber pen** draws black final marks
  above the sketch. Both share three widths and optional pressure sensitivity.
- Double-tap the Apple Pencil barrel to alternate between the last two distinct
  tools, initially fiber and eraser. Tool settings are preserved. Enable
  double-tap in iPad settings; taps during a stroke or fill are ignored.
- Erasing removes only the covered area. Choose **Sketch eraser** for gray
  pencil, or **Fiber eraser (everything)** for pencil, fiber, and textures.
  Three sizes are available; the circle shows the actual area. Each complete
  eraser gesture is one undo action. Undo is also available in the bottom bar.
- **Texture fill:** choose stone, brick, wood, or tiles, then tap inside a closed
  area with the Pencil. Visible pencil/fiber outlines form boundaries; guide
  dots and previous textures do not. Enclosed holes stay empty. A second fill
  replaces the texture in that area. Marks are monochrome, slightly irregular
  vector strokes aligned to the map's 30°/45° grid.
- Use two fingers to pan and zoom. The framing button fits the drawing.
- Hide the dot grid without disabling guided mode.
- Choose 30°/45° and grid spacing in **Settings before drawing**. To change them
  later, erase or undo all strokes until the map is empty.

A single map is saved locally after each action. Release 1 maps remain readable
and their original file is backed up locally before editing. There is no map gallery or
new-map button yet. Undo/redo retains up to 100 actions in the current session;
its history is not restored after closing the app.

**Export PNG** shares the entire drawing on white, without dots, with a maximum
longest side of 4096 pixels. The editable map stays inside the app; the exported
PNG is an image.

## Verification

```sh
swift test
xcodebuild -project IsoBuild.xcodeproj -scheme IsoBuild \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The Swift package tests geometry, snapping, sample/pressure preservation,
selective partial erasure, release 1 loading, flood fill, texture generation,
and persistence. The app compiles the same core files without package downloads.

Release 2 verification uses 16 core tests and opt-in native rendering checks
on an iPad Air 11-inch (M4) simulator. Native checks validate pixel erasure,
overlapping marks, enclosed holes, opened outlines, undo/redo, persistence,
Pencil interaction registration, and tool switching with preserved settings.
Run a Debug simulator build with `--release2-preview` to execute them using
temporary storage and display all four textures; add `--preview-eraser` for
the eraser controls. The report is `tmp/release2-checks.json` inside the app
container. This mode never opens the normal saved map. Interactive gestures
and physical Pencil pressure still require verification on the iPad.

The generated project is ready to open. After adding or removing Swift files
or language resources, regenerate it with `python3 Tools/make_project.py`.
Existing build settings, including the signing Team, and the shared scheme are
preserved. The generator explicitly sets the app version and build number.

Mouse drawing is available in the simulator for interface checks. On a physical
iPad only Apple Pencil draws; fingers navigate the canvas.

## Pending Pencil Pro checks

Builds and automated tests do not validate latency, physical pressure, or how
endpoint connections feel. On the iPad, check:

1. An irregular stroke between dots: endpoints should connect naturally.
2. A stroke released far from its destination: its path should be preserved.
3. Verticals and both diagonals at different zoom levels.
4. Freehand mode, pressure enabled/disabled, and palm rejection.
5. Erasing, undo/redo, closing and reopening the app, and PNG export.
6. Pencil double-tap alternates the last two tools and respects the system's
   disabled setting; selecting a third tool updates the pair.

## Files

- `AGENTS.md`: project language and maintenance conventions.
- `DECISIONS.md`: confirmed requirements and prototype scope.
- `RELEASE_NOTES.md`: release 2 changes and usage.
- `Sources/IsoCore`: grid geometry, strokes, and serializable documents.
- `Sources/IsoBuild`: interface, Pencil input, rendering, and persistence.
- `Resources`: English keys and Spanish interface translations.
- `Tests/IsoCoreTests`: core tests.

Style reference: [Wistedt's tutorial](https://www.wistedt.net/tutorials/tutorial-isometric-dungeon-map/).
