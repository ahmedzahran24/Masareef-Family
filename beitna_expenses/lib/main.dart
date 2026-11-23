import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('ar');
  runApp(const BeitnaApp());
}

final auth = FirebaseAuth.instance;
final db = FirebaseFirestore.instance;
final money = NumberFormat('#,##0.##', 'en');
const primary = Color(0xFF12756B);

class BeitnaApp extends StatelessWidget {
  const BeitnaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'بيتنا | مصاريفنا',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: primary),
          scaffoldBackgroundColor: const Color(0xFFF6F9F8),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF6F9F8)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: StreamBuilder<User?>(
          stream: auth.authStateChanges(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Loading();
            return snap.data == null ? const LoginPage() : const HomeGate();
          },
        ),
      );
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

void alert(BuildContext context, Object error) {
  final msg = error is FirebaseAuthException
      ? switch (error.code) {
          'email-already-in-use' => 'البريد الإلكتروني مستخدم بالفعل',
          'invalid-email' => 'البريد الإلكتروني غير صحيح',
          'weak-password' => 'كلمة المرور ضعيفة، استخدم ٦ أحرف أو أكثر',
          'invalid-credential' || 'wrong-password' || 'user-not-found' => 'البريد أو كلمة المرور غير صحيحين',
          _ => 'خطأ في تسجيل الدخول: ${error.message ?? error.code}',
        }
      : 'حصل خطأ: $error';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();
  bool register = false, busy = false;
  @override
  void dispose() { email.dispose(); pass.dispose(); name.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (email.text.trim().isEmpty || pass.text.length < 6 || (register && name.text.trim().isEmpty)) {
      alert(context, 'اكتب البيانات كاملة وكلمة مرور من ٦ أحرف على الأقل'); return;
    }
    setState(() => busy = true);
    try {
      if (register) {
        final cred = await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: pass.text);
        await db.collection('users').doc(cred.user!.uid).set({'name': name.text.trim(), 'email': email.text.trim(), 'householdId': null});
      } else {
        await auth.signInWithEmailAndPassword(email: email.text.trim(), password: pass.text);
      }
    } catch (e) { if (mounted) alert(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.home_rounded, size: 76, color: primary),
        const SizedBox(height: 10),
        const Text('بيتنا', textAlign: TextAlign.center, style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: primary)),
        const Text('مصاريفنا سوا، وميزانيتنا واضحة ❤️', textAlign: TextAlign.center),
        const SizedBox(height: 36),
        Text(register ? 'إنشاء حساب جديد' : 'تسجيل الدخول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 16),
        if (register) ...[TextField(controller: name, decoration: const InputDecoration(labelText: 'اسمك')), const SizedBox(height: 12)],
        TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
        const SizedBox(height: 12),
        TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.all(10), child: Text(busy ? 'جارٍ التحميل...' : register ? 'إنشاء حساب' : 'دخول'))),
        TextButton(onPressed: busy ? null : () => setState(() => register = !register), child: Text(register ? 'عندي حساب بالفعل' : 'إنشاء حساب جديد')),
      ]),
    )))),
  );
}

class HomeGate extends StatelessWidget {
  const HomeGate({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('تعذّر تحميل الحساب: ${snapshot.error}')));
        if (!snapshot.hasData) return const Loading();
        final householdId = snapshot.data!.data()?['householdId'] as String?;
        return householdId == null ? const HouseholdSetup() : Dashboard(householdId: householdId);
      },
    );
  }
}

class HouseholdSetup extends StatefulWidget {
  const HouseholdSetup({super.key});
  @override
  State<HouseholdSetup> createState() => _HouseholdSetupState();
}

class _HouseholdSetupState extends State<HouseholdSetup> {
  bool busy = false;
  final houseName = TextEditingController(text: 'بيتنا');
  final invite = TextEditingController();
  @override
  void dispose() { houseName.dispose(); invite.dispose(); super.dispose(); }
  Future<void> createHouse() async {
    setState(() => busy = true);
    try {
      final uid = auth.currentUser!.uid;
      final house = db.collection('households').doc();
      await house.set({'name': houseName.text.trim().isEmpty ? 'بيتنا' : houseName.text.trim(), 'owner': uid, 'budget': 0.0, 'createdAt': FieldValue.serverTimestamp()});
      await house.collection('members').doc(uid).set({'role': 'owner', 'name': auth.currentUser!.email ?? '', 'joinedAt': FieldValue.serverTimestamp()});
      await db.collection('users').doc(uid).set({'householdId': house.id}, SetOptions(merge: true));
    } catch (e) { if (mounted) alert(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> joinHouse() async {
    final code = invite.text.trim().toUpperCase();
    if (code.isEmpty) { alert(context, 'اكتب كود الدعوة'); return; }
    setState(() => busy = true);
    try {
      final uid = auth.currentUser!.uid;
      final doc = await db.collection('invites').doc(code).get();
      if (!doc.exists) throw Exception('كود الدعوة غير صحيح');
      final hid = doc.data()!['householdId'] as String;
      await db.collection('households').doc(hid).collection('members').doc(uid).set({
        'role': 'member', 'inviteCode': code, 'name': auth.currentUser!.email ?? '', 'joinedAt': FieldValue.serverTimestamp(),
      });
      await db.collection('users').doc(uid).set({'householdId': hid}, SetOptions(merge: true));
    } catch (e) { if (mounted) alert(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ابدأوا مع بعض'), actions: [IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout))]),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.family_restroom_rounded, size: 90, color: primary),
        const SizedBox(height: 12),
        const Text('لو أول واحد، اعمل بيت جديد وشارك الكود مع شريكك.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextField(controller: houseName, decoration: const InputDecoration(labelText: 'اسم البيت')),
        const SizedBox(height: 10),
        FilledButton(onPressed: busy ? null : createHouse, child: const Text('إنشاء بيت جديد')),
        const Divider(height: 48),
        const Text('لو شريكك عمل البيت بالفعل، اكتب كود الدعوة:'),
        const SizedBox(height: 12),
        TextField(controller: invite, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'كود الدعوة')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: busy ? null : joinHouse, child: const Text('الانضمام للبيت')),
      ],
    )))),
  );
}

