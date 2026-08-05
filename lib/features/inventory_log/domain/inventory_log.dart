import 'package:cloud_firestore/cloud_firestore.dart';
      merchantId: merchantId ?? this.merchantId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      changeQuantity: changeQuantity ?? this.changeQuantity,
      previousQuantity: previousQuantity ?? this.previousQuantity,
      newQuantity: newQuantity ?? this.newQuantity,
      reason: reason ?? this.reason,
      userEmail: userEmail ?? this.userEmail,
      date: date ?? this.date,
    );
  }
}
