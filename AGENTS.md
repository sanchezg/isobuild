# Project conventions

- Use English for source identifiers, comments, documentation, filenames,
  developer diagnostics, and build scripts.
- Keep user-facing translations in `Resources/<language>.lproj/Localizable.strings`.
  Use English localization keys in Swift source through `AppStrings.text`.
- Keep the app interface in Spanish until the user requests a language change.
- Preserve GPLv3 and the attribution notices for gsanz.dev.
- When adding or removing Swift files or localized resources, regenerate the
  Xcode project with `python3 Tools/make_project.py`. Preserve existing build
  settings and the shared scheme, including the user's signing Team and run
  configuration. Version/build are explicitly controlled by the generator.
- Each build must package the corresponding source, including localization
  resources and legal files, through `Tools/package_source.py`.
