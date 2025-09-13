import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PayHereService {
  // Replace with your actual Sandbox credentials from the PayHere dashboard
  static const String sandboxMerchantId = "1232005"; // THIS IS A TEST ID, USE YOURS
  static const String merchantSecret = "MzU1NDkzNTU0MDIzOTA1NzQ4ODQzNTMxOTExMjAyMTIzNjY5OTA4Ng=="; // THIS IS A TEST SECRET, USE YOURS

  static void startPayment({
    required BuildContext context,
    required double amount,
    required String orderId,
    required String itemName,
    required Map<String, dynamic> customerDetails,
    required Function(String paymentId) onSuccess,
    required Function(String error) onError,
    required Function() onDismissed,
  }) async {
    // Web: open hosted checkout via Cloud Function
    if (kIsWeb) {
      final uri = Uri.https(
        'us-central1-ceylontix-app.cloudfunctions.net',
        '/payHereCheckout',
        {
          'merchant_id': sandboxMerchantId,
          'order_id': orderId,
          'items': itemName,
          'amount': amount.toStringAsFixed(2),
          'currency': 'LKR',
          'first_name': customerDetails['firstName'] ?? 'John',
          'last_name': customerDetails['lastName'] ?? 'Doe',
          'email': customerDetails['email'] ?? 'no-email@test.com',
          'phone': customerDetails['phone'] ?? '0771234567',
          'address': customerDetails['address'] ?? 'No. 1, Galle Road',
          'city': customerDetails['city'] ?? 'Colombo',
          'country': 'Sri Lanka',
          'sandbox': 'true',
        },
      );
      final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!ok) {
        onError('Could not open payment page. Please allow pop-ups and try again.');
      }
      return;
    }

    // Guard: PayHere plugin only supports Android/iOS
    if (!(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
      onError('PayHere is only supported on Android and iOS devices.');
      return;
    }

    // Payment details configuration
    Map paymentObject = {
      "sandbox": true, // Set to true for Sandbox, false for Production
      "merchant_id": sandboxMerchantId,
      "merchant_secret": merchantSecret,
      "notify_url": "https://your-backend.com/notify", // You can leave this empty for now
      "order_id": orderId,
      "items": itemName,
      "amount": amount.toStringAsFixed(2),
      "currency": "LKR",
      "first_name": customerDetails['firstName'],
      "last_name": customerDetails['lastName'],
      "email": customerDetails['email'],
      "phone": customerDetails['phone'],
      "address": customerDetails['address'],
      "city": customerDetails['city'],
      "country": "Sri Lanka",
    };

    try {
      PayHere.startPayment(
        paymentObject,
        (paymentId) {
          debugPrint("PayHere Payment Success: $paymentId");
          onSuccess(paymentId);
        },
        (error) {
          debugPrint("PayHere Payment Error: $error");
          onError(error);
        },
        () {
          debugPrint("PayHere Payment Dismissed");
          onDismissed();
        },
      );
    } on MissingPluginException catch (_) {
      onError('Payment plugin not available. Perform a full restart on a real Android/iOS device or emulator after adding payhere_mobilesdk_flutter.');
    } catch (e) {
      onError('Payment failed to start: ${e.toString()}');
    }
  }
}





