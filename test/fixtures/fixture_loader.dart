import 'dart:convert';
import 'dart:io';

/// Raw text of `test/fixtures/<name>`. `flutter test` runs from the project root.
String fixtureText(String name) =>
    File('test/fixtures/$name').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(fixtureText(name)) as Map<String, dynamic>;
