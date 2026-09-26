import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'services/local_db.dart';
import 'services/users_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonte Inter vem empacotada em assets/google_fonts; não baixa da internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  await LocalDb.instance.init();
  // Não bloqueia a abertura esperando a rede; o login aguarda se precisar.
  UsersSyncService.startInBackground();
  runApp(const CantinhoApp());
}
