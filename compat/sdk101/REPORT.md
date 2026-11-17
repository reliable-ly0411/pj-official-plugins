# Official plugins: SDK 1.0.1 compatibility audit

Snapshot checked on 2026-11-17 in an isolated Debian 13 x86_64 cloud workspace. No host build, product pin change, merge, release, tag update, force push, or PR creation was performed.

## Exact source identities

- SDK: `ffd749ab343c3211b5100f124f6c873667b82629`; source VERSION `1.0.1`. Upstream HEAD and the peeled v1.0.1 tag agree; annotated tag object `b0e73ef290b1ab590041cde047b7ceadda4360c4` peels to this commit.
- Official fork `main`: `37e1bde18b8a425b9b64d7fe54c165464942b5eb`, SDK_VERSION `0.38.0-dev.3`.
- Official upstream `main`: `5b6cc5c1e55afe4695e5ac58ef5f835bcc52e5a9`, SDK_VERSION `1.0.0`; fork is 70 commits behind, with zero fork-only commits. This audit did not move fork main.
- Chinese host stable and development refs both resolved to `1613eaec28e7c4aee13f7efc72f5e2b2d73a35ae`. Its mirror main was `8800f77ef1ca5ace1d7819d29804e6b209c579a1`. No host files were changed.
- Host Wasm official-source pin (`cmake/PjWasmDependencies.cmake`): upstream `7ed9067d003fdf8f15decf5995651488d8bb937f`, SDK_VERSION `1.0.0-dev.2`.
- Host baseline's `official_plugin_source_sync` points to the translation branch `7f089a2271600c632f24c6f082dabec2d8295704`, whose upstream base is that `7ed9067...` pin. This is not a replacement for the native binary/source locks.
- Host native CSV rebuild: `ba6ee417d91a01aae778a0ec3a4443a024671123`, `data_load_csv/v1.0.7`, SDK `0.34.1`, current `csv-loader.patch` SHA256 `0f0b6ceaca36e914d8beb458156aeb6c07e87ebe5668d517b1f8d1e69597a442` plus the pinned display-language helper.
- Host native source-lock also fixes protobuf 1.2.0 (`c843cb210af16cb5832cef85c125513c94f65d50`, SDK0.32.0), assistant 0.2.0 (`ba245df89fb26e7905890654173fe289794410a1`, SDK0.34.1), transform editor 1.0.4 and WebRTC 1.0.1 (`2bc991cae2dba7f9f1468dbf8dd72d89797699bc`, SDK0.20.0), MCAP 1.3.0 (`ffa967324aa03b7d076f91e2bf93aff92ebfbda0`, SDK0.34.1). These locks remain unchanged.

[inventory.json](inventory.json) records these source-lock records and all 20 native official entries. There are 18 official core plugins on Windows, plus APBIN; Linux adds the assistant and ROS2 streamer. FFT is an additional feedback-test plugin, not one of those 18 default entries. The native registry is pinned to historical released archive hashes; it does not follow either repository's main.

## Requested upstream changes

| Change | Exact commit | Relevance |
|---|---|---|
| #369 Windows Chinese CSV paths | `4d223f6948fcabe18ad07afcd453a0f84d823de8` | Converts the host UTF-8 path to a filesystem u8 path in both preview and import. Present in Wasm-source pin 7ed9067 and current upstream; absent from fork main 37e1bde. Native CSV has its own equivalent path repair plus stronger synthetic path ABI tests in the pinned host patch. |
| #391 incremental log append | `66d6e544c74b9499f31527b7a79ea8ab3c148770` | Log Widget 1.0.1 changes count/probe/undelivered-sample bookkeeping and eviction accounting, with targeted tests. Missing from 7ed9067's Log Widget 1.0.0. Log Widget is absent from the native registry lock; introducing it needs its own host/Qt acceptance. |
| #397 reject CSV imports retaining no rows | `bae7e986a7bae7a9ac7d029fcd806e2b9c8c892b` | CSV 1.0.9 returns a failure when all rows were skipped, so the host can retain an old dataset on failed reload; also corrects the skip prompt. Absent from both current native CSV1.0.7 lock and Wasm-source CSV1.0.8 pin. |
| #389 SDK1.0.0 migration | `71511521dea2cbd615908c68dcfcf0f707e92719` | Changes SDK_VERSION dev.2 → 1.0.0, raises only NavMap's MeshMap contract floor to released1.0.0, updates exporter release identity, and documents CSV's path fix. It is not a blanket min_sdk_required increase or a change to the host's existing pins. |

## Build and dependency scope

The isolated [`CMakeLists.txt`](CMakeLists.txt) calls only selected plugin subdirectories, avoiding the repository's aggregate build. All selected plugins and SDK are compiled with GCC14.2, C++20, Release, warnings fatal. The dependency toolchain is the source-SDK Conan dependency resolution, with JSON3.12.0, fmt12.1.0, fast_float8.1.0 and GTest1.17.0. CSV uses Howard Hinnant date3.0.4 exact source `f94b8f36c6180be0021876c4a397a054fe50c6f2`, with timezone library OFF (header-only parsing). FFT uses pocketfft `bb87ca50df0478415a12d9011dc374eeed4e9d93`, the exact source of Conan `0.0.0.cci.20240801`, with multithreading disabled as in the official recipe. Dependency and plugin licenses stay in their source trees.

