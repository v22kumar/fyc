"""Regression tests for the four notification defects fixed together.

Each test names the defect it pins. All of them run offline: the WhatsApp
tests capture the request body instead of sending it, which is the only way to
check a payload shape without a Meta account.

What these tests CANNOT prove is called out in test_whatsapp_defects — the
payload matching Meta's published contract is checked here; Meta accepting it
is not, and needs one real send against an approved template.
"""
import asyncio

import pytest


# ── DEF-01 · the legacy FCM module is gone ────────────────────────────────────

def test_legacy_fcm_module_is_gone():
    """app.services.notifications targeted the FCM legacy HTTP API, which
    Google decommissioned in June 2024. It must not come back."""
    with pytest.raises(ModuleNotFoundError):
        __import__("app.services.notifications")


def test_nothing_imports_the_legacy_module():
    """A reintroduced import would silently stop delivering again — the old
    helpers caught their own errors and returned False."""
    import pathlib

    app_dir = pathlib.Path(__file__).resolve().parent.parent / "app"
    offenders = [
        str(p.relative_to(app_dir))
        for p in app_dir.rglob("*.py")
        if "from app.services.notifications import" in p.read_text(encoding="utf-8")
        or "from app.services import notifications" in p.read_text(encoding="utf-8")
    ]
    assert offenders == [], f"legacy FCM module imported by: {offenders}"


def test_issue_notifications_expose_three_distinct_messages():
    """The reporter's acknowledgement and the volunteer's assignment used to be
    the same message, so reporting a pothole told you to go and fix it."""
    from app.services import issue_notifications as n

    assert hasattr(n, "notify_issue_received")
    assert hasattr(n, "notify_issue_assigned")
    assert hasattr(n, "notify_issue_resolved")


@pytest.mark.parametrize(
    "key",
    [
        "issue.received", "issue.assigned", "issue.resolved",
        "birthday.self", "birthday.member",
    ],
)
def test_new_i18n_keys_resolve_in_every_registered_language(key):
    """Hardcoded Tamil/English strings were what the deleted module carried.
    Their replacements must exist in all four registered languages."""
    from app.core import i18n

    params = {"category": "Roads", "name": "Meena"}
    for lang in i18n.REGISTERED_LANGS:
        for part in ("title", "body"):
            text = i18n.t(f"{key}.{part}", lang, **params)
            assert text, f"{key}.{part} missing for {lang}"
            assert "{" not in text, f"{key}.{part} left an unfilled placeholder in {lang}"


# ── DEF-02 · template parameters reach the payload ────────────────────────────

class _CapturedPost:
    """Stands in for requests.post and records what it was given."""

    def __init__(self):
        self.json = None

    def __call__(self, url, headers=None, json=None, timeout=None):
        self.json = json

        class _Resp:
            status_code = 200

            @staticmethod
            def raise_for_status():
                return None

        return _Resp()


def _send_with(monkeypatch, parameters):
    from app.services import whatsapp_service as ws

    captured = _CapturedPost()
    monkeypatch.setattr(ws.requests, "post", captured)
    provider = ws.MetaCloudWhatsAppProvider(api_key="k", phone_number_id="1")
    assert provider.send_template("+919876543210", "tmpl", parameters) is True
    return captured.json


def test_template_parameters_are_sent_as_body_components(monkeypatch):
    """DEF-02: send_template accepted a parameters argument and dropped it, so
    every {{1}} went out empty or Meta rejected the message outright."""
    body = _send_with(monkeypatch, ["Warriors", "Summer Cup"])

    components = body["template"]["components"]
    assert components == [{
        "type": "body",
        "parameters": [
            {"type": "text", "text": "Warriors"},
            {"type": "text", "text": "Summer Cup"},
        ],
    }]


def test_parameter_order_is_preserved(monkeypatch):
    """Meta's body parameters are positional. Order is the whole contract."""
    body = _send_with(monkeypatch, ["first", "second", "third"])
    texts = [p["text"] for p in body["template"]["components"][0]["parameters"]]
    assert texts == ["first", "second", "third"]


