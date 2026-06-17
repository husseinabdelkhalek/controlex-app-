import json
import re

def extract_file(filename, check_str):
    with open(r'C:\Users\pc\.gemini\antigravity-ide\brain\f1c89e0e-004b-409d-b078-59b8fd63d5fa\.system_generated\logs\transcript.jsonl', 'r', encoding='utf-8') as f:
        for line in f:
            if check_str in line:
                data = json.loads(line)
                content = data.get('content', '')
                if check_str in content and 'The following code has been modified' in content:
                    # Parse the lines
                    lines = content.split('\n')
                    output = []
                    found_start = False
                    for l in lines:
                        if re.match(r'^\d+: ', l):
                            found_start = True
                            output.append(l.split(': ', 1)[1])
                        elif found_start and not l.strip():
                            # Sometimes empty lines don't have the number prefix if it's the end, 
                            # wait, view_file prints `12: ` even for empty lines.
                            # If it doesn't match `\d+: `, we might be at the end of the file view block
                            # But wait, view_file always prefixes empty lines like `13: ` 
                            # If we hit something else, maybe the file ended.
                            pass
                    
                    if output:
                        with open(filename, 'w', encoding='utf-8') as out:
                            out.write('\n'.join(output) + '\n')
                        print(f'Recovered {filename}')
                        return

extract_file('lib/theme/app_theme.dart', 'class AppTheme')
extract_file('lib/widgets/glass_card.dart', 'class GlassCard')
extract_file('lib/screens/dashboard_screen.dart', 'class DashboardScreen')
extract_file('lib/widgets/interactive_grid.dart', 'class InteractiveGrid')
