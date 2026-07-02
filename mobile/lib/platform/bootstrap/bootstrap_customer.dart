import 'bootstrap.dart';

Future<void> bootstrapCustomer() async {
  SharedBootstrap.isAdmin = false;
  // Execute base shared platform routines
  await SharedBootstrap.initSharedPlatform();
  
  // Custom Customer-only configuration/features flags could be registered here
}
