# Collecting the government contacts

The civic directory ships with every office listed and **not one contact
detail**. That is the design, not an omission: a fabricated address for a real
public official is worse than an empty one, because the letter goes nowhere and
the log says it was delivered.

This is how the empty half gets filled.

## The one rule

**Nothing is written down that was not read on an official page.**

- Official sources only: district administration sites, department sites, NIC
  portals, official PDFs.
- Every contact records the exact URL it was read from and the date it was read.
- If no official contact is published, the record stays empty and is marked
  `not_found`. That is a real answer and it belongs in the report.
- Never a search-engine summary, never a business directory, never an inferred
  jurisdiction.

The importer enforces the first three mechanically — a contact without a source
or a date is rejected, not warned about — so the rule survives whoever is doing
the typing at 11pm.

## The workflow

```
python scripts/civic_contacts_worksheet.py > seeds/civic_contacts.worksheet.json
#   ... a human fills it in, from official pages only ...
python scripts/import_civic_contacts.py seeds/civic_contacts.worksheet.json
#   reads the file, writes civic_contacts_report.md, changes nothing
python scripts/import_civic_contacts.py seeds/civic_contacts.worksheet.json \
    --apply --org <organization-uuid>
```

The dry run is the default. `--apply` refuses to run at all if any record failed
its checks, so a half-good file cannot be half-imported.

## Where to start

Not at the top of the list. `GET /api/v1/civic/directory/health` ranks the empty
offices by how many blocked routes each one would open, and the ordering is
steep: in testing, filling in the District Collector and one local sanitary
office unblocked **20 of 28** routes on its own.

Fill in the top few, re-run health, repeat. Forty offices in list order is a
chore nobody finishes.

## What each record needs

```json
{
  "office_id": "COLLECTORATE/50/district_collector",
  "department": "COLLECTORATE",
  "office_name": "District Collectorate, Kanniyakumari",
  "designation_en": "District Collector",
  "designation_ta": "மாவட்ட ஆட்சியர்",
  "officer_name": null,
  "phone": null,
  "email": null,
  "address": null,
  "jurisdiction": null,
  "source_url": null,
  "verified_at": null,
  "confidence": "not_found",
  "notes": null
}
```

`office_id` is generated — never invent one. An id that is not in the canonical
list is rejected rather than created, so a typo cannot quietly add a desk that
does not exist.

`officer_name` is optional and never used for routing. Officers transfer; the
desk does not. `designation_en` is "Commissioner", not a person's name.

`confidence` is one of `official_government_website`, `official_pdf`,
`department_portal`, `not_found`.

## The 39 offices

### Ward Councillor / Ward Member — வார்டு உறுப்பினர்

*Start at:* Nagercoil Corporation ward list — https://www.tnurbantree.tn.gov.in/nagercoil/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `WARD_OFFICE/10/ward_councillor` | Ward Councillor | வார்டு உறுப்பினர் | any |

### Local Body — Engineering Wing — நகராட்சி — பொறியியல் பிரிவு

*Start at:* https://www.tnurbantree.tn.gov.in/nagercoil/ (Engineering wing)

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `ULB_ENGINEERING/20/assistant_engineer` | Assistant Engineer | உதவி பொறியாளர் | any |
| `ULB_ENGINEERING/30/commissioner@CORPORATION` | Commissioner | ஆணையர் | Corporation |
| `ULB_ENGINEERING/30/executive_officer@TOWN_PANCHAYAT` | Executive Officer | செயல் அலுவலர் | Town Panchayat |

### Local Body — Water Supply — நகராட்சி — குடிநீர் வழங்கல்

*Start at:* https://www.tnurbantree.tn.gov.in/nagercoil/ (Water supply)

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `ULB_WATER/20/assistant_engineer_water_supply` | Assistant Engineer — Water Supply | உதவி பொறியாளர் — குடிநீர் | any |
| `ULB_WATER/30/commissioner@CORPORATION` | Commissioner | ஆணையர் | Corporation |

### Local Body — Street Lighting — நகராட்சி — தெரு விளக்கு

*Start at:* https://www.tnurbantree.tn.gov.in/nagercoil/ (Street lighting)

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `ULB_ELECTRICAL/20/assistant_engineer_street_lighting` | Assistant Engineer — Street Lighting | உதவி பொறியாளர் — தெரு விளக்கு | any |
| `ULB_ELECTRICAL/30/commissioner@CORPORATION` | Commissioner | ஆணையர் | Corporation |

### Local Body — Health & Sanitation — நகராட்சி — சுகாதாரம் மற்றும் தூய்மை

*Start at:* https://www.tnurbantree.tn.gov.in/nagercoil/ (Health & sanitation)

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `ULB_HEALTH/20/sanitary_inspector` | Sanitary Inspector | சுகாதார ஆய்வாளர் | any |
| `ULB_HEALTH/30/city_health_officer@CORPORATION` | City Health Officer | நகர சுகாதார அலுவலர் | Corporation |

