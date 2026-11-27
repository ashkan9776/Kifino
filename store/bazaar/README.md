# Cafe Bazaar listing kit

Everything needed for the Kifino page on Cafe Bazaar. Upload the files from this folder.

| File | Size | Use |
|---|---|---|
| `icon-512.png` | 512×512 | App icon, full-bleed square (Bazaar rounds the corners) |
| `icon-512-rounded.png` | 512×512 | Same icon with transparent rounded corners, if a panel shows it unmasked |
| `banner-1024x500.png` | 1024×500 | Cover / promo banner |
| `banner-2048x1000.png` | 2048×1000 | Same banner at 2×, for any slot that asks for more pixels |
| `screenshots/01.png` … `07.png` | 1080×1920 | Store screenshots, in the order listed below |

Bazaar's published guideline confirms a 512×512 icon and requires at least one screenshot. The
banner size follows the common 1024×500 feature-graphic convention. Check the upload form in the
developer panel; if it asks for a different size, change `--window-size` in `src/render.sh`.

## Screenshot order

1. همه‌ی پولت، در یک نگاه: home
2. ثبت هزینه در چند ثانیه: add transaction (dark)
3. بفهم پولت کجا می‌رود: analytics
4. برای هدف‌هایت پس‌انداز کن: goals
5. تراکنش‌ها، مرتب و منظم: activity
6. اقساط، چک و کسب‌وکار: tools
7. حالت تاریک، آرام برای چشم: home (dark)

## Listing text (suggested)

**Short description**

> مدیریت پول شخصی و کسب‌وکار؛ ساده، فارسی و بدون نیاز به اینترنت

**Full description**

> کیفینو دستیار مالی فارسی شماست. هزینه‌ها و درآمدها را در چند ثانیه ثبت کنید، ببینید پولتان کجا می‌رود و برای هدف‌هایتان پس‌انداز کنید.
>
> • ثبت سریع تراکنش با دکمه‌های مبلغ آماده و خواندن پیامک بانکی
> • چند حساب: کارت بانکی، کیف پول نقد، سپرده و…
> • بودجه‌ی ماهانه با هشدار نزدیک شدن به سقف
> • اهداف پس‌انداز با نمایش پیشرفت
> • تراکنش‌های تکراری: اجاره، حقوق و قبض‌ها را یک بار ثبت کنید
> • اقساط و وام، چک‌ها، بدهی و طلب، دارایی‌ها
> • تحلیل هزینه‌ها بر اساس دسته، جریان نقدی و نرخ پس‌انداز
> • ابزارهای کسب‌وکار: فاکتور، مشتریان و انبار
> • حسابداری دوبل: اسناد، دفاتر، تراز آزمایشی و ترازنامه
> • تقویم شمسی، اعداد فارسی، تومان و ریال
> • حالت روشن و تاریک
> • قفل با رمز و پشتیبان‌گیری رمزنگاری‌شده
>
> داده‌های شما روی گوشی خودتان ذخیره می‌شود و برای کار با برنامه به اینترنت نیازی نیست.

## Regenerating

The art is plain HTML rendered by headless Chrome. It uses the app's own Vazirmatn fonts and the logo
from `store/brand/`.

```bash
store/bazaar/src/render.sh        # needs google-chrome-stable and rsvg-convert
```

- `src/banner.html`: banner layout.
- `src/slide.tpl` + `src/slides.tsv`: one row per screenshot (theme, source screen, title, subtitle).
- `src/screens/`: raw app captures (1080×2310, status bar cropped) taken on an emulator with
  sample data. To refresh them, capture new screens with `adb exec-out screencap -p`, crop the
  top 90px, and run `render.sh` again.
