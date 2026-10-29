#!/bin/zsh
set -eu
NEW=${0:A:h:h}
RESTRUCTURE=$NEW/.build/check
mkdir -p $RESTRUCTURE/tmp
OUT=$RESTRUCTURE/build/swiftc
export TMPDIR=$RESTRUCTURE/tmp
FRAMEWORKS=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks
LIBS=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib
PRIVATE=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks
FLAGS=(-Xfrontend -disable-sandbox -swift-version 6 -warnings-as-errors -module-cache-path $RESTRUCTURE/build/modcache)
GRDB_SRC=${GRDB_SRC:-$RESTRUCTURE/build/grdb}
mkdir -p $OUT
typeset -A sandbox_probe
sandbox_probe[testFileStoreRoundTripAndFailures]=atomic
sandbox_probe[testKeychainStoreRoundTripsAndForgets]=keychain
sandbox_probe[testArtifactStoreWritesAtomicallyWithSafeName]=atomic
sandbox_probe[testProposeFileWritesThroughArtifactStoreAtomically]=atomic
cd $NEW
names=(Core Design Shell Storage Hub Calculation Mail Assistant Airtable ClickUp Google Sevdesk Clockodo Shipping)
if (( $# )); then names=(${@:#App}); fi
needs_grdb=0
for module in $names; do [[ $module == Storage || $module == Hub || $module == Calculation || $module == Mail || $module == Assistant || $module == Google ]] && needs_grdb=1; done
if (( needs_grdb )); then
  if [[ ! -d $GRDB_SRC/GRDB ]]; then
    CLONE=$TMPDIR/grdb-clone
    rm -rf $CLONE
    git clone --template= --depth 1 --branch v6.29.3 https://github.com/groue/GRDB.swift $CLONE
    rm -rf $CLONE/.git
    mv $CLONE $GRDB_SRC
  fi
  if [[ ! -f $OUT/libGRDB.a ]]; then
    swiftc -Xfrontend -disable-sandbox -swift-version 5 -module-cache-path $RESTRUCTURE/build/modcache \
      -DSQLITE_ENABLE_FTS5 -DSWIFT_PACKAGE -Onone -parse-as-library -emit-module -emit-library -static \
      -module-name GRDB -I $GRDB_SRC/Sources/CSQLite -emit-module-path $OUT/GRDB.swiftmodule -o $OUT/libGRDB.a \
      $(find $GRDB_SRC/GRDB -name '*.swift' | sort)
  fi
fi
typeset -A probe_ok
build_probe() {
  local name=$1 source=$2
  if [[ ! -x $OUT/${name}_probe ]]; then
    print -r -- $source > $OUT/${name}_probe.swift
    swiftc -Xfrontend -disable-sandbox -module-cache-path $RESTRUCTURE/build/modcache $OUT/${name}_probe.swift -o $OUT/${name}_probe 2> /dev/null
  fi
  probe_ok[$name]=0
  if $OUT/${name}_probe > /dev/null 2>&1; then probe_ok[$name]=1; fi
}
build_probe atomic 'import Foundation
let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true)
let file = directory.appendingPathComponent(UUID().uuidString)
do { try Data("x".utf8).write(to: file, options: .atomic); try? FileManager.default.removeItem(at: file); exit(0) } catch { exit(1) }'
build_probe keychain 'import Foundation
import Security
let name = "alfa.probe." + UUID().uuidString
let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: name, kSecAttrAccount: "a"]
let added = SecItemAdd(query.merging([kSecValueData: Data("v".utf8)]) { _, new in new } as CFDictionary, nil)
_ = SecItemDelete(query as CFDictionary)
exit(added == errSecSuccess ? 0 : 1)'
for module in $names; do
  source_dir=Sources/$module
  [[ -d $source_dir ]] || source_dir=Sources/Integrations/$module
  swiftc $FLAGS -parse-as-library -enable-testing -emit-module -emit-library -static \
    -module-name $module -I $OUT -I $GRDB_SRC/Sources/CSQLite -emit-module-path $OUT/$module.swiftmodule -o $OUT/lib$module.a \
    $(find $source_dir -name '*.swift' | sort)
done
for module in $names; do
  test_class=${module}Tests
  mkdir -p $OUT/$module
  print -r -- "import XCTest
let suite = XCTestSuite(forTestCaseClass: $test_class.self)
suite.run()
exit(suite.testRun!.hasSucceeded ? 0 : 1)" > $OUT/$module/main.swift
  libs=($OUT/lib*.a(N))
  swiftc $FLAGS -I $OUT -I $GRDB_SRC/Sources/CSQLite -lsqlite3 -I $LIBS -L $LIBS -F $FRAMEWORKS -Xlinker -rpath -Xlinker $FRAMEWORKS -Xlinker -rpath -Xlinker $LIBS -Xlinker -rpath -Xlinker $PRIVATE \
    -o $OUT/run_$module Tests/$test_class/$test_class.swift $OUT/$module/main.swift $libs
  log=$OUT/$module/test.log
  set +e
  $OUT/run_$module > $log 2>&1
  exit_code=$?
  set -e
  tail -n 4 $log
  started=$(grep -c "^Test Case '.*' started" $log || true)
  ended=$(grep -cE "^Test Case '.*' (passed|failed)" $log || true)
  if (( exit_code > 1 )) || (( started != ended )); then
    echo "check_modules: $module test run crashed"
    exit 1
  fi
  if (( exit_code != 0 )); then
    failed=(${(f)"$(sed -n "s/^Test Case '-\[run_$module\.$test_class \(.*\)\]' failed.*/\1/p" $log)"})
    if (( ${#failed} == 0 )); then
      echo "check_modules: $module tests failed"
      exit 1
    fi
    skipped=()
    for name in $failed; do
      kind=${sandbox_probe[$name]-}
      if [[ -z $kind ]] || (( ${probe_ok[$kind]} )); then
        echo "check_modules: $module test failed: $name"
        exit 1
      fi
      skipped+=($name)
    done
    echo "check_modules: $module sandbox-skipped: $skipped"
  fi
done
if (( $# == 0 )) || (( ${@[(Ie)App]} )); then
  swiftc $FLAGS -parse-as-library -typecheck -I $OUT -I $GRDB_SRC/Sources/CSQLite $(find App -name '*.swift' | sort)
  echo "check_modules: App typechecked"
fi
echo "check_modules: all passed"
