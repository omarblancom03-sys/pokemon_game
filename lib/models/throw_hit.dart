/// MODELO: cómo estaba el Pokémon cuando la Poké Ball le dio (lo que da
/// bonus de captura):
///  - [unaware]: no te había visto (×1,5);
///  - [fromBehind]: la bola le llegó por la espalda (×2 en vez de ×1,5);
///  - [eating]: se estaba comiendo una baya (×1,5);
///  - [asleep]: estaba dormido (×2).
typedef ThrowHit = ({bool unaware, bool fromBehind, bool eating, bool asleep});