class Dashboard extends StatefulWidget {
  final String householdId;
  const Dashboard({super.key, required this.householdId});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  String get hid => widget.householdId;
  String get monthKey => DateFormat('yyyy-MM').format(month);
  void changeMonth(int by) => setState(() => month = DateTime(month.year, month.month + by));
  Future<void> editBudget(double previous) async {
    final c = TextEditingController(text: previous == 0 ? '' : previous.toStringAsFixed(0));
    final value = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('الميزانية الشهرية'),
      content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ بالجنيه')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())), child: const Text('حفظ'))],
    ));
    c.dispose();
    if (value == null || value < 0) return;
    try { await db.collection('households').doc(hid).update({'budget': value}); }
    catch (e) { if (mounted) alert(context, e); }
  }
  Future<void> createInvite() async {
    try {
      final uid = auth.currentUser!.uid;
      final random = Random.secure();
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      String code = '';
      bool success = false;
      for (int i = 0; i < 5 && !success; i++) {
        code = List.generate(10, (_) => alphabet[random.nextInt(alphabet.length)]).join();
        try {
          await db.collection('invites').doc(code).set({'householdId': hid, 'creator': uid, 'createdAt': FieldValue.serverTimestamp()});
          success = true;
        } on FirebaseException catch (e) { if (e.code != 'already-exists') rethrow; }
      }
      if (!success) throw Exception('تعذّر إنشاء الكود، حاول ثانية');
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('كود دعوة شريكك'),
        content: SelectableText(code, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26, letterSpacing: 2)),
        actions: [TextButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: code)); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('نسخ الكود'))],
      ));
    } catch (e) { if (mounted) alert(context, e); }
  }
  Future<void> deleteEntry(String id) async {
    try { await db.collection('households').doc(hid).collection('entries').doc(id).delete(); }
    catch (e) { if (mounted) alert(context, e); }
  }
  @override
  Widget build(BuildContext context) {
    final house = db.collection('households').doc(hid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: house.snapshots(),
      builder: (context, houseSnap) {
        if (houseSnap.hasError) return Scaffold(body: Center(child: Text('خطأ في البيت: ${houseSnap.error}')));
        if (!houseSnap.hasData) return const Loading();
        final houseData = houseSnap.data!.data();
        if (houseData == null) return const Scaffold(body: Center(child: Text('البيت غير موجود')));
        final budget = (houseData['budget'] as num?)?.toDouble() ?? 0;
        return Scaffold(
          appBar: AppBar(
            title: Text('🏠 ${houseData['name'] ?? 'بيتنا'}'),
            actions: [
              IconButton(tooltip: 'كود دعوة', onPressed: createInvite, icon: const Icon(Icons.person_add_alt_1)),
              IconButton(tooltip: 'تسجيل الخروج', onPressed: () => auth.signOut(), icon: const Icon(Icons.logout)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEntry(hid: hid))),
            icon: const Icon(Icons.add), label: const Text('إضافة حركة'),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: house.collection('entries').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('تعذّر تحميل الحركات: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final records = snap.data!.docs.where((d) {
                final stamp = d.data()['createdAt'] as Timestamp?;
                if (stamp == null) return false;
                final date = stamp.toDate();
                return date.year == month.year && date.month == month.month;
              }).toList();
              final income = records.where((d) => d.data()['type'] == 'income').fold<double>(0, (a, d) => a + ((d.data()['amount'] as num).toDouble()));
              final expenses = records.where((d) => d.data()['type'] == 'expense').fold<double>(0, (a, d) => a + ((d.data()['amount'] as num).toDouble()));
              final byCategory = <String, double>{};
              for (final d in records.where((d) => d.data()['type'] == 'expense')) {
                final category = d.data()['category'] as String? ?? 'أخرى';
                byCategory[category] = (byCategory[category] ?? 0) + (d.data()['amount'] as num).toDouble();
              }
              final categories = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_right)),
                  Text(DateFormat('MMMM yyyy', 'ar').format(month), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_left)),
                ]),
                Card(color: primary, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('صافي الشهر', style: TextStyle(color: Colors.white70)),
                  Text('${money.format(income - expenses)} ج.م', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text('الدخل: ${money.format(income)}    |    المصروفات: ${money.format(expenses)}', style: const TextStyle(color: Colors.white)),
                ]))),
                const SizedBox(height: 8),
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Expanded(child: Text('الميزانية الشهرية', style: TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => editBudget(budget), icon: const Icon(Icons.edit_outlined))]),
                  Text('${money.format(expenses)} / ${money.format(budget)} ج.م'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: budget > 0 ? (expenses / budget).clamp(0.0, 1.0) : 0),
                  const SizedBox(height: 6),
                  Text(budget == 0 ? 'حدد ميزانية من علامة التعديل' : 'المتبقي: ${money.format(budget - expenses)} ج.م',
                    style: TextStyle(color: budget > 0 && expenses > budget ? Colors.red : null)),
                ]))),
                const SizedBox(height: 20),
                const Text('المصاريف حسب الفئة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                if (categories.isEmpty) const Text('لسه مفيش مصاريف في الشهر ده'),
                ...categories.map((c) => Card(child: ListTile(
                  title: Text(c.key), trailing: Text('${money.format(c.value)} ج.م'),
                  subtitle: LinearProgressIndicator(value: expenses > 0 ? c.value / expenses : 0),
                ))),
                const SizedBox(height: 20),
                const Text('آخر الحركات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                if (records.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('أضف أول مصروف أو دخل من الزر تحت 👇')),
                ...records.map((d) {
                  final v = d.data(); final isExpense = v['type'] == 'expense';
                  return Card(child: ListTile(
                    leading: CircleAvatar(backgroundColor: isExpense ? Colors.red.shade50 : Colors.green.shade50,
                      child: Icon(isExpense ? Icons.arrow_upward : Icons.arrow_downward, color: isExpense ? Colors.red : primary)),
                    title: Text('${v['category'] ?? 'أخرى'}${(v['note'] as String? ?? '').isNotEmpty ? ' • ${v['note']}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${v['createdByName'] ?? ''} • ${DateFormat('d/M  h:mm a', 'ar').format((v['createdAt'] as Timestamp).toDate())}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                      Text('${isExpense ? '-' : '+'}${money.format(v['amount'])}', style: TextStyle(color: isExpense ? Colors.red : primary, fontWeight: FontWeight.bold)),
                      if (v['createdBy'] == auth.currentUser!.uid)
                        SizedBox(height: 24, child: IconButton(iconSize: 18, padding: EdgeInsets.zero, tooltip: 'حذف',
                          onPressed: () => deleteEntry(d.id), icon: const Icon(Icons.delete_outline))),
                    ]),
                  ));
                }),
              ]);
            },
          ),
        );
      },
    );
  }
}

