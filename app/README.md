# CollegeSapien Mobile App

A Flutter mobile application for managing university attendance, timetables, and academic resources. Designed with a vibrant, modern UI that matches the exact Figma design specifications.

## Location

This app lives in `app/` at the root of the CollegeSapien monorepo.

## Features

- 📊 **Attendance Tracking**: Real-time attendance percentage display with visual progress indicators
- 📅 **Smart Timetable**: View today's schedule with color-coded class cards
- 📚 **Next Class Preview**: Quick glance at upcoming classes with room and time details
- 👥 **Community Feed**: Stay updated with shared notes and resources from classmates
- 📖 **Academic Resources**: Quick access to previous year papers and study materials
- 🎨 **Responsive Design**: Optimized for all mobile screen sizes

## Design

This app is built from a Figma design using the Figma MCP plugin, ensuring pixel-perfect accuracy and 1:1 visual parity with the original design. The UI features:

- Custom color scheme with vibrant accents
- Bold shadows and borders for a modern, playful look
- Responsive layouts that adapt to different screen sizes
- Custom typography using Lexend Mega, Public Sans, Inter, and Patrick Hand fonts

## Setup Instructions

### Prerequisites

- Flutter SDK (>= 3.0.0)
- Dart SDK (>= 3.0.0)
- iOS Simulator / Android Emulator or physical device

### Font Setup

This app uses custom fonts. You need to download and add the following font files to the `fonts/` directory:

**Lexend Mega:**

- LexendMega-Bold.ttf (weight 700)
- LexendMega-SemiBold.ttf (weight 600)
- LexendMega-Regular.ttf (weight 400)

**Public Sans:**

- PublicSans-ExtraBold.ttf (weight 800)
- PublicSans-Bold.ttf (weight 700)
- PublicSans-SemiBold.ttf (weight 600)
- PublicSans-Regular.ttf (weight 400)
- PublicSans-Light.ttf (weight 300)

**Inter:**

- Inter-Bold.ttf (weight 700)
- Inter-Medium.ttf (weight 500)

**Patrick Hand:**

- PatrickHand-Regular.ttf (weight 400)

You can download these fonts from:

- Lexend Mega: https://fonts.google.com/specimen/Lexend+Mega
- Public Sans: https://fonts.google.com/specimen/Public+Sans
- Inter: https://fonts.google.com/specimen/Inter
- Patrick Hand: https://fonts.google.com/specimen/Patrick+Hand

### Installation

1. **Navigate to the project directory:**

   ```bash
   cd app
   ```

2. **Create the fonts directory and add font files:**

   ```bash
   mkdir fonts
   # Download and add the font files listed above to the fonts/ directory
   ```

3. **Install dependencies:**

   ```bash
   flutter pub get
   ```

4. **Configure Firebase:**

   ```bash
   flutterfire configure
   ```

   This should add platform Firebase config files for the same Firebase project as the API.

5. **Run the app:**
   ```bash
   flutter run --dart-define=CODESAPIENS_API_BASE_URL=https://asia-south1-codesapien-college.cloudfunctions.net/api/api/v1
   ```

For local API testing, point `CODESAPIENS_API_BASE_URL` to the Functions emulator URL and keep `DISABLE_APP_CHECK=true` on the backend emulator.

### Web integration tests

Run the web suite with a ChromeDriver matched to the installed Chrome version:

```bash
./tool/run_web_integration_tests.sh
```

The runner downloads and caches the matching Chrome-for-Testing driver under
`.tools/` and uses Flutter's `flutter drive -d chrome` flow. The
real-login test also requires `app/.env` with `TEST_ACCOUNT_EMAIL` and
`TEST_ACCOUNT_PASSWORD`.

Email/password and Google sign-in are wired in the app. Passwordless email-link auth is supported by the backend contract, but mobile deep-link capture still requires the Firebase platform link configuration before exposing it in the UI.

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   └── home_screen.dart     # Main home screen
└── widgets/
    ├── attendance_card.dart       # Attendance percentage card
    ├── next_class_card.dart       # Next class information card
    ├── timetable_card.dart        # Individual timetable entry card
    ├── community_feed_card.dart   # Community feed post card
    └── resource_button.dart       # Academic resource button

assets/
└── images/                  # All image assets from Figma
```

## Color Palette

- **Background**: `#FEEEC3` (Cream/Beige)
- **Primary Yellow**: `#FFD966`
- **Accent Green**: `#D2FFB6`
- **Accent Pink**: `#FFC0B6`
- **Accent Purple**: `#E3B6FF`
- **Accent Blue**: `#B6EAFF`
- **Navigation Blue**: `#B4E4FF`
- **Tag Purple**: `#9191FF`
- **Show All Button**: `#FFB6B6`
- **Bottom Nav**: `#FFD966`

## Responsive Design

The app is fully responsive and adapts to different screen sizes:

- Dynamic sizing using `MediaQuery`
- Flexible layouts with `Expanded` and `Flexible` widgets
- Horizontal scrolling for timetable cards
- Adaptive padding and spacing
- Images scale proportionally to screen width

## Screenshots

The app includes the following screens/sections:

1. **Header**: University name with menu and profile picture
2. **Attendance Card**: Large, prominent attendance percentage display
3. **Next Class Card**: Upcoming class information
4. **Today's Timetable**: Horizontal scrollable class cards
5. **Community Feed**: Shared notes and resources from peers
6. **Academic Resources**: Quick access buttons
7. **Bottom Navigation**: Five-tab navigation with active state

## Notes

- All assets are downloaded from the Figma design and stored in `assets/images/`
- Assets are valid for 7 days from the Figma MCP server
- The design follows the exact specifications from the Figma file
- Custom shadows, borders, and decorative elements are implemented using Flutter widgets

## License

Licensed under the [MIT License](../LICENSE).
