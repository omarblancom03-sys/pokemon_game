import 'sound_service.dart';

/// Fuera de la web (Windows, tests): sin sonido.
SoundService createPlatformSoundService() => SilentSoundService();
