import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelName: 'Audio Service',
      androidNotificationOngoing: true,
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
    // Broadcast media item changes.
    // _player.currentIndexStream.listen((index) {
    //   final playlist = queue.value ?? [];
    //   print('current index: $index, playlist: ${playlist.length}');
    //   if (index != null && playlist.isNotEmpty) {
    //     mediaItem.add(playlist[index]);
    //   }
    // });

    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForDurationChanges();
    _listenForSequenceStateChange();

    _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      print('new sequence state: ');
      print(sequenceState?.sequence.length);
    });

    // _player.sequenceStateStream
    //     .map((state) => state?.effectiveSequence)
    //     .distinct()
    //     .listen((audioSourceList) {
    //   final mediaItems =
    //       audioSourceList?.map((source) => source.tag as MediaItem).toList() ??
    //           [];
    //   // queue.add(mediaItems);
    //   print('sequence updated');
    //   mediaItems.forEach((element) => print(element.title));
    // });

    // _player.sequenceStateStream.listen((state) {
    //   final sequence = state?.effectiveSequence;
    //   final mediaItems =
    //       sequence?.map((source) => source.tag as MediaItem).toList();
    //   queue.add(mediaItems);
    // });
    // .distinct()
    // .map((sequence) =>
    //     sequence?.map((source) => source.tag as MediaItem).toList())
    // .pipe(queue);

    try {
      await _player.setAudioSource(_playlist, preload: false);
    } catch (e) {
      print("Error: $e");
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = _player.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
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
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      if (index == null) return;
      final newQueue = queue.value!;
      final oldMediaItem = newQueue[index];
      final newMediaItem = oldMediaItem.copyWith(duration: duration);
      newQueue[index] = newMediaItem;
      queue.add(newQueue);
      mediaItem.add(newMediaItem);
    });
  }

  void _listenForSequenceStateChange() {
    _player.sequenceStateStream.listen((SequenceState? sequenceState) {
      final sequence = sequenceState?.effectiveSequence;
      if (sequence == null || sequence.isEmpty) return;
      print('This line is never reached.');
      final items = sequence.map((source) => source.tag as MediaItem);
      queue.add(items.toList());
    });
  }

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
    final index = playbackState.value.queueIndex!;
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
    if (shuffleMode == AudioServiceShuffleMode.none) {
      _player.setShuffleModeEnabled(false);
    } else {
      _player.setShuffleModeEnabled(true);
      _player.shuffle();
    }
  }

  // void _shuffleQueue(List<int>? queueIndices) {
  //   final playlist = queueIndices!.map((index) => queue.value![index]).toList();
  //   queue.add(playlist);
  // }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    // manage Just Audio
    final audioSource = _createAudioSource(mediaItem);
    _playlist.add(audioSource);

    // notify system
    final newQueue = queue.value?..add(mediaItem);
    queue.add(newQueue);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    // manage Just Audio
    final audioSource = mediaItems.map(_createAudioSource);
    _playlist.addAll(audioSource.toList());

    // notify system
    final newQueue = queue.value?..addAll(mediaItems);
    queue.add(newQueue);
  }

  IndexedAudioSource _createAudioSource(MediaItem mediaItem) {
    return AudioSource.uri(
      Uri.parse(mediaItem.extras!['url']),
      tag: mediaItem,
    );
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final playlist = queue.value!;
    playlist.removeAt(index);
    queue.add(playlist);
    _playlist.removeAt(index);
  }

  @override
  Future<void> stop() async {
    await _player.dispose();
    return super.stop();
  }

  @override
  Future customAction(
    String name,
    Map<String, dynamic>? arguments,
  ) async {
    if (name == 'dispose') {
      await _player.dispose();
      super.stop();
    }
  }
}
