# کیفینو — Kifino

<div dir="rtl">

**مرکز هوشمند مدیریت پول** — سیستم‌عامل مالی شخصی و کسب‌وکار کوچک، فارسی‌محور و کاملاً آفلاین: ثبت سریع درآمد و هزینه با زبان طبیعی فارسی، حساب‌ها، بودجه، بدهی و طلب، اقساط، چک، دارایی، اهداف، تراکنش‌های تکراری و یک ماژول **حسابداری دوبل** کامل با کدینگ استاندارد ایرانی.

</div>

**Kifino** is a Persian-first, offline-first finance app for individuals and small
businesses, built with Flutter for **Android** and **Windows**. Everything is
stored locally in SQLite; there is no account and no server.

This README is the handbook for **developers** (how the code works and how to
change it safely) and **designers** (the Kifino 2 design system and how to work
with it).

---

## Contents

1. [Feature map](#1-feature-map)
2. [Quick start](#2-quick-start)
3. [Project structure](#3-project-structure)
4. [Architecture](#4-architecture)
5. [Data, money & the database](#5-data-money--the-database)
6. [Feature internals](#6-feature-internals)
7. [Persian, RTL & dates](#7-persian-rtl--dates)
8. [Design system (for designers)](#8-design-system-for-designers)
9. [Testing](#9-testing)
10. [Build, sign & release](#10-build-sign--release)
11. [Conventions & contribution checklist](#11-conventions--contribution-checklist)
12. [Troubleshooting](#12-troubleshooting)
13. [Known limitations & roadmap](#13-known-limitations--roadmap)

---

## 1. Feature map

| Feature | What it does | Code |
|---|---|---|
| Dashboard | Net worth, this Jalali month's flow, quick actions, «پیش رو» (upcoming), insight, accounts, recent activity | `lib/features/dashboard` |
| Transactions | Income / expense / transfer, categories, tags, swipe-to-delete with undo, search | `lib/features/transactions`, `search` |
| Accounts | Bank cards, cash, savings, credit, investment, crypto; Toman/Rial/foreign currencies | `lib/features/accounts` |
| Recurring | Rent, salary, subscriptions, bills: auto-posted or reminded on a schedule | `lib/features/recurring` |
| Budgets | Category budgets with alert thresholds | `lib/features/budgets` |
| Debts & receivables | Who owes whom, partial payments, due dates | `lib/features/debts` |
| Installments | Loan plans, payment history, Jalali-month schedule | `lib/features/installments` |
| Checks | Iranian cheques (صیادی): issued/received, clear, bounce, history | `lib/features/checks` |
| Assets & goals | Gold, currency, property… and savings goals | `lib/features/assets`, `goals` |
| Business | Contacts, products, inventory (weighted-average cost), invoices, quotes, returns, aging report, PDF invoices | `lib/features/business` |
| Accounting | Double-entry: Iranian chart of accounts, vouchers, journal, ledger, trial balance, financial statements, fiscal years, audit log, bank reconciliation, XLSX legal books | `lib/features/accounting` |
| Analytics | Cash flow, category spending, runway, savings rate, budget adherence | `lib/features/analytics` |
| AI assistant | **Rule-based** (no network): Persian natural-language entry («۳۵۰ تومن اسنپ») and Iranian bank-SMS parsing | `lib/features/ai_assistant` |
| Security | PIN (PBKDF2) with lockout, biometrics, screenshot protection | `lib/features/security` |
| Backup | AES-256-GCM encrypted backup/restore, CSV export, balance repair | `lib/features/backup` |
| Notifications | Due-date reminders (installments, checks, debts, recurring) | `lib/features/notifications` |
| Multi-company | One database file per company/ledger, switchable | `lib/core/database/company_registry.dart` |
| Sync | Outbox queue only; **no server exists yet** (see §13) | `lib/features/sync` |

---

## 2. Quick start

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter | **3.47.9** (stable) | CI is pinned to this. Newer versions work locally with the caveats in §12. |
| Dart | ≥ 3.13 (bundled) | |
| JDK | 17 | Android builds |
| Android SDK | API level from Flutter defaults | an emulator or a device |
| Visual Studio 2022+ with "Desktop development with C++" | Windows builds only | |

### Run it

```bash
git clone git@github.com:ashkan9776/Kifino.git
cd Kifino
flutter pub get
flutter run                      # pick an Android device/emulator
flutter run -d windows           # on a Windows machine
```

The first launch runs onboarding (language → base currency → first account).
Generated Drift code (`*.g.dart`) is committed, so no code generation is needed
just to run the app.

> **Screenshots look black?** Screenshot protection (`FLAG_SECURE`) is on by
> default. Turn it off in **بیشتر → امنیت و رمز عبور**.

---

## 3. Project structure

```text
lib/
├── main.dart                 # bootstrap: root DI → company DI → background jobs → runApp
├── app/
│   ├── app.dart              # KifinoApp: BlocProviders, theme, lock overlay, lifecycle
│   ├── router/               # go_router config + bottom bar / navigation rail shell
│   ├── theme/                # AppTheme, AppColors (semantic), AppTypography, AppSpacing
│   └── localization/         # AppLocalizations (fa/en strings), Persian Material locale
├── core/
│   ├── constants/            # AppConstants (DB version…), AppCurrency (base currency)
│   ├── database/             # Drift database, tables/, migrations, company registry,
│   │                         #   account_balance.dart, currency_label_repair.dart
│   ├── design_system/        # tokens/ (colors, radii, shadows, motion) + showcase page
│   ├── di/                   # get_it ServiceLocator (root + company scopes)
│   ├── errors/               # Result<T>, Failure types, exceptions
│   ├── utils/                # Money, JalaliDate & formatters, TextNormalizer, logger…
│   └── widgets/              # shared components (AppCard, AppMoneyText, tiles…)
└── features/<feature>/
    ├── data/repositories/    # Drift-backed implementations
    ├── domain/               # entities, repository interfaces, pure services
    └── presentation/         # bloc|cubit/, pages/, widgets/

test/                         # mirrors lib/ — unit, bloc, repository, widget, golden tests
docs/                         # CI_CD.md, DESIGN.md
android/ windows/ web/        # platform runners (web is not a supported target)
third_party/vazirmatn/        # vendored font package
.github/workflows/            # ci.yml, release.yml, scheduled_health.yml
```

---

## 4. Architecture

### Layers

```text
Widget (page)  ──events──▶  Bloc / Cubit  ──calls──▶  Repository (interface, domain/)
      ▲                         │                          │
      └──── state (Equatable) ◀─┘                          ▼
                                                 RepositoryImpl (data/) ──▶ Drift AppDatabase
```

- **Domain** (`domain/`) has entities (immutable, `Equatable`), repository
  interfaces and pure services (`RecurringService`, `InstallmentSchedule`,
  `AutoVoucherService`…). No Flutter imports where avoidable.
- **Data** (`data/repositories/`) maps Drift rows to entities. Repositories
  return `Result<T>` (`Success` / `FailureResult`) instead of throwing; user-facing
  error messages are Persian.
- **Presentation** uses `flutter_bloc`. Most features watch a Drift stream
  (`watchX()`), so the UI updates itself after any write; there is no manual
  refresh.

### Dependency injection: two scopes

`get_it` (`lib/core/di/injection.dart`) uses two scopes:

| Scope | Lives for | Contains |
|---|---|---|
| **root** | the whole app run | `SharedPreferences`, `CompanyRegistry`, `CompanyController`, secure storage |
| **company** | one active company | `AppDatabase` (that company's file), every repository, service and bloc factory |

Switching company pops the company scope (closing its database) and pushes a new
one. `KifinoApp` re-keys the widget tree on the company id so every bloc is
rebuilt.

### Bootstrap order (`main.dart` → `ServiceLocator.init`)

1. Root scope.
2. Company scope: open DB → register repositories/services/blocs.
3. Set `AppCurrency.base` from saved settings, **before** anything computes money.
4. One-time data repairs (`CurrencyLabelRepair`), seed default categories and
   the chart of accounts, initialise notifications.
5. Fire-and-forget background jobs: prune the offline sync outbox, post due
   recurring transactions (also re-run on every app resume, see `app.dart`).
6. `runApp`.

### Navigation

`go_router` with a `StatefulShellRoute` of five tabs: **خانه / تراکنش‌ها /
تحلیل / کسب‌وکار / بیشتر** (`/dashboard`, `/activity`, `/analytics`,
`/business`, `/more`). Everything else is a full-screen route on the root
navigator (e.g. `/recurring`, `/recurring/edit`, `/accounting/...`,
`/transaction/new`). On screens ≥ 600 dp the shell becomes a `NavigationRail`.

---

## 5. Data, money & the database

### Money rules (read before touching amounts)

- Amounts are **integers in minor units** (`Money.minorUnits`); never `double`.
  Toman and Rial have 0 decimals, USD/EUR/GBP… have 2.
- Every stored amount carries its currency code. **Toman ↔ Rial convert ×10**
  (`Money.normalizeTo`, `isCompatibleWith`); other currency pairs are never
  mixed (there are no exchange rates).
- Totals are always shown in the user's **base currency** (`AppCurrency.base`).
  Normalise before summing. Never hard-code `Currency.irr` or `Currency.toman` in
  UI or blocs.
- Forms save in `AppCurrency.base` and label the field with
  `AppCurrency.base.symbol`.

### The balance invariant

> `account.currentBalance = initialBalance + Σ effects of its active transactions`

Every module that moves money creates a real transaction row, so this always
holds. `TransactionRepository.recomputeBalances()` rebuilds balances from this
rule; it's exposed to users as **بازسازی مانده‌ها** on the backup page. Modules
that change a balance outside the transaction repository (installments,
checks) must call `applyAccountBalanceDelta()` in
`core/database/account_balance.dart`, which converts Toman/Rial.

### Transactions owned by other modules

Auto-generated transactions remember their owner in
`sourceType` / `sourceId` (`TransactionSource`: installment, check, debt, goal):

| Source | Edit amount/account from Activity | Delete from Activity |
|---|---|---|
| installment, check | ✗ (use the module) | ✗ (use the module) |
| debt, goal | ✗ | ✓, and the debt/goal amount is reverted (undo re-applies it) |
| recurring (`recurringRuleId`) | ✓ (bills differ month to month) | ✓ |

### Schema & migrations

Drift, schema version in `AppConstants.databaseVersion` (currently **11**).

| Version | Change |
|---|---|
| 1 | base tables |
| 2 | financial goals |
| 3 | accounting (subjects, documents, transactions, fiscal years) |
| 4 | sync columns on accounting rows |
| 5 | audit log, detail ledgers/values/links |
| 6 | product secondary unit & conversion factor |
| 7 | installment payments |
| 8 | asset custom type name |
| 9 | product weighted-average cost |
| 10 | transaction `source_type`/`source_id` (+ backfill), `sync_queue.last_attempt_at`, `installments.first_due_date` |
| 11 | `recurring_rules` table |

**Adding a column or table:**

1. Edit/add the table in `lib/core/database/tables/` (register new tables in
   `@DriftDatabase(tables: [...])`).
2. Bump `AppConstants.databaseVersion`.
3. Add an `if (from < N)` block in `app_database.dart`. Use
   `_addColumnIfMissing` for columns, which makes the migration safe to re-run.
4. Regenerate: `dart run build_runner build --delete-conflicting-outputs`.
5. **Backups:** add new tables to export, wipe and restore in
   `backup_service.dart`. New columns need nothing: restore fills missing
   columns from their defaults (`_withColumnDefaults`), so old backups keep
   restoring. Give non-nullable new columns a `withDefault`.
6. Add a migration test (see `test/core/database/migration_v10_test.dart`, which
   rewinds a real file to an older version).

### Multi-company files

`CompanyRegistry.dbFileNameFor(id)`: the default company is `kifino_local.db`,
and others are `kifino_company_<id>.db`, all in the app documents directory.

---

## 6. Feature internals

### Recurring transactions (`features/recurring`)

- A rule has a start date, frequency (daily/weekly/monthly/yearly) and interval.
  Occurrence *n* is always computed **from the start date**
  (`Recurrence.occurrence`), so 31 Shahrivar → 30 Mehr → back to 31 later;
  months and years are Jalali.
- `RecurringService.postDue()` runs at startup and on resume. Occurrence *n* of
  rule *r* becomes transaction id `rec_<r>_<n>`, so a crash between posting and
  advancing can never double-post. Catch-up is capped at 62 per rule per run.
- `autoPost=false` rules only remind. The user confirms with **پرداخت شد**
  (`postNow`) or skips.
- Editing the schedule or resuming a paused rule restarts from today and never
  back-posts.
- Reminders: one local notification per rule, `remindDaysBefore` days ahead at
  09:00.

### Installments

`InstallmentSchedule` treats intervals that are multiples of 30 as Jalali months
anchored on `firstDueDate`. Paying, deleting a payment or settling all of it
keeps the plan, the account and the linked transactions consistent in one DB
transaction.

### Security

- PIN: PBKDF2-HMAC-SHA256 (120k iterations, run in an isolate), salted,
  constant-time compare; old SHA-256 hashes are upgraded on the next unlock.
- Lockout: 4 free misses, then 30 s doubling up to 30 min; it's stored in secure
  storage, so it survives restarts. A successful biometric unlock resets it.
- `FLAG_SECURE` through the `ir.kifino.app/security` method channel
  (`MainActivity.kt`).

### Backup

Format v2: PBKDF2 (300k) → AES-256-GCM, with a SHA-256 checksum of the payload
and the schema version in plain metadata. Restore is a single DB transaction
(wipe + insert); it refuses backups from a newer schema. Legacy v1
(AES-CBC) files still restore.

### Sync

Every write enqueues an outbox row (`sync_queue`). With no backend configured
(`UnavailableRemoteSyncClient`), rows older than 30 days are pruned at startup.
Retries use exponential backoff measured from the last attempt.

### Accounting

`AutoVoucherService` turns business events (sales, purchases, cheque clearing…)
into balanced double-entry vouchers. Posted documents must be balanced. Closed
fiscal years are locked (`_ensurePeriodOpen`).

---

## 7. Persian, RTL & dates

- The default locale is `fa` (RTL). Strings live in
  `lib/app/localization/app_localizations.dart` (`l10n.isPersian ? 'فا' : 'en'`),
  but many screens still have inline Persian literals (see §13).
- **Digits:** wrap any interpolated number in `TextNormalizer.auto(...)` so it
  renders Persian digits in Persian (`'فعال (${n})'` → «فعال (۳)»). `Money.format`
  and `AppMoneyText` already do this.
- **Input:** accept both digit sets with `normalizeNumericInput()`.
- **Dates:** store `DateTime`/epoch ms; display Jalali via `JalaliDate`,
  `AppDateFormatter.format/formatFull`. Month boundaries use
  `startOfJalaliMonth`/`endOfJalaliMonth`; month stepping uses `addJalaliMonths`.
  - Past events: `formatRelative` («۳ ساعت پیش»).
  - Due dates (past or future): `formatDue` («امروز»، «فردا»، «۳ روز دیگر»، «۳ دی»).
- **Directional icons:** for "go forward" always use `Icons.chevron_right*`.
  Flutter mirrors it, so it points left in RTL. Never choose the icon by
  direction yourself.
- **Signed amounts:** `AppMoneyText` keeps the minus glued to the digits in an
  LTR isolate, and zero never gets a sign.

---

## 8. Design system (for designers)

Kifino 2 is a **Persian-modern** identity: calm, legible and trustworthy. It's
built from **Firoozeh** (turquoise, from Persian tilework) for the brand, **Ink**
navy for weighty surfaces, warm **Sand** neutrals instead of cold greys, and
**Gold** for goals and achievements. The full reference is in
[`docs/DESIGN.md`](docs/DESIGN.md).

### See it in the app

- **بیشتر → نمایش سیستم طراحی (توسعه‌دهنده)** opens the live showcase
  (`/design-system`) with every token and component in light and dark.
- Switch light/dark/system in **بیشتر → حالت نمایش**.
- To take screenshots, turn off screenshot protection first (§2).

### Color

Three layers: **primitives** (`core/design_system/tokens/colors.dart`, raw hex
values) → **semantic** (`app/theme/app_colors.dart`, `context.customColors`) →
components. Screens use semantic names only, so the brand can be changed in one
file.

| Role | Light | Dark | Use |
|---|---|---|---|
| Primary (Firoozeh) | `#0B7F7A` | `#2EC4B6` | actions, selection, links, active tab |
| Primary tint | `#EAF7F5` | `#0E2F33` | selected chips/tabs, soft highlights |
| Ink (hero) | `#0F1B2E` → `#0B1220` | `#16243A` → `#0F1B2E` | net-worth and summary cards |
| Background | `#FAF8F4` | `#0A0F1A` | scaffold |
| Surface | `#FFFFFF` | `#111827` | cards, sheets, dialogs |
| Surface variant | `#F3F0EA` | `#182235` | inputs, fills |
| Border (hairline) | `#E8E3DA` | `#243047` | card outlines, dividers |
| Text primary / secondary / tertiary | `#0F1B2E` / `#6B655B` / `#8C8579` | `#F4F1EA` / `#A7ADB8` / `#6C7586` | |
| Income | `#0F8A45` | `#3DD68C` | money in |
| Expense | `#D93B40` | `#FF6B70` | money out, errors |
| Transfer | `#4F5BD5` | `#8E97F0` | |
| Debt / warning | `#D9822B` | `#F2B266` | |
| Receivable / info | `#2F7DD1` | `#79B4F2` | |
| Asset | `#7C5CE0` | `#AD97F5` | |
| Gold (goals, business) | `#9A7314` | `#E2B84A` | |

Rules:
- Every text/background pairing meets **WCAG AA** (body text ≥ 4.5:1; the
  tertiary color is for hints only).
- Green and red mean **money direction only**. Never use them for decoration.
- Dark mode is a designed set of values, not an automatic inversion.
- **Charts** use one validated categorical order (lightness band, chroma floor,
  colour-blind ΔE ≥ 8 between neighbours, ≥ 3:1 on both surfaces):
  `#14A39B #7C5CE0 #C0701E #2F7DD1 #C2477A #A8800F #4F5BD5 #A3532E`.
  A category keeps its color across periods, and slices past the sixth fold
  into a neutral «سایر».

### Typography

**Vazirmatn** (bundled; weights 300–700) for both Persian and Latin. Persian
needs larger sizes and taller lines than Latin, and **letter-spacing must stay
0**, because it pulls joined letters apart.

| Style | Size / weight / line height | Use |
|---|---|---|
| displayLarge | 30 / 700 / 1.3 | rare hero titles |
| displayMedium | 24 / 700 / 1.35 | |
| titleLarge | 19 / 700 / 1.4 | app bar titles, greeting |
| titleMedium | 16 / 600 / 1.45 | section headers |
| titleSmall | 14.5 / 600 / 1.45 | list-item titles |
| bodyLarge | 15 / 400 / 1.6 | paragraphs |
| bodyMedium | 13.5 / 400 / 1.6 | default body |
| bodySmall | 12 / 400 / 1.5 | meta lines (account · date) |
| labelLarge / Medium / Small | 13.5 / 12 / 11 | buttons, chips, nav labels (never below 11) |
| moneyHeadline / Tile / Sub | 30 / 15.5 / 13 (700/700/500) | amounts, with **tabular figures** |

### Shape, space & elevation

- **Radii:** cards 20 · buttons & inputs 14 · icon badges 14 · sheets 28 ·
  dialogs 24 · chips pill (`KifinoRadii`).
- **Spacing:** 4-point scale, `xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48`
  (`AppSpacing`). Screen gutter 16, gap between sections 24.
- **Elevation:** flat. Cards get a 1 px hairline border and no shadow; depth comes
  from white-on-sand. Only hero cards use the ink gradient.
- **Touch targets:** ≥ 44 dp; buttons 48 dp high.
- **Motion:** 150 / 220 / 280 / 350 ms with `easeOutCubic` (`KifinoMotion`).
  Motion shows a state change and is never decorative.

### Components (`lib/core/widgets`)

| Component | Purpose |
|---|---|
| `AppCard` | the surface; flat, hairline border, ripple on tap |
| `AppSectionHeader` | section title with an optional «همه» action |
| `AppIconBadge` | tinted rounded-square icon, the single icon style for lists and actions |
| `AppMoneyText` | formatted, signed, colour-coded amounts (optional count-up animation) |
| `AppTransactionTile` | one transaction row (category badge, title, account · date, amount) |
| `AppAccountCard` | compact account card for the dashboard strip |
| `AppButton`, `AppAmountField`, `AppDatePicker` (Jalali), `AppEmptyState`, `AppErrorState`, `AppSkeleton`, `AppBudgetProgress` | the rest of the kit |

Prefer these over hand-built containers, so the app keeps one rhythm.

### Key screens

- **Dashboard:** greeting + Jalali date → ink net-worth card (this month's
  income vs expense bar) → 5 quick actions → «پیش رو» upcoming → insight →
  accounts → recent → tools card.
- **Bottom bar:** attached to the screen edge, 5 tabs with a pill indicator, and
  the add button inside the bar.
- **Recurring:** ink summary (monthly commitments), templates, rule list with
  actions; the editor is a full screen with the save button pinned at the
  bottom.

### Designer workflow

1. Change **values** in the primitives file. Change **meaning** (which role uses
   which value) in `app_colors.dart`. Avoid touching screens for color.
2. Re-check contrast for any new text pairing (AA). For chart palettes, run a
   colour-blind validation.
3. Check both themes and an RTL + Persian-digits screen.
4. Ask a developer to run `flutter test --update-goldens test/goldens` and
   review the updated reference images in `test/goldens/goldens/`.

---

## 9. Testing

```bash
flutter test                                   # everything (~300 tests)
flutter test test/features/recurring           # one area
flutter test --update-goldens test/goldens     # after intentional visual changes
```

- Repository and service tests use an in-memory DB:
  `AppDatabase(NativeDatabase.memory())`.
- Bloc tests use `bloc_test`. Widget tests register fakes in `get_it`; see
  `test/widget_test.dart`, and add new services there when the shell needs
  them.
- `test/bootstrap_test.dart` boots the **real** DI and DB, so it catches
  registration mistakes.
- Migration tests build an older schema (raw SQL or rewound file) and open it
  with the current `AppDatabase`.
- Goldens: `test/goldens/design_system_goldens_test.dart`.

When you fix a bug, add a test that fails without the fix.

---

## 10. Build, sign & release

```bash
# Android
flutter build apk --release --split-per-abi   # → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
flutter build appbundle --release             # → build/app/outputs/bundle/release/app-release.aab

# Windows (on Windows)
flutter build windows --release               # → build/windows/x64/runner/Release/kifino.exe
```

### Signing

Create `android/key.properties` (git-ignored; template in
`android/key.properties.example`) next to your keystore:

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=upload-keystore.jks
```

Without it, release builds are **silently signed with the debug key**. That's
fine for testing, but never ship such a build: users can't update it later. Check
a build with
`apksigner verify --print-certs <apk>`; the signer should be `CN=Kifino`.

### CI/CD (`.github/workflows`, details in [`docs/CI_CD.md`](docs/CI_CD.md))

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | push / PR to main branches | `dart format` check, `flutter analyze --fatal-infos --fatal-warnings`, tests with coverage, Android debug build, Windows release build |
| `release.yml` | tag `v*.*.*` (e.g. `v1.0.0`) or manual | signed APKs (per ABI + universal), AAB, Windows zip, SHA-256 checksums → GitHub Release |
| `scheduled_health.yml` | weekly | dependency and repository health audit |

Release signing secrets: `KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`,
`STORE_PASSWORD`.

---

## 11. Conventions & contribution checklist

- **Branch, PR, CI green, merge.** Don't push to `main` directly.
- Commit style: `feat:`, `fix:`, `ci:`, `style:`… with a body that explains *why*.
- Persian for user-facing text; English for code, comments and commit
  messages.
- No raw colors (`Colors.red`, `Color(0x…)`) or inline font sizes in feature
  code. Use semantic colors, `AppTypography` and tokens.
- No hard-coded currency. Use `AppCurrency.base`, and normalise before summing.
- Writes that touch several tables go in one `_db.transaction(...)`.
- Repositories return `Result`; blocs turn failures into states that the UI
  shows, and never swallow them silently (log with `AppLogger`).

Before opening a PR:

```bash
dart format .
flutter analyze
flutter test
```

and check the screen in **light + dark** on a phone-sized emulator.

---

## 12. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Android Gradle Plugin version (…) is lower than Flutter's minimum` | Your local Flutter is newer than the pinned 3.47.9. Build with `--android-skip-build-dependency-validation`, or use 3.47.9. |
| `pubspec.lock` changes after `pub get` | A newer local Flutter re-resolved pinned SDK packages. Don't commit it: `git checkout pubspec.lock`. |
| ~100 `deprecated_member_use` infos about `material.dart` | Flutter ≥ 3.50 split the Material library. CI (3.47.9) doesn't report them; the migration is planned (§13). |
| Black screenshots / screen recording | Screenshot protection; turn it off in Security settings. |
| Windows build `STL1011 … /await` | Fixed in `windows/CMakeLists.txt` (`_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`). Keep it until `local_auth_windows` drops `/await`. |
| `*.g.dart` out of date after a schema change | `dart run build_runner build --delete-conflicting-outputs` |
| An old backup fails to restore | It should not: missing columns get defaults. File a bug with the backup's `schemaVersion`. |

---

## 13. Known limitations & roadmap

- **No sync server.** The outbox exists, but nothing is ever sent. A future
  backend needs a full initial snapshot.
- **Localization:** about 1,200 Persian literals still live in widgets; move them
  into `AppLocalizations` to support English properly.
- **Database encryption:** only backups are encrypted; the live DB is not
  (SQLCipher is a candidate).
- **Exchange rates:** no cross-currency transfers (e.g. Toman → USD).
- **Large files to split:** `business_repository_impl.dart`,
  `accounting_repository_impl.dart`, `business_hub_page.dart`,
  `checks_page.dart`.
- **Flutter 3.50 Material split:** migrate `package:flutter/material.dart`
  imports before moving CI past 3.47.9.
- **Debt/goal payments made before v10** carry no source link, so deleting them
  doesn't revert the debt/goal.
