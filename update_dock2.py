import re
import os

def update_dock(filepath, is_local):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # The current dock starts with `Positioned(` under `// Unified Horizontal Floating Glass Quick-Action Dock`
    # and ends with `        ],` of the Stack.
    
    # We will search for the entire dock block and replace it.
    start_marker = "// Unified Horizontal Floating Glass Quick-Action Dock"
    
    # Let's write the new dock for dashboard_screen
    dashboard_dock = '''// Unified Horizontal Floating Glass Quick-Action Dock
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundBase.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: AppTheme.primaryCyan.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // AI Assistant Button
                      _buildDockButton(
                        tourKey: _aiTourKey,
                        icon: Icons.smart_toy_outlined, // Changed icon
                        color: Colors.purpleAccent,
                        onTap: () {
                          showGlassDialog(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.5),
                            builder: (context) => const AiChatOverlay(),
                          );
                        },
                      ),

                      // Central Pulsing Mic / Voice Control Button
                      _buildCenterVoiceButton(),

                      // Create Widget Button
                      _buildDockButton(
                        tourKey: _addKey,
                        icon: Icons.dashboard_customize_outlined, // Changed icon
                        color: AppTheme.primaryViolet,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ).then((_) => _loadWidgets()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }'''

    local_dock = '''// Unified Horizontal Floating Glass Quick-Action Dock
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundBase.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: AppTheme.primaryCyan.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Logout / Exit Button
                      _buildDockButton(
                        key: null,
                        icon: Icons.power_settings_new_outlined, // Changed icon
                        color: Colors.redAccent,
                        onTap: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (r) => false,
                        ),
                      ),
                      
                      // Local Settings Button
                      _buildDockButton(
                        key: null,
                        icon: Icons.tune, // Changed icon
                        color: AppTheme.primaryCyan,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LocalSettingsScreen()),
                        ).then((_) => _init()),
                      ),
                      
                      // Central Pulsing Mic / Voice Control Button
                      _buildCenterVoiceButton(),
                      
                      // Smart Scenes Button
                      _buildDockButton(
                        key: null,
                        icon: Icons.electric_bolt_outlined, // Changed icon
                        color: Colors.amberAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmartScenesScreen(isLocalMode: true)),
                        ).then((_) => _loadScenes()),
                      ),
                      
                      // AI Assistant Button
                      _buildDockButton(
                        key: _aiTourKey,
                        icon: Icons.smart_toy_outlined, // Changed icon
                        color: Colors.purpleAccent,
                        onTap: () {
                          showGlassDialog(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.5),
                            builder: (context) => const AiChatOverlay(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }'''

    # Find where the dock starts
    start_index = content.find(start_marker)
    if start_index == -1:
        return
        
    # We replace from start_marker up to the end of `Widget _buildDockButton` definition which comes right after the dock block ends.
    # Actually, it's easier to just use regex to replace everything from `// Unified` down to `    );` before `  }`
    end_marker = "    );\n  }"
    
    # We'll locate the end_marker that comes after start_marker
    dock_block_pattern = re.compile(re.escape(start_marker) + r'.*?        \],\n      \),\n    \);\n  \}', re.DOTALL)
    
    new_dock = local_dock if is_local else dashboard_dock
    content = dock_block_pattern.sub(new_dock, content)
    
    # We also want to change the mic icon in _buildCenterVoiceButton
    content = content.replace("Icons.mic", "Icons.graphic_eq")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f"Updated {filepath}")

update_dock("lib/screens/dashboard_screen.dart", False)
update_dock("lib/screens/local_dashboard_screen.dart", True)
