import os
import re

directory = r'c:\WorkStation\FYC_Connect\mobile\lib'

def fix_all_consts():
    widgets = [
        'Center', 'Padding', 'SizedBox', 'Container', 'Row', 'Column', 'Align', 
        'Positioned', 'Expanded', 'Flexible', 'Stack', 'Text', 'Icon', 
        'CircularProgressIndicator', 'EdgeInsets', 'BorderSide', 'BorderRadius', 
        'BoxDecoration', 'Border', 'Card', 'DecoratedBox', 'Theme', 
        'ElevatedButton', 'OutlinedButton', 'TextButton', 'IconButton',
        'Divider', 'VerticalDivider', 'Spacer', 'Scaffold', 'AppBar',
        'BottomNavigationBar', 'FloatingActionButton', 'Drawer', 'SafeArea'
    ]
    pattern = r'\bconst\s+(' + '|'.join(widgets) + r')\b'
    
    modified_count = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                original = content
                
                # Check if it uses design tokens which were previously const
                if 'AppColors.' in content or 'DSSpacing.' in content or 'DSRadius.' in content or 'DSElevation.' in content:
                    content = re.sub(pattern, r'\1', content)

                if content != original:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    modified_count += 1
                    
    print(f"Total files stripped of const: {modified_count}")

if __name__ == '__main__':
    fix_all_consts()
