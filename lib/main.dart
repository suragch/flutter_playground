import 'package:flutter/material.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeVariation>(
      valueListenable: themeNotifier,
      builder: (context, value, child) {
        return MaterialApp(
          theme: ThemeData(
              primarySwatch: value.color, brightness: value.brightness),
          home: const HomeWidget(),
        );
      },
    );
  }
}

var themeNotifier = ValueNotifier<ThemeVariation>(
  const ThemeVariation(Colors.blue, Brightness.light),
);

class ThemeVariation {
  const ThemeVariation(this.color, this.brightness);
  final MaterialColor color;
  final Brightness brightness;
}

class HomeWidget extends StatefulWidget {
  const HomeWidget({Key? key}) : super(key: key);
  @override
  _HomeWidgetState createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> {
  late AudioPlayer _player;
  final url = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3';
  late Stream<DurationState> _durationState;
  var _labelLocation = TimeLabelLocation.below;
  var _labelType = TimeLabelType.totalTime;
  TextStyle? _labelStyle;
  double _visibility = 1.0;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _durationState = Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        _player.positionStream,
        _player.playbackEventStream,
        (position, playbackEvent) => DurationState(
              progress: position,
              buffered: playbackEvent.bufferedPosition,
              total: playbackEvent.duration,
            ));
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setUrl(url);
    } catch (e) {
      debugPrint('An error occured $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('building app');
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _themeButtons(),
            _labelLocationButtons(),
            _labelTypeButtons(),
            _labelSizeButtons(),
            const Spacer(),
            _visibilityButtons(),
            const Spacer(),
            _progressBar(),
            _playButton(),
          ],
        ),
      ),
    );
  }

  Wrap _themeButtons() {
    return Wrap(children: [
      OutlinedButton(
        child: const Text('light'),
        onPressed: () {
          themeNotifier.value =
              const ThemeVariation(Colors.blue, Brightness.light);
        },
      ),
      OutlinedButton(
        child: const Text('dark'),
        onPressed: () {
          themeNotifier.value =
              const ThemeVariation(Colors.blue, Brightness.dark);
        },
      ),
    ]);
  }

  Wrap _labelLocationButtons() {
    return Wrap(children: [
      OutlinedButton(
        child: const Text('below'),
        onPressed: () {
          setState(() => _labelLocation = TimeLabelLocation.below);
        },
      ),
      OutlinedButton(
        child: const Text('above'),
        onPressed: () {
          setState(() => _labelLocation = TimeLabelLocation.above);
        },
      ),
      OutlinedButton(
        child: const Text('sides'),
        onPressed: () {
          setState(() => _labelLocation = TimeLabelLocation.sides);
        },
      ),
      OutlinedButton(
        child: const Text('none'),
        onPressed: () {
          setState(() => _labelLocation = TimeLabelLocation.none);
        },
      ),
    ]);
  }

  Wrap _labelTypeButtons() {
    return Wrap(children: [
      OutlinedButton(
        child: const Text('total time'),
        onPressed: () {
          setState(() => _labelType = TimeLabelType.totalTime);
        },
      ),
      OutlinedButton(
        child: const Text('remaining time'),
        onPressed: () {
          setState(() => _labelType = TimeLabelType.remainingTime);
        },
      ),
    ]);
  }

  Wrap _labelSizeButtons() {
    final fontColor = Theme.of(context).textTheme.bodyText1?.color;
    return Wrap(children: [
      OutlinedButton(
        child: const Text('standard label size'),
        onPressed: () {
          setState(() => _labelStyle = null);
        },
      ),
      OutlinedButton(
        child: const Text('large'),
        onPressed: () {
          setState(
              () => _labelStyle = TextStyle(fontSize: 40, color: fontColor));
        },
      ),
      OutlinedButton(
        child: const Text('small'),
        onPressed: () {
          setState(
              () => _labelStyle = TextStyle(fontSize: 8, color: fontColor));
        },
      ),
    ]);
  }

  Wrap _visibilityButtons() {
    return Wrap(children: [
      OutlinedButton(
        child: const Text('Invisible'),
        onPressed: () {
          setState(() => _visibility = 0.0);
        },
      ),
      OutlinedButton(
        child: const Text('Visible'),
        onPressed: () {
          setState(() => _visibility = 1.0);
        },
      ),
    ]);
  }

  StreamBuilder<DurationState> _progressBar() {
    return StreamBuilder<DurationState>(
      stream: _durationState,
      builder: (context, snapshot) {
        final durationState = snapshot.data;
        final progress = durationState?.progress ?? Duration.zero;
        final buffered = durationState?.buffered ?? Duration.zero;
        final total = durationState?.total ?? Duration.zero;
        return AnimatedOpacity(
          opacity: _visibility,
          duration: const Duration(milliseconds: 300),
          child: ProgressBar(
            progress: progress,
            buffered: buffered,
            total: total,
            onSeek: (duration) {
              _player.seek(duration);
            },
            timeLabelLocation: _labelLocation,
            timeLabelType: _labelType,
            timeLabelTextStyle: _labelStyle,
          ),
        );
      },
    );
  }

  StreamBuilder<PlayerState> _playButton() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          return Container(
            margin: const EdgeInsets.all(8.0),
            width: 32.0,
            height: 32.0,
            child: const CircularProgressIndicator(),
          );
        } else if (playing != true) {
          return IconButton(
            icon: const Icon(Icons.play_arrow),
            iconSize: 32.0,
            onPressed: _player.play,
          );
        } else if (processingState != ProcessingState.completed) {
          return IconButton(
            icon: const Icon(Icons.pause),
            iconSize: 32.0,
            onPressed: _player.pause,
          );
        } else {
          return IconButton(
            icon: const Icon(Icons.replay),
            iconSize: 32.0,
            onPressed: () => _player.seek(Duration.zero),
          );
        }
      },
    );
  }
}

class DurationState {
  const DurationState({
    required this.progress,
    required this.buffered,
    this.total,
  });
  final Duration progress;
  final Duration buffered;
  final Duration? total;
}
