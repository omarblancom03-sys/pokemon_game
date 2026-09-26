// PRUEBAS del MAPA GRANDE (lo que se marca): el mundo entero con el norte
// arriba (x hacia el este, y hacia el sur), las flechas del jugador y de la
// cámara bien giradas, y qué sale: bolas del suelo, arbustos con las bayas
// que les quedan, bayas sueltas ya en el suelo y carteles en todo el mapa;
// Pokémon solo cerca del jugador y nunca los escondidos.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_game/game/map/map_layout.dart';
import 'package:pokemon_game/game3d/sim/map_overview.dart';
import 'package:pokemon_game/game3d/sim/minimap.dart';
import 'package:pokemon_game/game3d/sim/wild_pokemon.dart';
import 'package:pokemon_game/game3d/sim/world3d_sim.dart';
import 'package:vector_math/vector_math.dart';

import '../fakes/fake_pokemon_repository.dart';

void main() {
  // 40 x 8 casillas (80 x 16 m): un arbusto (3,2) y un cartel (5,2).
  final layout = MapLayout.parse([
    'T' * 40,
    for (var row = 1; row < 7; row++)
      switch (row) {
        2 => 'T..b.s${'.' * 33}T',
        4 => 'T..@${'.' * 35}T',
        _ => 'T${'.' * 38}T',
      },
    'T' * 40,
  ]);

  World3DSim world() =>
      World3DSim(layout: layout, random: Random(2), maxFieldItems: 3);

  test('north up: x grows to the east and y to the south, 0..1', () {
    final s = world();
    final map = MapOverview.of(s);
    expect(map.width, 80);
    expect(map.depth, 16);
    final corner = map.project(Vector3(80, 0, 16));
    expect(corner.x, closeTo(1, 1e-9));
    expect(corner.y, closeTo(1, 1e-9));
    final mid = map.project(Vector3(20, 0, 4));
    expect(mid.x, closeTo(0.25, 1e-9));
    expect(mid.y, closeTo(0.25, 1e-9));
  });

  test('arrows: facing south points down; the camera looks where it '
      'looks', () {
    expect(MapOverview.screenAngle(0), closeTo(pi, 1e-9)); // sur = abajo
    expect(MapOverview.screenAngle(pi / 2), closeTo(pi / 2, 1e-9)); // este
    final s = world()..camera.yaw = 0; // cámara mirando al norte (−Z)
    expect(MapOverview.of(s).cameraAngle % (2 * pi), closeTo(0, 1e-9));
    s.camera.yaw = -pi / 2; // mirando al este (+X)
    expect(MapOverview.of(s).cameraAngle, closeTo(pi / 2, 1e-9));
  });

  test('balls, signs and bushes (with their berries) all over the map', () {
    final s = world();
    var map = MapOverview.of(s);
    expect(map.balls, hasLength(3));
    expect(map.signs, [s.cellCenter(5, 2)]);
    expect(map.bushes.single.at, s.cellCenter(3, 2));
    expect(map.bushes.single.berries, 3);

    s.player
      ..teleport(s.cellCenter(3, 3))
      ..facing = pi;
    s.shakeBush();
    map = MapOverview.of(s);
    expect(map.bushes.single.berries, 0);
    expect(map.berries, isEmpty, reason: 'still in the air');
    // Lejos, para que no las recoja: ya en el suelo sí salen.
    s.player.teleport(s.cellCenter(30, 5));
    for (var i = 0; i < 90; i++) {
      s.update(1 / 60);
    }
    expect(MapOverview.of(s).berries, hasLength(3));
  });

  test('Pokémon only near you (and never the hidden ones)', () {
    final s = world();
    WildPokemon add(String id, Vector3 at, {bool hidden = false}) {
      final w = WildPokemon(id: id, pokemon: fakePokemon(1), position: at)
        ..hidden = hidden;
      s.wild.add(w);
      return w;
    }

    final me = s.player.position;
    add('near', me + Vector3(10, 0, 0));
    add('far', me + Vector3(MapOverview.wildRange + 5, 0, 0));
    add('hidden', me + Vector3(6, 0, 2), hidden: true);
    final alert = add('alert', me + Vector3(0, 0, 5));
    s.behavior.startle(alert);

    final wild = MapOverview.of(s).wild;
    expect(wild.map((w) => w.at), [me + Vector3(10, 0, 0), alert.position]);
    expect(wild.map((w) => w.mark), [MinimapMark.calm, MinimapMark.alert]);
  });
}
