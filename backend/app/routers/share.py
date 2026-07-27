"""Public share helpers: QR codes for short links.

The QR encodes the absolute short URL (e.g. https://fyc-web.fly.dev/e/K7P2) so a
printed notice or banner can carry it and anyone can scan straight to the event
or tournament. Rendered server-side (segno, pure-Python) so web, mobile and any
generated poster image all get an identical, dependency-free QR.
"""
import io
import re

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.core.config import settings

router = APIRouter(prefix="/share", tags=["Share"])

# Only our own short links may be encoded — this is not an open QR-for-anything
# service. A code is the short base32 alphabet we mint in core/short_code.py.
_SHORT_PATH = re.compile(r"^/(e|t)/[0-9A-Za-z]{3,12}$")


@router.get("/qr.svg")
def qr_svg(u: str = Query(..., description="Same-site short path, e.g. /e/K7P2")):
    """Return an SVG QR code for one of our short links. Cached hard — a code's
    target never changes, so the QR is immutable."""
    u = u.strip()
    if not _SHORT_PATH.match(u):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                            detail="Only /e/<code> or /t/<code> short links are allowed")

    import segno  # local import keeps startup lean

    url = f"{settings.WEB_BASE_URL.rstrip('/')}{u}"
    buf = io.BytesIO()
    segno.make(url, error="m").save(buf, kind="svg", scale=8, border=2, dark="#0f172a")
    return Response(
        content=buf.getvalue(),
        media_type="image/svg+xml",
        headers={"Cache-Control": "public, max-age=604800, immutable"},
    )
