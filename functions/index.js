const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const express = require("express"); // Add express for body parsing
const cors = require("cors"); // Optional: for CORS

admin.initializeApp();

const db = admin.firestore();

/**
 * Callable Cloud Function to grant a user the admin role.
 */
exports.addAdminRole = functions.https.onCall(async (data, context) => {
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can add other admins.",
    );
  }

  const email = data.email;
  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with one argument 'email'.",
    );
  }

  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});
    return {
      message: `Success! ${email} has been made an admin.`,
    };
  } catch (error) {
    console.error("Error setting custom claim:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Error setting admin role.",
    );
  }
});

/**
 * HTTP Function to generate and serve a self-submitting PayHere form.
 * This is the endpoint the Flutter web app should launch, which will then
 * POST to PayHere, solving the redirect issue caused by GET requests.
 */
exports.payhereWebCheckout = functions.https.onRequest((req, res) => {
  // 1. Get the Merchant Secret from secure config
  const merchantSecret = process.env.PAYHERE_SECRET;
  if (!merchantSecret) {
    console.error("CRITICAL: PayHere secret is not configured.");
    return res.status(500).send("Server configuration error.");
  }

  // 2. Extract payment data from the query parameters
  const {
    merchant_id,
    order_id,
    amount,
    currency,
    return_url,
    cancel_url,
    notify_url,
    items,
    first_name,
    last_name,
    email,
    phone,
    address,
    city,
    country,
  } = req.query;

  // 3. Basic validation
  if (!merchant_id || !order_id || !amount || !currency) {
    return res.status(400).send("Missing required payment parameters.");
  }

  // 4. Generate the security hash
  const amountFormatted = parseFloat(amount).toFixed(2);
  const hashedSecret = crypto
      .createHash("md5")
      .update(merchantSecret)
      .digest("hex")
      .toUpperCase();
  const prehash =
    merchant_id + order_id + amountFormatted + currency + hashedSecret;
  const hash = crypto
      .createHash("md5")
      .update(prehash)
      .digest("hex")
      .toUpperCase();

  // 5. Construct the self-submitting HTML form
  const htmlForm = `
    <!DOCTYPE html>
    <html>
    <head>
        <title>Redirecting to PayHere...</title>
    </head>
    <body onload="document.forms[0].submit();" style="text-align:center; padding-top:50px; font-family:sans-serif;">
        <h2>Redirecting to Secure Payment Gateway</h2>
        <p>Please wait...</p>
        <form method="post" action="https://sandbox.payhere.lk/pay/checkout">
            <input type="hidden" name="merchant_id" value="${merchant_id}">
            <input type="hidden" name="return_url" value="${return_url || ""}">
            <input type="hidden" name="cancel_url" value="${cancel_url || ""}">
            <input type="hidden" name="notify_url" value="${notify_url || ""}">
            <input type="hidden" name="order_id" value="${order_id}">
            <input type="hidden" name="items" value="${items || ""}">
            <input type="hidden" name="amount" value="${amountFormatted}">
            <input type="hidden" name="currency" value="${currency}">
            <input type="hidden" name="hash" value="${hash}">
            <input type="hidden" name="first_name" value="${first_name || ""}">
            <input type="hidden" name="last_name" value="${last_name || ""}">
            <input type="hidden" name="email" value="${email || ""}">
            <input type="hidden" name="phone" value="${phone || ""}">
            <input type="hidden" name="address" value="${address || ""}">
            <input type="hidden" name="city" value="${city || ""}">
            <input type="hidden" name="country" value="${country || ""}">
            <noscript><input type="submit" value="Click here to proceed if you are not redirected."></noscript>
        </form>
    </body>
    </html>
  `;

  // 6. Send the HTML response
  res.set("Content-Type", "text/html");
  res.status(200).send(htmlForm);
});

/**
 * HTTP Webhook to handle PayHere payment notifications.
 * This is the most secure way to confirm a payment and create a booking.
 */
const payhereNotifyApp = express();
payhereNotifyApp.use(cors({ origin: true }));
payhereNotifyApp.use(express.json());
payhereNotifyApp.use(express.urlencoded({ extended: true }));

payhereNotifyApp.post("/", async (req, res) => {
  // 1. Get the Merchant Secret from secure config
  const merchantSecret = process.env.PAYHERE_SECRET;
  if (!merchantSecret) {
    console.error("CRITICAL: PayHere secret is not configured.");
    res.status(500).send("Server configuration error.");
    return;
  }

  // 2. Extract data from the POST request from PayHere
  const {
    merchant_id: merchantId,
    order_id: orderId,
    payhere_amount: amount,
    payhere_currency: currency,
    status_code: statusCode,
    md5sig,
  } = req.body;

  if (!merchantId || !orderId || !amount || !currency || !statusCode || !md5sig) {
    res.status(400).send("Missing required fields.");
    return;
  }

  // 3. Validate the signature to ensure the request is from PayHere
  const localMd5sig = crypto
    .createHash("md5")
    .update(
      merchantId +
        orderId +
        amount +
        currency +
        statusCode +
        crypto.createHash("md5").update(merchantSecret).digest("hex").toUpperCase(),
    )
    .digest("hex")
    .toUpperCase();

  if (localMd5sig !== md5sig) {
    console.error(`Signature mismatch for order ${orderId}.`);
    res.status(401).send("Unauthorized");
    return;
  }

  // 4. Process the payment status
  const pendingBookingRef = db.collection("pending_bookings").doc(orderId);

  if (statusCode == 2) { // Payment was successful
    try {
      await db.runTransaction(async (t) => {
        const pendingDoc = await t.get(pendingBookingRef);
        if (!pendingDoc.exists) {
          throw new Error(`Pending booking ${orderId} not found.`);
        }
        const bookingData = pendingDoc.data();

        // Create the final booking document
        const finalBookingRef = db.collection("bookings").doc();
        t.set(finalBookingRef, bookingData);

        // Decrement the ticket tier quantity
        const eventRef = db.collection("events").doc(bookingData.eventId);
        const eventDoc = await t.get(eventRef);
        if (!eventDoc.exists) throw new Error("Event not found");

        const eventData = eventDoc.data();
        const tiers = eventData.ticketTiers;
        const tierIndex = tiers.findIndex((t) => t.name === bookingData.tierName);

        if (tierIndex === -1) throw new Error("Ticket tier not found");
        if (tiers[tierIndex].quantity < bookingData.quantity) {
          throw new Error("Not enough tickets available.");
        }
        tiers[tierIndex].quantity -= bookingData.quantity;
        t.update(eventRef, { ticketTiers: tiers });

        // Clean up the pending booking
        t.delete(pendingBookingRef);
      });
      console.log(`Successfully processed and booked order ${orderId}.`);
      res.status(200).send("OK");
    } catch (error) {
      console.error(`Transaction failed for order ${orderId}:`, error);
      await pendingBookingRef.delete().catch((e) => {
        console.error(`Failed to delete pending booking ${orderId} after transaction failure:`, e);
      });
      res.status(500).send("Internal Server Error: Booking transaction failed.");
    }
  } else {
    // Payment failed or was cancelled, clean up the pending booking
    try {
      await pendingBookingRef.delete();
      console.log(`Order ${orderId} failed/cancelled. Pending booking deleted.`);
      res.status(200).send("OK");
    } catch (error) {
      console.error(`Failed to delete pending booking for failed order ${orderId}:`, error);
      res.status(500).send("Internal Server Error: Cleanup failed.");
    }
  }
});
exports.payhereNotify = functions.https.onRequest(payhereNotifyApp);
