"""Sixty players, one hall, one wifi router.

The per-IP limit on /otp/send was 5/minute, and slowapi keys on the caller's
address — so a whole venue behind one NAT is a single bucket. Five players get
a code each minute; the rest get 429s that look, from a phone, exactly like the
app being broken. A registration desk would take a quarter of an hour to work
through the room and nobody would understand why.

The limit belongs on the number a code is sent to, not on the building the
players are standing in.
"""
import uuid

import pytest

from app.models.tenant import Organization
from app.routers import auth as auth_router


@pytest.fixture(autouse=True)
def _restore_throttle():
    yield
    auth_router._throttle_in_tests = False
    auth_router._otp_sends.clear()


def _org(db):
    org = Organization(id=uuid.uuid4(), slug=f"ot-{uuid.uuid4().hex[:6]}",
                       name_ta="நிறுவனம்", name_en="Org")
    db.add(org)
    db.commit()
    return org


def _send(client, org_id, phone):
    return client.post("/api/v1/auth/otp/send", json={
        "organization_id": str(org_id), "phone_number": phone})


def _clear():
    auth_router._otp_sends.clear()
    auth_router._throttle_in_tests = True


def test_a_hall_full_of_players_can_all_sign_in(client, db, monkeypatch):
    """The case the old limit could not survive.

    Every request here comes from the same address, because in a hall it does.
    """
    _clear()
    org = _org(db)
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: True)
    monkeypatch.setattr(auth_router.settings, "TWILIO_VERIFY_SID", "VAtest",
                        raising=False)

    for i in range(40):
        r = _send(client, org.id, f"+9198765{i:05d}")
        assert r.status_code == 200, \
            f"player {i} was refused a code — this is the registration desk"


def test_one_number_cannot_be_hammered(client, db, monkeypatch):
    """The limit that actually matters: per number, not per building."""
    _clear()
    org = _org(db)
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: True)
    monkeypatch.setattr(auth_router.settings, "TWILIO_VERIFY_SID", "VAtest",
                        raising=False)

    phone = "+919487984964"
    for _ in range(auth_router._OTP_PER_PHONE):
        assert _send(client, org.id, phone).status_code == 200

    blocked = _send(client, org.id, phone)
    assert blocked.status_code == 429
    assert "this number" in blocked.json()["detail"]


def test_one_persons_retries_never_block_the_person_beside_them(client, db,
                                                                monkeypatch):
    _clear()
    org = _org(db)
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: True)
    monkeypatch.setattr(auth_router.settings, "TWILIO_VERIFY_SID", "VAtest",
                        raising=False)

    for _ in range(auth_router._OTP_PER_PHONE + 2):
        _send(client, org.id, "+919000000001")

    assert _send(client, org.id, "+919000000002").status_code == 200, \
        "a neighbour's impatience is not this player's problem"


def test_a_refused_number_is_counted_not_just_logged(client, db, monkeypatch):
    """"It works for me and not for them" needs a number, not a log.

    A trial SMS plan only delivers to numbers verified in the provider's
    console. The owner's phone works; every player's does not — and from the
    server's side nothing looks wrong, because the request succeeded and the
    message simply never arrived. On the morning sixty players try at once
    that distinction is the whole event.
    """
    _clear()
    org = _org(db)
    before = auth_router.delivery_report()["refused"]

    monkeypatch.setattr(auth_router.settings, "TWILIO_VERIFY_SID", "VAtest",
                        raising=False)
    monkeypatch.setattr(auth_router.settings, "OTP_BYPASS_CODE", "",
                        raising=False)
    # Twilio refuses this number, and so does every fallback.
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: False)
    monkeypatch.setattr(auth_router, "deliver_otp",
                        lambda phone, otp, email=None: {"whatsapp": False,
                                                        "email": False})

    r = _send(client, org.id, "+919363608792")
    assert r.status_code == 502, "the club is told nobody could carry it"
    assert "organizer" in r.json()["detail"].lower()
    assert auth_router.delivery_report()["refused"] == before + 1


def test_a_delivered_code_is_counted_by_channel(client, db, monkeypatch):
    _clear()
    org = _org(db)
    monkeypatch.setattr(auth_router.settings, "TWILIO_VERIFY_SID", "VAtest",
                        raising=False)
    monkeypatch.setattr(auth_router, "send_verify_otp", lambda phone: True)

    assert _send(client, org.id, "+919000000123").status_code == 200
    assert auth_router.delivery_report()["by_channel"].get("sms", 0) >= 1
