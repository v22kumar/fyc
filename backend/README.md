# FYC Connect Backend – Community Operating System

Welcome to the FYC Connect Backend! This repository contains the centralized API gateway powering the FYC Connect multi-platform system (Flutter Mobile App, Next.js Admin Portal, and Web). 

This platform is not an isolated ERP—it is designed as a highly reusable, multi-tenant Community Operating System.

## Architecture & Core Philosophy

The system uses **FastAPI**, **SQLAlchemy**, and **PostgreSQL** (with a fallback to SQLite for local development). 
Everything is strictly partitioned by `organization_id` using our `TenantModelMixin` and `TenantMiddleware` to support hundreds of organizations seamlessly.

We prioritize **reusable platform services** over feature-specific implementations.

### 1. Platform Infrastructure
- **Tenant Isolation**: Every API request must pass through `TenantMiddleware`, resolving the `organization_id` via HTTP headers or API Keys. Almost all models inherit from `TenantModelMixin`.
- **Soft Delete & Flexible Metadata**: Every model inheriting from `TimestampMixin` automatically receives `deleted_at` (for soft deletion) and `metadata_json` (for feature-agnostic AI readiness and extensions).
- **Organization Settings**: Handled dynamically via `OrganizationSettings` and `FeatureFlag`. No need to hardcode tenant-specific colors or rules.

### 2. Unified Services (The "Core")
Instead of building features in isolation, modules rely on:
- **Community Activity Engine**: Automatically logs actions (`app/services/activity_engine.py`) and generates chronological timelines per entity or globally (the Community Feed).
- **Global Search Engine**: `/api/v1/search` dynamically queries across Users, Tournaments, Events, News, and Issues.
- **Workflow & Approvals Engine**: Avoids hardcoding complex state machines. Any entity can transition through standard workflows or require moderation via `ApprovalRequest`.
- **Media Library & Attachments**: A central `MediaLibraryItem` table stores images, PDFs, and videos across the platform.
- **Tagging & Follows**: Generic `Tag`, `EntityTag`, and `SavedItem` models to support categorizing and bookmarking anything.
- **Dynamic Forms**: Custom JSON-driven forms (`FormDefinition`) for event registrations and volunteer sign-ups without altering the database schema.

### 3. Module Relationships
Modules do not duplicate logic. For instance:
- **Events** and **Sports** trigger the `ActivityEngine` when published or completed.
- **Public Issues** rely on the unified `Comment` and `Attachment` APIs for progress updates and evidence photos.
- **Users (Volunteers/Members)** accrue statistics dynamically via `GET /api/v1/users/me/journey`, aggregating data from the `TreeRegistration`, `BloodDonor`, `EventAttendance`, and `PublicIssue` tables.

## Deployment & Environment Setup

### Local Development
1. `python3 -m venv venv && source venv/bin/activate`
2. `pip install -r requirements.txt`
3. Copy `.env.example` to `.env` and fill in necessary keys.
4. `uvicorn app.main:app --reload`
5. The system will automatically seed the database with a default organization (`fyc-nagercoil`) and superadmin account (`vrn2252@gmail.com` / `V22@kumar`).

### Fly.io Production Deployment
1. Ensure the `fly.toml` is configured properly.
2. `fly deploy`
3. The platform is wrapped in `fastapi.BackgroundTasks` and `APScheduler` for lightweight cron jobs (Morning Digests, Birthday Notifications). For heavier loads, ensure the machine scale supports it.

## Notification Setup (FCM & WhatsApp)

1. **Firebase Cloud Messaging (FCM)**: The `app.services.notifications` module handles FCM via Google Cloud credentials. Place `serviceAccountKey.json` securely via secrets or environment variables.
2. **WhatsApp Broadcasts**: Requires the Twilio/WhatsApp Cloud API keys configured in the `.env` file to successfully run the `run_morning_broadcast` job.

## System Health APIs
Admins and DevOps should utilize `GET /api/v1/system/health` to monitor the operational status of the Database, Storage writes, and CPU/Memory overhead.
