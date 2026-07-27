import json
import os

with open('extracted.json', 'r', encoding='utf-8') as f:
    extracted = json.load(f)

# Manually translate a few key ones or use a generic approach
# I will use a generic English translation for all, as this is just an example, 
# but I should try to make it look professional.

translations = {
  "text_1": "Reached maximum limit!",
  "text_2": "Your current account is a guest account. You have reached the maximum allowed limit for additions.\\n\\nPlease link your account to Google to continue using the app for free without limits, and to save your data from being lost.",
  "text_3": "Later",
  "text_4": "Link to Google Account",
  "text_5": "Account upgraded successfully! You can now continue without limits.",
  "text_6": "Sales Invoice",
  "text_7": "Customer Data:",
  "text_8": "Order Date:",
  "text_9": "Product",
  "text_10": "Quantity",
  "text_11": "Price",
  "text_12": "Total",
  "text_13": "Total Due:",
  "text_14": "Amount Paid:",
  "text_15": "Remaining (Credit):",
  "text_16": "Thank you for your business!",
  "text_17": "Customer Statement",
  "text_18": "Order History:",
  "text_19": "Order Date",
  "text_20": "Paid",
  "text_21": "Remaining",
  "text_22": "Status",
  "text_23": "cancelled' ? 'Cancelled",
  "text_24": "Approved",
  "text_25": "Scan Barcode",
  "text_26": "Anonymous login failed",
  "text_27": "Initializing your workspace...",
  "text_28": "Retry",
  "text_29": "User not logged in",
  "text_30": "Login cancelled",
  "text_31": "Account linked successfully!",
  "text_32": "Please enter phone number",
  "text_33": "Complete Registration",
  "text_34": "To protect your data from loss, please link your Google account and enter a contact number.",
  "text_35": "Link to Google Account",
  "text_36": "Account linked successfully",
  "text_37": "Phone Number (WhatsApp)",
  "text_38": "Save and Continue",
  "text_39": "Manage Categories",
  "text_40": "No categories currently",
  "text_41": "Add New Category",
  "text_42": "Category Name",
  "text_43": "Cancel",
  "text_44": "Save",
  "text_45": "Edit Category",
  "text_46": "Update",
  "text_47": "User not registered",
  "text_48": "Edit Customer Data",
  "text_49": "Add New Customer",
  "text_50": "Customer Name",
  "text_51": "Required",
  "text_52": "Phone Number",
  "text_53": "Save Changes",
  "text_54": "Add Customer",
  "text_55": "Manage Customers",
  "text_56": "No customers yet.\\nTap + to add a new customer.",
  "text_57": "Delete Customer",
  "text_58": "Are you sure you want to delete this customer?",
  "text_59": "Delete",
  "text_60": "Edit",
  "text_61": "Print Statement",
  "text_62": "Add Customer",
  "text_63": "View",
  "text_64": "Expenses",
  "text_65": "No expenses currently",
  "text_66": "Total Expenses",
  "text_67": "Add New Expense",
  "text_68": "Description (e.g. Shop Rent)",
  "text_69": "Amount",
  "text_70": "Category (Optional)",
  "text_71": "Please enter description",
  "text_72": "Please enter a valid amount greater than zero",
  "text_73": "Inventory Log",
  "text_74": "No transactions recorded yet",
  "text_75": "Product not found",
  "text_76": "Insufficient stock quantity",
  "text_77": "Customer not found",
  "text_78": "Insufficient quantity to reactivate order",
  "text_79": "No product found with this barcode",
  "text_80": "Requested quantity not available in stock",
  "text_81": "Paid amount cannot be greater than total",
  "text_82": "New Sales Order",
  "text_83": "Credit Sale",
  "text_84": "Record order as customer debt",
  "text_85": "Advance Paid Amount (Optional)",
  "text_86": "No orders yet.\\nTap + to create a new order.",
  "text_87": "Are you sure you want to delete this order? Product quantity will be returned to stock.",
  "text_88": "Pending 🟡",
  "text_89": "Processing 🔵",
  "text_90": "Shipped 🟠",
  "text_91": "Completed 🟢",
  "text_92": "Cancelled 🔴",
  "text_93": "Print PDF Invoice",
  "text_94": "New Order",
  "text_95": "processing': return 'Processing",
  "text_96": "shipped': return 'Shipped",
  "text_97": "delivered': return 'Completed",
  "text_98": "cancelled': return 'Cancelled",
  "text_99": "Pending",
  "text_100": "Manual Edit",
  "text_101": "Add Product",
  "text_102": "No products yet.\\nTap + to add a new product.",
  "text_103": "Are you sure you want to delete this product?",
  "text_104": "Reports & Profits",
  "text_105": "Total Sales",
  "text_106": "Net Profit",
  "text_107": "Total Debt (Credit)",
  "text_108": "Daily Sales",
  "text_109": "No sales yet",
  "text_110": "Best Sellers",
  "text_111": "ar', child: Text('Arabic",
  "text_112": "Upgrade Account",
  "text_113": "Tajer Pro Plan 🚀",
  "text_114": "Enjoy unlimited products and customers, with advanced support and detailed analytics.",
  "text_115": "You must link your Google account first to subscribe to the plan.",
  "text_116": "Link Account Now",
  "text_117": "Plan purchase and subscription ($10/month) is available only via the Android app from Google Play, and cannot be paid via web browser.",
  "text_118": "Please download the app on your phone to complete the upgrade and payment process.",
  "text_119": "No subscriptions available currently. Please try again later.",
  "text_120": "Subscribe Now",
  "text_121": "Restore Previous Purchases",
  "text_122": "Manage Suppliers",
  "text_123": "No suppliers currently",
  "text_124": "No phone number",
  "text_125": "Outstanding Debts",
  "text_126": "Add New Supplier",
  "text_127": "Supplier Name",
  "text_128": "Phone Number",
  "text_129": "Opening Balance (Debts)",
  "text_130": "Edit Supplier",
  "text_131": "Update Debts"
}

ar_path = 'lib/l10n/app_ar.arb'
en_path = 'lib/l10n/app_en.arb'

if os.path.exists(ar_path):
    with open(ar_path, 'r', encoding='utf-8') as f:
        existing_ar = json.load(f)
else:
    existing_ar = {}

if os.path.exists(en_path):
    with open(en_path, 'r', encoding='utf-8') as f:
        existing_en = json.load(f)
else:
    existing_en = {}

existing_ar.update(extracted)
existing_en.update(translations)

with open(ar_path, 'w', encoding='utf-8') as f:
    json.dump(existing_ar, f, ensure_ascii=False, indent=2)

with open(en_path, 'w', encoding='utf-8') as f:
    json.dump(existing_en, f, ensure_ascii=False, indent=2)

print("Updated ARB files.")
