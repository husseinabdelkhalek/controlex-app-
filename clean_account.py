import re

def clean_account_screen():
    path = "lib/screens/account_screen.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove unused imports
    content = content.replace("import '../core/api_constants.dart';", "")
    # Remove duplicate import
    content = re.sub(r'import \'package:url_launcher/url_launcher\.dart\';\n.*import \'package:url_launcher/url_launcher\.dart\';', r'import \'package:url_launcher/url_launcher.dart\';', content, flags=re.DOTALL)
    
    # Remove unused fields
    content = content.replace("bool _is2FALoading = false;", "")
    content = content.replace("bool _showAdafruit = true;", "")
    content = content.replace("bool _showFirebase = true;", "")
    content = content.replace("bool _showSessions = false;", "")
    
    # Remove references to these in _fetchData
    content = re.sub(r'bool hasAdafruit = _aioUserCtrl\.text\.isNotEmpty;.*_showFirebase = true;\s*}', '', content, flags=re.DOTALL)

    # Remove unused _buildTextField
    content = re.sub(r'Widget _buildTextField.*?\}', '', content, flags=re.DOTALL)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

clean_account_screen()
