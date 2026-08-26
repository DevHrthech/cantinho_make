import 'package:flutter/material.dart';

import 'app.dart';
import 'services/local_db.dart';
import 'services/users_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.instance.init();
  await const UsersSyncService().syncUsuarios();
  runApp(const CantinhoApp());
}
