import 'package:local_auth/local_auth.dart';

final LocalAuthentication _localAuth = LocalAuthentication(); // Correct class name

Future<bool> authenticateWithBiometrics() async {
  try {
    // Check if biometrics are available
    final bool canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canAuthenticate) {
      print("Biometrics not available on this device.");
      return false;
    }

    // Check if biometrics are enrolled
    final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      print("No biometrics enrolled on this device.");
      return false;
    }

    // Authenticate the user
    final bool didAuthenticate = await _localAuth.authenticate(
      localizedReason: 'Scan your fingerprint to authorize attendance', // Message shown to the user
      options: const AuthenticationOptions(
        biometricOnly: true, // Only allow biometrics (no fallback to PIN/pattern)
      ),
    );

    if (!didAuthenticate) {
      print("Biometric authentication failed or was canceled by the user.");
    }

    return didAuthenticate;
  } catch (e) {
    print("Error during biometric authentication: $e");
    return false;
  }
}
