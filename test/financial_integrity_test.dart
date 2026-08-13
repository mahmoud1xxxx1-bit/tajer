import 'package:flutter_test/flutter_test.dart';
import 'package:tajer/features/orders/domain/order.dart';
import 'package:tajer/features/orders/domain/cart_item.dart';
import 'package:tajer/features/products/domain/product.dart';
import 'package:tajer/features/shifts/domain/shift.dart';

void main() {
  group('Financial Integrity & Math Accuracy Tests', () {
    
    test('1. Tax Calculation (Exclusive & Inclusive) with Floating Point Precision', () {
      // Test case: Product cost is 13.33, Tax is 15% Exclusive
      final itemExclusive = CartItem(
        productId: 'p1',
        productName: 'Test Item 1',
        quantity: 1,
        price: 13.33,
        total: 13.33,
        taxMode: TaxMode.store,
        taxPercentage: 15.0,
        isTaxInclusive: false,
      );

      final taxRateEx = itemExclusive.getEffectiveTax(15.0);
      expect(taxRateEx, 15.0);

      // Manual tax calculation: 13.33 * 0.15 = 1.9995
      double taxAmountEx = itemExclusive.total * (taxRateEx / 100);
      double grandTotalEx = itemExclusive.total + taxAmountEx;

      expect(taxAmountEx, closeTo(1.9995, 0.0001));
      expect(grandTotalEx, closeTo(15.3295, 0.0001));

      // Test case: Product cost is 100, Tax is 15% Inclusive
      final itemInclusive = CartItem(
        productId: 'p2',
        productName: 'Test Item 2',
        quantity: 1,
        price: 100.0,
        total: 100.0,
        taxMode: TaxMode.store,
        taxPercentage: 15.0,
        isTaxInclusive: true,
      );

      final taxRateIn = itemInclusive.getEffectiveTax(15.0);
      expect(taxRateIn, 15.0);

      // Reverse tax calculation: 100 - (100 / 1.15) = 13.04347...
      double taxAmountIn = itemInclusive.total - (itemInclusive.total / (1 + (taxRateIn / 100)));
      double basePriceIn = itemInclusive.total - taxAmountIn;

      expect(taxAmountIn, closeTo(13.0434, 0.0001));
      expect(basePriceIn, closeTo(86.9565, 0.0001));
      expect(basePriceIn + taxAmountIn, 100.0);
    });

    test('2. Shift Cash Drawer Closing Equation', () {
      // Equation: Opening + Cash Sales + Debt Collections(Cash) - Cash Expenses - Cash Returns = Expected Cash
      // Let's simulate a scenario
      
      double openingCash = 100.0;
      double cashSales = 200.0;
      double cardSales = 500.0;
      double debtCollectionsCash = 150.0;
      double cashExpenses = 50.0;
      double cashReturns = 20.0;

      // Note: Shifts in Tajer track expenses manually, but we can test the expected math
      double expectedCash = openingCash + cashSales + debtCollectionsCash - cashExpenses - cashReturns;

      expect(expectedCash, 380.0);
      
      // Let's verify how shift models this:
      final shift = Shift(
        id: 's1',
        merchantId: 'm1',
        employeeId: 'e1',
        employeeName: 'Emp 1',
        startTime: DateTime.now(),
        startCash: openingCash,
        cashSales: cashSales,
        cardTotal: cardSales,
        debtCollectionsCash: debtCollectionsCash,
        refundsCash: cashReturns,
        status: 'open',
      );

      // Inside ShiftRepository or Shift Closing Screen, expected cash is calculated.
      // We will emulate that logic here.
      // Expected = startCash + (cashSales ?? 0) + (debtCollectionsCash ?? 0) - (refundsCash ?? 0) - (expensesCash ?? 0)
      double calculatedExpected = shift.startCash + 
                                  (shift.cashSales ?? 0.0) + 
                                  (shift.debtCollectionsCash ?? 0.0) - 
                                  (shift.refundsCash ?? 0.0) - 
                                  cashExpenses; // Assuming cashExpenses comes from another stream
      
      expect(calculatedExpected, 380.0);
    });

    test('3. Split Payment Integrity', () {
      // An order is 1000. Customer pays 200 Cash, 300 Network, and 500 is Credit (Debt).
      final order = AppOrder(
        id: 'o1',
        merchantId: 'm1',
        customerId: 'c1',
        customerName: 'Cust 1',
        total: 1000.0,
        paidAmount: 500.0,
        isCredit: true,
        paymentMethod: 'split',
        splitCashAmount: 200.0,
        splitNetworkAmount: 300.0,
        createdAt: DateTime.now(),
      );

      // Verify that split sum equals paidAmount
      double sumSplit = (order.splitCashAmount ?? 0.0) + (order.splitNetworkAmount ?? 0.0);
      expect(sumSplit, order.paidAmount);

      // Verify that remaining debt is correct
      double remainingDebt = order.total - order.paidAmount;
      expect(remainingDebt, 500.0);
    });

    test('4. COGS and Gross Profit Calculation', () {
      // Selling 2 items.
      // Item 1: Cost 10, Sale Price 20, Qty 2 = Total Sales 40, Total Cost 20
      // Item 2: Cost 50, Sale Price 45 (Loss), Qty 1 = Total Sales 45, Total Cost 50
      
      final items = [
        CartItem(
          productId: 'p1',
          productName: 'Item 1',
          quantity: 2,
          price: 20.0,
          total: 40.0,
          costPrice: 10.0, // Per unit cost
        ),
        CartItem(
          productId: 'p2',
          productName: 'Item 2',
          quantity: 1,
          price: 45.0,
          total: 45.0,
          costPrice: 50.0,
        ),
      ];

      double totalSales = 0.0;
      double totalCOGS = 0.0;

      for (var item in items) {
        totalSales += item.total;
        totalCOGS += (item.costPrice ?? 0.0) * item.quantity;
      }

      expect(totalSales, 85.0);
      expect(totalCOGS, 70.0);

      double grossProfit = totalSales - totalCOGS;
      expect(grossProfit, 15.0);
    });
  });
}
