import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';

import 'package:media_player/providers/player_provider.dart';
import 'package:media_player/providers/playlist_provider.dart';
import 'package:media_player/providers/file_browser_provider.dart';
import 'package:media_player/providers/history_provider.dart';
import 'package:media_player/services/audio_handler.dart';
import 'package:media_player/screens/home_screen.dart';

final globalPlayerProvider = PlayerProvider();
final globalPlaylistProvider = PlaylistProvider();
final globalHistoryProvider = HistoryProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup auto play next
  globalPlayerProvider.onCompleted = () {
    final nxt = globalPlaylistProvider.next();
    if (nxt != null) {
      globalPlayerProvider.openMedia(nxt.path, isVideo: nxt.isVideo);
    }
  };

  // Inisialisasi media_kit
  MediaKit.ensureInitialized();

  // Inisialisasi audio handler untuk background playback
  try {
    await AudioHandler.instance.init();
    
    AudioHandler.instance.setCallbacks(
      onNext: () {
        final nxt = globalPlaylistProvider.next();
        if (nxt != null) {
          globalPlayerProvider.openMedia(nxt.path, isVideo: nxt.isVideo);
        }
      },
      onPrev: () {
        final prev = globalPlaylistProvider.previous();
        if (prev != null) {
          globalPlayerProvider.openMedia(prev.path, isVideo: prev.isVideo);
        }
      },
    );
  } catch (e) {
    debugPrint('Gagal inisialisasi AudioHandler: $e');
  }

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D0D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MediaPlayerApp());
}

class MediaPlayerApp extends StatelessWidget {
  const MediaPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: globalPlayerProvider),
        ChangeNotifierProvider.value(value: globalPlaylistProvider),
        ChangeNotifierProvider.value(value: globalHistoryProvider),
        ChangeNotifierProvider(create: (_) => FileBrowserProvider()),
      ],
      child: MaterialApp(
        title: 'Media Player',
        debugShowCheckedModeBanner: false,
        theme: _buildDarkTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const Color primaryDark = Color(0xFF0D0D0D);
    const Color surfaceDark = Color(0xFF1A1A2E);
    const Color cardDark = Color(0xFF16213E);
    const Color accentPurple = Color(0xFF7F5AF0);
    const Color accentTeal = Color(0xFF2CB67D);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: accentPurple,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentPurple,
        secondary: accentTeal,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      cardColor: cardDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: accentPurple,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPurple,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentTeal,
        inactiveTrackColor: Colors.white24,
        thumbColor: accentTeal,
        overlayColor: accentTeal.withValues(alpha: 0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: Colors.white54,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: Colors.white12,
      useMaterial3: true,
    );
  }
}
