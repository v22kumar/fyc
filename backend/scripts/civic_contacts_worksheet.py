"""Generate the collection worksheet for the civic directory.

The directory ships with every office listed and no contact details, because a
fabricated address for a real public official is worse than an empty one — the
letter goes nowhere and the log says it was delivered. Filling it in is human
work: reading official pages and writing down what is actually published.

This produces the sheet that work is done on. It is generated from
`seeds/civic_directory.py` rather than typed out, so the worksheet and the
canonical office list cannot drift apart — regenerate it after any change to the
seed and the new offices appear with empty fields.

Every record carries `source_hint`: the official page to look on. A hint is a
place to look, not a claimed fact, and it is stripped on import.

    python scripts/civic_contacts_worksheet.py > seeds/civic_contacts.worksheet.json
"""
import json
import re
import sys

sys.path.insert(0, ".")

from seeds.civic_directory import AUTHORITIES, DEPARTMENTS  # noqa: E402

#: Where each department's contacts are published, as far as this project knows.
#: Deliberately a *starting point for a human*, not a source of record: the page
#: may have moved, and whoever collects the data records the URL they actually
#: read, which is what lands in `source_url`.
SOURCE_HINTS = {
    "WARD_OFFICE": "Nagercoil Corporation ward list — https://www.tnurbantree.tn.gov.in/nagercoil/",
    "ULB_ENGINEERING": "https://www.tnurbantree.tn.gov.in/nagercoil/ (Engineering wing)",
    "ULB_WATER": "https://www.tnurbantree.tn.gov.in/nagercoil/ (Water supply)",
    "ULB_ELECTRICAL": "https://www.tnurbantree.tn.gov.in/nagercoil/ (Street lighting)",
    "ULB_HEALTH": "https://www.tnurbantree.tn.gov.in/nagercoil/ (Health & sanitation)",
    "VILLAGE_PANCHAYAT": "https://kanniyakumari.nic.in/localbodies/",
    "PANCHAYAT_UNION": "https://kanniyakumari.nic.in/localbodies/ and https://tnrd.tn.gov.in/",
    "TNRD": "https://tnrd.tn.gov.in/",
    "HIGHWAYS": "Tamil Nadu Highways Department — district/divisional office listing",
    "NHAI": "https://nhai.gov.in/ regional office listing",
    "TANGEDCO": "https://www.tnebnet.org/ section/subdivision office listing",
    "TWAD": "https://twadboard.tn.gov.in/ division listing",
    "REVENUE": "https://kanniyakumari.nic.in/directory/ and https://www.cra.tn.gov.in/",
    "SCHOOL_EDUCATION": "Kanniyakumari CEO/BEO listing on https://kanniyakumari.nic.in/",
    "HEALTH_SERVICES": "Kanniyakumari DDHS listing on https://kanniyakumari.nic.in/",
    "TNPCB": "https://tnpcb.gov.in/ district office listing",
    "TNSTC": "TNSTC Tirunelveli region — branch/divisional office listing",
    "POLICE": "Kanniyakumari district police — station and SP office listing",
    "COLLECTORATE": "https://kanniyakumari.nic.in/directory/",
    "CM_HELPLINE": "https://www.tn.gov.in/grievance",
    "CPGRAMS": "https://pgportal.gov.in/",
}


def office_id(dept_code: str, rung: int, designation_en: str, local_body) -> str:
    """A stable identifier for one desk.

    Built from the four things that distinguish an office — department, height,
    designation, and the kind of local body it belongs to — so re-running the
    worksheet against an unchanged seed produces identical ids and a collector's
    half-finished file still merges.
    """
    slug = re.sub(r"[^a-z0-9]+", "_", designation_en.lower()).strip("_")
    suffix = f"@{local_body.value}" if local_body else ""
    return f"{dept_code}/{int(rung)}/{slug}{suffix}"


def build() -> list[dict]:
    departments = {code: (en, ta) for code, en, ta, *_ in DEPARTMENTS}
    records = []
    for dept_code, rung, designation_en, designation_ta, local_body in AUTHORITIES:
        dept_en, _ = departments.get(dept_code, (dept_code, None))
        records.append({
            "office_id": office_id(dept_code, rung, designation_en, local_body),
            "department": dept_code,
            "department_name_en": dept_en,
            "office_name": None,
            "designation_en": designation_en,
            "designation_ta": designation_ta,
            "officer_name": None,
            "phone": None,
            "email": None,
            "address": None,
            "jurisdiction": local_body.value if local_body else None,
            "source_url": None,
            "verified_at": None,
            # Every office starts here honestly. A record still saying not_found
            # after collection means nobody could find a published contact,
            # which is a real answer and belongs in the report.
            "confidence": "not_found",
            "notes": None,
            "source_hint": SOURCE_HINTS.get(dept_code),
        })
    return records


if __name__ == "__main__":
    print(json.dumps(build(), indent=2, ensure_ascii=False))
