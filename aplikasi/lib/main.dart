import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watermark App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? selectedFile;
  bool isLoading = false;
  String message = "";
  List<int>? downloadedBytes; // simpan hasil PDF

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> uploadFile() async {
    if (selectedFile == null) return;

    setState(() {
      isLoading = true;
      message = "";
      downloadedBytes = null;
    });

    var uri = Uri.parse("http://127.0.0.1:8000/process"); // ganti IP sesuai server
    var request = http.MultipartRequest("POST", uri);

    request.files.add(await http.MultipartFile.fromPath("file", selectedFile!.path));
    request.fields["using_for"] = "Test Watermark";
    request.fields["nama"] = "User Demo";
    request.fields["nisn"] = "123456";

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        var bytes = await response.stream.toBytes();

        setState(() {
          downloadedBytes = bytes;
          message = "✅ File berhasil diproses. Klik tombol Download.";
        });
      } else {
        var errorText = await response.stream.bytesToString();
        setState(() {
          message = "❌ Upload gagal (${response.statusCode}): $errorText";
        });
      }
    } catch (e) {
      setState(() {
        message = "❌ Error: $e";
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveFile() async {
    if (downloadedBytes == null) return;

    try {
      // cari folder Downloads user
      Directory? dir = await getDownloadsDirectory();
      String savePath;

      if (dir != null) {
        savePath = "${dir.path}/watermarked.pdf";
      } else {
        // fallback manual Linux
        savePath = "/home/${Platform.environment['USER']}/Downloads/watermarked.pdf";
      }

      File outFile = File(savePath);
      await outFile.writeAsBytes(downloadedBytes!);

      setState(() {
        message = "✅ Disimpan ke: $savePath";
      });
    } catch (e) {
      setState(() {
        message = "❌ Gagal menyimpan: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Watermark Generator")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedFile != null) Text("Dipilih: ${selectedFile!.path}"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: pickFile,
                child: const Text("Pilih File"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : uploadFile,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Proses File"),
              ),
              const SizedBox(height: 20),
              if (downloadedBytes != null)
                ElevatedButton.icon(
                  onPressed: saveFile,
                  icon: const Icon(Icons.download),
                  label: const Text("Download PDF"),
                ),
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
