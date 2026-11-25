# Kifino 2 — Design system

A Persian-modern identity for a money app: calm, legible, trustworthy.

## Color

| Role | Light | Dark | Use |
|---|---|---|---|
| Brand · Firoozeh | `#0B7F7A` | `#2EC4B6` | primary actions, selection, links |
| Ink | `#0F1B2E` | `#16243A` | hero cards (net worth, summaries) |
| Sand background | `#FAF8F4` | `#0A0F1A` | scaffold |
| Surface | `#FFFFFF` | `#111827` | cards (hairline border, no shadow) |
| Text primary / secondary / tertiary | `#0F1B2E` / `#6B655B` / `#8C8579` | `#F4F1EA` / `#A7ADB8` / `#6C7586` | |
| Income / Expense | `#0F8A45` / `#D93B40` | `#3DD68C` / `#FF6B70` | money direction only |
| Gold | `#9A7314` | `#E2B84A` | goals, business, premium |

Every text pairing was checked against WCAG (body ≥ 4.5:1). Primitives live in
`lib/core/design_system/tokens/colors.dart`; screens use the semantic layer
(`AppColors`, `context.customColors`) only.

**Charts** use one validated categorical order (lightness band, chroma floor,
colour-blind ΔE ≥ 8 between neighbours, ≥ 3:1 contrast on both card
surfaces): `#14A39B #7C5CE0 #C0701E #2F7DD1 #C2477A #A8800F #4F5BD5 #A3532E`.
A category keeps its own colour across periods; slices beyond six fold into a
neutral «سایر».

## Type

Vazirmatn throughout. Persian needs more size and line height than Latin, and
letter-spacing must stay `0` (it pulls joined letters apart). Body 13.5–15,
labels never below 11, money in tabular figures.

## Shape & surfaces

Cards radius 20 with a 1px hairline, buttons/inputs 14, sheets 28, dialogs 24.
No drop shadows on cards; depth comes from the sand-vs-white contrast.

## RTL rules

- "Go forward" chevrons use `Icons.chevron_right*` — Flutter mirrors it to
  point left in RTL. Never pick the icon by direction yourself.
- Signed amounts keep the sign glued to the digits inside a left-to-right
  isolate (`AppMoneyText`), and zero has no sign.
- Due dates read as calendar days (`AppDateFormatter.formatDue`: امروز، فردا،
  ۳ روز دیگر، ۳ دی); relative "ago" phrasing is for past events only.

## Components

`AppCard`, `AppSectionHeader`, `AppIconBadge`, `AppMoneyText`,
`AppTransactionTile`, `AppAccountCard` — prefer them over hand-built
containers so the app keeps one rhythm.

## Screen patterns (the kit — `lib/core/widgets/app_kit.dart`)

Every screen is assembled from the same few pieces. If a screen needs
something bespoke, extend the kit instead.

| Pattern | Component | Used for |
|---|---|---|
| Module summary | `AppSummaryHero` (+ `AppHeroFigure`, optional `progress`) | accounts, debts (net position), loans, assets, goals, business, analytics period |
| Metric | `AppStatTile` | analytics health grid |
| Grouped rows | `AppListGroup` + `AppListRow` | settings, accounts by type, accounting modules, pickers |
| Filters | `AppFilterBar` (chips) | activity, debts, cheques — never segmented controls for filtering |
| Picker / form sheet | `showAppSheet` | account picker, theme/language/currency, categories |
| Selection grid | `AppChoiceGrid` (`AppChoice.onTap` for action tiles) | categories, More tools |
| Inline message | `AppNotice` | locked fields, low stock, sync simulator |
| Status | `AppStatusBadge` (tone + icon, never colour alone) | PRO, «به‌زودی», paid/overdue |
| Money in a hero | `MoneyTextStyle` scope | lets `AppMoneyText` inherit the hero size |

### Rules of thumb

- **Summary first, then the list.** A module opens with its hero; the hero
  disappears when there is nothing to summarise and an empty state with one
  create action takes its place.
- **Group by meaning:** transactions by day (with the day's net), accounts by
  type, settings by purpose.
- **Say only true things.** Copy about security, sync or "AI" must describe
  what the build actually does (no "connected" without a server, no
  "always online" for an offline engine).
- **Tabs switch, everything else stacks:** links to a bottom-bar destination
  use `context.go`, other screens `context.push`.
- **Coloured buttons in dark mode** use dark text — the dark-mode type
  colours are light.
