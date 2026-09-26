import 'sound_service.dart';
import 'web_sound_service.dart';

/// En la web: sonidos sintetizados con Web Audio.
SoundService createPlatformSoundService() => WebSoundService();
