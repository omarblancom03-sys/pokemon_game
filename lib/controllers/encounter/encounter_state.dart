import '../../models/pokemon.dart';
import '../../services/poke_api_exception.dart';

/// Las cuatro fases de un encuentro. Cualquier estado que no sea
/// [EncounterNone] mantiene el juego en pausa.
///
/// Al ser `sealed`, la vista puede hacer un switch completo y cada estado
/// lleva dentro los datos que necesita (el Pokémon, el error...).
sealed class EncounterState {
  const EncounterState();
}

/// Paseando libremente: no hay encuentro.
final class EncounterNone extends EncounterState {
  const EncounterNone();
}

/// Ash tocó [smokeId] y se está descargando el Pokémon al azar.
final class EncounterResolving extends EncounterState {
  const EncounterResolving(this.smokeId);

  final String smokeId;
}

/// Ya se sabe qué Pokémon es y el EncounterHandler está en marcha
/// (es decir, se está mostrando el encuentro / la captura).
final class EncounterActive extends EncounterState {
  const EncounterActive(this.smokeId, this.pokemon);

  final String smokeId;
  final Pokemon pokemon;
}

/// Falló la descarga: el usuario puede reintentar o cancelar.
final class EncounterFailed extends EncounterState {
  const EncounterFailed(this.smokeId, this.error);

  final String smokeId;
  final PokeApiException error;
}
