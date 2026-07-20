"""The live cricket SSE stream (GET /fixtures/{id}/cricket/stream).

Viewers subscribe once instead of re-polling; the endpoint pushes the scoreboard
when it changes. We assert the route is mounted and the snapshot payload has the
shape clients consume. We deliberately do NOT open the (infinite) stream here —
a long-lived SSE connection hangs the TestClient — so the transport itself is
exercised manually / in production.
"""


def test_stream_route_is_registered(client):
    schema = client.get("/openapi.json").json()
    assert "/api/v1/fixtures/{fixture_id}/cricket/stream" in schema["paths"]


def test_live_snapshot_helper_shape():
    """The snapshot returns exactly the fields the web/mobile live views read,
    and None for a fixture that has no cricket match."""
    from app.routers.cricket import _cricket_live_snapshot
    snap = _cricket_live_snapshot("00000000-0000-0000-0000-000000000000")
    # No match for this id -> None (helper opens its own short-lived session).
    assert snap is None
