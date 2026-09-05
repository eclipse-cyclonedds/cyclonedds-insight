# Repository guide for coding agents

These instructions apply throughout this repository.

## Project and architecture

CycloneDDS Insight is a desktop DDS inspection and testing application built with
Python, PySide6, Qt Quick/QML, and CycloneDDS Python bindings. It supports Linux,
macOS, and Windows. There is no web frontend or installable Python project package.

| Area | Responsibility |
| --- | --- |
| `src/main.py` | Application startup, environment setup, QML context properties/type registration, worker wiring, shutdown |
| `src/dds_access/` | Discovery, domain participants, DDS readers/writers, QoS, IDL compilation, and interoperability datatypes |
| `src/models/` | Qt item/list/table models, proxies, and feature controllers exposed to QML |
| `src/module_handler.py` | Imported/discovered IDL types, dynamic module loading, and editable data-tree construction |
| `src/views/` | QML screens, dialogs, reusable controls, icons, and theme constants |
| `src/translations/` | ID-based Qt translation catalogs for languages |
| `src/utils/` | Logging, build metadata fallback, file/system helpers, and QML utilities |
| `src/updater.py`, `src/models/updater_model.py` | Standalone updater entry point and update/download logic |
| `resources.qrc`, `res/`, `main.spec` | Embedded resources, platform assets, and PyInstaller bundle configuration |
| `docs/manual/` | Sphinx/reStructuredText user and installation manuals |
| `.azure/`, `azure-pipelines.yml` | Cross-platform builds, packaging, and tag-triggered releases |

Trace feature changes through the relevant view, model, and DDS/helper code.
Keep DDS operations and data transformation in Python; use QML for presentation,
interaction, and view state. Extend the existing feature model or helper before
introducing another service layer.

## Development commands and environment

Run commands from the repository root. Use the existing `deps/venv` environment
when available. Dependencies are pinned in `requirements.txt`; CycloneDDS and its
Python bindings are built from source under `deps/`, with the bindings installed
in editable mode. Installing `requirements.txt` alone is insufficient.

- Routine development: `bash run.sh` on macOS/Linux or `.\run.bat` in Windows
  Command Prompt. These activate the environment, copy the upstream XSD, compile
  translations, regenerate Qt resources, and launch the app at trace log level.
- Initial native build and packaging: `bash build.sh` or `.\build.bat`. Read the
  script before running it. **`build.sh` starts by deleting `deps/`**, including
  its virtual environment and dependency checkouts; it is not an incremental
  validation command. Its initial `rm -r ./deps &&` can also stop setup when
  `deps/` does not exist. Windows setup assumes fresh dependency directories.
- The scripts require Python, Git, CMake, and a native compiler. Windows installer
  creation additionally requires Inno Setup. Consult `.azure/templates/build-insight.yml`
  for the full build sequence and platform packaging steps.
- CI currently selects Python 3.10. Preserve compatibility with that configured
  baseline unless changing the supported runtime and CI is part of the task.

Source execution needs `CYCLONEDDS_HOME` pointing to
`deps/cyclonedds/build/install`. Packaging also needs `CYCLONEDDS_PYTHON_HOME`
pointing to `deps/cyclonedds-python`. `run.sh` sets `CYCLONEDDS_URI` to the root
`cyclone.xml`; `run.bat` does not set it. Account for this difference when
reproducing discovery/configuration issues. Preserve the early environment setup
before the first CycloneDDS import in the entry points.

## Python and Qt model conventions

- Use four-space indentation, `PascalCase` classes, and the surrounding module's
  naming style. Python methods mix snake_case and Qt-style camelCase; do not rename
  exposed methods just to standardize spelling. Imports generally use `src/` as
  the import root, for example `from models...` and `from dds_access...`.
- Keep existing license/copyright headers. For new source files, follow the
  neighboring header format and `SPDX-License-Identifier: EPL-2.0 OR BSD-3-Clause`.
- Use `from loguru import logger as logging` for application logging. Route
  actionable failures through the existing model error signals and QML error
  center (`rootWindow.showOperationError`, `src/views/errors/`) where applicable.
  Avoid swallowing new failures or reporting success after an operation fails.
