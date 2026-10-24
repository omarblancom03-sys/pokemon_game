// PRUEBAS de las HUELLAS DE POKÉMON: uno que cruza la tierra del camino deja
// huellas (una pata a cada lado, hacia donde va, más grandes si el Pokémon
// es grande y más marcadas si corre); en la hierba o el césped no; ni los
// que no pisan el suelo (escondidos, en un árbol o dentro de una bola). Se
// borran como las del entrenador.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/mesh/footprint_mesh.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:pokemon_game/models/pokemon.dart';
import 'package:pokemon_game/models/pokemon_type.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Una franja de camino (fila 2: z de 4 a 6) entre hierba alta.
  final layout = MapLayout.parse(const [
    'TTTTTTTTTTTTTTTT',
    'T""""""""""""""T',
    'T==============T',
    'T""""""""""""""T',
    'T.@............T',
    'TTTTTTTTTTTTTTTT',
  ]);

  WildPokemon pokemonOf(World3DSim s, {int height = 5}) {
    final w = WildPokemon(
      id: 'w${s.wild.length}',
      pokemon: Pokemon(
        id: 25,
        name: 'poke-25',
        types: const [PokemonType.electric],
        imageUrl: null,
        height: height,
        weight: 1,
      ),
      position: Vector3(10, 0, 2.5),
    )..idleTime = 1e9; // que no se mueva solo
    s.wild.add(w);
    return w;
  }

  /// Lleva a [w] en línea recta de z = 2,5 a z = 7,5 (cruza el camino)
  /// a [speed] m/s, mirando hacia +Z.
  void cross(World3DSim s, WildPokemon w, {double speed = 1.3}) {
    // El jugador, lejos, quieto y de lado: que nadie se asuste y huya.
    s.player.teleport(Vector3(29, 0, 3));
    w.facing = 0;
    for (var z = 2.5; z < 7.5; z += speed / 60) {
      w
        ..position = Vector3(10, 0, z)
        ..velocity = Vector3(0, 0, speed);
      s.update(1 / 60);
    }
  }

  test('crossing the dirt path leaves alternating prints, pointing where '
      'it went; none on the grass', () {
    final s = World3DSim(layout: layout, maxFieldItems: 0);
    final w = pokemonOf(s);
    cross(s, w);
    final prints = s.pawPrints.prints;
    // 2 m de camino a 0,5 m por unidad de tamaño.
    final spacing = World3DSim.pawSpacing * w.pawSize;
    expect(prints.length, inInclusiveRange(2 / spacing - 1, 2 / spacing + 1));
    for (final p in prints) {
      expect(p.position.z, inInclusiveRange(4, 6));
      expect(p.facing, 0);
      expect(p.size, w.pawSize);
      expect(p.depth, FootprintTrail.walkDepth);
    }
    // Una a cada lado (a la izquierda y a la derecha de su camino).
    for (var i = 1; i < prints.length; i++) {
      expect(
        (prints[i].position.x - 10).sign,
        -(prints[i - 1].position.x - 10).sign,
      );
    }
    expect(s.footprints.prints, isEmpty, reason: 'the trainer did not walk');
  });

  test('a big one leaves bigger, wider apart prints; running marks deeper', () {
    final s = World3DSim(layout: layout, maxFieldItems: 0);
    final small = pokemonOf(s, height: 3);
    final big = pokemonOf(s, height: 30);
    expect(big.pawSize, greaterThan(small.pawSize));
    cross(s, big, speed: WildPokemon.fleeSpeed);
    expect(s.pawPrints.prints, isNotEmpty);
    // (La primera, al pisar la tierra, aún no sabe a qué iba: aquí se le
    // mueve a mano y no lleva velocidad.)
    for (final p in s.pawPrints.prints.skip(1)) {
      expect(p.size, big.pawSize);
      expect(p.depth, FootprintTrail.runDepth);
    }
  });

  test('hidden ones or those inside a ball leave nothing; they fade away '
      'like the trainer prints', () {
    final s = World3DSim(layout: layout, maxFieldItems: 0);
    final w = pokemonOf(s)..hidden = true;
    cross(s, w);
    w
      ..hidden = false
      ..capturedBy = 'ball';
    cross(s, w);
    expect(s.pawPrints.prints, isEmpty);
    w.capturedBy = null;
    cross(s, w);
    expect(s.pawPrints.prints, isNotEmpty);
    for (var t = 0.0; t < FootprintTrail.life + 0.1; t += 0.1) {
      s.update(0.1);
    }
    expect(s.pawPrints.prints, isEmpty);
  });

  test('the paw mesh is flat on the ground, facing up, toes to +Z', () {
    final mesh = buildPawPrint();
    var front = 0.0;
    var back = 0.0;
    for (var i = 0; i < mesh.vertexCount; i++) {
      expect(mesh.positions[i * 3 + 1], 0);
      expect(mesh.normals[i * 3 + 1], closeTo(1, 1e-6));
      front = max(front, mesh.positions[i * 3 + 2]);
      back = min(back, mesh.positions[i * 3 + 2]);
    }
    // Los dedos (delante) llegan más lejos que el talón de la almohadilla.
    expect(front, greaterThan(-back));
    expect(front - back, closeTo(0.13, 0.01));
  });
}
