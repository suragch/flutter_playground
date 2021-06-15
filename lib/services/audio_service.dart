import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelName: 'Audio Service',
      androidNotificationOngoing: true,
      androidEnableQueue: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    //queue.add(albums);

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      final playlist = queue.value!;
      print('current index: $index, playlist: ${playlist.length}');
      if (index != null && playlist.isNotEmpty) {
        mediaItem.add(playlist[index]);
      }
    });

    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen(_broadcastState);

    _player.durationStream.listen((duration) {
      print('duration: $duration');
      final index = _player.currentIndex;
      if (index == null) return;
      final newQueue = queue.value!;
      final oldMediaItem = newQueue[index];
      print('old: $oldMediaItem newQueue: $newQueue index: $index');
      final newMediaItem = oldMediaItem.copyWith(duration: duration);
      newQueue[index] = newMediaItem;
      queue.add(newQueue);
      mediaItem.add(newMediaItem);
      //mediaItem.
    });

    try {
      print("### _player.load");
      // After a cold restart (on Android), _player.load jumps straight from
      // the loading state to the completed state. Inserting a delay makes it
      // work. Not sure why!
      //await Future.delayed(Duration(seconds: 2)); // magic delay
      // _playlist = ConcatenatingAudioSource(
      //   children: queue.value!
      //       .map((item) => AudioSource.uri(Uri.parse(item.id)))
      //       .toList(),
      // );
      await _player.setAudioSource(_playlist);
      print("### loaded");
    } catch (e) {
      print("Error: $e");
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value!.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  // for any methods that you want to use on AudioHandler override them

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value!.length) return;
    _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> skipToNext() async {
    await _skip(1);
  }

  @override
  Future<void> skipToPrevious() async {
    await _skip(-1);
  }

  Future<void> _skip(int offset) async {
    final queue = this.queue.value!;
    final index = playbackState.value!.queueIndex!;
    if (index < 0 || index >= queue.length) return;
    return skipToQueueItem(index + offset);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final oldIndices = _player.effectiveIndices!;
    switch (shuffleMode) {
      case AudioServiceShuffleMode.none:
        final list = List.generate(
            oldIndices.length, (index) => queue.value![oldIndices[index]]);
        queue.add(list);
        _player.setShuffleModeEnabled(false);
        break;
      case AudioServiceShuffleMode.group:
      case AudioServiceShuffleMode.all:
        _player.setShuffleModeEnabled(true);
        _player.shuffle();
        final playlist =
            oldIndices.map((index) => queue.value![index]).toList();
        queue.add(playlist);
        break;
    }
  }

  void _shuffleQueue(List<int>? queueIndices) {
    final playlist = queueIndices!.map((index) => queue.value![index]).toList();
    queue.add(playlist);
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final playlist = queue.value!;
    playlist.add(mediaItem);
    queue.add(playlist);
    _playlist.add(AudioSource.uri(Uri.parse(mediaItem.extras!['url'])));
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    queue.add(queue.value!..addAll(mediaItems));
    _playlist.addAll(mediaItems
        .map((item) => AudioSource.uri(Uri.parse(item.extras!['url'])))
        .toList());
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final playlist = queue.value!;
    playlist.removeAt(index);
    queue.add(playlist);
    _playlist.removeAt(index);
  }
}
