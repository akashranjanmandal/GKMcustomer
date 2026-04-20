# Ghar Ka Mali — Customer Flutter App

## Quick Start
```bash
cd gkm_customer_app
flutter pub get
flutter run
```

## Architecture
```
lib/
├── main.dart                          # Entry, routing, shell, splash
├── data/services/
│   ├── api.dart                       # All API calls (swagger 2.1.0 verified)
│   └── auth.dart                      # Auth state (ChangeNotifier)
└── presentation/
    ├── theme/theme.dart               # Colors (C.*), shadows (s1/s2/s3), AT.light
    ├── widgets/widgets.dart           # GCard, GBtn, GBadge, GNavBar, GSkel, etc.
    └── screens/
        ├── auth/login_screen.dart     # OTP login, new-user name capture
        ├── home/home_screen.dart      # Dashboard, stats, active booking, plans preview
        ├── bookings/
        │   ├── bookings_screen.dart   # List + tabs + booking detail + rating + cancel
        │   └── book_screen.dart       # 5-step booking: location→plan→addons→schedule→confirm
        ├── shop/shop_screen.dart      # Plans marketplace + Add-ons with cart
        ├── wallet/wallet_screen.dart  # Balance, top-up presets, PayU, transactions
        ├── plantopedia/               # AI plant ID (camera/gallery), history
        └── profile/profile_screen.dart # Profile + Subscriptions + Notifications + Complaints
```

## Brand Colors
| Token       | Hex       | Use               |
|-------------|-----------|-------------------|
| C.forest    | #03411A   | Primary           |
| C.gold      | #EDCF87   | Accent, CTA       |
| C.goldDk    | #D4B96A   | Gold dark         |
| C.earth     | #96794F   | Secondary accent  |

## Nav Tabs (GNavBar)
0 = Home | 1 = Bookings | 2 = Shop | 3 = Wallet | 4 = Me (Profile)

## Key Features
- **Login**: Phone → 6-digit OTP → optional name capture for new users
- **Book**: Location serviceability check → Plan selection → Add-ons → Date/time → Confirm
- **Shop**: Plans marketplace + Add-ons tab with cart total
- **Bookings**: Tabbed list (All/Pending/Active/Done/Cancelled) + detail with OTP display, rating, cancel
- **Wallet**: Balance, preset top-up (₹100–₹5000), custom amount, PayU redirect, transaction history  
- **Plantopedia**: AI plant ID via camera/gallery, results with care guide, identification history
- **Subscriptions**: Pause / Resume / Cancel with confirmation
- **Notifications**: Mark read, mark all read
- **Complaints**: Create with type + priority, history list

## Lottie Animations
Place `.json` files in `assets/lottie/`. Download from https://lottiefiles.com:
- `plant_grow.json` — Splash/loading
- `success.json` — Booking confirmed
- `empty.json` — Empty states

Usage: `Lottie.asset('assets/lottie/plant_grow.json', width: 120)`

## API Base
`https://gkm.gobt.in/api` — configured in `lib/data/services/api.dart` → `kBase`

## Android Permissions Required
INTERNET · ACCESS_FINE_LOCATION · CAMERA · READ_MEDIA_IMAGES

## Dependencies
google_fonts · flutter_animate · lottie · shimmer · cached_network_image ·
image_picker · provider · http · shared_preferences · geolocator ·
fl_chart · intl · url_launcher · permission_handler

Developed by Gobt · GKM v1.0
