import os

content = '''rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Safely get user's merchantId, default to empty string if missing
    function getUserMerchantId() {
      let userDoc = get(/databases/\/documents/users/\);
      return userDoc != null ? userDoc.data.get('merchantId', '') : '';
    }
    
    function hasAccess(merchantId) {
      return isAuthenticated() && (
        request.auth.uid == merchantId || 
        getUserMerchantId() == merchantId
      );
    }
    
    // Users Collection (AppUser profile)
    match /users/{userId} {
      allow read: if isAuthenticated() && (request.auth.uid == userId || hasAccess(resource.data.get('merchantId', '')));
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (request.auth.uid == userId || hasAccess(resource.data.get('merchantId', ''))) 
                    && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['plan']));
      allow delete: if isAuthenticated() && hasAccess(resource.data.get('merchantId', ''));
    }

    // Device Registry (Anti-abuse)
    match /device_registry/{deviceId} {
      allow read, write: if isAuthenticated();
      allow delete: if false;
    }

    // --- ROOT COLLECTIONS ---
    match /products/{productId} {
      allow read, update, delete: if hasAccess(resource.data.merchantId);
      allow create: if hasAccess(request.resource.data.merchantId);
    }
    match /customers/{customerId} {
      allow read, update, delete: if hasAccess(resource.data.merchantId);
      allow create: if hasAccess(request.resource.data.merchantId);
    }
    match /orders/{orderId} {
      allow read, update, delete: if hasAccess(resource.data.merchantId);
      allow create: if hasAccess(request.resource.data.merchantId);
    }

    // --- MERCHANT SUB-COLLECTIONS ---
    match /merchants/{merchantId} {
      match /categories/{categoryId} {
        allow read, update, delete: if hasAccess(merchantId);
        allow create: if hasAccess(merchantId);
      }
      match /expenses/{expenseId} {
        allow read, update, delete: if hasAccess(merchantId);
        allow create: if hasAccess(merchantId);
      }
      match /suppliers/{supplierId} {
        allow read, update, delete: if hasAccess(merchantId);
        allow create: if hasAccess(merchantId);
      }
      match /employees/{employeeId} {
        allow read, update, delete: if hasAccess(merchantId);
        allow create: if hasAccess(merchantId);
      }
      match /inventory_logs/{logId} {
        allow read, update, delete: if hasAccess(merchantId);
        allow create: if hasAccess(merchantId);
      }
    }
  }
}'''

with open('firestore.rules', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated firestore.rules")
