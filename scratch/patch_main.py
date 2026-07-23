import re
import sys

with open('backend/app/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add ai_router import
if 'from app.routers import ai as ai_router' not in content:
    content = content.replace(
        'from app.routers import weekly_games as weekly_games_router',
        'from app.routers import weekly_games as weekly_games_router\\nfrom app.routers import ai as ai_router'
    )

# 2. Add include_router
if 'app.include_router(ai_router.router, prefix="/api/v1")' not in content:
    content = content.replace(
        'app.include_router(weekly_games_router.router, prefix="/api/v1")',
        'app.include_router(weekly_games_router.router, prefix="/api/v1")\\napp.include_router(ai_router.router, prefix="/api/v1")'
    )

# 3. Add AI jobs
job_imports = """        from app.services.daily_digest import (
            run_thirukkural_digest, 
            run_news_digest, 
            run_evening_digest,
            run_ai_daily_digest_job,
            run_ai_news_summary_job
        )"""

job_schedules = """        scheduler.add_job(run_evening_digest, "cron", hour=14, minute=30, timezone="UTC",  # 8:00 PM IST
                          id="evening_digest", replace_existing=True)
                          
        # AI content caching jobs
        scheduler.add_job(run_ai_daily_digest_job, "cron", hour=0, minute=0, timezone="UTC",  # 5:30 AM IST
                          id="ai_daily_digest", replace_existing=True)
        scheduler.add_job(run_ai_news_summary_job, "cron", hour=1, minute=0, timezone="UTC",  # 6:30 AM IST
                          id="ai_news_summary", replace_existing=True)"""

if 'run_ai_daily_digest_job' not in content:
    content = content.replace(
        'from app.services.daily_digest import run_thirukkural_digest, run_news_digest, run_evening_digest',
        job_imports
    )
    
if 'id="ai_daily_digest"' not in content:
    content = content.replace(
        'scheduler.add_job(run_evening_digest, "cron", hour=14, minute=30, timezone="UTC",  # 8:00 PM IST\\n                          id="evening_digest", replace_existing=True)',
        job_schedules
    )

with open('backend/app/main.py', 'w', encoding='utf-8') as f:
    f.write(content)
print("main.py patched successfully")
