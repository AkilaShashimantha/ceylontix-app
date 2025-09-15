import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';

class PayHereService {
  // Use your actual Sandbox Merchant ID here
  static const String sandboxMerchantId = "1232005"; 

  // This service is now ONLY for mobile payments.
  static void startPayment({
    required BuildContext context,
    required double amount,
    required String orderId,
    required String itemName,
    required Map<String, dynamic> customerDetails,
    required Function(String paymentId) onSuccess,
    required Function(String error) onError,
    required Function() onDismissed,
  }) {
    // Guard: This method is not for web. The web has its own checkout flow.
    if (kIsWeb) {
      onError('This payment method is for mobile devices only.');
      return;
    }

    // This must match the URL of your deployed 'payhereNotify' function
    const notifyUrl = 'https://us-central1-ceylontix-app.cloudfunctions.net/payhereNotify';

    // Payment details configuration for the native mobile SDK
    Map<String, dynamic> paymentObject = {
      "sandbox": true,
      "merchant_id": sandboxMerchantId,
      // NOTE: The merchant_secret is NOT required for mobile SDK initialization.
      // It is only used for server-side hash generation.
      "notify_url": notifyUrl, // CRITICAL: This now points to your backend webhook
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
      onError('Payment plugin not available. Please restart the app on a real Android/iOS device or emulator.');
    } catch (e) {
      onError('Payment failed to start: ${e.toString()}');
    }
  }
}