def test_no_components_block_when_there_are_no_parameters(monkeypatch):
    """A template with no variables must not be sent an empty components list —
    Meta rejects a parameter count that disagrees with the template."""
    body = _send_with(monkeypatch, None)
    assert "components" not in body["template"]


def test_dict_parameters_still_work_and_are_ordered(monkeypatch):
    """Accepted for backward compatibility, sorted by key, warned about."""
    body = _send_with(monkeypatch, {"a_first": "1", "b_second": "2"})
    texts = [p["text"] for p in body["template"]["components"][0]["parameters"]]
    assert texts == ["1", "2"]


def test_non_string_parameters_are_coerced(monkeypatch):
    """Meta requires text; a score or a count must not serialise as an int."""
    body = _send_with(monkeypatch, [7, None])
    texts = [p["text"] for p in body["template"]["components"][0]["parameters"]]
    assert texts == ["7", "None"]


def test_live_callers_pass_ordered_sequences():
    """The two real callers used to pass dicts whose sorted order was wrong:
    {"title": …, "body": …} sorts body before title."""
    import inspect

    from app.routers import sports
    from app.services import notification_service

    for mod in (sports, notification_service):
        src = inspect.getsource(mod)
        assert "parameters={" not in src, (
            f"{mod.__name__} passes WhatsApp template parameters as a dict; "
            "Meta's parameters are positional — pass a list"
        )


# ── DEF-03 · no group send against an endpoint that has none ──────────────────

def test_group_send_is_gone():
    """DEF-03: the Cloud API has no group messaging on /messages, so
    recipient_type=group could only ever fail — and did, silently."""
    from app.services import whatsapp_broadcast

    assert not hasattr(whatsapp_broadcast, "send_to_group")


def _code_without_comments(path) -> str:
    """Source with comments removed.

    A comment explaining why a pattern is banned must not itself trip the ban,
    or the only way to document the rule is to delete the documentation. Borrowed
    from SEASON BLACK's scripts/content-lint.sh, which hit this exact problem —
    and so did the first version of this test, which failed on the note above
    send_to_group's removal.
    """
    import io
    import tokenize

    src = path.read_text(encoding="utf-8")
    try:
        tokens = [
            t for t in tokenize.generate_tokens(io.StringIO(src).readline)
            if t.type != tokenize.COMMENT
        ]
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return src  # unparseable: fail loud rather than silently skipping it
    return tokenize.untokenize(tokens)


def test_no_group_recipient_type_anywhere_in_app():
    import pathlib

    app_dir = pathlib.Path(__file__).resolve().parent.parent / "app"
    offenders = [
        str(p.relative_to(app_dir))
        for p in app_dir.rglob("*.py")
        if '"recipient_type": "group"' in _code_without_comments(p)
    ]
    assert offenders == [], f"unsupported group send reintroduced in: {offenders}"


def test_broadcast_status_no_longer_reports_a_phantom_failure():
    """group_ok was always False, telling an admin a delivery had failed when
    no such delivery was ever possible."""
    from app.services.whatsapp_broadcast import _last_broadcast

    assert "group_ok" not in _last_broadcast
    assert set(_last_broadcast) == {"run_at", "members_sent", "members_failed"}


# ── DEF-06 · _run_async works with and without a running loop ─────────────────

async def _answer():
    return "value"


def test_run_async_without_a_running_loop():
    """The ordinary case: an APScheduler worker thread or a sync route."""
    from app.services.ai_service import _run_async

    assert _run_async(_answer()) == "value"


def test_run_async_inside_a_running_loop():
    """DEF-06: the old code detected this case, did nothing about it (an empty
    `pass`), then called run_until_complete anyway and raised."""
    from app.services.ai_service import _run_async

    async def outer():
        # _run_async is sync and blocking; run it off the loop thread, which is
        # how a sync route called from async code would reach it.
        return await asyncio.get_running_loop().run_in_executor(
            None, _run_async, _answer()
        )

    assert asyncio.run(outer()) == "value"


def test_run_async_returns_none_instead_of_raising():
    """A digest is worth degrading, not worth a 500."""
    from app.services.ai_service import _run_async

    async def boom():
        raise RuntimeError("upstream is down")

    assert _run_async(boom()) is None
