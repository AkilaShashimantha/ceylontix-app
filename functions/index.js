/* eslint-disable max-len */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

// This function is correct and remains unchanged.
exports.addAdminRole = onCall(async (request) => {
  if (!request.auth || !request.auth.token.admin) {
    throw new HttpsError("permission-denied", "Only admins can add other admins.");
  }
  const email = request.data.email;
  if (!email) {
    throw new HttpsError("invalid-argument", "The function must be called with one argument 'email'.");
  }
  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});
    return {message: `Success! ${email} has been made an admin.`};
  } catch (error) {
    console.error("Error setting custom claim:", error);
    throw new HttpsError("internal", "Error setting admin role.");
  }
});

exports.generatePayHereHash = onCall({ cors: true }, (request) => {
  const {
    merchant_id: merchantId,
    order_id: orderId,
    amount,
    currency,
  } = request.data || {};

  const merchantSecret = process.env.PAYHERE_SECRET;
  if (!merchantSecret) {
    throw new HttpsError("internal", "Server configuration error: PAYHERE_SECRET not set.");
  }

  const hash = crypto
    .createHash("md5")
    .update(
      merchantId +
        orderId +
        amount +
        currency +
        crypto.createHash("md5").update(merchantSecret).digest("hex").toUpperCase(),
    )
    .digest("hex")
    .toUpperCase();

  return { hash };
});

// This function is correct and remains unchanged.
exports.payhereNotify = onRequest(async (req, res) => {
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  let body = req.body;
  try {
    if (!body || Object.keys(body).length === 0) {
      const raw = req.rawBody ? req.rawBody.toString() : "";
      const ctype = (req.headers["content-type"] || "").toString();
      if (ctype.includes("application/x-www-form-urlencoded")) {
        const params = new URLSearchParams(raw);
        body = Object.fromEntries(params.entries());
      } else if (raw) {
        body = JSON.parse(raw);
      }
    }
  } catch (e) {
    console.error("Failed to parse notify body:", e);
    return res.status(400).send("Invalid body");
  }

  console.log("PayHere Notify URL was hit. Parsed Body:", body);

  const merchantSecret = process.env.PAYHERE_SECRET;
  if (!merchantSecret) {
    console.error("CRITICAL: PayHere secret is not configured.");
    return res.status(500).send("Server configuration error.");
  }

  const {
    merchant_id: merchantId,
    order_id: orderId,
    payhere_amount: amount,
    payhere_currency: currency,
    status_code: statusCode,
    md5sig,
  } = body || {};

  if (!merchantId || !orderId || !amount || !currency || !statusCode || !md5sig) {
    console.error("Missing required notify fields", body);
    return res.status(400).send("Missing fields");
  }

  const localMd5sig = crypto.createHash("md5").update(
      String(merchantId) +
      String(orderId) +
      String(amount) +
      String(currency) +
      String(statusCode) +
      crypto.createHash("md5").update(merchantSecret).digest("hex").toUpperCase(),
  ).digest("hex").toUpperCase();

  if (localMd5sig !== md5sig) {
    console.error(`Signature mismatch for order ${orderId}. expected ${localMd5sig} got ${md5sig}`);
    return res.status(401).send("Unauthorized");
  }

  const pendingBookingRef = db.collection("pending_bookings").doc(orderId);

  if (String(statusCode) === "2") { // '2' means a successful payment
    try {
      await db.runTransaction(async (t) => {
        const pendingDoc = await t.get(pendingBookingRef);
        if (!pendingDoc.exists) {
          throw new Error(`Pending booking ${orderId} not found.`);
        }
        const bookingData = pendingDoc.data();

        const finalBookingRef = db.collection("bookings").doc(orderId);
        t.set(finalBookingRef, {...bookingData, status: "confirmed"});

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
        t.update(eventRef, {ticketTiers: tiers});

        t.delete(pendingBookingRef);
      });
      console.log(`Successfully processed and booked order ${orderId}.`);
      return res.status(200).send("OK");
    } catch (error) {
      console.error(`Transaction failed for order ${orderId}:`, error);
      return res.status(500).send("Booking transaction failed.");
    }
  } else {
    await pendingBookingRef.delete().catch(() => {});
    console.log(`Order ${orderId} failed/cancelled (status ${statusCode}). Pending booking deleted.`);
    return res.status(200).send("OK");
  }
});

