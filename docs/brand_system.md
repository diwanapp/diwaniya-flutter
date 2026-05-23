# Diwaniya Brand System

## 1. Purpose

This document defines the approved visual identity system for Diwaniya. It is the single reference for colors, logo usage, app icon usage, and future UI styling decisions.

The objective is to keep Diwaniya visually premium, calm, Saudi-relevant, and consistent across the mobile app, owner dashboard, legal documents, investor materials, and future marketing assets.

## 2. Brand Direction

Diwaniya is positioned as a premium Saudi social utility app for managing majlis / diwaniya communities.

The visual identity should feel premium, warm, Saudi-inspired, modern, calm, clear, and trustworthy.

Core product descriptor: كل أمور ديوانيتك في مكان واحد

Approved brand line: لمة مرتبة

Internal visual metaphor: الدّارة الذكية

## 3. Approved Core Palette

| Role | Name | HEX | Usage |
|---|---|---:|---|
| Main dark background | Majlis Night | `#0B111C` | Dark app background |
| Deep blue surface | Majlis Blue Dark | `#0B1724` | Deep cards and premium backgrounds |
| Primary blue | Majlis Blue | `#10263A` | Main identity blue, light-mode text |
| Soft blue | Majlis Blue Soft | `#183B55` | Gradients, elevation, secondary surfaces |
| Primary accent | Sand Taupe | `#B79A72` | Main CTA accents and navigation highlights |
| Light accent | Sand Taupe Light | `#C8AD83` | Premium highlights and subtle shimmer |
| Warm warning/gold | Sand Gold | `#D9B56D` | Offers, warnings, premium indicators |
| Primary light text | Warm Ivory | `#F5EFE3` | Key text on dark backgrounds |
| Muted ivory | Ivory Muted | `#E8DDCB` | Secondary light text |
| Supporting taupe | Soft Taupe | `#8C8173` | Tertiary text and subtle UI |
| Light taupe | Soft Taupe Light | `#B8AFA2` | Secondary dark-mode text |

## 4. Feature Accent Colors

Feature accents must remain controlled and limited. Do not introduce random bright colors directly in screens.

### Polls — Desert Amber

| Role | HEX |
|---|---:|
| Poll Accent | `#C98745` |
| Poll Accent Light | `#D9A760` |
| Poll Surface Dark | `#2A2119` |

Used for poll banners, poll CTAs, active poll icons, and poll activity indicators.

### Chat — Sage Green

| Role | HEX |
|---|---:|
| Chat Accent | `#7FAE8A` |
| Chat Accent Light | `#9DBA8F` |
| Chat Surface Dark | `#12231E` |

Used for chat cards, chat icons, unread indicators, and chat activity indicators.

## 5. Semantic Colors

| Role | Recommended HEX | Usage |
|---|---:|---|
| Success | `#7FAE8A` | Completed actions and positive states |
| Warning | `#D9B56D` | Non-critical warnings and offers |
| Error / Critical | `#9F4D4D` | Delete, reject, and critical warning states |
| Error Light | `#C06A6A` | Error highlights |
| Info | `#6EA6C9` | Neutral information |

## 6. Implementation Rules

All colors must be centralized in:

`lib/config/theme/app_colors.dart`

Screens should use `context.cl` and approved getters such as `c.accent`, `c.warning`, `c.error`, `c.info`, `c.pollAccent`, and `c.chatAccent`.

Avoid hardcoded legacy colors such as `Color(0xFF60A5FA)`, `Color(0xFF34D399)`, `Color(0xFFFBBF24)`, `Color(0xFFF87171)`, and `Color(0xFF2DD4A8)` unless they are formally added to `AppColors`.

## 7. Logo Assets

Approved current assets are stored in:

`assets/brand/`

Current operational files:

- `app_icon_1024.png`
- `app_icon_512.png`
- `logo_mark_dark_512.png`
- `logo_mark_light_512.png`
- `logo_mark_primary_1024.png`
- `logo_mark_primary_512.png`
- `logo_mark_splash_1024.png`
- `android_launcher_preview_1024.png`

## 8. Splash / Welcome Logo

Use `assets/brand/logo_mark_splash_1024.png` for in-app splash and welcome screens.

This asset is referenced by:

`lib/shared/widgets/diwaniya_brand_mark.dart`

It should appear on a deep Majlis Blue background and should not be placed inside an additional square frame.

## 9. Android Launcher Icon

The current Android launcher icon is generated from:

`assets/brand/android_launcher_preview_1024.png`

Generated Android icon files:

- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

The Android app label is Arabic: ديوانية

Defined in `android/app/src/main/res/values/strings.xml` and linked from `android/app/src/main/AndroidManifest.xml`.

## 10. Logo Usage Rules

Do:

- Use the transparent mark on dark Majlis Blue backgrounds.
- Use the app icon version for launcher and store usage.
- Keep the logo large enough to remain legible.
- Maintain clear space around the mark.

Do not:

- Put the transparent logo inside an extra square frame.
- Add heavy glow behind the logo.
- Use transparent images as launcher icons.
- Use low-resolution logo files.
- Mix splash logo and launcher icon use cases.

## 11. Designer Improvement Brief

The current logo assets are acceptable for MVP and internal testing. For official launch, request final exports from the designer:

1. Transparent logo mark, 1024x1024 PNG
2. Transparent logo mark, 512x512 PNG
3. Clean SVG logo mark
4. Android adaptive icon foreground/background
5. iOS app icon, 1024x1024 PNG
6. Play Store icon, 512x512 PNG
7. App Store icon, 1024x1024 PNG

Visual target: deep Majlis Blue background, metallic Warm Ivory / Sand Taupe mark, strong but subtle shine, high clarity at small sizes, and no unwanted internal frame.

## 12. Current Quality Status

| Area | Status |
|---|---|
| Core app palette | Approved |
| Home screen identity | Approved |
| Premium subscription card | Approved |
| Poll / chat feature accents | Approved |
| Splash logo | Accepted for MVP |
| Android launcher icon | Accepted for MVP |
| Arabic Android app label | Approved |
| iOS icon | Pending |
| Android adaptive icon | Pending |
| Final designer logo export | Pending |

## 13. Future Identity Work

1. Build Android Adaptive Icon.
2. Prepare iOS App Icon 1024x1024.
3. Replace the current splash logo if the designer provides a stronger final mark.
4. Review onboarding and welcome screens visually.
5. Review all feature screens for hardcoded colors.
6. Create brand-aligned store screenshots.
7. Align the owner dashboard with the same palette.
