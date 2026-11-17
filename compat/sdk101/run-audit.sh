#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Linux-only reproduction. Old-source regressions remain failures (exit 8).
set -euo pipefail
if [[ $# != 1 ]]; then
  echo "Usage: $0 NEW_EMPTY_WORK_DIRECTORY" >&2
  exit 2
fi
harness_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p -- "$1"
audit_root=$(cd -- "$1" && pwd)
if [[ -n "$(ls -A -- "$audit_root")" ]]; then
  echo "Refusing nonempty audit directory: $audit_root" >&2
  exit 2
fi
for tool in git cmake ninja conan python3; do command -v "$tool" >/dev/null; done
export CONAN_HOME="$audit_root/conan"
checkout_exact() {
  local url=$1 sha=$2 path=$3
  git init -q "$path"
  git -C "$path" remote add origin "$url"
  git -C "$path" fetch --depth 1 origin "$sha"
  git -C "$path" checkout -q --detach FETCH_HEAD
  [[ $(git -C "$path" rev-parse HEAD) == "$sha" ]]
}
checkout_exact https://github.com/PlotJuggler/plotjuggler_sdk.git \
  ffd749ab343c3211b5100f124f6c873667b82629 "$audit_root/sdk"
checkout_exact https://github.com/PlotJuggler/pj-official-plugins.git \
  5b6cc5c1e55afe4695e5ac58ef5f835bcc52e5a9 "$audit_root/upstream"
for entry in host:7ed9067d003fdf8f15decf5995651488d8bb937f native:ba6ee417d91a01aae778a0ec3a4443a024671123; do
  name=${entry%%:*}; sha=${entry#*:}
  git -C "$audit_root/upstream" fetch --depth 1 origin "$sha"
  git -C "$audit_root/upstream" worktree add --detach "$audit_root/$name" "$sha"
done
checkout_exact https://github.com/reliable-ly0411/PlotJuggler-zh-CN.git \
  1613eaec28e7c4aee13f7efc72f5e2b2d73a35ae "$audit_root/host-source"
patch_dir="$audit_root/host-source/packaging/localization/plugin-patches"
python3 - "$patch_dir" <<'PY'
import hashlib, pathlib, sys
p = pathlib.Path(sys.argv[1])
for name, expected in {
    'csv-loader.patch': '0f0b6ceaca36e914d8beb458156aeb6c07e87ebe5668d517b1f8d1e69597a442',
    'pj_display_language.hpp': 'ecaa306b2cfe29940ed0d418e72739aef3d4d019dd1a01f212b6ac937f5badae',
}.items():
    assert hashlib.sha256((p / name).read_bytes()).hexdigest() == expected, name
PY
git -C "$audit_root/native" apply --check "$patch_dir/csv-loader.patch"
git -C "$audit_root/native" apply "$patch_dir/csv-loader.patch"
cp "$patch_dir/pj_display_language.hpp" "$audit_root/native/pj_display_language.hpp"
checkout_exact https://github.com/HowardHinnant/date.git \
  f94b8f36c6180be0021876c4a397a054fe50c6f2 "$audit_root/date"
checkout_exact https://github.com/mreineck/pocketfft.git \
  bb87ca50df0478415a12d9011dc374eeed4e9d93 "$audit_root/pocketfft"
cmake -S "$audit_root/date" -B "$audit_root/date-build" -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$audit_root/prefix" -DBUILD_TZ_LIB=OFF -DBUILD_TESTING=OFF
cmake --install "$audit_root/date-build"
mkdir -p "$audit_root/prefix/lib/cmake/pocketfft"
python3 - "$audit_root" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
# The official pocketfft recipe uses this source revision with its worker pool disabled.
(p / 'prefix/lib/cmake/pocketfft/pocketfftConfig.cmake').write_text(
    'add_library(pocketfft::pocketfft INTERFACE IMPORTED)\n'
    'set_target_properties(pocketfft::pocketfft PROPERTIES '
    'INTERFACE_INCLUDE_DIRECTORIES "' + (p / 'pocketfft').as_posix() + '" '
    'INTERFACE_COMPILE_DEFINITIONS POCKETFFT_NO_MULTITHREADING)\n')
PY
conan profile detect
conan install "$audit_root/sdk" -of "$audit_root/deps" -s build_type=Release \
  -s compiler.cppstd=20 -o with_tests=True \
  -c tools.cmake.cmaketoolchain:generator=Ninja --build=missing
result=0
for snapshot in upstream host native; do
  plugins=data_load_csv
  if [[ $snapshot == upstream ]]; then
    plugins='data_load_csv;parser_json;toolbox_fft;toolbox_quaternion;data_stream_dummy;data_load_3d'
  fi
  cmake -S "$harness_dir" -B "$audit_root/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$audit_root/deps/conan_toolchain.cmake" \
    -DCMAKE_PREFIX_PATH="$audit_root/prefix" -DSDK_SOURCE="$audit_root/sdk" \
    -DPLUGIN_SOURCE="$audit_root/$snapshot" -DREFERENCE_SOURCE="$audit_root/upstream" \
    -DCSV_PATH_TEST_SOURCE="$audit_root/native/data_load_csv/tests/csv_file_paths_test.cpp" \
    -DAUDIT_PLUGINS="$plugins" > "$audit_root/configure-$snapshot.log" 2>&1
  cmake --build "$audit_root/build" --parallel 2 > "$audit_root/build-$snapshot.log" 2>&1
  status=0
  ctest --test-dir "$audit_root/build" --output-on-failure -V \
    > "$audit_root/ctest-$snapshot.log" 2>&1 || status=$?
  printf '%s\t%s\n' "$snapshot" "$status" >> "$audit_root/ctest-status.tsv"
  cp "$audit_root/build/Testing/Temporary/LastTest.log" "$audit_root/lasttest-$snapshot.log"
  if [[ $status != 0 ]]; then result=$status; fi
  echo "$snapshot: CTest exit $status; see $audit_root/ctest-$snapshot.log"
done
# Deliberately do not relabel regressions in the historical product pins as passes.
exit "$result"
