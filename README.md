# CeylonTix - Event Ticketing Platform

[![Status: Beta](https://img.shields.io/badge/status-beta-green)](https://ampcode.com/threads/T-eaf0d90b-acf4-4bf4-94a8-aba12cc5b9a2)

A comprehensive Flutter-based event ticketing platform with admin management, secure payments, and QR code verification.

## App Logo

![CeylonTix App Logo](assets/logo/app_logo.png)

## 🎯 Project Overview

CeylonTix is a full-featured event ticketing application that provides a complete solution for event organizers and attendees. Built with Flutter for cross-platform compatibility and powered by Firebase for real-time data management.

## ✨ Current Features

### 🎫 **User Features**
- **Event Discovery**: Browse and search events with real-time filtering
- **Event Details**: View comprehensive event information with high-quality images
- **Multi-Tier Ticketing**: Purchase tickets from different pricing tiers
- **Secure Payment**: Integrated PayHere payment gateway with professional preview
- **Digital Tickets**: QR code-based tickets for easy entry
- **User Authentication**: Google Sign-In integration
- **Responsive Design**: Optimized for web, mobile, and tablet

### 🔧 **Admin Features**
- **Admin Dashboard**: Comprehensive management interface
- **Event Management**: Create, edit, and delete events with image uploads
- **Sales Analytics**: Real-time sales tracking and revenue analytics
- **Advanced Reporting**: 
  - Search events by name
  - Filter events by date range
  - Generate professional PDF reports with CeylonTix branding
- **Ticket Verification**: QR code scanner for ticket validation at events
- **Customer Management**: View detailed booking information

### 🛠️ **Technical Features**
- **Cross-Platform**: Web, Android, and iOS support
- **Real-time Data**: Firebase Firestore integration
- **Cloud Functions**: Server-side payment processing
- **PDF Generation**: Professional reports with company branding
- **Image Processing**: Support for Google Drive and FreeImage.host URLs
- **Modern UI**: Material Design with proper accessibility labels

## 🚀 What You Can Do

### **As a Customer:**
1. **Browse Events**: View all available events with search functionality
2. **Purchase Tickets**: Select ticket tiers and complete secure payment
3. **Payment Preview**: Review purchase details before payment
4. **Digital Tickets**: Receive QR code tickets after successful payment
5. **Account Management**: Sign in with Google for personalized experience

### **As an Admin:**
1. **Manage Events**: Full CRUD operations for events
2. **Track Sales**: Monitor ticket sales in real-time
3. **Generate Reports**: Create detailed sales reports with filtering options
4. **Download Analytics**: Export sales data as professional PDF reports
5. **Verify Tickets**: Scan QR codes to validate tickets at events
6. **Customer Support**: Access detailed booking information

### **As a Developer:**
1. **Deploy to Web**: Host on Firebase Hosting or any web server
2. **Mobile Apps**: Build for Android and iOS app stores
3. **Extend Features**: Modular architecture for easy feature additions
4. **Customize Branding**: Easy theme and logo customization

## 🛡️ Security & Payment

- **Secure Authentication**: Firebase Auth with Google Sign-In
- **Payment Processing**: PayHere integration (sandbox and production)
- **Data Protection**: Firestore security rules and server-side validation
- **QR Verification**: Encrypted ticket validation system

## 📱 Supported Platforms

- **Web**: Chrome, Firefox, Safari, Edge
- **Android**: Android 5.0+ (API level 21+)
- **iOS**: iOS 11.0+
- **Desktop**: Windows, macOS, Linux (Flutter desktop)

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Firebase       │    │   PayHere       │
│   (Frontend)    │◄──►│   (Backend)      │    │   (Payments)    │
│                 │    │                  │    │                 │
│ • User Interface│    │ • Authentication │    │ • Payment       │
│ • State Mgmt    │    │ • Firestore DB   │    │   Processing    │
│ • Navigation    │    │ • Cloud Functions│    │ • Webhooks      │
│ • QR Scanner    │    │ • File Storage   │    │ • Security      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🚦 Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Firebase CLI
- Android Studio / VS Code
- PayHere merchant account (for payments)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/AkilaShashimantha/ceylontix-app.git
cd ceylontix-app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase (if not already done)
firebase init
```

4. **Set up PayHere**
   - Update `lib/src/data/services/payhere_service.dart` with your merchant credentials
   - Configure webhook URLs in Firebase Functions

5. **Run the application**
```bash
# Web development
flutter run -d chrome

# Android emulator/device
flutter run -d android

# iOS simulator/device (macOS only)
flutter run -d ios
```

## 🏗️ Build for Production

### Web Deployment
```bash
flutter build web --release
firebase deploy --only hosting
```

### Mobile App Store
```bash
# Android Play Store
flutter build appbundle --release

# iOS App Store (macOS only)
flutter build ios --release
```

## 📊 Database Structure

### Collections:
- `events/` - Event information and ticket tiers
- `bookings/` - Confirmed ticket purchases
- `pending_bookings/` - Temporary payment processing
- `users/` - User profiles and preferences

### Security:
- Role-based access control (admin/user)
- Server-side validation for all transactions
- Encrypted QR codes for ticket verification

## 🛠️ Dependencies

### Core Dependencies
```yaml
flutter: sdk
firebase_core: ^2.32.0
cloud_firestore: ^4.17.5
firebase_auth: ^4.20.0
payhere_mobilesdk_flutter: ^3.2.0
```

### Features
```yaml
qr_flutter: ^4.1.0          # QR code generation
mobile_scanner: ^3.5.7      # QR code scanning  
pdf: ^3.10.7                # PDF generation
printing: ^5.12.0           # PDF sharing/printing
google_sign_in: ^6.3.0      # Authentication
```

## 🎨 Customization

### Branding
1. Replace `assets/logo/app_logo.png` with your logo
2. Update colors in `lib/main.dart` theme configuration
3. Modify company name in PDF templates

### Payment Gateway
1. Update PayHere credentials in services
2. Configure webhook endpoints
3. Test with sandbox before production

## 📈 Analytics & Monitoring

- **Firebase Analytics**: User engagement and app performance
- **Crashlytics**: Error tracking and crash reporting
- **Custom Metrics**: Sales analytics and revenue tracking
- **Admin Dashboard**: Real-time business insights

## 🧪 Testing

```bash
# Run all tests
flutter test

# Test specific features
flutter test test/unit/
flutter test test/integration/
```

## 📦 Project Structure

```
lib/
├── main.dart                          # App entry point
├── src/
    ├── data/
    │   ├── repositories/              # Data access layer
    │   └── services/                  # External service integrations
    ├── domain/
    │   ├── entities/                  # Business models
    │   └── repositories/              # Repository interfaces
    └── presentation/
        ├── screens/                   # UI screens
        │   ├── admin/                 # Admin dashboard & management
        │   ├── auth/                  # Authentication screens
        │   └── user/                  # Customer-facing screens
        └── widgets/                   # Reusable UI components
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit a pull request

## 🐛 Known Issues

- Mobile scanner may require camera permissions on first use
- PayHere sandbox mode for testing payments
- Date filtering currently supports event dates only

## 🚧 Roadmap

### Upcoming Features
- [ ] Email notifications for bookings
- [ ] Event categories and filtering
- [ ] Bulk ticket operations
- [ ] Advanced analytics dashboard
- [ ] Multi-language support
- [ ] Social media integration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Developer**: Akila Shashimantha
- **Repository**: [GitHub - CeylonTix App](https://github.com/AkilaShashimantha/ceylontix-app)
- **Issues**: Report bugs and feature requests in GitHub Issues

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- PayHere for payment gateway
- Material Design for UI guidelines

---

**Status**: ✅ Production Ready | **Version**: 1.0.0 | **Last Updated**:16 /09/2025
