// Carga los "fixtures": respuestas reales de PokeAPI guardadas en archivos
// .json, para que las pruebas de parseo usen datos idénticos a los de
// producción.

import 'dart:convert';
import 'dart:io';

/// Raw text of `test/fixtures/<name>`. `flutter test` runs from the project root.
String fixtureText(String name) =>
    File('test/fixtures/$name').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixtureText(name)) as Map<String, dynamic>;
