import 'pokemon.dart';

/// VARIOCOLOR (shiny): el arte oficial con los colores raros. PokeAPI lo
/// guarda junto al normal; se deduce del número para no tocar el modelo
/// (ni su JSON) por algo que solo es cosmético.
extension PokemonShiny on Pokemon {
  String get shinyImageUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/'
      'pokemon/other/official-artwork/shiny/$id.png';
}
