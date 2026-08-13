const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Helper to send notification to the merchant
async function notifyMerchant(merchantId, title, body) {
  try {
    const settingsDoc = await admin.firestore()
      .collection('merchants')
      .doc(merchantId)
      .collection('settings')
      .doc('security')
      .get();
    
    let notifyOnCancel = true;
    let notifyOnDrawerShortage = true;
    let notifyOnCredit = false;

    if (settingsDoc.exists) {
      const data = settingsDoc.data();
      notifyOnCancel = data.notifyOnCancel ?? true;
      notifyOnDrawerShortage = data.notifyOnDrawerShortage ?? true;
      notifyOnCredit = data.notifyOnCredit ?? false;
    }

    // Basic logic mapping (can be expanded)
    if (title.includes('إلغاء') && !notifyOnCancel) return;
    if (title.includes('عجز') && !notifyOnDrawerShortage) return;
    if (title.includes('آجل') && !notifyOnCredit) return;

    // Get Merchant FCM Tokens
    const merchantDoc = await admin.firestore().collection('merchants').doc(merchantId).get();
    if (!merchantDoc.exists) return;
    
    const fcmTokens = merchantDoc.data().fcmTokens || [];
    if (fcmTokens.length === 0) return;

    const message = {
      notification: {
        title: title,
        body: body,
      },
      tokens: fcmTokens, // Sends only to the merchant's devices
    };

    await admin.messaging().sendMulticast(message);
    console.log(`Notification sent to merchant ${merchantId}`);
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}

exports.monitorOrderCancellations = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'cancelled' && after.status === 'cancelled') {
      // Check if it was cancelled by an employee
      const creatorName = after.creatorName || 'مجهول';
      // If the merchant himself cancelled it, we might not want to notify him.
      // Assuming 'isEmployee' flag or logic is handled on app side when setting creatorName.
      // For now, we alert any cancellation not done by "التاجر"
      if (creatorName !== 'التاجر') {
         await notifyMerchant(
           after.merchantId,
           'تنبيه: إلغاء فاتورة ⚠️',
           `مرحباً! تم إلغاء الفاتورة من قبل الموظف (${creatorName}). يرجى المراجعة عند تفرغك.`
         );
      }
    }

    // Monitor Credit (Debt)
    if (!before.isCredit && after.isCredit) {
       const creatorName = after.creatorName || 'مجهول';
       if (creatorName !== 'التاجر') {
         await notifyMerchant(
           after.merchantId,
           'تنبيه: فاتورة آجل (دين) 📝',
           `تم تسجيل فاتورة بالآجل للعميل (${after.customerName}) من قبل الموظف (${creatorName}).`
         );
       }
    }
});

exports.monitorDrawerShortage = functions.firestore
  .document('shifts/{shiftId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if shift just closed
    if (before.status === 'open' && after.status === 'closed') {
      const expectedCash = after.expectedCash || 0;
      const actualCash = after.actualCash || 0;
      const difference = actualCash - expectedCash;

      if (difference < 0) {
        const creatorName = after.employeeName || 'مجهول';
        await notifyMerchant(
           after.merchantId,
           'تنبيه: عجز في الصندوق 🚨',
           `الوردية التي أغلقها (${creatorName}) تحتوي على عجز مالي بقيمة ${Math.abs(difference)}. التفاصيل متاحة في شاشة الورديات.`
        );
      }
    }
});
