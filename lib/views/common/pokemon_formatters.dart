import 'package:flutter/material.dart';

import '../../models/pokemon_type.dart';
import '../../services/poke_api_exception.dart';

/// `"mr-mime"` → `"Mr Mime"`.
String displayName(String apiName) => apiName
    .split('-')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// `25` → `"#025"`.
String dexNumber(int id) => '#${id.toString().padLeft(3, '0')}';

/// `"generation-i"` → `"Generación I"`.
String generationLabel(String apiName) {
  final numeral = generationNumeral(apiName);
  return numeral.isEmpty ? displayName(apiName) : 'Generación $numeral';
}

/// `"generation-i"` → `"I"`; empty when the name carries no numeral.
String generationNumeral(String apiName) {
  final parts = apiName.split('-');
  return parts.length < 2 ? '' : parts.last.toUpperCase();
}

/// Decimetres (as the API returns them) → `"0.7 m"`.
String heightLabel(int decimetres) =>
    '${(decimetres / 10).toStringAsFixed(1)} m';

/// Hectograms (as the API returns them) → `"6.9 kg"`.
String weightLabel(int hectograms) =>
    '${(hectograms / 10).toStringAsFixed(1)} kg';

/// User-facing message for a load failure.
String errorMessage(Object error) => switch (error) {
  PokeApiNetworkException() => 'Sin conexión. Revisa tu internet.',
  PokeApiNotFoundException() => 'No se encontró el Pokémon.',
  PokeApiServerException(:final statusCode) =>
    'PokeAPI no responde (error $statusCode).',
  PokeApiParseException() => 'Respuesta inesperada de PokeAPI.',
  _ => 'Algo salió mal.',
};

extension PokemonTypeStyle on PokemonType {
  Color get color => switch (this) {
    PokemonType.normal => const Color(0xFFA8A77A),
    PokemonType.fire => const Color(0xFFEE8130),
    PokemonType.water => const Color(0xFF6390F0),
    PokemonType.electric => const Color(0xFFF7D02C),
    PokemonType.grass => const Color(0xFF7AC74C),
    PokemonType.ice => const Color(0xFF96D9D6),
    PokemonType.fighting => const Color(0xFFC22E28),
    PokemonType.poison => const Color(0xFFA33EA1),
    PokemonType.ground => const Color(0xFFE2BF65),
    PokemonType.flying => const Color(0xFFA98FF3),
    PokemonType.psychic => const Color(0xFFF95587),
    PokemonType.bug => const Color(0xFFA6B91A),
    PokemonType.rock => const Color(0xFFB6A136),
    PokemonType.ghost => const Color(0xFF735797),
    PokemonType.dragon => const Color(0xFF6F35FC),
    PokemonType.dark => const Color(0xFF705746),
    PokemonType.steel => const Color(0xFFB7B7CE),
    PokemonType.fairy => const Color(0xFFD685AD),
    PokemonType.stellar => const Color(0xFF40B5A5),
    PokemonType.unknown => const Color(0xFF68A090),
  };

  String get label => displayName(apiName);
}
