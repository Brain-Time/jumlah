import 'dart:ffi';

import 'package:sqlite3/open.dart';

/// Diese Test-Umgebung hat nur `libsqlite3.so.0` installiert (kein
/// `libsqlite3-dev`-Paket mit dem unversionierten Symlink `libsqlite3.so`,
/// den `package:sqlite3` standardmäßig auf Linux sucht). Muss eine
/// Top-Level-Funktion sein, da sqflite_common_ffi sie über einen Isolate
/// verschickt.
DynamicLibrary openLinuxSystemSqlite3() =>
    DynamicLibrary.open('libsqlite3.so.0');

void setUpLinuxSqlite3Fallback() {
  open.overrideFor(OperatingSystem.linux, openLinuxSystemSqlite3);
}
