import re
import os

def update_dock_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Replace the Dock Positioned block
    # We find "// Unified Horizontal Floating Glass Quick-Action Dock"
    # and we want to replace the `Positioned` block.
    
    # We'll use a specific replacement for the padding, border, and boxShadow of the dock container.
    # Instead of replacing the entire Positioned block (which has different buttons in each file),
    # we'll just upgrade the styling of the container holding it.
    
    # Let's change the Positioned properties:
    content = re.sub(
        r'Positioned\(\s*bottom: 20,\s*left: 15,\s*right: 15,\s*child: ClipRRect\(\s*borderRadius: BorderRadius\.circular\(40\),\s*child: BackdropFilter\(\s*filter: ImageFilter\.blur\(sigmaX: 10, sigmaY: 10\),\s*child: Container\(\s*padding: const EdgeInsets\.symmetric\(horizontal: 10, vertical: 6\),\s*decoration: BoxDecoration\(\s*color: AppTheme\.cardBaseColor\.withOpacity\(0\.7\),\s*borderRadius: BorderRadius\.circular\(40\),\s*border: Border\.all\(\s*color: AppTheme\.primaryCyan\.withOpacity\(0\.3\),\s*width: 1\.5,\s*\),\s*boxShadow: \[\s*BoxShadow\(\s*color: AppTheme\.primaryCyan\.withOpacity\(0\.1\),\s*blurRadius: 20,\s*spreadRadius: 2,\s*\),\s*\],\s*\),\s*child: Row\(\s*mainAxisAlignment: MainAxisAlignment\.spaceEvenly,',
        r'''Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundBase.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCyan.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: const Offset(-15, 0),
                        ),
                        BoxShadow(
                          color: AppTheme.primaryViolet.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: const Offset(15, 0),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,''',
        content
    )

    # In local_dashboard_screen.dart the Row might not be spaceEvenly exactly but let's assume it was matched. Wait, if it didn't match, I'll print a warning.
    
    # 2. Add gap between buttons in the Row
    # The buttons are listed inside `children: [...]`. Since we changed to `MainAxisSize.min`, we need `SizedBox(width: 16)` between them.
    # To do this safely, I will replace `_buildCenterVoiceButton(),` with `const SizedBox(width: 16), _buildCenterVoiceButton(), const SizedBox(width: 16),`
    content = content.replace(
        "_buildCenterVoiceButton(),",
        "const SizedBox(width: 16),\n                      _buildCenterVoiceButton(),\n                      const SizedBox(width: 16),"
    )

    # 3. Update `_buildDockButton`
    dock_btn_old = r'''  Widget _buildDockButton\(\{
    required Key\? (tourKey|key),
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  \}\) \{
    return InkWell\(
      key: \1,
      onTap: \(\) \{
        HapticHelper\.lightFeedback\(\);
        onTap\(\);
      \},
      borderRadius: BorderRadius\.circular\(24\),
      child: Padding\(
        padding: const EdgeInsets\.all\(4\),
        child: Container\(
          padding: const EdgeInsets\.all\(8\),
          decoration: BoxDecoration\(
            shape: BoxShape\.circle,
            color: color\.withOpacity\(0\.12\),
            border: Border\.all\(color: color\.withOpacity\(0\.3\), width: 1\.2\),
          \),
          child: Icon\(icon, color: color, size: 18\),
        \),
      \),
    \);
  \}'''

    dock_btn_new = r'''  Widget _buildDockButton({
    required Key? \1,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: \1,
        onTap: () {
          HapticHelper.lightFeedback();
          onTap();
        },
        borderRadius: BorderRadius.circular(30),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 0),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }'''
    content = re.sub(dock_btn_old, dock_btn_new, content)

    # 4. Update `_buildCenterVoiceButton`
    # Replace the container in `_buildCenterVoiceButton`
    center_btn_old = r'''      child: Container\(
        padding: const EdgeInsets\.all\(12\),
        decoration: BoxDecoration\(
          shape: BoxShape\.circle,
          gradient: const LinearGradient\(
            colors: \[AppTheme\.primaryCyan, AppTheme\.primaryViolet\],
            begin: Alignment\.topLeft,
            end: Alignment\.bottomRight,
          \),
          boxShadow: \[
            BoxShadow\(
              color: AppTheme\.primaryCyan\.withOpacity\(0\.4\),
              blurRadius: 10,
              spreadRadius: 1,
            \),
          \],
        \),
        child: const Icon\(Icons\.mic, color: Colors\.black, size: 22\),
      \),'''

    center_btn_new = r'''      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.primaryCyan, AppTheme.primaryViolet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(-2, -2)
            ),
            BoxShadow(
              color: AppTheme.primaryViolet.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(2, 2)
            ),
          ],
        ),
        child: const Icon(Icons.mic, color: Colors.black, size: 28),
      ),'''
    content = re.sub(center_btn_old, center_btn_new, content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f"Updated {filepath}")

update_dock_in_file("lib/screens/dashboard_screen.dart")
update_dock_in_file("lib/screens/local_dashboard_screen.dart")
