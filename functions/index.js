const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto"); // Node.js crypto library for hashing

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Callable Cloud Function to grant a user the admin role.
 * Only an existing admin can call this function.
 */
exports.addAdminRole = functions.https.onCall(async (data, context) => {
  // Security: caller must be an admin
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can add other admins.",
    );
  }

  // Validate input
  const email = (
    data && typeof data.email === "string" ? data.email : ""
  ).trim();
  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Provide 'email' (non-empty string).",
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


// ======================================================================
// ** NEW FUNCTION FOR SECURE WEB PAYMENTS **
// ======================================================================
/**
* Hosted PayHere checkout entry point for Web.
* GET /payHereCheckout?merchant_id=...&order_id=...&items=...&amount=...
*   &currency=LKR&first_name=...&last_name=...&email=...&phone=...
*   &address=...&city=...&country=...
 * Returns an auto-submitting HTML form to PayHere Sandbox/Prod checkout
 * with a server-computed hash.
*/
exports.payHereCheckout = functions.https.onRequest((req, res) => {
  if (req.method !== "GET") {
    return res.status(405).send("Method Not Allowed");
  }

  const cfg = functions.config();
  const cfgSecret = cfg && cfg.payhere && cfg.payhere.secret;
  const MERCHANT_SECRET = cfgSecret ||
    "MzgxNjc1NDc1MzQwODQyMTI0NzAyMDk0MzUzNzQzMzcx" +
    "MzU4OTI0MA==";

  const sandbox = req.query.sandbox !== "false";
  const baseUrl = sandbox ? "https://sandbox.payhere.lk/pay/checkout" : "https://www.payhere.lk/pay/checkout";

  const required = [
    "merchant_id",
    "order_id",
    "items",
    "amount",
    "first_name",
    "last_name",
    "email",
    "phone",
    "address",
    "city",
  ];
  for (const k of required) {
    if (!req.query[k]) {
      return res.status(400).send(`Missing '${k}'`);
    }
  }

  const merchantId = String(req.query.merchant_id);
  const orderId = String(req.query.order_id);
  const items = String(req.query.items);

  // Validate amount
  const amountRaw = req.query.amount;
  const amountNum = Number(amountRaw);
  if (isNaN(amountNum) || amountNum <= 0) {
    return res.status(400).send("Invalid 'amount'");
  }
  const amount = amountNum.toFixed(2);

  const currency = req.query.currency ?
    String(req.query.currency) :
    "LKR";
  const currencyUpper = currency.toUpperCase();
  const firstName = String(req.query.first_name);
  const lastName = String(req.query.last_name);
  const email = String(req.query.email);
  const phone = String(req.query.phone);
  const address = String(req.query.address);
  const city = String(req.query.city);
  const country = String(req.query.country || "Sri Lanka");
  // const notifyUrl = String(req.query.notify_url || "");
  const returnUrl = String(req.query.return_url || "");
  const cancelUrl = String(req.query.cancel_url || ""); // Define cancelUrl

  // Construct prehash string according to PayHere documentation
  const prehash =
    merchantId +
    orderId +
    amount +
    currencyUpper +
    email +
    MERCHANT_SECRET;
  const hash = crypto.createHash("md5")
      .update(prehash)
      .digest("hex"); // Add .digest("hex") to get the hash string

  res.set("Content-Type", "text/html");
  res.status(200).send(
      "<!DOCTYPE html>" +
      "<html lang=\"en\">" +
      "<head><meta charset=\"utf-8\">" +
      "<title>Redirecting...</title></head>" +
      "<body>" +
      `<form id="phForm" method="post" action="${baseUrl}">` +
      `<input type="hidden" name="merchant_id" value="${merchantId}">` +
      `<input type="hidden" name="return_url" value="${returnUrl}">` +
      `<input type="hidden" name="cancel_url" value="${cancelUrl}">` +
      `<input type="hidden" name="currency" value="${currencyUpper}">` +
      `<input type="hidden" name="order_id" value="${orderId}">` +
      `<input type="hidden" name="items" value="${items}">` +

      `<input type="hidden" name="amount" value="${amount}">` +
      `<input type="hidden" name="first_name" value="${firstName}">` +
      `<input type="hidden" name="last_name" value="${lastName}">` +
      `<input type="hidden" name="email" value="${email}">` +
      `<input type="hidden" name="phone" value="${phone}">` +
      `<input type="hidden" name="address" value="${address}">` +
      `<input type="hidden" name="city" value="${city}">` +
      `<input type="hidden" name="country" value="${country}">` +
      `<input type="hidden" name="hash" value="${hash}">` +
      "</form>" +
      "<p>Redirecting to PayHere...</p>" +
      "<script>document.getElementById('phForm').submit();</script>" +
      "</body></html>",
  );
});
