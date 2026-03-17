# Invoice Archiving — Confluence Knowledge Base

> Compiled from Confluence (confluence.united-internet.org) on 2026-03-17.
> Sources: spaces IBS, ACCCO, FHPMO, FSS, STRERP, ERP and others.

---

## Table of Contents

1. [Overview & Architecture](#1-overview--architecture)
2. [EASY Archive — Core System](#2-easy-archive--core-system)
3. [Invoice Generation & Archiving Process (IBS / Infor LN)](#3-invoice-generation--archiving-process-ibs--infor-ln)
4. [Re-generating Missing Invoices in Easy Archive (Workaround)](#4-re-generating-missing-invoices-in-easy-archive-workaround)
5. [Legal Archive Product (Billing Process)](#5-legal-archive-product-billing-process)
6. [EASY Archive @ Strato — Project (AR Documents)](#6-easy-archive--strato--project-ar-documents)
7. [Easy Archive Migration (IONOS Carve-Out)](#7-easy-archive-migration-ionos-carve-out)
8. [Invoice Management Process (ACCCO O2C)](#8-invoice-management-process-accco-o2c)
9. [Issue Invoice Document Process](#9-issue-invoice-document-process)
10. [Select, Generate and Post Invoice Data (incl. Tax Validation)](#10-select-generate-and-post-invoice-data-incl-tax-validation)
11. [Checking Invoices (Erzeugung, Archivierung) — STRERP](#11-checking-invoices-erzeugung-archivierung--strerp)
12. [Tax / Statutory Archiving Requirements](#12-tax--statutory-archiving-requirements)
13. [Historical Background — Archiving & Invoices (2019)](#13-historical-background--archiving--invoices-2019)

---

## 1. Overview & Architecture

The invoice archiving landscape spans multiple systems across the IONOS / United Internet group:

| System | Role |
|---|---|
| **EASY Archive** | Primary document archive for customer-facing documents (invoices, credit notes, dunning letters). Operated by **Cronon** on behalf of IONOS. |
| **OnBase** | Legacy archive (Strato); being decommissioned by **June 2026**. Historical O2C documents being migrated to EASY Archive. |
| **E-Archive (Access)** | Legacy archive (IONOS carve-out context). Historical documents being migrated to EASY Archive. |
| **HCP** (Hamburg Content Platform) | Generates PDF invoices and stores them in EASY Archive; sends e-mails to customers. |
| **Infor LN** (via Cronon) | ERP / Billing backend. Produces invoice data that is pushed to HCP/Bison and then archived. |
| **Bison** | Integration middleware between Infor LN and HCP/archive. |
| **DWH** (Data Warehouse) | Used to identify invoices not present in EASY Archive (reconciliation). |

**End-to-end flow:**
```
Contract in Infor LN
  → Billing / Invoice Generation (Infor LN / Cronon)
  → Bison integration
  → HCP: creates PDF, stores in EASY Archive, sends e-mail to customer
  → EASY Archive (persistent document store)
  → Accounts Receivable open entry in Infor LN
```

---

## 2. EASY Archive — Core System

- EASY Archive is the **single target platform** for all O2C documents (invoices, credit notes, cancellation documents, dunning letters).
- Operated by **Cronon** in collaboration with the IONOS team.
- Accessed by front-end systems (customer portal, agent tools) via read interfaces.
- **Legal requirement:** documents must be retained for statutory audit periods (GDPdU / GoBS compliance). Both PDF invoices *and* all underlying master and transactional data (prices, product data, customer addresses, VAT IDs, etc.) must be available.

### Archiving in EASY Archive — Synchronous / Asynchronous

- **As of August 2022:** synchronous document archiving is **not functional**. A workaround using an EBE (asynchronous processing) was implemented.
- Result: a small number of invoices are missing from EASY Archive daily; identified via a regular DWH ↔ EASY Archive reconciliation (at least monthly).

---

## 3. Invoice Generation & Archiving Process (IBS / Infor LN)

Source pages: `(3) Fakturierung` (IBS, page 144380478) and `EN_(3) Invoicing` (IBS, page 599576202).

The invoice generation runs **automatically every day** in the **Evening Job (Abendjob)** and **Invoice Generation Job (Rechnungserzeugungsjob)**.

### Steps

1. **Confirm billable items globally** — `cisli2219m000`
   - Path: Billing Extension → Debtors/AR → Invoice Generation → Processing Invoice Data → Globally Confirm Billable Items
   - Tick checkbox: *Special Sales Invoices (Rechnungen Sonderverkäufe)*
   - Parameters: Commercial Company (from/to), Special Sale ID (from/to)

2. **Review billable items after confirmation** — `cisli3600m000`
   - Path: Invoicing → 360° Overview Invoicing → Billable Items
   - Newly confirmed items get status **confirmed**; others remain unchanged.

3. **List Special Sales Invoices** — `cisli2520m000`
   - Path: Billing Extension → Invoicing → Invoice Data → Special Sales Invoices

4. **Manual invoicing of a single invoice**
   - In `cisli3600m000`, select billable items for the contract, filter by Customer Number and Date, click **Create Invoices**.

5. **Create and process invoice run** — `cisli2200m000`
   - Invoice run creation triggers document number assignment (Belegnummernvergabe) via the print step in Billing (`txstr2500m000`).

6. **Integration processing → HCP**
   - Invoice data sent via Bison to HCP.
   - HCP creates the PDF, stores it in EASY Archive, and sends the e-mail notification to the customer.

7. **General Ledger posting**
   - Open entry created in Accounts Receivable: `tfacr2520m000` (Invoice-to Business Partner — Open Entries).

---

## 4. Re-generating Missing Invoices in Easy Archive (Workaround)

Source page: `Regelprozess: Nachgenerieren von Rechnungen für das Easy Archiv ohne Emailversand` (IBS, page 178033063).

This is the **standard operating procedure** for re-archiving invoices that are not present in EASY Archive.

### Background

Due to the non-functional synchronous archiving (see §2), a daily gap exists. A reconciliation run (at minimum monthly) compares DWH invoices against EASY Archive.

### Process

1. **Identify missing invoices**
   - Query DWH for invoice numbers (including collective invoices / Sammelrechnungen).
   - Query EASY Archive database (excluding dunning notices).
   - Import both datasets into a working database (WorkerDB or dedicated Postgres instance).
   - Cross-reference via an INSERT into a work table.

2. **Re-generate via IPS (without e-mail)**
   - Missing invoices must be re-generated via **IPS** (Invoice Processing System).
   - **Critical:** re-processing must NOT trigger a regular e-mail dispatch to customers via Charon.
   - HCP has an additional connector for this: the field `SuppressRelay` in Pluton/Charon (implemented via ticket BSSBISON-1777).
   - To suppress relay: place data in the exchange drive `/media/ipsshare/norelay`.
   - The flag `SuppressRelay` is set so that Charon skips e-mail dispatch but still archives the document.

3. **Verification**
   - After re-generation, confirm the invoices appear in EASY Archive.

---

## 5. Legal Archive Product (Billing Process)

Source pages: `Legal Archive` (IBS, page 255760592), `EN_Legal Archive` (IBS, page 599576751), `Legal Archive` (FSS, page 437862860), `Legal Archive - Service 340` (FSS, page 437862916).

"Legal Archive" is both the **archiving system** and a **billable product** (Service ID 340) sold to B2B customers. Its end-to-end billing process in Infor LN is documented as follows.

### Master Data Setup

- **Contract & Contract Items** — Session `txstr1100m000`
  - Path: Billing Extension → Master Data → Contracts
  - Example contract: `89000152`
  - Contract items visible via: Actions → Contract Items

- **Product Configurator** — Session `txibd0501m000`
  - Path: Billing Extension → Billing → Master Data → Product Configurator
  - Tariff structure per product/tariff group/tariff block is configured here.
  - Tariff rates per period: Billing Unit, Validity, Amount, Free Allowances.

- **Conversion Factors** — Session `tcibd0103m000`
  - Path: Master Data → Code Definitions → Logistics Codes → Conversion Factors
  - Used for MiB → GiB conversion; must be entered and approved.

### Consumption Data Provisioning

- **Login ID for Consumption Data** — Session `txcdr0110m000`
  - Path: Billing Extension → Billing → Master Data → Product Configurator → Consumption Data Record → Master Data → Login ID for Consumption Data
  - Links Contract ↔ CDR Identifier ↔ Service ID.
  - CDR Identifier for Legal Archive (340): `871000084`
  - Interface: `createLegalArchiveUsageData` writes consumption data into Infor LN.
  - Raw consumption data lands in session `txcdr1540m000`.

### Consumption Data Processing

1. **Condense consumption data** — Session *Consumption Data Legal Archive*, option **Densify Consumption Data**.
   - Result in: `txcdr1545m000` (Legal Archive — Billing Data) and `txcdr1546m000` (Legal Archive — Billing Details).
   - Also creates due date structure: `txcdr2520m000`.

2. **Bill consumption data** — Session *Consumption Data Legal Archive*, option **Bill Consumption Data**.
   - Transfer to Billing: `txstr2500m000`.
   - Sequence number written back from Billing → `txcdr1545m000`.

### Invoice Creation

3. **Transfer invoice to invoicing** — Status changes from *Selected* → *Generated* in `txstr2500m000`.
4. **Confirm special sales** — `cisli2219m000`.
5. **Create and process invoice run** — `cisli2200m000`.
   - Document number assigned via print step → Billing (`txstr2500m000`) and Legal Archive Billing Data (`txcdr1545m000`).
6. **Open entry in AR** — `tfacr2520m000` (Invoice-to Business Partner — Open Entries).

---

## 6. EASY Archive @ Strato — Project (AR Documents)

Source page: `EASY Archive (AR Documents)` (FHPMO, page 623257660).

| Field | Value |
|---|---|
| Project ID | EASY |
| Project Name | EASY Archive@Strato (AR Documents) |
| Project Manager | Ileana Boero |
| Process Owner | Dirk Blumenthal |
| Project Client | Michael Klemund |
| Status | Green (on track) |
| Jira Project Ticket | PROJECTS-1334 |
| Implementation Ticket | BSSI-368 |

### Goal

Consolidate the O2C document archive by:
- **Phase 1:** Archive all newly generated O2C documents (invoices, credit notes, cancellations, dunning letters) in EASY Archive and connect all front-ends for read access.
- **Phase 2:** Migrate all historical O2C documents from **OnBase** (and E-Archive) to EASY Archive, validate completeness and integrity, and **decommission OnBase by June 2026**.

OnBase deactivation deadline: **June 2026** (mandatory; depends on PROJECTS-1334 and PROJECTS-1129).

### Document Types Covered

- Invoices (Rechnungen)
- Credit notes (Gutschriften)
- Cancellation documents (Stornodokumente)
- Dunning letters (Mahnschreiben)

---

## 7. Easy Archive Migration (IONOS Carve-Out)

Source page: `(12) Easy Archive Migration` (ACCCO, page 94509947).

### Background

IONOS's customer communication archiving (invoices, etc.) was historically based on the **Access archiving system**. The IONOS carve-out from United Internet / Access required a rebuild of the archiving system at IONOS. All IONOS customer documents must be migrated from the Access-based system to the new IONOS system (EASY Archive, operated by Cronon).

### Key People

| Role | Person |
|---|---|
| Target System Owner | Peter Schneewind |
| Easy Contact Person | Thomas Inselberger |
| Migration Executor | Cronon (via Easy) |

### Migration Model

- The Access system stores a **mix** of documents from Access, Hosting and Mail&Media.
- Database size: **multiple TB** (MySQL alone).
- Documents are migrated one-by-one via a script run by Easy/Cronon.
- During migration, two systems co-exist:
  - **Old Access system:** historical documents + document types not yet switched.
  - **New IONOS system (EASY Archive):** already migrated documents + switched document types.
- Migration is complete when all document types are switched to the new system (no new documents in Access) and all historical IONOS documents have been migrated and then deleted from Access.

---

## 8. Invoice Management Process (ACCCO O2C)

Source page: `Invoice Management` (ACCCO, page 445586796).

This is the **Level-2 process** within the Order-to-Cash (O2C) process framework. It contains four Level-3 sub-processes:

1. Select, generate and post invoice data (incl. tax validation)
2. Issue invoice document
3. *(credit note handling)*
4. *(cancellation handling)*

### Process Flow Summary

```
Contract activation
  → Decision: Credit Note OR Consumption Data collection
  → Select, generate and post invoice data (+ tax validation)
  → Issue invoice document
  → Invoice delivered to customer
  → Invoice archived
```

### Outputs

- Accurate and documented invoice data ready for processing.
- Invoices sent to customers through defined distribution channels.
- **Archived invoice documents for future reference.**
- Proper handling of credit notes / cancellations.

**Prerequisite:** confirmed contract from Contract Management; accurate consumption data (if usage-based).

---

## 9. Issue Invoice Document Process

Source page: `Issue invoice document` (ACCCO, page 445586833). Jira: BSSI-650.

### Scope

Only IONOS shop after ACCCO go-live for the market.

### Description

This process covers **output management** — invoice dispatch and archiving after invoice data is generated in Infor LN.

**Flow:**
```
Invoice data generated in Infor LN
  → Transferred to HCP via Bison
  → Decision: PDF invoice OR Electronic invoice (b2bRouter)
```

**PDF invoice path:**
1. HCP creates the PDF invoice.
2. HCP **archives the invoice** in EASY Archive.
3. HCP sends e-mail to the customer.
4. Invoice data transferred to b2bRouter.
5. b2bRouter validates that invoice amounts match between b2bRouter and Infor LN.
6. Invoice sent via b2bRouter.

**Electronic invoice path (b2bRouter integration):**
- Requires b2bRouter integration in the ACCCO architecture.
- Validation: invoice amounts in b2bRouter must match Infor LN.

### Systems Involved

- **Infor LN** — source of invoice data
- **Bison** — integration middleware
- **HCP** — PDF generation and archiving trigger
- **EASY Archive** — document storage
- **b2bRouter** — electronic invoice dispatch

---

## 10. Select, Generate and Post Invoice Data (incl. Tax Validation)

Source page: `Select, generate and post invoice data` (ACCCO, page 445586830). Jira: BSSI-688.

### Scope

Only IONOS shop after ACCCO go-live.

### Description

This process describes the **billing generation** step, from item selection through tax determination to posting.

**Input data collected for tax determination:**
- VAT ID (syntax-checked and register-validated)
- Customer address (with address score from address validation)
- Payment data and country
- Customer IP address and country
- Customer telephone number and country
- Consumption data (if usage-based)
- Products, prices, CO-PA features

**VAT ID Validation:**
- Syntax-checked VAT ID → register validation.
- Valid VAT ID → customer classified as **business customer**.
- Failed validation → customer classified as **end customer** → OSS process triggered.

**After validation:** Accounts Receivable validation → billing generation → confirmations → compressions.

**Scale:** supports **up to millions of invoices** with minimal manual intervention.

---

## 11. Checking Invoices (Erzeugung, Archivierung) — STRERP

Source page: `Rechnungen prüfen (Erzeugung, Archivierung, etc.)` (STRERP, page 156290812).

- The Infor status of each invoice can be checked via the **Rechnungen prüfen** program.
- Session `txdms2500m000` (Belege / Documents): allows searching by creation date, posting key, and document number.
- Visible fields: amount, currency, payment method, **Saperion status** (archiving system status).
- Used to verify that invoices have been correctly archived in Saperion/EASY Archive.

---

## 12. Tax / Statutory Archiving Requirements

Source page: `ACCCO — Abstimmung zu steuerlichen Archivierungsanforderungen` (ACCCO, page 86043157).

### Requirements

- Data must be retained for tax audits.
- Vouchers (Belege) and postings (Buchungssätze) must match.
- Providing PDF invoices alone is **not sufficient** — all master and transactional data that led to the invoice must also be available:
  - Price and product data
  - Customer master data (address, VAT ID, etc.)

### Assumptions

- All document data for active customers is fully migrated to EASY Archive (same scope as current Billing).
- Inactive customer data must also be transferred to EASY Archive in a suitable form for audit purposes.
- Historical booking data (Buchungssätze) remains in **RMCA** for the historical period.

### Legal Reference Documents

- **GDPdU-Konzept** (Grundsätze zum Datenzugriff und zur Prüfbarkeit digitaler Unterlagen):
  - `GDPdU-Konzept_2013_05_02.docx`
  - `GDPdU-Konzept_2016_06_21.docx`
- **Aufbewahrungsfristen** (Retention periods / definitions): original at Access Confluence, copy at UI Confluence (`https://confluence.united-internet.org/x/L2zgAw`).

### Data Architecture for Tax Audits

- EASY Archive: all document data (invoices + master data).
- RMCA (sub-ledger): historical booking data.
- Both systems must remain accessible and consistent.

---

## 13. Historical Background — Archiving & Invoices (2019)

Source page: `2019/07/18 Archiving and Invoices` (IOMAIL, page 28706164). Participants include Karl-Heinz Wagenblast, Matthias Riesterer, Christian Hatz, Michael Scholze, and others.

### Key Decisions / Discussion Points (July 2019)

- **EASY Archive separation:** Must be separated as part of the carve-out. Data delivery interfaces need to switch to the new system.
- **Cronon as partner:** Already in contact with Easy regarding migration. Status at that time: preparation phase.
- **Scope of EASY Archive:** Agreement needed on what documents should ultimately be in the archive (invoices, dunning letters, agent communications?).
- **Current state (2019):** Agent communications stored in MAPS, not EASY Archive. Incoming customer communication (fax, letters, emails) also in MAPS.
- **Invoice documents (Billing):** Rechnungen and Mahnschreiben generated by Billing. Interface agreement required to ensure correct PDF/ODT layout generation.
- **Switch sequence:** Archive switch expected *before* OMS (Order Management System) switch. Transition period handling to be clarified.
- **Signatures on invoices:** Under review whether legally still required for DE.
- **Genesis:** Being evaluated as a future data archiving system (all customer emails to be archived). Storage periods for marketing vs. process emails to be clarified. Legal storage requirements to be determined.
- **Product modeling:** Moving to Cronon (commercial + technical). SPIN / product catalog separation maintained.

---

## Summary: Key Facts for Invoice Archiving

| Topic | Detail |
|---|---|
| Primary archive system | EASY Archive (operated by Cronon) |
| Documents archived | Invoices, credit notes, cancellations, dunning letters |
| Generation system | Infor LN → Bison → HCP → EASY Archive |
| Missing invoice workaround | Re-generate via IPS with `SuppressRelay` flag; data in `/media/ipsshare/norelay` |
| Reconciliation frequency | At least monthly (DWH vs. EASY Archive) |
| Legacy systems | OnBase (Strato, decommission June 2026), E-Archive/Access (IONOS, migration ongoing) |
| Legal retention | GDPdU compliant; PDFs + all master/transactional data required |
| Tax audit readiness | EASY Archive (documents) + RMCA (postings) |
| Invoice archiving status check | Infor LN session `txdms2500m000`, field: Saperion status |
| Billing product "Legal Archive" | Service ID 340, CDR-based billing via `txcdr0110m000` / `txcdr1545m000` |
