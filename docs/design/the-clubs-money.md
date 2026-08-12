# The club's money

FYC needed to record who contributed to the anniversary. What it got is a
contribution ledger the anniversary happens to be the first tenant of, because
"anniversary payments" is a table you rewrite in 2027 and a campaign is a row
you create.

Three new tables. Not one column changed on `events`, `users`, or anything
else — and that is a design constraint, not a coincidence. This repository has
no migration tool: schema changes ride a startup reconcile in `main.py`, where
`create_all` makes brand-new tables for free but an altered column needs a
hand-written `ALTER` line. One of those has been forgotten before, and it took
down every read of `user_profiles`. New tables are the shape that cannot fail
that way.

## Money is an integer number of paise

The suite runs on SQLite. Production runs on Postgres. SQLite has no decimal
type, so a `Numeric` column round-trips through a C double there while behaving
exactly as advertised in production — the arithmetic that passes in CI is not
the arithmetic the club's ledger performs.

That is a bad way to find out about a currency type, and the way you find out
is a total somebody reads aloud at a meeting and cannot reconcile.

So ₹3,500 is `350000`. Sums are integer sums. Rupees exist at exactly two
edges: parsing what a treasurer typed, and formatting what an admin reads. The
formatting happens on the *server*, and the app is handed both the paise and
the string, so the two can never disagree about whether ₹1,00,000 has its
commas in the Indian places. `format(n, ',')` gets that wrong for every amount
above ₹99,999 — which is the entire range a campaign total lives in.

## A treasurer is an appointment, not a role

`users.role` has six values and this module adds none. A seventh would follow
the person into every other campaign and every future year; the requirement is
the opposite — being trusted with the anniversary collection is not a standing
power.

So `finance_campaign_assignments` is a row, scoped to one campaign, revoked
rather than deleted. "Who was allowed to take money in August" is a question
the club may need to answer later, and a deleted row cannot answer it.

**Verification follows the role.** Executives and above turn a treasurer's
claim into the club's record. Being appointed to collect does not make somebody
a verifier, which is the entire point of the distinction between *recorded* and
*verified*.

The rule lives in exactly one function, `finance_access.resolve`. Cricket
answers the equivalent question with the same four-line comparison copy-pasted
at four call sites. It works — the risk is the fifth copy, written in a hurry,
that forgets. The ledger is not where that should be discovered, so the
deliverable of that milestone was the *negative* tests: nineteen of them, over
HTTP, asserting what each kind of caller cannot do.

One of those tests caught its own harness. Four permission tests passed on the
first run for the wrong reason — the requests were missing `X-Organization-ID`,
so every one of them was 403 before it ever reached an authorization rule. A
test that asserts 403 will happily pass on the wrong 403.

## Three things look like recording a payment twice

They have different causes, and treating them as one problem is why duplicate
protection usually ends up either useless or infuriating.

**The request arrived twice.** A double tap, a retry, an offline entry replayed
after it already landed. Not a duplicate at all — the same payment, described
again. The client generates an id before the network is involved; the second
request returns the first row and nobody is told anything, because nothing
happened. Uniqueness is a database constraint rather than a check-then-insert,
because two concurrent requests both pass a check.

**The same transaction reference.** A UTR is unique in the real world, so two
of them in one collection is always an error. Refused outright, naming the row
that already has it — *"UTR 123456 is already recorded — ₹1,000 from Ravi."* A
withdrawn row leaves the index, so a reference typed in error and cancelled
does not block the correct entry replacing it.

**Same person, same amount, minutes apart.** Might be a mistake. Might be two
neighbours who each gave ₹500 in cash. Only a human knows, so the server asks
and the app offers *"It's another one"*. This one deliberately reaches across
treasurers, which catches the duplicate that actually happens at an event: Ravi
pays once, Arun writes it in his phone and Suresh writes it in his. Neither has
done anything wrong and neither can see the other's list, so nothing but the
server is in a position to notice.

## Nothing is deleted, and nothing is stored twice

Withdrawing a contribution requires a reason and keeps the row. Rejection and
cancellation stay separate statuses because "this was never real" and "this was
real and has been undone" are different facts about the club's money, and the
distinction is the only thing that would ever explain the total.

Every change writes to `AuditLog` — the table the club already has, already
carrying who, when, against which row, from what, to what. A finance-specific
audit table would have been one more thing to keep correct in exchange for no
additional truth.

And there is no running-total column anywhere. Every figure on the dashboard is
derived from the rows on read, the same call already made for cricket standings
and net run rate. A stored total is a second source of truth that goes wrong
quietly, and here the thing going quietly wrong is how much money the club
thinks it has.

## Where the target went

`target_amount_paise` is nullable, settable and clearable at any time, because
the club has not decided one yet and may raise it halfway through.

Nullable rather than zero, and the summary reports `null` rather than a number.
Zero would make the dashboard claim 100% collected on the first rupee, and 0%
remaining when nothing has been raised.

`suggested_amount_paise` is the other half of that: ₹3,500 a head is this
year's plan, so it lives on the campaign where an admin can change it — not as
a constant in the app that would need a release.

## The boundary left for expenses

`contributions` is income only. It carries no sign, no direction flag and no
type discriminator, and it should not acquire one. An expense is a different
table under the same campaign, with its own approver and its own vocabulary.
Letting money flow both ways through this table is exactly what would make the
eventual expense module a rewrite instead of an addition.

## What is not here

**The app.** This is the backend: three tables, one router, 76 tests. The
screens a treasurer will actually use are the next milestone, and they are
deliberately not shipping in the week of a code freeze and a chess tournament.

**Cash in hand.** The system will confidently report ₹62,500 collected while
some of it is still in a treasurer's pocket, and that gap is what causes an
argument in year one. The answer is a settlement record — treasurer hands cash
to the club — and the schema leaves room for it. What ships now does not claim
to be a cash-in-hand figure, and should not be read as one.

**Receipts, pledges, refunds, partial payments.** `certificates.py` already
renders PDFs and `notification_service.py` already delivers things. None of
them need a schema change this design forecloses. None of them are here.
