# دليل تصحيح مشكلة السينسور - Sensor Debug Guide

## المشكلة الحالية
السينسور لا يعرض القيم ويظهر "--" بدلاً منها

## التغييرات التي تم إجراؤها ✅

### 1. تحسين Socket Service
**الملف**: `lib/services/socket_service.dart`
- إضافة logging لحالة الاتصال
- تتبع الأخطاء في الاتصال
- طباعة جميع الأحداث المستقبلة:
  - `widget-status-update`
  - `sensor-data`
  - `new-sensor-reading`

### 2. تحسين Dashboard Screen - Socket Setup
**الملف**: `lib/screens/dashboard_screen.dart` - `_setupSocket()`
- طباعة معرّف المستخدم (User ID)
- تأكيد إعداد المستمعين (listeners)
- معالجة الأخطاء مع رسائل واضحة

### 3. تحسين Widget Updates
**الملف**: `lib/screens/dashboard_screen.dart` - `_updateWidgetFromSocket()`
- طباعة معرّف الـ widget المتحدّث
- عرض القيمة الجديدة
- التحقق من نوع الـ widget
- اكتشاف الـ widgets المفقودة

### 4. تحسين تحميل الـ Widgets
**الملف**: `lib/screens/dashboard_screen.dart` - `_loadWidgets()`
- عدد الـ widgets المستقبلة من API
- **تفصيل كل sensor widget**:
  - المعرّف والاسم
  - الحالة الكاملة
  - القيمة الأولية

### 5. تحسين عرض السينسور
**الملف**: `lib/screens/dashboard_screen.dart` - `_buildSensorWidget()`
- طباعة اسم السينسور والقيمة المعروضة

---

## كيفية استخدام الـ Debug

### 1. قم بتشغيل التطبيق
```bash
flutter run
```

### 2. افتح جزء "Run" في VS Code
انظر إلى الـ console output

### 3. ابحث عن الرسائل التالية بالترتيب:

#### ✅ الخطوة 1: تأكد من اتصال Socket
```
✅ Connected to Socket.IO server UI
📤 Joining user room: [USER_ID]
🔗 Setting up socket listeners...
✅ Socket listeners set up successfully
```
**إذا لم تجد هذه الرسائل:**
- السيرفر غير متاح
- المشكلة في اتصال الـ Socket

#### ✅ الخطوة 2: تحقق من تحميل الـ Widgets
```
📥 Loading widgets from API...
📦 Received X widgets from API
📊 Sensor Widget: [widget_id] - [sensor_name]
   State: {lastValue: 23.5}
   Value: 23.5
```
**إذا رأيت "Value: null":**
- API لا يرجع قيمة أولية
- يجب على السيرفر تحديث `state.lastValue`

#### ✅ الخطوة 3: تحقق من استقبال البيانات من Socket
```
📡 Received sensor-data event: {widgetId: xxx, value: 24.2}
🔄 Updating widget xxx with socket data: {...}
   📊 Setting value: 24.2
✅ Widget xxx updated successfully
```
**إذا لم تستقبل أي رسائل:**
- Socket connection مقطوعة
- السيرفر لا يرسل الأحداث
- الـ widget ID غير صحيح

---

## جدول استكشاف الأخطاء

| المشكلة | الأعراض | الحل |
|--------|---------|------|
| **Socket لم تتصل** | لا توجد رسالة "Connected to Socket.IO" | تحقق من URL الـ API و socket configuration |
| **لا توجد قيمة أولية** | القيمة تظهر "--" عند التحميل | السيرفر يجب أن يرجع `state.lastValue` في API |
| **لا توجد تحديثات فورية** | القيمة لا تتغير عند التغيير على السيرفر | السيرفر لا يرسل `sensor-data` أو `widget-status-update` events |
| **الـ widget ID غير صحيح** | رسالة "Socket data missing widgetId" | تحقق من اسم المفتاح (key) في الـ event data |

---

## نموذج الـ Sensor Widget المتوقع

من API:
```json
{
  "id": "sensor_123",
  "type": "sensor",
  "name": "Temperature",
  "icon": "sensors",
  "state": {
    "lastValue": "23.5",
    "lastUpdate": "2024-05-21T10:30:00Z"
  },
  "configuration": {
    "unit": "°C"
  }
}
```

من Socket Event:
```json
{
  "widgetId": "sensor_123",
  "value": "24.2",
  "lastUpdate": "2024-05-21T10:35:00Z"
}
```

---

## خطوات الإصلاح المقترحة

### إذا كانت المشكلة من جهة **Frontend**:
✅ تم إضافة logging - استخدمها لفهم سبب المشكلة

### إذا كانت المشكلة من جهة **Backend**:
1. **تأكد من أن API endpoint يعيد state data:**
   ```
   GET /api/widgets
   Response: { state: { lastValue: "value" } }
   ```

2. **تأكد من أن Socket يرسل الأحداث:**
   - استخدم "sensor-data" أو "widget-status-update"
   - تأكد من إرسال widgetId في البيانات

3. **تحقق من بيانات الـ widget:**
   - type يجب أن يكون "sensor"
   - state.lastValue يجب أن يحتوي على قيمة

---

## ملاحظات مهمة

⚠️ الـ logging سيعرض جميع الأحداث على الـ console
- إذا أردت إيقاف الـ logging في المستقبل، يمكنك إزالة `print()` statements

💡 إذا كنت تقوم بتطوير السيرفر:
- تأكد من إرسال الأحداث إلى الـ room الصحيح: `socket.to(userId).emit(...)`
- استخدم نفس أسماء الأحداث المذكورة أعلاه

🔄 اختبر التحديثات:
1. غير قيمة السينسور على السيرفر
2. لاحظ التحديث على التطبيق
3. تحقق من الـ console logs للتأكد من الاتصال