- Treat `Signal` signatures, `@Slot` argument/result types, `Property` definitions,
  model roles, context-property names, and registered QML types as shared APIs.
  Update Python and QML consumers together. Register new exposed objects/types in
  the appropriate entry point using the existing `org.eclipse.cyclonedds.insight`
  module where needed.
- For Qt models, pair `beginInsertRows`/`beginRemoveRows`/`beginResetModel` with
  their corresponding end calls around mutations. Emit `dataChanged` with the
  affected roles for updates. Keep role IDs, byte-string `roleNames()`, `data()`,
  and QML delegates consistent; preserve source/proxy index mapping.
- Respect QObject thread ownership. `DdsData` is a singleton moved to a worker
  thread; existing models communicate with it through queued signal connections.
  Send cross-thread results through signals rather than modifying UI models from
  a worker. Keep blocking DDS waits, IDL compilation, and downloads off the UI
  thread.
- Preserve worker lifetime and shutdown paths: stop polling/read loops, wake DDS
  waitsets through their guard conditions, and quit/wait for threads as appropriate.
  Follow `DomainParticipantFactory.get_participant(...)` context-manager usage for
  shared participant lifetime management.
- Preserve DDS wire type names, field types, keys, and annotations in
  `src/dds_access/datatypes/`, including OpenSplice interoperability definitions.
  Do not change them as ordinary naming/style cleanup.

## QML, appearance, and translations

- Follow the existing four-space indentation, `PascalCase.qml` component names,
  camelCase IDs/properties/functions, and versionless Qt imports.
- Reuse `Constants.qml` for theme colors, typography, radii, and spacing, and
  existing components under `elements/`, `icons/`, and `selection_details/`.
  Preserve light/dark mode behavior, layout resizing, and native platform styling.
  `src/views/qmldir` declares the `Constants` singleton.
- Use `qsTrId("section.key")` for UI text. Catalog entries use `<message id="...">`
  in an unnamed context, rather than source-text translation keys. Reuse existing
  IDs when the meaning matches; add or update corresponding entries in all six
  catalogs: `en`, `de`, `nl`, `fr`, `jp`, and `cn`. Keep these existing filename/code
  conventions. Preserve `%1`, `%2`, etc. and the associated `.arg(...)` calls.
- Add new or moved QML files and embedded assets to `resources.qrc`, and update
  resource imports/URLs. The app loads `qrc:/src/views/main.qml`; merely creating a
  QML file on disk does not include it in the running resource bundle.
- Regenerate resources after QML, asset, or translation edits. With the development
  environment active, compile each changed catalog using
  `pyside6-lrelease src/translations/cyclonedds-insight_en.ts` (substitute its
  language), then run `pyside6-rcc resources.qrc -o src/qrc_file.py`. The run scripts
  perform this sequence for every language and prepare the XSD as well.

## Files, persistence, and packaging

- Do not hand-edit or commit generated `src/qrc_file.py`, `src/build_info.py`,
  `*.qm`, or the root `cyclonedds.xsd`. Edit QML/TS/QRC sources; the schema is copied
  from the dependency checkout. Keep `deps/`, `build/`, `dist/`, logs, bytecode,
  and documentation output out of changes. `.gitignore` records these exclusions.
- Preserve existing `QSettings` keys and `QStandardPaths` storage locations.
  Imported IDL and generated Python types live under the application's data
  directory, not in the source tree. Avoid using real saved user data as disposable
  test fixtures.
- Use Qt URL/local-file conversion and platform-aware path handling. Paths such
  as `CycloneDDS Insight` contain spaces. Check both source and frozen execution
  when changing file lookup, subprocesses, native libraries, or IDL compilation;
  frozen execution uses `sys._MEIPASS` and bundled `idlc`/`_idlpy` libraries.
- Keep related changes aligned across `build.sh`, `build.bat`, the Azure build
  template, and `main.spec`. Linux additionally bundles a standalone `Updater`;
  Windows uses `setup.iss`; Debian packaging uses `create_debian_pkg.sh` and
  `res/debian-pkg/`. `setup_dmg.sh` is a separate macOS packaging helper; current
  CI publishes a tarred app bundle.
- Version metadata lives in `src/version.py` and `docs/manual/variables.json`.
  Change versions only as part of a requested version/release change. CI generates
  build metadata, while `utils/build_info_helper.py` supplies development fallbacks.
