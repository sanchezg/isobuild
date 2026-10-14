# IsoBuild

A native isometric drawing prototype for iPad and Apple Pencil.
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
- Black ink and an opaque gray marker are available. The eraser removes whole
  strokes; each eraser gesture is one undo action.
- Use two fingers to pan and zoom. The framing button fits the drawing.
- Hide the dot grid without disabling guided mode.
- Choose 30°/45° and grid spacing in **Settings before drawing**. To change them
  later, erase or undo all strokes until the map is empty.

A single map is saved locally after each action. There is no map gallery or
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

The Swift package tests 30°/45° geometry, destination selection, snapping
tolerance, preservation of the sampled path and pressure, erasing, and document
serialization. The app compiles the same core files directly, without package
downloads.

Verified on October 14, 2026 with Xcode 27.0: device and simulator builds,
eight passing core tests, and a visible launch on an iPad Air 11-inch (M4)
simulator running iPadOS 26.5. Screenshots are in `Artifacts/ipad-prototype.png`
and `Artifacts/ipad-credits.png`. Interactive drawing gestures and physical
Apple Pencil input still require verification.

The generated project is ready to open. After adding or removing Swift files
or language resources, regenerate it with `python3 Tools/make_project.py`.
This resets project settings, including any manually selected signing Team.

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

## Files

- `AGENTS.md`: project language and maintenance conventions.
- `DECISIONS.md`: confirmed requirements and prototype scope.
- `Sources/IsoCore`: grid geometry, strokes, and serializable documents.
- `Sources/IsoBuild`: interface, Pencil input, rendering, and persistence.
- `Resources`: English keys and Spanish interface translations.
- `Tests/IsoCoreTests`: core tests.

Style reference: [Wistedt's tutorial](https://www.wistedt.net/tutorials/tutorial-isometric-dungeon-map/).
