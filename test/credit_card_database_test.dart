import 'package:cashflow/models/account_model.dart';
import 'package:cashflow/models/category_model.dart';
import 'package:cashflow/models/credit_card_model.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;

  const databaseFileName = 'money_tracker.db';

  setUp(() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseFileName);
    await DatabaseHelper.instance.close();
    await deleteDatabase(path);
  });

  tearDown(() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseFileName);
    await DatabaseHelper.instance.close();
    await deleteDatabase(path);
  });

  test('credit card operations: spend with fund lock, pay bill, and delete transaction', () async {
    final dbHelper = DatabaseHelper.instance;

    // 1. Create a bank account with 50,000 balance
    final bankAccountId = await dbHelper.createAccount(Account(
      name: 'Salary Checking',
      balance: 50000.0,
      type: 'Bank',
    ));

    // 2. Create a credit card account with 0 balance (liability)
    final ccAccountId = await dbHelper.createAccount(Account(
      name: 'Infinia CC',
      balance: 0.0,
      type: 'Credit Card',
    ));

    // 3. Create credit card metadata
    final ccId = await dbHelper.createCreditCard(CreditCard(
      accountId: ccAccountId,
      creditLimit: 200000.0,
      statementDay: 1,
      dueDay: 20,
      defaultLockAccountId: bankAccountId,
      autoLock: true,
    ));

    final fetchedCc = await dbHelper.getCreditCardByAccountId(ccAccountId);
    expect(fetchedCc, isNotNull);
    expect(fetchedCc!.creditLimit, 200000.0);
    expect(fetchedCc.defaultLockAccountId, bankAccountId);

    // Initial balances
    expect(await dbHelper.calculatePhysicalBalance(), 50000.0);
    expect(await dbHelper.calculateUsableBalance(), 50000.0);
    expect(await dbHelper.getTotalCreditCardOutstanding(), 0.0);

    // 4. Create category for expense
    final catId = await dbHelper.createCategory(Category(name: 'Dining Out'));

    // 5. Spend 5,000 on CC with lock in bank account
    final txId = await dbHelper.createCreditCardExpenseTransaction(
      ccAccountId: ccAccountId,
      categoryId: catId,
      amount: 5000.0,
      date: '2026-09-14T12:00:00',
      note: 'Dinner with friends',
      lockBankAccountId: bankAccountId,
    );
    expect(txId, isPositive);

    // Verify balances after CC spend:
    // CC liability should be 5,000
    final ccAccounts = await dbHelper.readAllAccounts();
    final ccAcc = ccAccounts.firstWhere((a) => a.id == ccAccountId);
    final bankAcc = ccAccounts.firstWhere((a) => a.id == bankAccountId);

    expect(ccAcc.balance, 5000.0); // Owed
    expect(bankAcc.balance, 50000.0); // Physical bank unchanged

    // Physical cash remains 50,000 (excluding CC)
    expect(await dbHelper.calculatePhysicalBalance(), 50000.0);
    // Locked funds is 5,000
    expect(await dbHelper.getTotalLockedAmount(), 5000.0);
    expect(await dbHelper.getLockedAmountForCreditCard(ccId), 5000.0);
    // Usable balance is 50,000 - 5,000 = 45,000
    expect(await dbHelper.calculateUsableBalance(), 45000.0);

    // Verify lock breakdown for the bank account
    final bankLocks = await dbHelper.getLocksForAccount(bankAccountId);
    expect(bankLocks, hasLength(1));
    expect(bankLocks.first.amount, 5000.0);
    expect(bankLocks.first.isCreditCardLock, isTrue);
    expect(bankLocks.first.displayName, 'Infinia CC');

    // 6. Pay CC Bill of 5,000 from Bank Account
    final paymentTxId = await dbHelper.payCreditCardBill(
      ccAccountId: ccAccountId,
      bankAccountId: bankAccountId,
      amount: 5000.0,
      note: 'Full bill payment',
    );
    expect(paymentTxId, isPositive);

    // Verify balances after bill payment:
    final postPayAccounts = await dbHelper.readAllAccounts();
    final postPayCc = postPayAccounts.firstWhere((a) => a.id == ccAccountId);
    final postPayBank = postPayAccounts.firstWhere((a) => a.id == bankAccountId);

    expect(postPayCc.balance, 0.0); // Liability cleared
    expect(postPayBank.balance, 45000.0); // Physical bank reduced by 5,000
    expect(await dbHelper.calculatePhysicalBalance(), 45000.0);
    expect(await dbHelper.getTotalLockedAmount(), 0.0); // Lock released
    expect(await dbHelper.calculateUsableBalance(), 45000.0);

    // 7. Test expense deletion with lock rollback
    // Add another spend of 3,000
    final txId2 = await dbHelper.createCreditCardExpenseTransaction(
      ccAccountId: ccAccountId,
      categoryId: catId,
      amount: 3000.0,
      date: '2026-09-15T10:00:00',
      note: 'Shopping',
      lockBankAccountId: bankAccountId,
    );

    expect(await dbHelper.getTotalLockedAmount(), 3000.0);
    expect(await dbHelper.calculateUsableBalance(), 42000.0);

    // Now delete this transaction
    await dbHelper.deleteTransaction(txId2);

    // After deleting CC transaction, CC balance resets and locked funds rollback
    final afterDelAccounts = await dbHelper.readAllAccounts();
    final afterDelCc = afterDelAccounts.firstWhere((a) => a.id == ccAccountId);
    expect(afterDelCc.balance, 0.0);
    expect(await dbHelper.getTotalLockedAmount(), 0.0);
    expect(await dbHelper.calculateUsableBalance(), 45000.0);
  });
}
