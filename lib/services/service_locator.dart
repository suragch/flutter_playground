import 'package:audio_service/audio_service.dart';
import 'package:flutter_playground/page_manager.dart';
import 'package:flutter_playground/services/playlist_repository.dart';
import 'package:get_it/get_it.dart';

import 'audio_service.dart';

GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // services
  getIt.registerSingleton<AudioHandler>(await initAudioService());
  getIt.registerLazySingleton<PlaylistRepository>(() => DemoPlaylist());

  // page state
  getIt.registerLazySingleton<PageManager>(() => PageManager());
}