### Village Panchayat — ஊராட்சி

*Start at:* https://kanniyakumari.nic.in/localbodies/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `VILLAGE_PANCHAYAT/10/ward_member@VILLAGE_PANCHAYAT` | Ward Member | வார்டு உறுப்பினர் | Village Panchayat |
| `VILLAGE_PANCHAYAT/30/panchayat_president@VILLAGE_PANCHAYAT` | Panchayat President | ஊராட்சித் தலைவர் | Village Panchayat |

### Panchayat Union (Block) — ஊராட்சி ஒன்றியம்

*Start at:* https://kanniyakumari.nic.in/localbodies/ and https://tnrd.tn.gov.in/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `PANCHAYAT_UNION/30/block_development_officer` | Block Development Officer | ஊராட்சி ஒன்றிய வளர்ச்சி அலுவலர் | any |

### State Highways Department — மாநில நெடுஞ்சாலைத் துறை

*Start at:* Tamil Nadu Highways Department — district/divisional office listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `HIGHWAYS/40/assistant_divisional_engineer` | Assistant Divisional Engineer | உதவி கோட்டப் பொறியாளர் | any |
| `HIGHWAYS/50/divisional_engineer` | Divisional Engineer | கோட்டப் பொறியாளர் | any |

### National Highways Authority of India — தேசிய நெடுஞ்சாலை ஆணையம்

*Start at:* https://nhai.gov.in/ regional office listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `NHAI/50/project_director` | Project Director | திட்ட இயக்குநர் | any |

### TANGEDCO — Electricity Board — மின்சார வாரியம் (TANGEDCO)

*Start at:* https://www.tnebnet.org/ section/subdivision office listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `TANGEDCO/20/assistant_engineer_section_office` | Assistant Engineer — Section Office | உதவி பொறியாளர் — பிரிவு அலுவலகம் | any |
| `TANGEDCO/40/assistant_executive_engineer` | Assistant Executive Engineer | உதவி செயற்பொறியாளர் | any |
| `TANGEDCO/50/executive_engineer` | Executive Engineer | செயற்பொறியாளர் | any |

### TWAD Board — Water Supply & Drainage — குடிநீர் வடிகால் வாரியம்

*Start at:* https://twadboard.tn.gov.in/ division listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `TWAD/40/assistant_executive_engineer` | Assistant Executive Engineer | உதவி செயற்பொறியாளர் | any |
| `TWAD/50/executive_engineer` | Executive Engineer | செயற்பொறியாளர் | any |

### Revenue Department — வருவாய்த் துறை

*Start at:* https://kanniyakumari.nic.in/directory/ and https://www.cra.tn.gov.in/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `REVENUE/20/village_administrative_officer` | Village Administrative Officer | கிராம நிர்வாக அலுவலர் | any |
| `REVENUE/30/tahsildar` | Tahsildar | வட்டாட்சியர் | any |
| `REVENUE/40/revenue_divisional_officer` | Revenue Divisional Officer | வருவாய் கோட்டாட்சியர் | any |

### School Education Department — பள்ளிக் கல்வித் துறை

*Start at:* Kanniyakumari CEO/BEO listing on https://kanniyakumari.nic.in/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `SCHOOL_EDUCATION/20/headmaster` | Headmaster | தலைமை ஆசிரியர் | any |
| `SCHOOL_EDUCATION/30/block_education_officer` | Block Education Officer | வட்டாரக் கல்வி அலுவலர் | any |
| `SCHOOL_EDUCATION/50/chief_educational_officer` | Chief Educational Officer | முதன்மைக் கல்வி அலுவலர் | any |

### Public Health & Medical Services — பொது சுகாதாரத் துறை

*Start at:* Kanniyakumari DDHS listing on https://kanniyakumari.nic.in/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `HEALTH_SERVICES/20/block_medical_officer` | Block Medical Officer | வட்டார மருத்துவ அலுவலர் | any |
| `HEALTH_SERVICES/50/deputy_director_of_health_services` | Deputy Director of Health Services | துணை இயக்குநர், சுகாதாரப் பணிகள் | any |

### TN Pollution Control Board — மாசுக் கட்டுப்பாட்டு வாரியம்

*Start at:* https://tnpcb.gov.in/ district office listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `TNPCB/50/district_environmental_engineer` | District Environmental Engineer | மாவட்ட சுற்றுச்சூழல் பொறியாளர் | any |
| `TNPCB/60/member_secretary` | Member Secretary | உறுப்பினர் செயலாளர் | any |

### TN State Transport Corporation — அரசு போக்குவரத்துக் கழகம்

*Start at:* TNSTC Tirunelveli region — branch/divisional office listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `TNSTC/30/branch_manager` | Branch Manager | கிளை மேலாளர் | any |
| `TNSTC/50/divisional_manager` | Divisional Manager | கோட்ட மேலாளர் | any |

