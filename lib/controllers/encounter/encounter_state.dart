import '../../models/pokemon.dart';
import '../../services/poke_api_exception.dart';

/// Lifecycle of an encounter. Anything other than [EncounterNone] pauses the
/// game.
sealed class EncounterState {
  const EncounterState();
}

/// Free roaming.
final class EncounterNone extends EncounterState {
  const EncounterNone();
}

/// Ash touched [smokeId]; the random Pokémon is being fetched.
final class EncounterResolving extends EncounterState {
  const EncounterResolving(this.smokeId);

  final String smokeId;
}

/// The Pokémon is known and the `EncounterHandler` is running.
final class EncounterActive extends EncounterState {
  const EncounterActive(this.smokeId, this.pokemon);

  final String smokeId;
  final Pokemon pokemon;
}

/// Fetching the Pokémon failed; the user can retry or cancel.
final class EncounterFailed extends EncounterState {
  const EncounterFailed(this.smokeId, this.error);

  final String smokeId;
  final PokeApiException error;
}
