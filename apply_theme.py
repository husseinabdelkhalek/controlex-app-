import re

def update_account_screen():
    path = "lib/screens/account_screen.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace the container holding the 3 buttons
    old_buttons = """            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBaseColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.badge,
                    title: AppLocalization.get('personal_info'),
                    subtitle: AppLocalization.isArabicNotifier.value ? 'تعديل بيانات الحساب' : 'Edit profile details',
                    color: AppTheme.primaryCyan,
                    onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(initialData: {'username': _usernameCtrl.text, 'email': _emailCtrl.text, 'googleProfilePicture': _googleProfilePicture})));
                      if (result == true) _fetchData();
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildListTile(
                    icon: Icons.cloud_sync,
                    title: AppLocalization.isArabicNotifier.value ? 'الربط والبيانات' : 'Integrations',
                    subtitle: AppLocalization.isArabicNotifier.value ? 'إعدادات Adafruit و Firebase' : 'Adafruit & Firebase settings',
                    color: AppTheme.primaryViolet,
                    onTap: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => IntegrationsSettingsScreen(initialData: {'adafruitUsername': _aioUserCtrl.text, 'adafruitApiKey': _aioKeyCtrl.text, 'firebaseUrl': _firebaseUrlCtrl.text, 'firebaseSecret': _firebaseSecretCtrl.text})));
                      if (result == true) _fetchData();
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildListTile(
                    icon: Icons.security,
                    title: AppLocalization.get('security_settings'),
                    subtitle: AppLocalization.isArabicNotifier.value ? 'التحقق بخطوتين والجلسات' : '2FA & Active Sessions',
                    color: Colors.greenAccent,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => SecuritySettingsScreen(initialData: {'security': {'twoFactorEnabled': _twoFactorEnabled}}, initialSessions: _sessions)));
                      _fetchData();
                    },
                  ),
                ],
              ),
            ),"""

    new_buttons = """            _buildGlassButton(
              icon: Icons.badge,
              title: AppLocalization.get('personal_info'),
              subtitle: AppLocalization.isArabicNotifier.value ? 'تعديل بيانات الحساب' : 'Edit profile details',
              color: AppTheme.primaryCyan,
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(initialData: {'username': _usernameCtrl.text, 'email': _emailCtrl.text, 'googleProfilePicture': _googleProfilePicture})));
                if (result == true) _fetchData();
              },
            ),
            const SizedBox(height: 12),
            _buildGlassButton(
              icon: Icons.cloud_sync,
              title: AppLocalization.isArabicNotifier.value ? 'الربط والبيانات' : 'Integrations',
              subtitle: AppLocalization.isArabicNotifier.value ? 'إعدادات Adafruit و Firebase' : 'Adafruit & Firebase settings',
              color: AppTheme.primaryViolet,
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => IntegrationsSettingsScreen(initialData: {'adafruitUsername': _aioUserCtrl.text, 'adafruitApiKey': _aioKeyCtrl.text, 'firebaseUrl': _firebaseUrlCtrl.text, 'firebaseSecret': _firebaseSecretCtrl.text})));
                if (result == true) _fetchData();
              },
            ),
            const SizedBox(height: 12),
            _buildGlassButton(
              icon: Icons.security,
              title: AppLocalization.get('security_settings'),
              subtitle: AppLocalization.isArabicNotifier.value ? 'التحقق بخطوتين والجلسات' : '2FA & Active Sessions',
              color: Colors.greenAccent,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => SecuritySettingsScreen(initialData: {'security': {'twoFactorEnabled': _twoFactorEnabled}}, initialSessions: _sessions)));
                _fetchData();
              },
            ),
            const SizedBox(height: 16),"""
            
    content = content.replace(old_buttons, new_buttons)

    # Inject _buildGlassButton method
    glass_button_method = """  Widget _buildGlassButton({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Container(
      decoration: AppTheme.glassDecoration(
        borderRadius: BorderRadius.circular(20),
        borderColor: color.withValues(alpha: 0.3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)
                    ],
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }"""
    
    if "_buildGlassButton" not in content:
        content = content.replace("Widget _buildListTile", glass_button_method + "\n\n  Widget _buildListTile")

    # Update appbar for inner screens
    for screen_path in ["lib/screens/profile_settings_screen.dart", "lib/screens/integrations_settings_screen.dart", "lib/screens/security_settings_screen.dart"]:
        with open(screen_path, "r", encoding="utf-8") as f:
            inner_content = f.read()
        
        # appbar
        inner_content = inner_content.replace(
            "backgroundColor: AppTheme.cardBaseColor,",
            "backgroundColor: Colors.transparent,\n        flexibleSpace: Container(decoration: AppTheme.glassDecoration(borderRadius: BorderRadius.zero)),"
        )
        
        # update inputs
        inner_content = inner_content.replace(
            "fillColor: Colors.white.withValues(alpha: 0.05)",
            "fillColor: AppTheme.cardBaseColor.withValues(alpha: 0.3)"
        )
        inner_content = inner_content.replace(
            "borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))",
            "borderSide: const BorderSide(color: AppTheme.glassBorder)"
        )
        
        # elevated buttons
        inner_content = re.sub(
            r'ElevatedButton\(\s*style: ElevatedButton\.styleFrom\([^)]+\),\s*onPressed:',
            r'''Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.9),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppTheme.primaryCyan, width: 1.5),
                        ),
                        elevation: 0,
                      ),
                      onPressed:''',
            inner_content
        )
        
        # fix child: Text for ElevatedButton
        inner_content = inner_content.replace("child: Text(", "child: const Text(")
        inner_content = inner_content.replace(
            "child: const Text(\n                    AppLocalization.get('update_profile'),", 
            "child: Text(\n                    AppLocalization.get('update_profile'),"
        )

        # change integrations and security cards to glass cards
        inner_content = re.sub(
            r'decoration: BoxDecoration\(\s*color: AppTheme\.cardBaseColor,\s*borderRadius: BorderRadius\.circular\(\d+\),\s*border: Border\.all\([^)]+\),\s*\)',
            r'decoration: AppTheme.glassDecoration(borderRadius: BorderRadius.circular(20))',
            inner_content
        )
        
        with open(screen_path, "w", encoding="utf-8") as f:
            f.write(inner_content)
        
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

update_account_screen()
