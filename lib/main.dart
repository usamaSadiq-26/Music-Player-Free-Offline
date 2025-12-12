import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as per_handler; // Import with prefix to use openAppSettings

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Music Player',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();
  
  List<SongModel> songs = [];
  bool loading = true;
  bool permissionDenied = false;

  @override
  void initState() {
    super.initState();
    // Start by requesting necessary permissions and loading songs
    requestPermissionsAndLoad();
  }

  // Handles requesting media/storage permissions based on the platform
  Future<void> requestPermissionsAndLoad() async {
    // Determine the correct permission type based on the operating system
    final Permission permission = Platform.isAndroid 
      ? Permission.audio 
      : Permission.storage;

    var status = await permission.request();

    if (status.isGranted) {
      // For older Android versions, we sometimes need an explicit check/request via the plugin
      if (Platform.isAndroid) {
        await _audioQuery.checkAndRequest(retryRequest: false); 
      }
      loadSongs();
    } else {
      // Handle denied permission state
      if (mounted) {
        setState(() {
          loading = false;
          permissionDenied = true;
        });
      }
    }
  }

  // Fetches songs from the device's storage
  Future<void> loadSongs() async {
    try {
      List<SongModel> loaded = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      if (mounted) {
        setState(() {
          songs = loaded;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
         setState(() => loading = false);
        // Show a snackbar if song loading fails
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load songs from device.')),
        );
      }
    }
  }

  // Plays the selected song using the just_audio player
  void playSong(SongModel song) async {
    try {
      await _player.stop();
      
      if (song.uri == null) {
        throw Exception('Song URI is null');
      }
      
      await _player.setAudioSource(AudioSource.uri(Uri.parse(song.uri!)));
      await _player.play();
      
      // FIX: Guard context usage after the await calls
      if (!mounted) return;
      
      // Provide user feedback that the song is playing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Now playing: ${song.title}')),
      );
      
    } catch (e) {
      // FIX: Guard context usage in the catch block as well (optional but safer)
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing "${song.title}": $e')),
      );
    }
  }

  @override
  void dispose() {
    // Important: Dispose of the audio player to free up resources
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      // FIX: Removed 'const' before Scaffold
      return Scaffold(
        appBar: AppBar(title: const Text('Offline Music Player')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (permissionDenied) {
      // FIX: Removed 'const' before Scaffold
      return Scaffold(
        appBar: AppBar(title: const Text('Offline Music Player')), 
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Media Permission Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please grant permission to read audio files from your device settings.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // FIX: ElevatedButton.icon cannot be const because onPressed is a dynamic function
                ElevatedButton.icon(
                  // Opens application settings to allow the user to grant permission manually
                  onPressed: per_handler.openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main song list view
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Music Player')),
      body: songs.isEmpty
          ? const Center(child: Text('No songs found on device'))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final s = songs[index];
                return ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(s.title),
                  subtitle: Text(s.artist ?? 'Unknown Artist'),
                  onTap: () => playSong(s),
                );
              }),
    );
  }
}