### Police — காவல் துறை

*Start at:* Kanniyakumari district police — station and SP office listing

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `POLICE/20/station_house_officer_inspector` | Station House Officer / Inspector | காவல் நிலை ஆய்வாளர் | any |
| `POLICE/40/deputy_superintendent_of_police` | Deputy Superintendent of Police | காவல் துணைக் கண்காணிப்பாளர் | any |
| `POLICE/50/superintendent_of_police` | Superintendent of Police | காவல் கண்காணிப்பாளர் | any |

### District Collectorate, Kanniyakumari — மாவட்ட ஆட்சியர் அலுவலகம்

*Start at:* https://kanniyakumari.nic.in/directory/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `COLLECTORATE/50/district_collector` | District Collector | மாவட்ட ஆட்சியர் | any |

### CM Helpline — IIPGCMS — முதலமைச்சர் உதவி மையம்

*Start at:* https://www.tn.gov.in/grievance

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `CM_HELPLINE/60/chief_minister_s_special_cell` | Chief Minister's Special Cell | முதலமைச்சர் சிறப்பு பிரிவு | any |

### CPGRAMS — Central Government Grievances — மத்திய அரசு குறைதீர் மையம்

*Start at:* https://pgportal.gov.in/

| Office id | Designation | Tamil | Applies to |
| --- | --- | --- | --- |
| `CPGRAMS/70/nodal_appellate_authority` | Nodal Appellate Authority | மைய மேல்முறையீட்டு அதிகாரி | any |

## Which department owns which complaint

The routing ladders, as seeded. A complaint climbs these in order.

**ROAD** (urban)

> Ward Councillor / Ward Member → Local Body — Engineering Wing → Local Body — Engineering Wing → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

*A road on a national or state highway belongs to NHAI or the Highways Department instead. Road class cannot be derived from GPS, so the club reviewer switches the route when they recognise the road.*

**ROAD** (rural)

> Village Panchayat → Village Panchayat → Panchayat Union (Block) → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**STREET_LIGHT** (urban)

> Ward Councillor / Ward Member → Local Body — Street Lighting → Local Body — Street Lighting → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**STREET_LIGHT** (rural)

> Village Panchayat → Panchayat Union (Block) → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**DRINKING_WATER** (urban)

> Ward Councillor / Ward Member → Local Body — Water Supply → Local Body — Water Supply → TWAD Board — Water Supply & Drainage → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**DRINKING_WATER** (rural)

> Village Panchayat → TWAD Board — Water Supply & Drainage → Panchayat Union (Block) → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**DRAINAGE** (urban)

> Ward Councillor / Ward Member → Local Body — Engineering Wing → Local Body — Engineering Wing → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**DRAINAGE** (rural)

> Village Panchayat → Panchayat Union (Block) → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**GARBAGE** (urban)

> Ward Councillor / Ward Member → Local Body — Health & Sanitation → Local Body — Health & Sanitation → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**GARBAGE** (rural)

> Village Panchayat → Panchayat Union (Block) → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**PUBLIC_HEALTH** (urban)

> Local Body — Health & Sanitation → Local Body — Health & Sanitation → Public Health & Medical Services → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**PUBLIC_HEALTH** (rural)

> Village Panchayat → Panchayat Union (Block) → Public Health & Medical Services → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**ELECTRICITY** (any)

> TANGEDCO — Electricity Board → TANGEDCO — Electricity Board → TANGEDCO — Electricity Board → CM Helpline — IIPGCMS

*A live or fallen wire is an emergency and belongs on the phone to 1912, not in a review queue.*

**ENCROACHMENT** (any)

> Revenue Department → Revenue Department → Revenue Department → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

*Land is a revenue subject, so this runs VAO → Tahsildar → RDO → Collector.*

**SCHOOL** (any)

> School Education Department → School Education Department → School Education Department → CM Helpline — IIPGCMS

**HEALTHCARE** (any)

> Public Health & Medical Services → Public Health & Medical Services → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**POLLUTION** (any)

> TN Pollution Control Board → TN Pollution Control Board → District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

**TRANSPORT** (any)

> TN State Transport Corporation → TN State Transport Corporation → CM Helpline — IIPGCMS

**SAFETY** (any)

> Police → Police → Police → CM Helpline — IIPGCMS

*Anything happening right now goes to 100, not through this ladder.*

**OTHER** (any)

> District Collectorate, Kanniyakumari → CM Helpline — IIPGCMS

## When a source disagrees with another

Record both, as two rows for the same `office_id`, each with its own
`source_url`. The importer reports the conflict with both URLs and lets a person
decide — a stale page is the usual cause, and picking a winner by rule is how the
wrong number becomes permanent.

## After import

Contacts go stale. `verified_at` is what makes that visible: the directory flags
an entry nobody has checked in a year rather than quietly using it. Re-checking
the handful of offices that matter most is a yearly job, not a one-off.

