import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';

/// Dieser Linux-Dev-Host hat nur `libsqlite3.so.0` (kein `libsqlite3-dev`-
/// Paket mit dem unversionierten Symlink, den `package:sqlite3` auf Linux
/// standardmäßig sucht) — identischer Fix wie in
/// `test/sqlite_ffi_test_setup.dart`. Muss eine Top-Level-Funktion sein, da
/// sqflite_common_ffi sie über einen Isolate verschickt.
DynamicLibrary _openLinuxSystemSqlite3() =>
    DynamicLibrary.open('libsqlite3.so.0');

/// Android/iOS nutzen `sqflite` nativ (kein FFI nötig). Für Desktop-Builds
/// (aktuell nur zum lokalen Testen ohne Emulator relevant) muss
/// `databaseFactory` explizit auf `sqflite_common_ffi` umgestellt werden.
void initializeSqliteForDesktopIfNeeded() {
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    return;
  }
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openLinuxSystemSqlite3);
  }
  sqfliteFfiInit();
  // databaseFactoryFfi delegiert an einen separaten Isolate, der die
  // open.overrideFor()-Registrierung aus diesem Isolate nicht sieht (siehe
  // test/sqlite_ffi_test_setup.dart). databaseFactoryFfiNoIsolate laeuft im
  // selben Isolate.
  databaseFactory = databaseFactoryFfiNoIsolate;
}
