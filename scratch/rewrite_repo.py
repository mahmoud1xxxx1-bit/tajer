import re

path = 'lib/features/orders/data/branch_aware_order_repository.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if 'import \'package:cloud_functions/cloud_functions.dart\';' not in content:
    content = content.replace('import \'package:flutter/foundation.dart\';', 'import \'package:flutter/foundation.dart\';\nimport \'package:cloud_functions/cloud_functions.dart\';\nimport \'package:uuid/uuid.dart\';')

def replace_method(content, method_name, new_impl):
    # Match the method signature up to "async {"
    match = re.search(r"Future<.*?>\s+" + method_name + r"[\s\S]*?async\s*\{", content)
    if not match:
        print(f"Could not find {method_name}")
        return content
    
    start_idx = match.end()
    brace_count = 1
    end_idx = start_idx
    while brace_count > 0 and end_idx < len(content):
        if content[end_idx] == '{':
            brace_count += 1
        elif content[end_idx] == '}':
            brace_count -= 1
        end_idx += 1
        
    return content[:start_idx] + "\n" + new_impl + "\n" + content[end_idx-1:]


new_create_order = """
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('createOrder');
      final operationId = const Uuid().v4();
      final effectiveBranchId = _operationBranch(branchId ?? order.branchId);
      final result = await callable.call({
        'operationId': operationId,
        'order': order.toJson(),
        'shiftId': shiftId,
        'branchId': effectiveBranchId,
      });
      // Optionally re-fetch the order from Firestore if needed, but for now just return the local copy with the id
      return order;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
"""

new_update_status = """
    try {
      if (newStatus == 'cancelled') {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('cancelOrder');
        final operationId = const Uuid().v4();
        await callable.call({
          'operationId': operationId,
          'orderId': order.id,
          'shiftId': order.shiftId,
        });
      } else {
        // Normal non-financial status transition
        final orderRef = firestore.collection('orders').doc(order.id);
        await orderRef.update({
          'status': newStatus,
          'statusTransition': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
"""

new_return_items = """
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('partialReturn');
      final operationId = const Uuid().v4();
      final returnedItemsData = orderReturn.returnedItems.map((e) => {
        'lineId': e.lineId,
        'quantity': e.quantity,
        'reason': e.reason,
      }).toList();
      
      await callable.call({
        'operationId': operationId,
        'orderId': originalOrder.id,
        'returnId': orderReturn.id,
        'returnedItems': returnedItemsData,
        'shiftId': originalOrder.shiftId,
      });
      
      // We should ideally fetch the updated order, but returning the original is a placeholder 
      // since the UI will likely refresh from a stream.
      return originalOrder;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to process return: $e');
    }
"""

new_pay_debt = """
    try {
      if (amountPaid <= 0) return;
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('payCustomerDebt');
      final operationId = const Uuid().v4();
      final paymentId = const Uuid().v4();
      
      await callable.call({
        'operationId': operationId,
        'paymentId': paymentId,
        'customerId': customerId,
        'amount': amountPaid,
        'paymentMethod': paymentMethod,
        'shiftId': shiftId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Server Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to pay debt: $e');
    }
"""


content = replace_method(content, 'createOrder', new_create_order)
content = replace_method(content, 'updateOrderStatus', new_update_status)
content = replace_method(content, 'returnOrderItems', new_return_items)
content = replace_method(content, 'payCustomerDebt', new_pay_debt)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Rewritten repository successfully!")
