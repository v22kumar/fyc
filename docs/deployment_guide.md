# FYC Connect — VPS Deployment Guide

## Prerequisites
- Ubuntu 22.04 LTS VPS (minimum 1 vCPU, 2 GB RAM, 20 GB SSD)
- Domain pointed to the VPS IP:
  - `fyc.org` → VPS IP
  - `www.fyc.org` → VPS IP
  - `api.fyc.org` → VPS IP
  - `admin.fyc.org` → VPS IP
- SSH access as root or sudo user

## 1. Install Docker & Docker Compose

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker
docker --version   # Docker 26+
```

## 2. Clone the Repository

```bash
git clone https://github.com/v22kumar/fyc.git /opt/fyc
cd /opt/fyc
git checkout claude/end-to-end-readiness-b531n1
```

## 3. Configure Environment Variables

```bash
cp .env.example .env
nano .env
```

**Required changes in `.env`:**
| Variable | Action |
|---|---|
| `POSTGRES_PASSWORD` | Set a strong random password |
| `SECRET_KEY` | Run: `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `OTP_BYPASS_CODE` | Leave **empty** in production |
| `FIRST_SUPERADMIN_PHONE` | Your admin mobile number |
| `FIRST_SUPERADMIN_PASSWORD` | Strong admin password |
| `PUBLIC_API_BASE` | `https://api.fyc.org` |
| `PUBLIC_DEFAULT_ORG_ID` | Leave as default or use your org UUID |

## 4. Build & Start Services

```bash
# Build all Docker images (takes 3–5 minutes first time)
docker compose build

# Start in background
docker compose up -d

# Verify all containers are healthy
docker compose ps
```

Expected output:
```
NAME            STATUS          PORTS
fyc-db-1        healthy
fyc-api-1       healthy
fyc-web-1       running
fyc-admin-1     running
fyc-nginx-1     running         0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

## 5. Initialise the Database (First Run Only)

```bash
docker compose exec api python scripts/init_db.py
```

This creates all tables and the first SUPER_ADMIN user.

## 6. SSL Certificates with Let's Encrypt

Install Certbot and generate certificates:

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx \
  -d fyc.org -d www.fyc.org \
  -d api.fyc.org -d admin.fyc.org \
  --non-interactive --agree-tos -m admin@fyc.org

# Restart nginx to apply
docker compose restart nginx
```

Auto-renewal is handled by certbot's systemd timer — verify it:
```bash
sudo systemctl status certbot.timer
```

## 7. Verify Deployment

Run the verification checklist:
```bash
# Backend health
curl https://api.fyc.org/api/v1/organizations/

# Public web
curl -I https://fyc.org/

# Admin login page
curl -I https://admin.fyc.org/login

# API docs (Swagger)
open https://api.fyc.org/docs
```

## 8. Operations Reference

### View logs
```bash
docker compose logs -f api        # Backend logs
docker compose logs -f nginx      # Access logs
docker compose logs -f db         # Database logs
```

### Update deployment
```bash
git pull origin claude/end-to-end-readiness-b531n1
docker compose build
docker compose up -d
```

### Database backup
```bash
docker compose exec db pg_dump -U fyc fyc_connect > backup_$(date +%Y%m%d).sql
```

### Restore from backup
```bash
cat backup_20241201.sql | docker compose exec -T db psql -U fyc fyc_connect
```

### Reset admin password
```bash
docker compose exec api python -c "
from app.core.database import SessionLocal
from app.core.security import get_password_hash
from app.models.user import User
db = SessionLocal()
u = db.query(User).filter(User.phone_number == '+919876543210').first()
u.password_hash = get_password_hash('new_password_here')
db.commit()
print('Password updated')
"
```

## 9. Firewall Setup

```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
sudo ufw status
```

> **Block direct access to service ports** (8000, 3000, 4321) — they are internal only, routed through nginx.

## 10. Mobile App (Flutter)

The Flutter APK must be built locally (or in CI). Point it to the production API:

```bash
# In mobile/, update lib/core/constants/api_constants.dart:
# static const String baseUrl = 'https://api.fyc.org';

flutter build apk --release
# Distribute via Firebase App Distribution or direct APK share
```

---

## Architecture Diagram

```
Internet
    │
    ▼
[nginx :80/:443]  ← SSL termination (Let's Encrypt)
    ├── fyc.org / www.fyc.org  → [Astro :80]  ← static HTML/CSS/JS
    ├── admin.fyc.org          → [Next.js :3000]
    └── api.fyc.org            → [FastAPI :8000]
                                        │
                                  [PostgreSQL :5432]
                                  [Uploads volume]
```
