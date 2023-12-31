import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vid2sub/Widget/video_player_view.dart';
import 'package:video_player/video_player.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
      theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  PlatformFile? videoFile;
  // late VideoPlayerController videoPlayerController;
  // late ChewieController chewieController;

  // @override
  // void initState() {
  //   super.initState();
  //   videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(
  //       'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'))
  //     ..initialize().then((_) {
  //       // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
  //       chewieController = ChewieController(
  //         videoPlayerController: videoPlayerController,
  //         autoPlay: false,
  //         looping: true,
  //         autoInitialize: true,
  //         showControls: true,
  //         allowFullScreen: true,
  //         allowMuting: true,
  //         draggableProgressBar: true,
  //         showOptions: true,
  //         subtitle: Subtitles([
  //           Subtitle(
  //             index: 0,
  //             start: Duration.zero,
  //             end: const Duration(seconds: 2),
  //             text: 'Hello from subtitles',
  //           ),
  //           Subtitle(
  //             index: 1,
  //             start: const Duration(seconds: 3),
  //             end: const Duration(seconds: 8),
  //             text: 'Whats up? :)',
  //           ),
  //         ]),
  //         subtitleBuilder: (context, subtitle) => Container(
  //           padding: const EdgeInsets.all(10.0),
  //           child: Text(
  //             subtitle,
  //             style: const TextStyle(color: Colors.white),
  //           ),
  //         ),
  //         allowPlaybackSpeedChanging: true,
  //         aspectRatio: 16 / 9,
  //         deviceOrientationsAfterFullScreen: [
  //           DeviceOrientation.portraitUp,
  //           DeviceOrientation.landscapeLeft,
  //           DeviceOrientation.landscapeRight,
  //         ],
  //         deviceOrientationsOnEnterFullScreen: [
  //           DeviceOrientation.landscapeLeft,
  //           DeviceOrientation.landscapeRight,
  //         ],
  //         placeholder: Container(
  //           color: Colors.grey,
  //         ),
  //       );

  //       setState(() {});
  //     });
  // }

  // @override
  // void dispose() {
  //   videoPlayerController.dispose();
  //   chewieController.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video to Audio Converter'),
      ),
      body: Column(
        children: [
          // const TextField(
          //   decoration: InputDecoration(
          //     hintText: 'Enter video URL',
          //   ),
          // ),
          ElevatedButton(
            onPressed: () async {
              await _pickVideo();
            },
            child: const Text('Upload Video'),
          ),
          // Center(
          //   child: chewieController.videoPlayerController.value.isInitialized
          //       ? AspectRatio(
          //           aspectRatio: chewieController
          //               .videoPlayerController.value.aspectRatio,
          //           child: Chewie(
          //             controller: chewieController,
          //           ))
          //       : Container(),
          // ),
          videoFile != null
              ? FutureBuilder(
                  key: UniqueKey(),
                  future: _convertVideoToSrt(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return VideoPlayerView(
                        key: UniqueKey(),
                        url: videoFile!.path!,
                        dataSourceType: DataSourceType.file,
                        subtitleData: snapshot.data.toString(),
                      );
                    } else {
                      return const CircularProgressIndicator();
                    }
                  })
              : Container(),
//           const VideoPlayerView(
//             url:
//                 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
//             dataSourceType: DataSourceType.network,
//             subtitleData: """
// 1
// 00:00:00,000 --> 00:00:02,000
// Cognac?

// 2
// 00:00:02,000 --> 00:00:04,000
// No, thank you.

// 3
// 00:00:04,000 --> 00:00:06,000
// Listen, I'm...

// 4
// 00:00:06,000 --> 00:00:08,000
// sorry...

// 5
// 00:00:08,000 --> 00:00:10,000
// for your loss.
// """,
//           ),
//           videoFile != null
//               ? VideoPlayerView(
//                   url: videoFile!.path,
//                   dataSourceType: DataSourceType.file,
//                   subtitleData: """
// 1
// 00:00:00,000 --> 00:00:02,000
// Cognac?

// 2
// 00:00:02,000 --> 00:00:04,000
// No, thank you.

// 3
// 00:00:04,000 --> 00:00:06,000
// Listen, I'm...

// 4
// 00:00:06,000 --> 00:00:08,000
// sorry...

// 5
// 00:00:08,000 --> 00:00:10,000
// for your loss.
// """,
//                 )
//               : Container(),
        ],
      ),
    );
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      videoFile = result.files.first;
    });
  }

  Future<String> _convertVideoToSrt() async {
    final directory = await getTemporaryDirectory();
    final tempAudioPath =
        '${directory.path}/${videoFile!.name + Random().nextInt(500).toString()}.m4a';

    await _convertVideoToAudio(videoFile!.path!, tempAudioPath);

    print('Audio file converted: $tempAudioPath');

    var srtData = await _sendAudioToOpenAI(tempAudioPath);
    print(srtData);
    return srtData;
  }

  // Future<void> _requestPermissionAndPickVideo() async {
  //   FilePickerResult? result = await FilePicker.platform.pickFiles(
  //     type: FileType.video,
  //     allowMultiple: false,
  //   );
  //   if (result == null || result.files.isEmpty) return;

  //   PlatformFile videoFile = result.files.first;
  //   // String videoPath = result.files.first.path!;
  //   final directory = await getTemporaryDirectory();
  //   final tempAudioPath =
  //       '${directory.path}/${videoFile.name + Random().nextInt(500).toString()}.m4a';

  //   await _convertVideoToAudio(videoFile.path!, tempAudioPath);

  //   print('Audio file converted: $tempAudioPath');

  //   setState(() {
  //     this.videoFile = File(videoFile.path!);
  //   });

  //   // var stream = await _sendAudioToOpenAI(tempAudioPath);
  //   // print(stream);
  //   return;
  // }

  Future<void> _convertVideoToAudio(String inputPath, String outputPath) async {
    String command =
        '-i $inputPath -vn -ar 44100 -ac 2 -c:a aac -b:a 192k $outputPath';

    int result = await _flutterFFmpeg.execute(command);

    if (result == 0) {
      print('Conversion successful');
    } else {
      print('Conversion failed');
    }
  }

  Future<dynamic> _sendAudioToOpenAI(String audioPath) async {
    final openaiApiKey = dotenv.env['OPENAI_API_KEY'];

    if (openaiApiKey == null || openaiApiKey.isEmpty) {
      print('OpenAI API key is missing');
      return null;
    }

    final url = Uri.parse('https://api.openai.com/v1/audio/translations');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll({'Authorization': 'Bearer $openaiApiKey'});
    request.fields['model'] = 'whisper-1';
    request.fields['response_format'] = 'srt';
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));
    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        print('Audio file sent successfully to OpenAI API');
        var responseData = await http.Response.fromStream(response);
        print(responseData.body);
        return responseData.body;
      } else {
        print('Failed to send audio file. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error sending audio file: $error');
      return null;
    }
  }
}
