import os
import re

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    lines = content.split('\n')
    new_lines = []
    
    for line in lines:
        # Check if the line contains a const that wraps DSSpacing or DSRadius
        if 'const ' in line and ('DSSpacing.' in line or 'DSRadius.' in line):
            # Remove const before common widgets that might wrap these
            line = re.sub(r'\bconst\s+(EdgeInsets|BorderRadius|SizedBox|Padding|Container|Radius)', r'\1', line)
            
            # Catch all: if it's still const something and contains DSSpacing/DSRadius
            if 'const ' in line and ('DSSpacing.' in line or 'DSRadius.' in line):
                line = re.sub(r'\bconst\s+', '', line)
        
        # Also remove const directly before them if present
        line = re.sub(r'\bconst\s+DSSpacing\.', 'DSSpacing.', line)
        line = re.sub(r'\bconst\s+DSRadius\.', 'DSRadius.', line)
        
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
                    print(f"Modified tokens: {file_path}")
    
    print(f"Total files modified for tokens: {modified_count}")

if __name__ == '__main__':
    main()
