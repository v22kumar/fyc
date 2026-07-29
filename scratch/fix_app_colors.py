import os
import re

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # 1. Fix textSecondary[X] and danger.shadeX
    content = re.sub(r'AppColors\.(textSecondary|danger|primary|success|warning|info)\[(\d{1,3})\]!?', lambda m: f"AppColors.{m.group(1)}.withOpacity(0.{m.group(2)[0]})", content)
    content = re.sub(r'AppColors\.(textSecondary|danger|primary|success|warning|info)\.shade(\d{1,3})', lambda m: f"AppColors.{m.group(1)}.withOpacity(0.{m.group(2)[0]})", content)

    # 2. Fix const usage with AppColors (e.g. const TextStyle(color: AppColors.background))
    # We will just strip const before TextStyle, Icon, CircularProgressIndicator, Text, TextButton, TextButton.styleFrom, BorderSide, BorderRadius, BoxShadow, BoxDecoration, etc.
    # A generic approach: if a line has "const " and "AppColors.", just remove the "const ".
    # This might remove valid consts on the same line, but in Flutter that's usually fine (it just becomes non-const).
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        if 'const ' in line and 'AppColors.' in line:
            line = re.sub(r'\bconst\s+', '', line)
        
        # If it's a default constructor param: `this.color = AppColors.background`
        # We can't use non-const in defaults. But we can't do much if it's required. Wait, we can change `this.color = AppColors.background` to `this.color` and set it in the body, or just leave it if it was not const but wait, default params MUST be const.
        # Let's fix `ai_sparkle.dart` manually later if needed, but let's try to fix it here:
        if 'this.color = AppColors' in line:
            line = line.replace('this.color = AppColors.background', 'this.color')
            # Note: this might break if it relied on it, but we can fix ai_sparkle manually.
            
        new_lines.append(line)

    content = '\n'.join(new_lines)

    if content != original:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

def main():
    directory = r'c:\WorkStation\FYC_Connect\mobile\lib'
    modified_count = 0
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                if process_file(file_path):
                    modified_count += 1
                    print(f"Modified AppColors: {file_path}")
    
    print(f"Total files modified: {modified_count}")

if __name__ == '__main__':
    main()
