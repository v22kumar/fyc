# FYC Connect — Makefile
# Common operations for development and production deployment.
# Usage: make <target>

.PHONY: help dev prod build init-db logs backup restore test lint clean

# ── Default ───────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  FYC Connect — Available Commands"
	@echo "  ────────────────────────────────"
	@echo "  make dev         Start backend + DB only (local dev)"
	@echo "  make prod        Start full stack (all 5 services)"
	@echo "  make build       Rebuild all Docker images"
	@echo "  make init-db     Initialise DB and create first superadmin"
	@echo "  make logs        Tail all service logs"
	@echo "  make backup      Dump PostgreSQL to ./backups/"
	@echo "  make restore f=<file>  Restore from a backup file"
	@echo "  make test        Run backend test suite (57 tests)"
	@echo "  make lint        Run hardcoded-string CI check"
	@echo "  make clean       Stop and remove containers + volumes"
	@echo ""

# ── Development ───────────────────────────────────────────────────────────────
dev:
	docker compose up db api

prod:
	docker compose up -d

build:
	docker compose build --no-cache

# ── Database ──────────────────────────────────────────────────────────────────
init-db:
	docker compose exec api python scripts/init_db.py

backup:
	@mkdir -p backups
	docker compose exec db pg_dump -U $${POSTGRES_USER:-fyc} $${POSTGRES_DB:-fyc_connect} \
	  > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Backup saved to backups/"

restore:
	@test -n "$(f)" || (echo "Usage: make restore f=backups/backup_YYYYMMDD.sql" && exit 1)
	cat $(f) | docker compose exec -T db psql -U $${POSTGRES_USER:-fyc} $${POSTGRES_DB:-fyc_connect}

# ── Quality ───────────────────────────────────────────────────────────────────
test:
	cd backend && python -m pytest tests/ -v

lint:
	python scripts/check_hardcoded_strings.py

# ── Maintenance ───────────────────────────────────────────────────────────────
logs:
	docker compose logs -f

clean:
	docker compose down -v
	@echo "All containers and volumes removed."
