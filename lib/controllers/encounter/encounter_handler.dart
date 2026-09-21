import '../../models/pokemon.dart';

/// Cómo terminó un encuentro: capturado o huido.
enum EncounterOutcome { caught, fled }

/// ─── CONTRATO DE ENCUENTRO (punto de enganche para la captura) ───────────
///
/// El GameController llama a [handleEncounter] cuando Ash ha tocado un humo
/// Y el Pokémon al azar ya se ha descargado de PokeAPI.
///
/// Mientras el Future devuelto no se complete, el juego sigue PAUSADO (Ash
/// no se mueve y no puede empezar otro encuentro). Al completarse, el humo
/// se consume y el juego se reanuda.
///
/// La animación de la Pokébola NO forma parte de esta entrega: para
/// añadirla basta con implementar esta interfaz (por ejemplo abriendo una
/// pantalla de captura y completando con su resultado) y registrarla en
/// `app/dependencies.dart` en lugar de StubEncounterHandler. No hay que
/// tocar nada más.
///
/// Quien la implemente no debería lanzar excepciones; si lo hace, el error
/// se registra y el encuentro se da por [EncounterOutcome.fled], para que el
/// juego nunca se quede congelado.
abstract interface class EncounterHandler {
  Future<EncounterOutcome> handleEncounter(Pokemon pokemon);
}
