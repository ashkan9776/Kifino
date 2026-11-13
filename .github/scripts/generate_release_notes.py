#!/usr/bin/env python3
import sys

def main():
    checksums_path = sys.argv[1] if len(sys.argv) > 1 else 'release_assets/checksums.txt'
    output_path = sys.argv[2] if len(sys.argv) > 2 else 'release_body.md'
    custom_notes = sys.argv[3] if len(sys.argv) > 3 else ''

    try:
        with open(checksums_path, 'r', encoding='utf-8') as f:
            checksums = f.read().strip()
    except Exception:
        checksums = 'No checksums available'

    body = f"""## کیفینو — Kifino Release 🚀

نسخه رسمی اپلیکیشن حسابداری و مدیریت مالی هوشمند کیفینو آماده دریافت است.

### 📦 فایل‌های اجرایی پیوست‌شده:
- **اندروید (Android):**
  - `Kifino-Android-Universal.apk`: نسخه عمومی برای تمامی گوشی‌های اندروید
  - `Kifino-Android-arm64-v8a.apk`: نسخه بهینه‌شده برای پردازنده‌های ۶۴ بیتی مدرن
  - `Kifino-Android-armeabi-v7a.apk`: نسخه برای پردازنده‌های قدیمی‌تر ۳۲ بیتی
  - `Kifino-Android-x86_64.apk`: نسخه برای شبیه‌سازها و پردازنده‌های اینتل/AMD
  - `Kifino-Android.aab`: بسته استاندارد App Bundle برای انتشار در گوگل‌پلی و مارکت‌ها
- **ویندوز دسکتاپ (Windows):**
  - `Kifino-Windows-x64.zip`: بسته کامل اجرای نیتیو روی ویندوز ۱۰ و ۱۱

### 🔒 کدهای صحت‌سنجی هش (SHA-256 Checksums):
```
{checksums}
```

---
> ساخته شده با موتور فلاتر، دیتابیس لوکال SQLite/Drift و معماری پایدار Clean Architecture.
"""

    if custom_notes.strip():
        body += f"\n### 📝 یادداشت‌های انتشار:\n{custom_notes.strip()}\n"

    with open(output_path, 'w', encoding='utf-8') as out:
        out.write(body)

    print(f"Generated release notes at {output_path}")

if __name__ == '__main__':
    main()
