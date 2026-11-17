# SDK 1.0.1 focused compatibility audit

This opt-in Linux audit builds selected official plugins and their actual tests,
without building the PlotJuggler application or the full plugin collection.
It changes no product pin, manifest/version, release recipe, or default build.
See [REPORT.md](REPORT.md) for the source identities, measured results and limits;
[inventory.json](inventory.json) records the host's distinct native source,
registry and Wasm pins.

Prerequisites: a C++20 compiler (tested GCC14.2 on Debian13 x86_64), Python3,
CMake>=3.22, Ninja, Conan2, git, Internet access and ELF inspection tools. Install
these in an isolated environment if needed. No Qt is required: the Log Widget
part tests its Qt-free loader/store/filter only.

Run from any directory with a new, empty writable directory:

```sh
/path/to/pj-official-plugins/compat/sdk101/run-audit.sh /tmp/pj-sdk101-audit
```

The script checks out exact SDK, official-plugin, host patch and dependency source
SHAs; verifies the existing patch/helper hashes; uses an isolated Conan cache;
and builds three source snapshots sequentially. It writes configure/build/CTest
logs and `ctest-status.tsv`. It continues after CTest failures to collect all
three snapshots, but returns failure when any snapshot fails. The two old source
snapshots are known to fail the newly added upstream regression tests. Those are
real failures, not tests marked `WILL_FAIL`, expected-failure passes, or waived
release gates. Upstream should exit0, host-pin and native-pin CTest should exit8
as documented in the report. A build/configuration failure stops immediately.

The CMake harness can also use already prepared exact checkouts and the SDK's
Conan dependency toolchain. Required cache paths are `SDK_SOURCE`, `PLUGIN_SOURCE`,
`REFERENCE_SOURCE` (the fixed upstream source supplying newer regression tests),
and `CSV_PATH_TEST_SOURCE` (the host-patched CSV path test). `AUDIT_PLUGINS` selects
the small subset; it defaults to CSV, JSON, FFT, Quaternion, Dummy Stream and3D.
`CMAKE_PREFIX_PATH` supplies header-only date3.0.4 and the pinned pocketfft config.
The script shows the complete invocation and dependency setup.

All tests are compiled directly from their respective checked-out source trees;
licenses and histories remain with those sources. The historical native CSV
snapshot applies only the already pinned host patch and helper. No private logs
or production data are required. There is no workflow trigger, publishing step,
registry edit, or repository push in this audit.

The source-only checks can be repeated against the prepared upstream checkout:

```sh
cd /tmp/pj-sdk101-audit/upstream
python3 scripts/bump_core_version.py --check
python3 -m unittest discover -s scripts/tests
python3 scripts/check_sdk_feature_floors.py \
  --sdk-floors /tmp/pj-sdk101-audit/sdk/pj_base/feature_floors.json
```

The measured report comes from the same harness/test sources and command stages
run in the isolated audit workspace. The packaged orchestration script was syntax
checked and its portable CMake paths were independently configured; the complete
fresh-directory script was not rerun after packaging. No test result is claimed
for that unexecuted orchestration rerun.
