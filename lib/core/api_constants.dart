class ApiConstants {
  static const String baseUrl = 'https://male-cindy-controlex1-bd3de383.koyeb.app';
  
  // Auth Endpoints
  static const String login = '$baseUrl/api/auth/login';
  static const String register = '$baseUrl/api/auth/register';
  static const String forgotPassword = '$baseUrl/api/auth/forgot-password';
  static const String verifyResetCode = '$baseUrl/api/auth/verify-reset-code';
  static const String resetPassword = '$baseUrl/api/auth/reset-password';
  static const String verify2Fa = '$baseUrl/api/auth/verify-2fa';
  static const String logout = '$baseUrl/api/auth/logout';

  // User Endpoints
  static const String userMe = '$baseUrl/api/user/me';
  static const String userUpdate = '$baseUrl/api/user/update';
  static const String clearData = '$baseUrl/api/user/clear-data';

  // Widgets Endpoints
  static const String getWidgets = '$baseUrl/api/widgets';
  static const String createWidget = '$baseUrl/api/widgets';
  static String updateWidget(String id) => '$baseUrl/api/widgets/$id';
  static String updateWidgetPosition(String id) => '$baseUrl/api/widgets/$id/position';
  static String deleteWidget(String id) => '$baseUrl/api/widgets/$id';

  // Commands Endpoints
  static const String sendCommand = '$baseUrl/api/command/send';
}
