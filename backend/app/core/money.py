"""Money, in whole paise, because a float is not money.

This module exists because of a specific property of this repository: the test
suite runs on SQLite and production runs on Postgres. SQLite has no decimal
type, so a `Numeric` column round-trips through a C double there while behaving
exactly as advertised in production. The arithmetic that passes in CI is then
not the arithmetic the club's ledger performs, and the difference surfaces as a
total somebody reads aloud at a meeting and cannot reconcile.

So money is an integer number of paise everywhere inside the system. ₹3,500 is
350000. Sums are integer sums. Rupees exist only at the two edges — parsing
what a treasurer typed, and formatting what an admin reads.

Indian digit grouping is not decoration either: ₹1,00,000 and ₹100,000 are the
same number, and only one of them is legible to the people using this app.
"""
from __future__ import annotations

from decimal import Decimal, InvalidOperation

# A single contribution above this is almost certainly a typo — an extra zero
# on ₹1,00,000. Refused with a message that says so rather than silently
# recording a lakh as ten. Not a policy about how much anyone may give; the
# ceiling is deliberately far above any plausible single donation.
MAX_CONTRIBUTION_PAISE = 100_00_00_000  # ₹1,00,00,000

# What the club planned per head for the Anniversary. A default the entry
# screen pre-fills, never a rule — people give more and less, and the schema
# has no opinion about it.
DEFAULT_SUGGESTED_PAISE = 3_500_00  # ₹3,500


def rupees_to_paise(value) -> int:
    """Parse what somebody typed into whole paise.

    Accepts an int, a float, a Decimal or a string with the usual decorations
    ("₹3,500", "3500.50", " 3500 "). Rejects anything that is not a number, and
    anything with sub-paise precision, rather than rounding it away quietly.
    """
    if isinstance(value, bool):
        raise ValueError("Amount must be a number.")
    if isinstance(value, int):
        return value * 100

    if isinstance(value, str):
        cleaned = value.strip().replace("₹", "").replace(",", "").replace(" ", "")
        if not cleaned:
            raise ValueError("Amount is required.")
        try:
            dec = Decimal(cleaned)
        except InvalidOperation:
            raise ValueError(f"'{value}' is not an amount.")
    else:
        try:
            dec = Decimal(str(value))
        except InvalidOperation:
            raise ValueError(f"'{value}' is not an amount.")

    paise = dec * 100
    # Decimal("Infinity") satisfies the precision check below, because
    # to_integral_value() of infinity is infinity — and int() then raises
    # OverflowError, which escapes the validator as a 500 instead of a
    # "that is not an amount" the member can act on. NaN gets the wrong
    # message for the same reason.
    if not paise.is_finite():
        raise ValueError(f"'{value}' is not an amount.")
    if paise != paise.to_integral_value():
        raise ValueError("Amounts go down to paise, no further.")
    return int(paise)


def paise_to_rupees(paise: int) -> Decimal:
    """Exact rupees for display or export. Decimal, never float."""
    return (Decimal(int(paise)) / 100).quantize(Decimal("0.01"))


def group_indian(whole: int) -> str:
    """12345678 → '1,23,45,678'.

    Last three digits, then pairs. `format(n, ',')` gives the wrong answer for
    every amount above ₹99,999, which is exactly the range a campaign total
    lives in.
    """
    s = str(abs(int(whole)))
    if len(s) <= 3:
        head = s
    else:
        last3, rest = s[-3:], s[:-3]
        pairs = []
        while len(rest) > 2:
            pairs.insert(0, rest[-2:])
            rest = rest[:-2]
        if rest:
            pairs.insert(0, rest)
        head = ",".join(pairs) + "," + last3
    return ("-" if whole < 0 else "") + head


def format_paise(paise: int, *, symbol: bool = True) -> str:
    """'₹1,00,000' for a round amount, '₹1,00,000.50' when the paise matter.

    Trailing '.00' is dropped because nobody writing a receipt by hand would
    add it, and every amount in this app is round in practice.
    """
    rupees = paise_to_rupees(paise)
    whole = int(rupees)
    fraction = abs(int((rupees - whole) * 100))
    text = group_indian(whole)
    if fraction:
        text = f"{text}.{fraction:02d}"
    return f"₹{text}" if symbol else text


def validate_contribution_paise(paise: int) -> int:
    """The two rules every contribution amount must satisfy."""
    if paise <= 0:
        raise ValueError("A contribution has to be more than zero.")
    if paise > MAX_CONTRIBUTION_PAISE:
        raise ValueError(
            f"{format_paise(paise)} looks like a typo — the most a single "
            f"contribution can be is {format_paise(MAX_CONTRIBUTION_PAISE)}."
        )
    return paise
