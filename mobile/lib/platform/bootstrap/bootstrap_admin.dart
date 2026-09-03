import '../../supabase/supabase_config.dart';
import 'bootstrap.dart';

Future<void> bootstrapAdmin() async {
  SharedBootstrap.isAdmin = true;
  // Admin uses a separate env asset so it never shares Customer OWANBE_API_BASE.
  await SupabaseConfig.load(fileName: 'assets/env/owanbe_config.admin');
  await SharedBootstrap.initSharedPlatform();
}
