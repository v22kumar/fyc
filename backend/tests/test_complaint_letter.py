"""The letter itself.

The skeleton is code so that a letter exists even when the model does not.
These check the shape holds without any model at all.
"""
from datetime import date

from app.services.complaint_letter import (
    CallRecord, Recipient, build_letter, maps_link,
)


def test_a_map_link_opens_the_pin():
    assert maps_link(8.1833, 77.4119).endswith("query=8.1833,77.4119")


def test_no_coordinates_no_link():
    assert maps_link(None, None) is None


def _letter(**kw):
    base = dict(
        recipient=Recipient("Assistant Engineer", "Nagercoil Corporation"),
        subject="Street light out at Vadasery",
        body="The light opposite the bus stand has been dead three weeks.",
        reporter_name="Arun Kumar",
    )
    base.update(kw)
    return build_letter(**base)


def test_the_letter_addresses_a_desk_not_a_person():
    _, body = _letter()
    assert body.startswith("To: Assistant Engineer, Nagercoil Corporation")


def test_the_reporter_signs_it():
    _, body = _letter(reporter_phone="+91 98400 00000")
    assert body.rstrip().endswith("+91 98400 00000")
    assert "Arun Kumar" in body


def test_a_promise_and_its_date_are_quoted_back():
    _, body = _letter(calls=[CallRecord("Assistant Engineer", date(2026, 8, 1), "PROMISED")])
    assert "1 August 2026" in body
    assert "said it would be attended to" in body
    assert "no action since" in body


def test_an_unanswered_call_is_recorded_as_such():
    _, body = _letter(calls=[CallRecord("Section Office", date(2026, 8, 2), "NO_ANSWER")])
    assert "without an answer" in body


def test_a_very_long_description_is_trimmed_not_the_address_block():
    """A mail client truncating the letter must not cost the officer the
    location and the reference."""
    _, body = _letter(body="x" * 9000, reference="FYC-1234",
                      place_name="Vadasery", latitude=8.1, longitude=77.4)
    assert "Reference: FYC-1234" in body
    assert "Vadasery" in body
    assert len(body) < 6000
