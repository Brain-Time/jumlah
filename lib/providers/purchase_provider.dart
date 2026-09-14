import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database_helper.dart';

/// Freischalt-Status der Sprachniveaus. Seit der App kostenlos ist
/// (10. September 2026) gibt es **keine Käufe/Freischalt-Codes mehr**:
/// Die Einstiegs-Stufe (A1) ist immer frei, jede weitere Stufe wird durch
/// Abschluss der vorherigen freigeschaltet (`DatabaseHelper.getUnlockedLevels`,
/// siehe `quiz_provider.dart`/`nextLevelAfter`). Dieser Provider hält nur den
/// Snapshot für die UI (z.B. Wörterbuch-Filter) und lädt ihn per
/// [PurchaseNotifier.initialize] bzw. [PurchaseNotifier.refresh].
class PurchaseState {
  const PurchaseState({this.unlockedLevels = const {}});

  /// Freigeschaltete Sprachniveaus (Gruppennamen, z.B. {'A1'}).
  final Set<String> unlockedLevels;

  bool isLevelUnlocked(String group) => unlockedLevels.contains(group);

  PurchaseState copyWith({Set<String>? unlockedLevels}) {
    return PurchaseState(unlockedLevels: unlockedLevels ?? this.unlockedLevels);
  }
}

/// Lädt die freigeschalteten Sprachniveaus aus SQLite (persistiert über die
/// `purchases`-Tabelle) — nur noch als Anzeige-Status, keine Kauf-Logik.
class PurchaseNotifier extends Notifier<PurchaseState> {
  @override
  PurchaseState build() {
    return const PurchaseState();
  }

  /// Muss einmal beim Öffnen eines Screens, der den Freischalt-Status nutzt
  /// (z.B. Wörterbuch), aufgerufen werden.
  Future<void> initialize() async {
    await refresh();
  }

  /// Lädt die freigeschalteten Sprachniveaus neu (z.B. nach einem
  /// Stufen-Abschluss im Quiz).
  Future<void> refresh() async {
    final unlocked = await DatabaseHelper.instance.getUnlockedLevels();
    state = state.copyWith(unlockedLevels: unlocked);
  }
}

final purchaseProvider = NotifierProvider<PurchaseNotifier, PurchaseState>(
  PurchaseNotifier.new,
);
