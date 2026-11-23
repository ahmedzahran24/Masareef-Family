# بيتنا | مصاريف البيت 🏠

تطبيق Flutter عربي للأندرويد لمتابعة مصاريف البيت بين شخصين باستخدام Firebase Authentication + Firestore.

## المميزات
- حساب مستقل لكل شخص بالبريد وكلمة المرور.
- إنشاء بيت والانضمام بكود دعوة، ومزامنة فورية بين الزوجين.
- تسجيل مصروف أو دخل مع الفئة والوصف، وحساب ملخص الشهر.
- ميزانية شهرية، تصفية معاملات حسب الشهر، وحذف معاملات المستخدم نفسه.
- قواعد Firestore تتحقق من عضوية البيت لكل قراءة وكتابة.

## قبل بناء APK
1. أنشئ مشروع Firebase في https://console.firebase.google.com.
2. من Authentication > Sign-in method فعّل Email/Password.
3. أنشئ Firestore Database، ثم الصق محتوى `firestore.rules` في Firestore > Rules وانشره.
4. سجل Android app بالمعرّف `com.beitna.beitna_expenses` **إن كان Flutter أنشأ هذا المعرّف**. افحص `android/app/build.gradle.kts` بعد توليد المشروع؛ المعرف الافتراضي هنا من `--org com.beitna` واسم المشروع `beitna_expenses` هو `com.beitna.beitna_expenses`.
5. نزل `google-services.json` من Firebase، وحوّله إلى base64 من هاتفك بأداة موثوقة محليًا، وضع النص في GitHub repository secret اسمه `GOOGLE_SERVICES_JSON_BASE64` (لا تنشره داخل المستودع). يمكنك أيضًا حفظ `google-services.json` محليًا في `android/app` عند البناء على كمبيوتر.
6. ارفع كل الملفات إلى مستودع GitHub، وانتقل Actions > Build Android APK > Run workflow (أو ارفع تعديلًا إلى main).
7. بعد نجاح البناء، نزّل Artifact `Beitna-Expenses-APK`، فك ملف ZIP ثم ثبّت `app-release.apk` على الهاتفين.

**مهم:** المشروع المرفق هو الشفرة الجاهزة للبناء، وليس APK تم تجميعه أو اختباره على جهاز Android هنا. لا تعمل المزامنة إلا بعد إعداد Firebase وتشغيل بناء ناجح. APK الناتج موقّع بمفتاح debug افتراضي في بناء Flutter release إذا لم تتم تهيئة توقيع إصدار خاص؛ يصلح للاختبار الشخصي وليس للنشر المتجر. للحفاظ على تحديثات متوافقة عبر الإصدارات، أضف مفتاح توقيع Release مستقر.

**تنبيه أمني:** كود الدعوة يستخدم للانضمام للبيت، فلا تشاركه إلا مع زوجتك. قواعد Firestore تتيح لصاحب الكود الوصول كعضو عند الانضمام. لم تتم إضافة آلية إلغاء الدعوة أو حدود طلبات أو حذف العضويات.
