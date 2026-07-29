import os
import re

directory = r'c:\WorkStation\FYC_Connect\mobile\lib'

def fix_imports_and_consts():
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                original = content
                
                # Check for AppColors usage and missing import
                if 'AppColors.' in content and 'app_theme.dart' not in content:
                    # insert import after last import
                    lines = content.split('\n')
                    last_import = -1
                    for i, line in enumerate(lines):
                        if line.startswith('import '):
                            last_import = i
                    if last_import != -1:
                        lines.insert(last_import + 1, "import 'package:fyc_connect/core/theme/app_theme.dart';")
                    else:
                        lines.insert(0, "import 'package:fyc_connect/core/theme/app_theme.dart';")
                    content = '\n'.join(lines)
                
                # Check for DSSpacing usage and missing import
                if 'DSSpacing.' in content and 'tokens.dart' not in content:
                    lines = content.split('\n')
                    last_import = -1
                    for i, line in enumerate(lines):
                        if line.startswith('import '):
                            last_import = i
                    if last_import != -1:
                        lines.insert(last_import + 1, "import 'package:fyc_connect/core/design_system/tokens.dart';")
                    content = '\n'.join(lines)

                # Strip const from common widgets if they use AppColors or DSSpacing in the file
                # To be safe and fix the multi-line issues, we'll just remove `const ` before these specific widgets throughout the file, which is perfectly valid Dart (just less optimized).
                if 'AppColors.' in content or 'DSSpacing.' in content or 'DSRadius.' in content or 'DSElevation.' in content:
                    widgets_to_unconst = [
                        'TextStyle', 'Icon', 'Text', 'CircularProgressIndicator', 
                        'EdgeInsets', 'SizedBox', 'BorderSide', 'Border', 'BorderRadius', 
                        'BoxDecoration', 'Padding', 'Container', 'Card'
                    ]
                    for w in widgets_to_unconst:
                        content = re.sub(r'\bconst\s+' + w + r'\b', w, content)

                if content != original:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Fixed: {file_path}")

if __name__ == '__main__':
    fix_imports_and_consts()
