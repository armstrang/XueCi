import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  try {
    app = await App.boot();
  } catch (e, s) {
    debugPrint('boot failed: $e\n$s');
    runApp(const BootFail());
    return;
  }
  runApp(const XueCiApp());
}

/// the word list could not be loaded (as the WebView app's .bootfail)
class BootFail extends StatelessWidget {
  const BootFail({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Data kata gagal dimuat. Tutup aplikasi lalu buka lagi.\n\nThe word list could not be loaded. Close the app and open it again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
