import os
import re

def fix_all():
    # 1. ai_daily_digest_card.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\ai\presentation\widgets\ai_daily_digest_card.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+AiSkeletonBar', 'AiSkeletonBar', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

    # 2. blood_donation_hub_screen.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\blood_donation\presentation\screens\blood_donation_hub_screen.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+LinearGradient', 'LinearGradient', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

    # 3. chess_home_page.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\chess\presentation\pages\chess_home_page.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        # Change `Color valueColor = AppColors.background,` to `Color? valueColor,`
        # and then we need to set it inside if it's a widget. 
        # Wait, if it's a constructor for a StatelessWidget or similar, 
        # we can't easily assign it if it's a field.
        # Let's inspect chess_home_page.dart first. We'll do it manually.
        pass

    # 4. ai_game_page.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\chess\presentation\pages\ai_game_page.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+TextSpan', 'TextSpan', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

    # 5. green_fyc_screen.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\green_fyc\presentation\screens\green_fyc_screen.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+AlwaysStoppedAnimation', 'AlwaysStoppedAnimation', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

    # 6. journey_screen.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\journey\presentation\screens\journey_screen.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+CircleAvatar', 'CircleAvatar', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

    # 7. cricket_scoring_screen.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\sports\presentation\screens\cricket_scoring_screen.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+LinearGradient', 'LinearGradient', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

    # 8. cricket_overs_history.dart
    f = r'c:\WorkStation\FYC_Connect\mobile\lib\features\sports\presentation\widgets\cricket_overs_history.dart'
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as file:
            c = file.read()
        c = re.sub(r'const\s+LinearGradient', 'LinearGradient', c)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(c)

if __name__ == '__main__':
    fix_all()
