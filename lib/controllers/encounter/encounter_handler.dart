import '../../models/pokemon.dart';

/// How an encounter ended, as decided by the capture sequence.
enum EncounterOutcome { caught, fled }

/// ─── CONTRATO DE ENCUENTRO (punto de enganche para la captura) ───────────
///
/// `GameController` calls [handleEncounter] after Ash touches a smoke AND the
/// random Pokémon has been resolved from PokeAPI. While the returned Future is
/// pending the game stays paused (Ash cannot move, no other encounter can
/// start). When it completes, the smoke is consumed and the game resumes.
///
/// The Poké Ball throw / capture animation is NOT part of this deliverable:
/// implement this interface (e.g. push a capture screen or overlay and
/// complete with its result) and register it in `app/dependencies.dart`,
/// replacing `StubEncounterHandler`. Nothing else needs to change.
///
/// Implementations should not throw; if they do, the error is reported and
/// the encounter is treated as [EncounterOutcome.fled] so the game never
/// stays frozen.
abstract interface class EncounterHandler {
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon);
}
