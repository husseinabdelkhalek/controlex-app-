import json

def extract_from_transcript(filename, log_path=r'C:\Users\pc\.gemini\antigravity-ide\brain\f1c89e0e-004b-409d-b078-59b8fd63d5fa\.system_generated\logs\transcript.jsonl'):
    view_file_found = False
    
    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                data = json.loads(line)
                
                # Check if it's a tool call to view_file for our filename
                if 'tool_calls' in data:
                    for tc in data['tool_calls']:
                        if tc.get('name') in ['default_api:view_file', 'view_file']:
                            args_str = tc.get('function', {}).get('arguments') or tc.get('args')
                            if isinstance(args_str, str):
                                args = json.loads(args_str)
                            else:
                                args = args_str or {}
                            if filename in args.get('AbsolutePath', ''):
                                view_file_found = True
                
                # If we found the call, the next message with 'content' might contain the tool response output
                # Or tool_responses block
                if view_file_found and data.get('type') == 'TOOL_RESPONSE':
                    if 'tool_responses' in data:
                        for resp in data['tool_responses']:
                            if 'output' in resp:
                                with open(filename, 'w', encoding='utf-8') as out:
                                    out.write(resp['output'])
                                print(f"Successfully recovered {filename}")
                                return True
            except Exception as e:
                pass
    return False

files_to_recover = [
    'lib/theme/app_theme.dart',
    'lib/widgets/glass_card.dart',
    'lib/screens/dashboard_screen.dart',
    'lib/widgets/interactive_grid.dart'
]

for f in files_to_recover:
    if not extract_from_transcript(f):
        print(f"Could not recover {f}")