class AddEntry extends StatefulWidget {
  final String hid;
  const AddEntry({super.key, required this.hid});
  @override
  State<AddEntry> createState() => _AddEntryState();
}

class _AddEntryState extends State<AddEntry> {
  bool expense = true, busy = false;
  String category = 'أكل وشرب';
  final amount = TextEditingController();
  final note = TextEditingController();
  static const expenseCategories = ['أكل وشرب', 'سوبر ماركت', 'فواتير', 'إيجار', 'مواصلات', 'صحة', 'ملابس', 'ترفيه', 'تعليم', 'أخرى'];
  static const incomeCategories = ['مرتب', 'دخل إضافي', 'هدية', 'أخرى'];
  @override
  void dispose() { amount.dispose(); note.dispose(); super.dispose(); }
  Future<void> save() async {
    final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) { alert(context, 'اكتب مبلغ صحيح أكبر من صفر'); return; }
    setState(() => busy = true);
    try {
      await db.collection('households').doc(widget.hid).collection('entries').add({
        'amount': value, 'type': expense ? 'expense' : 'income', 'category': category,
        'note': note.text.trim(), 'createdBy': auth.currentUser!.uid,
        'createdByName': auth.currentUser!.email ?? '', 'createdAt': Timestamp.now(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) alert(context, e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final options = expense ? expenseCategories : incomeCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة حركة جديدة')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('مصروف'), icon: Icon(Icons.remove_circle_outline)), ButtonSegment(value: false, label: Text('دخل'), icon: Icon(Icons.add_circle_outline))],
          selected: {expense}, onSelectionChanged: (v) => setState(() { expense = v.first; category = expense ? expenseCategories.first : incomeCategories.first; })),
        const SizedBox(height: 20),
        TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ بالجنيه المصري', prefixIcon: Icon(Icons.payments_outlined))),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(value: category, isExpanded: true, decoration: const InputDecoration(labelText: 'الفئة'),
          items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => category = v!)),
        const SizedBox(height: 16),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', hintText: 'مثال: طلبات البيت')),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.check), label: Padding(padding: const EdgeInsets.all(12), child: Text(busy ? 'جارٍ الحفظ...' : 'حفظ الحركة'))),
      ])),
    );
  }
}