// Explicit HTTP endpoint for web callers with CORS
exports.generatePayHereHashHttp = onRequest({
region: "us-central1",
}, (req, res) => {
// Manual CORS headers
res.set("Access-Control-Allow-Origin", "*");
res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

if (req.method === "OPTIONS") {
return res.status(204).send("");
}
if (req.method !== "POST") {
return res.status(405).send("Method Not Allowed");
}

let body = req.body;
if (!body || Object.keys(body).length === 0) {
try {
const raw = req.rawBody ? req.rawBody.toString() : "";
body = raw ? JSON.parse(raw) : {};
} catch (e) {
console.error("Failed to parse JSON body:", e);
return res.status(400).json({ error: "Invalid JSON" });
}
}

const defaultMerchantId = process.env.PAYHERE_MERCHANT_ID || "1232005";
const { merchant_id: merchantIdIn, order_id: orderId, amount, currency } = body || {};
const merchantId = merchantIdIn || defaultMerchantId;

const merchantSecret = process.env.PAYHERE_SECRET;
if (!merchantSecret) {
return res.status(500).json({ error: "Server configuration error: PAYHERE_SECRET not set." });
}

try {
const hash = crypto
.createHash("md5")
.update(
String(merchantId) +
String(orderId) +
String(amount) +
String(currency) +
crypto.createHash("md5").update(merchantSecret).digest("hex").toUpperCase(),
)
.digest("hex")
.toUpperCase();

return res.json({ hash, merchant_id: merchantId });
} catch (e) {
console.error("Error hashing for PayHere:", e);
return res.status(500).json({ error: "Internal error" });
}
});

/**
 * Sends a booking confirmation email using Resend.
 * Triggers when a new document is created in the 'bookings' collection.
 */
exports.sendBookingConfirmationEmail = onDocumentCreated("bookings/{bookingId}", async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const bookingData = snap.data();
  const bookingId = event.params.bookingId;
  const apiKey = process.env.RESEND_KEY;

  if (!apiKey) {
  console.error("CRITICAL: Resend API Key is not configured.");
  return;
  }
  const { Resend } = require("resend");
   const qr = require("qrcode");
  const resend = new Resend(apiKey);

  try {
    const qrCodeBuffer = await qr.toBuffer(bookingId);

    const emailHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Your Ticket for ${bookingData.eventName}</title>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol'; margin: 0; padding: 0; background-color: #f4f4f4; }
          .container { max-width: 600px; margin: 40px auto; background-color: #ffffff; border: 1px solid #e0e0e0; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
          .header { background-color: #007bff; color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .header h1 { margin: 0; font-size: 28px; }
          .content { padding: 30px; }
          .content h2 { color: #333; }
          .content p { line-height: 1.6; color: #555; }
          .ticket-details { margin-top: 20px; padding: 15px; background-color: #f9f9f9; border-left: 4px solid #007bff; }
          .ticket-details p { margin: 8px 0; }
          .qr-code { text-align: center; margin-top: 30px; }
          .qr-code h3 { color: #333; }
          .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e0e0e0; font-size: 12px; text-align: center; color: #888; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header"><h1>Your Ticket for ${bookingData.eventName}</h1></div>
          <div class="content">
            <h2>Booking Confirmed!</h2>
            <p>Hi ${bookingData.userName},</p>
            <p>Thank you for your purchase. Your ticket is confirmed and the QR code is attached to this email. Please present it at the event entrance for scanning.</p>
            <div class="ticket-details">
              <p><strong>Event:</strong> ${bookingData.eventName}</p>
              <p><strong>Tier:</strong> ${bookingData.tierName}</p>
              <p><strong>Quantity:</strong> ${bookingData.quantity}</p>
              <p><strong>Total Price:</strong> LKR ${bookingData.totalPrice.toFixed(2)}</p>
              <p><strong>Booking ID:</strong> ${bookingId}</p>
            </div>
            <div class="qr-code">
              <h3>Your QR Code Ticket</h3>
              <p>(See attachment: ticket_${bookingId}.png)</p>
            </div>
          </div>
          <div class="footer">
            <p>This is an automated email. Please do not reply.</p>
            <p>&copy; ${new Date().getFullYear()} CeylonTix</p>
          </div>
        </div>
      </body>
      </html>
    `;

    await resend.emails.send({
      from: "CeylonTix <onboarding@resend.dev>",
      to: [bookingData.userEmail],
      subject: `Your Ticket for ${bookingData.eventName}`,
      html: emailHtml,
      attachments: [
        {
          filename: `ticket_${bookingId}.png`,
          content: qrCodeBuffer,
        },
      ],
    });

    console.log(`Successfully sent email with Resend for booking ${bookingId}.`);
  } catch (error) {
    console.error(`Error sending Resend email for booking ${bookingId}:`, error);
  }
});
