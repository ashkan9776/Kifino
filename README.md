# کیفینو — Kifino

<div dir="rtl">

**مرکز هوشمند مدیریت پول** — سیستم‌عامل مالی شخصی و کسب‌وکار کوچک، فارسی‌محور و کاملاً آفلاین.

همه‌ی پولت یکجا: ثبت سریع درآمد و هزینه با زبان طبیعی فارسی، مدیریت حساب‌ها و کارت‌ها، بودجه‌بندی، بدهی و طلب، اقساط، چک‌ها، دارایی‌ها و اهداف مالی — به‌همراه یک ماژول **حسابداری دوبل** کامل با کدینگ استاندارد ایرانی، دفتر روزنامه، دفتر کل، تراز آزمایشی و ترازنامه.

</div>

<div dir="ltr">

**Kifino** — a Persian-first, offline-first personal & small-business financial OS.
Track income and expenses with natural-language entry, manage accounts, budgets,
debts, installments, checks, assets and goals, backed by a complete double-entry
accounting module (Iranian standard chart of accounts, journal, ledger, trial
balance and financial statements).

</div>

---

<div dir="rtl">

## امکانات کلیدی

- 💬 **ثبت با متن فارسی** — «۳۵۰ هزار تومن اسنپ» بنویس؛ دستیار هوشمند نوع، مبلغ، دسته و حساب رو تشخیص میده
- 🏦 **حسابداری دوبل** — کدینگ استاندارد ایرانی، سند حسابداری، دفاتر قانونی، تراز آزمایشی، ترازنامه و صورت سود و زیان
- 📊 **تحلیل مالی** — جریان نقدی، سلامت مالی، تاب‌آوری، ترند هزینه‌ها
- 🎯 **اهداف مالی** — پس‌انداز هدفمند با پیشرفت زنده
- ⏰ **یادآورهای سررسید** — اعلان واقعی برای قسط، چک و بدهی
- 🔒 **امنیت** — قفل با PIN و اثر انگشت، پشتیبان‌گیری رمزنگاری‌شده (AES-256)
- 📴 **آفلاین-محور** — همه‌چیز بدون اینترنت کار می‌کند؛ صف همگام‌سازی با تلاش مجدد
- 🖨 **خروجی PDF** — فاکتور و سند حسابداری با فونت فارسی
- 📈 **خروجی اکسل** — تمام تراکنش‌ها به CSV با تاریخ شمسی، و دفاتر قانونی حسابداری به XLSX

## معماری

```text
Flutter + Dart
Clean Architecture (data / domain / presentation)
BLoC + Riverless Cubits
Drift (SQLite) — offline-first با مهاجرت نسخه‌ای
go_router • get_it • fl_chart
```

## ساخت و خروجی نهایی (Build)

```bash
# دریافت وابستگی‌ها
flutter pub get

# بیلد نسخه اندروید
flutter build apk --release --split-per-abi

# بیلد نسخه ویندوز
flutter build windows --release
```

- خروجی اندروید: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- خروجی ویندوز: `build/windows/x64/runner/Release/kifino.exe`

## پایپ‌لاین CI/CD و انتشار خودکار

پروژه به پایپ‌لاین‌های خودکار **GitHub Actions** مجهز است:
- **اعتبارسنجی مداوم (CI):** تست خودکار فرمت، آنالیز ایستا (`flutter analyze`) و ۲۳۹+ تست واحد روی هر Push و PR.
- **انتشار خودکار (CD):** ساخت باینری‌های بهینه‌شده اندروید (APK و AAB) و ویندوز (Zip) و انتشار رسمی در GitHub Releases با تگ زدن (مانند `v1.0.0`).
- جزئیات کامل و نحوه تنظیم Keystore را در [مستند CI/CD](docs/CI_CD.md) بخوانید.

</div>
