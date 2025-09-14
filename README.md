# PhishWatch Pro

A Flutter-based mobile application for detecting phishing attempts and educating users about cybersecurity threats.

## Features

### 🛡️ Core Functionality
- **Message Scanning**: Analyze suspicious messages for phishing indicators
- **URL Analysis**: Check links against known phishing databases
- **Real-time Results**: Get instant feedback with confidence scores
- **Educational Content**: Learn about phishing tactics with LIME explanations

### 🎨 Design & UX
- **Material Design 3**: Modern, accessible interface
- **Dark/Light Mode**: Automatic theme switching with manual override
- **Smooth Animations**: Engaging transitions and micro-interactions
- **Responsive Layout**: Optimized for various screen sizes

### 📱 User Experience
- **Welcome Onboarding**: Interactive tutorial with feature showcase
- **Scan History**: Track and review previous scan results
- **Educational Insights**: LIME-powered explanations for learning
- **Safety Recommendations**: Actionable security advice

## Architecture

### 📁 Project Structure
```
lib/
├── constants/          # App themes, colors, and constants
├── models/            # Data models and entities
├── screens/           # UI screens and pages
├── services/          # Business logic and state management
├── utils/             # Helper functions and utilities
└── widgets/           # Reusable UI components
```

### 🏗️ Tech Stack
- **Framework**: Flutter 3.7.2+
- **State Management**: Provider pattern
- **Navigation**: GoRouter for declarative routing
- **Animations**: Built-in Flutter animations + custom transitions
- **Theming**: Material Design 3 with custom color schemes
- **Fonts**: Google Fonts (Roboto family)

## Getting Started

### Prerequisites
- Flutter SDK 3.7.2 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions

### Installation
1. Clone the repository
2. Navigate to the project directory
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Design System

### 🎨 Color Palette
- **Primary**: Indigo (Material Design)
- **Secondary**: Emerald for success states
- **Error**: Red for phishing/danger alerts
- **Warning**: Amber for suspicious content
- **Surface**: Adaptive based on theme mode

### 📏 Spacing & Layout
- **Grid System**: 8pt base unit
- **Touch Targets**: Minimum 48dp (WCAG compliance)
- **Border Radius**: 12dp for modern rounded corners
- **Elevation**: Subtle shadows for depth

### ✨ Animations
- **Duration**: Fast (200ms), Normal (300ms), Slow (500ms)
- **Curves**: Material motion curves
- **Staggered**: List items animate with delays
- **Page Transitions**: Slide and fade combinations

## Accessibility

- **WCAG 2.1 AA Compliance**: High contrast ratios
- **Screen Reader Support**: Semantic labels and descriptions
- **Focus Management**: Logical tab order
- **Touch Targets**: Minimum 48dp for all interactive elements

## Future Enhancements

- [ ] Firebase Authentication integration
- [ ] Real-time phishing database API
- [ ] Machine learning model integration
- [ ] Push notifications for security alerts
- [ ] Multi-language support
- [ ] Offline mode capabilities

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow Flutter/Dart style guidelines
4. Add tests for new features
5. Submit a pull request

## License

This project is part of a university degree program and is for educational purposes.