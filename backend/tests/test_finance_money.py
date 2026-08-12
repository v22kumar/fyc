"""Money is an integer number of paise, and this is why.

The suite runs on SQLite; production runs on Postgres. SQLite has no decimal
type, so a `Numeric` column round-trips through a C double there while behaving
exactly as advertised in production — the arithmetic that passes in CI is not
the arithmetic the club's ledger performs. The difference surfaces as a total
somebody reads aloud at a meeting and cannot reconcile.

So: integers, and a test that would actually notice.
"""
from decimal import Decimal

import pytest

from app.core.money import (MAX_CONTRIBUTION_PAISE, format_paise, group_indian,
                            paise_to_rupees, rupees_to_paise,
                            validate_contribution_paise)


def test_a_thousand_odd_amounts_sum_exactly():
    """The failure this module exists to prevent.

    Summed as floats, ₹0.10 a thousand times is not ₹100 — it is ₹100.00000000
    000001 or ₹99.99999999999999 depending on the order. As paise it is 10000,
    every time, in every order.
    """
    amounts = [rupees_to_paise("0.10")] * 1000
    assert sum(amounts) == 10000
    assert format_paise(sum(amounts)) == "₹100"


def test_indian_grouping_is_not_what_format_comma_gives_you():
    assert group_indian(100000) == "1,00,000"
    assert group_indian(12345678) == "1,23,45,678"
    # The one every naive implementation gets wrong.
    assert group_indian(100000) != format(100000, ",")


@pytest.mark.parametrize("typed,paise", [
    (3500, 350000),
    ("3500", 350000),
    ("₹3,500", 350000),
    (" 3500 ", 350000),
    ("3500.50", 350050),
    (Decimal("3500.5"), 350050),
])
def test_what_a_treasurer_might_type(typed, paise):
    assert rupees_to_paise(typed) == paise


def test_sub_paise_precision_is_refused_not_rounded_away():
    with pytest.raises(ValueError):
        rupees_to_paise("100.005")


def test_nonsense_is_refused():
    for bad in ("", "abc", "₹", True):
        with pytest.raises(ValueError):
            rupees_to_paise(bad)


def test_round_amounts_do_not_carry_a_pointless_decimal():
    assert format_paise(350000) == "₹3,500"
    assert format_paise(350050) == "₹3,500.50"
    assert format_paise(0) == "₹0"


def test_the_ceiling_catches_an_extra_zero():
    """₹1,00,000 typed as ₹1,00,00,000 is a plausible slip with a large blast
    radius — it would be the club's whole target, from one person."""
    validate_contribution_paise(100000 * 100)
    with pytest.raises(ValueError):
        validate_contribution_paise(MAX_CONTRIBUTION_PAISE + 1)


def test_zero_and_negative_are_not_contributions():
    for bad in (0, -100):
        with pytest.raises(ValueError):
            validate_contribution_paise(bad)


def test_export_amounts_are_exact_decimals_not_floats():
    assert paise_to_rupees(350050) == Decimal("3500.50")
    assert isinstance(paise_to_rupees(1), Decimal)