The six-plugin subset is CSV, JSON, FFT, Quaternion, Dummy Stream, and PCD/PLY 3D loader. Log Widget's Qt-free loader/store/filter is built separately against the real SDK widget-host bridge; it is not a full widget DSO build. The QWidget target explicitly requires Qt6.12.x, which is unavailable in this cloud image. Quaternion's own functional test is disabled upstream with `if(FALSE...)` because its mock retains an obsolete host callback signature; a successful library build must not be described as a functional-test pass.

## Results

Upstream `5b6cc5c...` built six shared libraries successfully with warnings fatal and all six ELF export checks passed (required exports present, zero GNU UNIQUE leaks). 11 CTest entries passed, comprising 218 gtests. No production source adaptation was required for this selected subset. Logs: `official-build-upstream.log`, `official-build-extra-upstream.log`, `official-ctest-upstream.log`.

| Executed upstream test | Result |
|---|---|
| Log loader/store/filter, real widget-host bridge and fake host | 39/39 PASS |
| CSV path tests through real source/dialog DSO (ASCII, Chinese dir/name, Traditional Chinese+emoji, missing-file errors) | 12/12 PASS on Linux |
| CSV parser | 56/56 PASS |
| CSV1.0.9 actual DSO all-rows-skipped failure and mixed-row prompt | 2/2 PASS |
| JSON actual DSO / dialog tests | 29/29 and 6/6 PASS |
| FFT actual DSO and algorithm tests | 24/24 PASS |
| 3D cloud / PCD / PLY / helpers | 13/13, 19/19, 15/15, 3/3 PASS |
| Quaternion and Dummy Stream | Compilation/ELF checks PASS; functional tests not executed |

The JSON, FFT, Quaternion, Dummy Stream, and 3D directories differ between host Wasm pin7ed9067 and upstream5b6cc5c only by the latter’s new `wasm.cmake`. Thus the tested native source/test bytes for those five plugins are identical to the host source pin; this does not prove a WebAssembly build.

The host Wasm-source pin `7ed9067...` also built CSV and the Qt-free log core cleanly under SDK1.0.1. Its own CSV parser56/56, path ABI12/12 and original log-core29/29 tests passed. Replaying the new upstream regressions against that older implementation produced two failing CTest entries: both CSV source tests failed, and8/39 new log-core tests failed (31 passed). These failures reproduce the missing #397 and #391 fixes; they are not SDK compile failures. Logs: `official-build-host.log`, `official-ctest-host.log`.

The failing log tests are `OlderHostCapKeepsWhatArrivedAndReportsIt`, `UndeliverableSampleStillAppendsIncrementally`, `UndeliverableSampleInTheTailIsCountedAsMissing`, `UndeliverableFirstSampleEvictedWithTheCountUnchanged`, `EvictedUndeliverableSamplesLeaveTheMissingCount`, `HostDroppingEverythingClearsTheMissingCount`, `EvictionWithAnUndeliverableSampleInTheBufferStaysExact`, and `EvictionSplittingEqualTimesStillSeesALateInsert` (all in `LogLoaderTest`). Both failing CSV tests are `CsvSourceTest.ImportWithEveryRowSkippedFails` and `CsvSourceTest.RowsSkippedPromptDoesNotBlameColumnCountForBadTimestamps`.

The exact native CSV source-lock (`ba6ee417...` + pinned host patch/helper) built cleanly under SDK1.0.1 with its ELF export guard. Existing parser49/49, path ABI12/12, and12 runtime-language tests in each of five processes (`zh_CN`, `zh_TW`, `en_US`, unknown, empty) passed:121 existing checks. Both newly supplied #397 CSV regressions still failed. CTest:7 entries passed,1 failed. Logs: `official-build-native-csv.log`, `official-ctest-native-csv.log`. No source adaptation was required for this native CSV build, and no product lock or old artifact was replaced.

The old-baseline failures remain failures in the reproduction script, which returns a nonzero exit rather than weakening a gate. No unexecuted platform or test may be inferred to pass.

- Upstream SDK_VERSION coherence check: PASS (declared build version1.0.0; explicit audit uses sourceSDK1.0.1).
- Upstream Python script tests: 99 total, 98 passed, 1 skipped.
- SDK feature-floor static scan of all35 upstream plugins against SDK1.0.1 table: PASS. This is declaration/source analysis, not runtime compatibility proof.

## Remaining limits and integration recommendations

- The18/20 native official-plugin set was not built in full. In particular MCAP, Parquet, ULog, MP4, Foxglove/PJ/WebRTC streams, ROS/Protobuf/DataTamer/Arrow parsers, Transform Editor, Mosaico, assistant and ROS2 were not compiled or functionally exercised in this audit. Static feature-floor scanning of these sources is not a compile/runtime pass.
- No Windows, macOS, ARM, WebAssembly, full application, final package, real GUI, Qt Log Widget DSO, clean-system installation, network streaming, ROS2, Arrow/Parquet/video, official-plugin sanitizer run, or heavy-plugin build was run. No previous platform result is reused as this audit's evidence.
- Keep native source locks, rebuilt localized bytes, upstream registry hashes, and Wasm source pins separate. A fork fast-forward alone changes none of the consumed artifacts.
- Prefer the actual released CSV1.0.9 source including #369/#397, preserving the fork's display-only localization and path ABI regressions; do not blindly reapply the already-upstream path hunks.
- Adopt Log Widget1.0.1 only together with compatible host count semantics and Qt6.12.x tests. Core tests validate the SDK bridge and algorithm but cannot replace actual widget loading and GUI acceptance.
- SDK1.0.1 is a source build candidate, not a guarantee for every old prebuilt native archive or every localization patch. Keep the native archive/provenance acceptance gates and rebuild/test each affected plugin before changing product pins.
