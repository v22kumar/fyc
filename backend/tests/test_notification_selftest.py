"""The notifications self-test endpoint: pushes to the caller's own device and
reports diagnostics. In the test environment Firebase isn't configured and the
user has no device token, so it must report both as false, still create the
in-app record, and never error."""
from tests.test_cricket_scoring import _make_org, _make_exec, _login, _h


def test_self_test_reports_diagnostics_and_records_inapp(client, db):
    org = _make_org(db)
    _make_exec(db, org.id, "9500000123")
    tok = _login(client, org.id, "9500000123")
    H = _h(org.id, tok)

    r = client.post("/api/v1/notifications/test", headers=H)
    assert r.status_code == 200, r.text
    body = r.json()
    # No Firebase + no token in the test env — reported honestly, no crash.
    assert body["firebase_initialised"] is False
    assert body["has_device_token"] is False
    assert body["push_sent"] is False
    assert isinstance(body["detail"], str) and body["detail"]

    # The in-app record is always created (visible in the bell regardless of push).
    from app.models.notification import Notification
    n = db.query(Notification).filter(Notification.notification_type == "TEST").first()
    assert n is not None
