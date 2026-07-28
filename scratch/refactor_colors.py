import os
import re

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # 1. Replace hardcoded colors with AppColors
    content = re.sub(r'\bColors\.blue(?:Accent)?\b', 'AppColors.info', content)
    content = re.sub(r'\bColors\.green(?:Accent)?\b', 'AppColors.success', content)
    content = re.sub(r'\bColors\.red(?:Accent)?\b', 'AppColors.danger', content)
    content = re.sub(r'\bColors\.orange(?:Accent)?\b', 'AppColors.warning', content)
    content = re.sub(r'\bColors\.yellow(?:Accent)?\b', 'AppColors.warning', content)
    content = re.sub(r'\bColors\.amber(?:Accent)?\b', 'AppColors.warning', content)
    content = re.sub(r'\bColors\.white\b', 'AppColors.background', content)
    content = re.sub(r'\bColors\.black\b', 'AppColors.textPrimary', content)
    content = re.sub(r'\bColors\.grey\b', 'AppColors.textSecondary', content)
    content = re.sub(r'\bColors\.transparent\b', 'Colors.transparent', content) # ignore

    # Replace some common hardcoded hex colors
    # e.g., Color(0xFF2196F3) -> AppColors.info
    # We will just do a general removal of `const` wherever `AppColors` is used inside it.

    # 2. Strip `const` from widget constructors containing AppColors.
    # This is tricky with regex. A common pattern is `const Icon(Icons.add, color: AppColors.primary)`
    # We can replace `const Icon(` with `Icon(` if we see AppColors in the same line or next few lines.
    # Actually, a safer regex is finding `const ` followed by an identifier, and if that block contains AppColors, remove `const`.
    # Since dart format often puts these on one line or formats them nicely, let's just do a naive pass:
    # If a line contains `const ` and `AppColors.`, remove the `const `.
    
    lines = content.split('\n')
    new_lines = []
    
    # We also have to handle multi-line consts. A robust way is to use Dart's own analyzer, but for a quick script:
    # We'll just look for `const ` on the same line as `AppColors.` or `Colors.` which got replaced.
    
    for line in lines:
        if 'const ' in line and 'AppColors.' in line:
            # We must be careful not to replace `const String` or `const double` etc.
            # Usually it's `const Icon(` or `const Text(`.
            line = re.sub(r'\bconst\s+([A-Z][a-zA-Z0-9_]*\()', r'\1', line)
            # Also handle `const EdgeInsets` if it happens to be on the same line, though harmless to leave if no AppColors inside it, wait if it has AppColors it's illegal.
        
        # Also remove `const ` before `AppColors` directly if someone did `color: const AppColors.primary` (though rare)
        line = re.sub(r'\bconst\s+AppColors\.', 'AppColors.', line)
        
        new_lines.append(line)

    content = '\n'.join(new_lines)

    if content != original:
        # Check if we need to add import for AppColors if we added it
        if 'AppColors' in content and 'app_theme.dart' not in content:
            # this is a bit naive but works for a flutter project if we just assume standard paths,
            # or we let `flutter analyze` and IDE auto-imports handle the rest.
            pass

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
                    print(f"Modified: {file_path}")
    
    print(f"Total files modified: {modified_count}")

if __name__ == '__main__':
    main()
