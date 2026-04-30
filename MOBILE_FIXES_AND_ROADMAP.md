# PiChat Mobile App - Critical Fixes & Feature Roadmap

> **Created**: February 7, 2026
> **Version**: 2.0
> **Status**: Active Development

---

## 📋 Executive Summary

This document outlines critical bugs to fix and features to implement for the PiChat mobile app. Issues are prioritized by severity and grouped into phases.

### Quick Reference - Severity Levels
| Level | Description |
|-------|-------------|
| 🔴 **CRITICAL** | App-breaking, must fix immediately |
| 🟠 **HIGH** | Major functionality missing/broken |
| 🟡 **MEDIUM** | Feature incomplete or UX issues |
| 🟢 **LOW** | Nice-to-have improvements |

---

## 🔴 Phase 1: Critical Bugs (Priority 1)

### 1.1 New Chat Button Not Working
**File**: `lib/features/chat/presentation/chat_screen.dart` (line ~182)
**Issue**: The "Chat" button has `onTap: () {}` - empty callback
**Expected**: Open a screen to start new conversation (contact picker or phone input)

**Fix**:
```dart
// Replace empty onTap with:
onTap: () => context.push('/home/chats/new'),
```

**Backend**: Need API endpoint to initiate chat with new contact:
```php
// routes/api.php
Route::post('/contacts', [ContactController::class, 'store']);
Route::post('/contacts/{uuid}/init-chat', [ChatController::class, 'initConversation']);
```

**Mobile Implementation**:
- Create `lib/features/chat/presentation/new_chat_screen.dart`
- Phone number input with country picker
- Search existing contacts
- Create new contact if not found
- Navigate to chat thread

---

### 1.2 24-Hour Window Not Enforced
**File**: `lib/features/chat/presentation/chat_threads.dart` (line ~550-700)
**Issue**: Message input field always shown, even when 24h window expired
**Expected**: Show template-only banner when `last_inbound_chat > 24 hours ago`

**Web Reference**: `ChatForm.vue` lines 113-125 - uses `isInboundChatWithin24Hours` computed property

**Mobile Fix**:
```dart
// In _buildMessageInput() method, add check:
bool _isWithin24HourWindow() {
  final lastInbound = widget.contact.lastInboundChatAt;
  if (lastInbound == null) return false;
  return DateTime.now().difference(lastInbound).inHours < 24;
}

Widget _buildMessageInput() {
  if (!_isWithin24HourWindow()) {
    return _build24HourExpiredBanner();
  }
  // ... existing input widget
}

Widget _build24HourExpiredBanner() {
  return Container(
    padding: const EdgeInsets.all(16),
    color: Colors.orange.shade50,
    child: Row(
      children: [
        Icon(Icons.warning_amber, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('24-hour window expired', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('You can only send template messages.'),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _showTemplatePicker,
          child: const Text('Send Template'),
        ),
      ],
    ),
  );
}
```

**Backend**: Add `last_inbound_chat_at` to contact API response:
```php
// ContactResource.php or contacts API
'last_inbound_chat_at' => $this->chats()
    ->where('type', 'inbound')
    ->latest('created_at')
    ->first()?->created_at,
```

---

### 1.3 Contacts Order Not Consistent (Local vs API)
**File**: `lib/features/chat/application/main_controller.dart`
**Issue**: Cached contacts show different order than fresh API data
**Expected**: Always show contacts sorted by `latest_chat_created_at DESC`

**Fix in MainDataController**:
```dart
Future<void> _loadContacts() async {
  // 1️⃣ Load cached contacts immediately
  var cachedContacts = await _contactRepo.getContacts(forceRefresh: false);
  
  // ✅ Sort by latest message time (newest first)
  cachedContacts.sort((a, b) {
    final aTime = a.latestChatCreatedAt ?? DateTime(1970);
    final bTime = b.latestChatCreatedAt ?? DateTime(1970);
    return bTime.compareTo(aTime); // DESC order
  });
  
  state = cachedContacts;

  // 2️⃣ Background refresh
  refreshContacts();
}

Future<void> refreshContacts() async {
  try {
    var apiContacts = await _contactRepo.getContacts(forceRefresh: true);
    
    // ✅ Sort API results too
    apiContacts.sort((a, b) {
      final aTime = a.latestChatCreatedAt ?? DateTime(1970);
      final bTime = b.latestChatCreatedAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    
    state = apiContacts;
  } catch (e) {
    print('Error refreshing contacts: $e');
  }
}
```

---

## 🟠 Phase 2: High Priority Features

### 2.1 Template Picker Issues
**File**: `lib/features/templates/presentation/template_picker_screen.dart`
**Issues**:
1. Variables show as "Variable 1, Variable 2" - no descriptive names
2. Long variable lists cause overflow (not scrollable)
3. No live template preview while filling variables
4. No scheduling option
5. No static vs dynamic field selection (like web)

**Web Reference**: `CampaignForm.vue` lines 40-120

**Fix - Complete Rewrite**:
```dart
// lib/features/templates/presentation/template_picker_screen.dart

/// Variables should include:
class TemplateVariable {
  final String component;     // header, body, button
  final int index;            // 1, 2, 3
  final String placeholder;   // Original placeholder text from template
  final String? sampleValue;  // Example value from Meta
  final bool isDynamic;       // Can use contact fields?
}

/// Variable selection types (match web)
enum VariableSelectionType {
  static,    // User types custom value
  dynamic,   // Use contact field (first_name, last_name, phone, email)
}

/// Dynamic field options (match web dynamicOptions)
enum DynamicField {
  firstName('first name', 'Contact First Name'),
  lastName('last name', 'Contact Last Name'),
  fullName('name', 'Contact Full Name'),
  phone('phone', 'Contact Phone'),
  email('email', 'Contact Email');
  
  final String value;
  final String label;
  const DynamicField(this.value, this.label);
}
```

**UI Improvements**:
```dart
Widget _buildVariableInputs() {
  return Expanded(  // ✅ Make scrollable
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header variables section
          if (_headerVariables.isNotEmpty) ...[
            _buildSectionHeader('Header Variables'),
            ..._headerVariables.map(_buildVariableInput),
          ],
          
          // Body variables section  
          if (_bodyVariables.isNotEmpty) ...[
            _buildSectionHeader('Body Variables'),
            ..._bodyVariables.map(_buildVariableInput),
          ],
          
          // Button variables section
          if (_buttonVariables.isNotEmpty) ...[
            _buildSectionHeader('Button Variables'),
            ..._buttonVariables.map(_buildVariableInput),
          ],
          
          const SizedBox(height: 100), // Space for send button
        ],
      ),
    ),
  );
}

Widget _buildVariableInput(TemplateVariable variable) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show placeholder text, not just "Variable 1"
          Text(
            '{{${variable.index}}} - ${variable.placeholder ?? "Value"}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (variable.sampleValue != null)
            Text(
              'Example: ${variable.sampleValue}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          const SizedBox(height: 8),
          
          // Static vs Dynamic dropdown
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<VariableSelectionType>(
                  value: _variableSelections[variable.key],
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                  ),
                  items: VariableSelectionType.values.map((t) => 
                    DropdownMenuItem(value: t, child: Text(t.name.capitalize()))
                  ).toList(),
                  onChanged: (v) => setState(() => _variableSelections[variable.key] = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _variableSelections[variable.key] == VariableSelectionType.static
                  ? TextField(
                      controller: _variableControllers[variable.key],
                      decoration: InputDecoration(
                        hintText: variable.sampleValue ?? 'Enter value',
                        isDense: true,
                      ),
                    )
                  : DropdownButtonFormField<DynamicField>(
                      decoration: const InputDecoration(
                        labelText: 'Contact Field',
                        isDense: true,
                      ),
                      items: DynamicField.values.map((f) =>
                        DropdownMenuItem(value: f, child: Text(f.label))
                      ).toList(),
                      onChanged: (v) => setState(() => _dynamicSelections[variable.key] = v!),
                    ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

**Add Template Preview**:
```dart
// Show live preview in split view (like web)
Widget build(BuildContext context) {
  return Scaffold(
    body: Row(
      children: [
        // Left: Form (on mobile, use tabs or sliding panel)
        Expanded(child: _buildForm()),
        
        // Right: Live Preview
        Expanded(child: _buildLivePreview()),
      ],
    ),
  );
}

Widget _buildLivePreview() {
  if (_selectedTemplate == null) {
    return Center(child: Text('Select a template'));
  }
  
  return Container(
    color: const Color(0xFFE5DDD5), // WhatsApp chat background
    child: Center(
      child: WhatsAppBubble(
        header: _renderHeader(),
        body: _renderBody(),
        footer: _selectedTemplate!.footer,
        buttons: _selectedTemplate!.buttons,
      ),
    ),
  );
}
```

**Add Scheduling**:
```dart
// Add schedule fields
bool _skipSchedule = true;
DateTime? _scheduledTime;
int _recurrings = 1;

// In form:
CheckboxListTile(
  title: const Text('Send immediately'),
  value: _skipSchedule,
  onChanged: (v) => setState(() => _skipSchedule = v!),
),

if (!_skipSchedule) ...[
  ListTile(
    title: const Text('Scheduled Time'),
    subtitle: Text(_scheduledTime?.toString() ?? 'Select time'),
    trailing: const Icon(Icons.calendar_today),
    onTap: _pickScheduleTime,
  ),
  TextField(
    decoration: const InputDecoration(labelText: 'Recurrings'),
    keyboardType: TextInputType.number,
    onChanged: (v) => _recurrings = int.tryParse(v) ?? 1,
  ),
],
```

---

### 2.2 Notifications Without Sound
**File**: `lib/core/services/notification_service.dart`
**Issue**: Local notifications don't play sound reliably

**Fix - Add Sound to AndroidNotificationDetails**:
```dart
// In _handleForegroundMessage and _showLocalNotification:
await _localNotifications.show(
  id: message.hashCode,
  title: notification.title ?? 'New Message',
  body: notification.body ?? '',
  notificationDetails: NotificationDetails(
    android: AndroidNotificationDetails(
      'high_importance_channel',
      'New Messages',
      importance: Importance.max,  // Changed from high
      priority: Priority.max,       // Changed from high
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification'), // Add custom sound
      enableVibration: true,
      enableLights: true,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.aiff', // Add sound file to iOS
    ),
  ),
);
```

**Add Sound Files**:
1. Android: Create `android/app/src/main/res/raw/notification.mp3`
2. iOS: Add `notification.aiff` to Runner bundle

---

### 2.3 Language Switcher Not Working
**File**: `lib/features/settings/presentation/settings_screen.dart` lines 330-350
**Issue**: Language changes saved to API but not applied to app

**Fix**:
```dart
void _showLanguageOptions(String current) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final lang in [('en', 'English'), ('fr', 'Français'), ('ar', 'العربية')])
            ListTile(
              title: Text(lang.$2),
              trailing: current == lang.$1 ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () async {
                Navigator.pop(ctx);
                
                // ✅ Actually change the locale!
                await context.setLocale(Locale(lang.$1));
                
                // Save to API
                _updateSetting('language', lang.$1);
              },
            ),
        ],
      ),
    ),
  );
}
```

**Fix RTL Direction**:
```dart
// In lib/main.dart - PiChatApp.build():
@override
Widget build(BuildContext context, WidgetRef ref) {
  return MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'PiChat',
    theme: ref.watch(appThemeProvider),
    routerConfig: ref.watch(appRouterProvider),
    locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates,
    // ✅ Add this builder for RTL support
    builder: (context, child) {
      return Directionality(
        textDirection: context.locale.languageCode == 'ar' 
          ? TextDirection.rtl 
          : TextDirection.ltr,
        child: child!,
      );
    },
  );
}
```

---

### 2.4 Theme Switcher Not Working
**File**: `lib/core/theme/app_theme.dart`
**Issue**: Only light theme defined, no dark theme or system preference

**Fix - Create Theme Notifier**:
```dart
// lib/core/theme/app_theme.dart

enum ThemeMode { light, dark, system }

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final appThemeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  
  // Get system brightness
  final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final isDark = mode == ThemeMode.dark || 
    (mode == ThemeMode.system && brightness == Brightness.dark);
  
  return isDark ? _darkTheme : _lightTheme;
});

final _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: Colors.white,
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: AppColors.primary,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
);
```

**Fix Settings Screen**:
```dart
void _showThemeOptions(String current) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final theme in ThemeMode.values)
            ListTile(
              title: Text(theme.name.capitalize()),
              trailing: current == theme.name 
                ? const Icon(Icons.check, color: AppColors.primary) 
                : null,
              onTap: () {
                Navigator.pop(ctx);
                // ✅ Actually update the provider!
                ref.read(themeModeProvider.notifier).state = theme;
                _updateSetting('theme', theme.name);
              },
            ),
        ],
      ),
    ),
  );
}
```

---

### 2.5 Chat Filter Not Working
**File**: `lib/features/chat/presentation/chat_screen.dart`
**Issue**: Filter UI exists but doesn't filter properly

**Current Code Analysis**:
The filter sheet exists and sets `activeFilterProvider`, but the filtering logic checks `c.lastChat?.status` which might be null or structured differently.

**Fix**:
```dart
// In filteredContactsProvider
final filteredContactsProvider = Provider<List<Contact>>((ref) {
  final contacts = ref.watch(mainDataProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final filter = ref.watch(activeFilterProvider);

  var filtered = contacts;

  // Apply search filter
  if (query.isNotEmpty) {
    filtered = filtered.where((c) {
      final name = (c.fullName ?? '').toLowerCase();
      final phone = c.phone.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  // Apply status filter
  if (filter != null) {
    switch (filter) {
      case 'unread':
        filtered = filtered.where((c) => c.unreadCount > 0).toList();
        break;
      case 'open':
        // ✅ Need to check ticket status, not chat status
        filtered = filtered.where((c) => c.ticketStatus == 'open').toList();
        break;
      case 'pending':
        filtered = filtered.where((c) => c.ticketStatus == 'pending').toList();
        break;
      case 'closed':
        filtered = filtered.where((c) => c.ticketStatus == 'closed').toList();
        break;
      case 'assigned_to_me':
        // ✅ Need current user ID and compare to assigned_to
        final userId = ref.watch(userIdProvider);
        filtered = filtered.where((c) => c.assignedTo == userId).toList();
        break;
    }
  }

  return filtered;
});
```

**Backend**: Add ticket info to contacts API:
```php
// In ContactResource or contacts query
'ticket_status' => $this->ticket?->status,
'assigned_to' => $this->ticket?->assigned_to,
```

**Mobile Model Update**:
```dart
// Contact model - add fields
final String? ticketStatus;
final int? assignedTo;
```

---

## 🟡 Phase 3: Medium Priority Features

### 3.1 Voice Recorder
**Missing Feature**: Web has voice recording, mobile doesn't

**Implementation**:
```dart
// lib/features/chat/presentation/widgets/voice_recorder.dart

import 'package:record/record.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(File audioFile) onRecordingComplete;
  
  @override
  _VoiceRecorderWidgetState createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _audioPath;
  
  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      _audioPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _audioPath!,
      );
      
      setState(() => _isRecording = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _duration += const Duration(seconds: 1));
      });
    }
  }
  
  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    
    if (path != null) {
      widget.onRecordingComplete(File(path));
    }
    
    setState(() {
      _isRecording = false;
      _duration = Duration.zero;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : AppColors.primary,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
        ),
      ),
    );
  }
}
```

**Add to pubspec.yaml**:
```yaml
dependencies:
  record: ^5.0.4
```

---

### 3.2 Video Recorder
**Implementation**:
```dart
// In _showAttachmentPicker, add:
_AttachmentOption(
  icon: Icons.videocam,
  label: 'Video',
  color: Colors.red,
  onTap: () {
    Navigator.pop(ctx);
    _recordVideo();
  },
),

Future<void> _recordVideo() async {
  final picker = ImagePicker();
  final video = await picker.pickVideo(
    source: ImageSource.camera,
    maxDuration: const Duration(minutes: 1),
  );
  
  if (video != null) {
    await _sendMediaFile(File(video.path));
  }
}
```

---

### 3.3 Location Sharing
**Implementation**:
```dart
// Add to pubspec.yaml
// geolocator: ^10.0.0
// google_maps_flutter: ^2.5.0

Future<void> _shareLocation() async {
  final permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied) return;
  
  final position = await Geolocator.getCurrentPosition();
  
  // Send location via API
  final chatRepo = ref.read(chatRepositoryProvider);
  await chatRepo.sendLocationMessage(
    widget.contact.uuid,
    latitude: position.latitude,
    longitude: position.longitude,
  );
}
```

**Backend API**:
```php
// ChatController.php
public function sendLocation(Request $request, $contactUuid)
{
    $request->validate([
        'latitude' => 'required|numeric',
        'longitude' => 'required|numeric',
        'name' => 'nullable|string',
        'address' => 'nullable|string',
    ]);
    
    // WhatsApp API location message format
    $locationPayload = [
        'latitude' => $request->latitude,
        'longitude' => $request->longitude,
        'name' => $request->name,
        'address' => $request->address,
    ];
    
    // Send via WhatsApp service
}
```

---

### 3.4 Quick Replies Management (CRUD)
**Missing**: No way to create/edit/delete quick replies from mobile

**Create Screen**:
```dart
// lib/features/settings/presentation/quick_replies_screen.dart

class QuickRepliesScreen extends ConsumerStatefulWidget {
  @override
  _QuickRepliesScreenState createState() => _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends ConsumerState<QuickRepliesScreen> {
  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(quickRepliesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Replies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: repliesAsync.when(
        data: (replies) => ListView.builder(
          itemCount: replies.length,
          itemBuilder: (context, index) {
            final reply = replies[index];
            return ListTile(
              title: Text(reply.title),
              subtitle: Text(reply.response, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: PopupMenuButton(
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onSelected: (value) {
                  if (value == 'edit') _showEditDialog(reply);
                  if (value == 'delete') _deleteReply(reply);
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
  
  void _showAddDialog() {
    final titleController = TextEditingController();
    final responseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Quick Reply'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title/Shortcut'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: responseController,
              decoration: const InputDecoration(labelText: 'Response'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(quickRepliesRepositoryProvider).create(
                title: titleController.text,
                response: responseController.text,
              );
              ref.invalidate(quickRepliesProvider);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

**Backend API**:
```php
// routes/api.php
Route::apiResource('canned-replies', CannedReplyController::class);

// CannedReplyController.php
public function store(Request $request)
{
    $request->validate([
        'title' => 'required|string|max:100',
        'response' => 'required|string|max:4096',
    ]);
    
    $reply = CannedReply::create([
        'organization_id' => $request->organization_id,
        'title' => $request->title,
        'response' => $request->response,
    ]);
    
    return response()->json($reply, 201);
}
```

---

### 3.5 Contact Labels
**Missing**: No way to label contacts or view labels

**Implementation**:

**1. Model**:
```dart
// lib/data/models/label_model.dart
class ContactLabel {
  final int id;
  final String name;
  final String color;
  final bool isExpirable;
  
  // fromJson, toJson...
}
```

**2. Contact Model Update**:
```dart
// Add to Contact
final List<ContactLabel> labels;
```

**3. Label Picker Widget**:
```dart
// lib/features/contacts/presentation/widgets/label_picker_sheet.dart
class LabelPickerSheet extends ConsumerWidget {
  final String contactUuid;
  final List<int> selectedLabelIds;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(labelsProvider);
    
    return DraggableScrollableSheet(
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: labelsAsync.when(
          data: (labels) => ListView.builder(
            controller: scrollController,
            itemCount: labels.length,
            itemBuilder: (context, index) {
              final label = labels[index];
              final isSelected = selectedLabelIds.contains(label.id);
              
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(int.parse(label.color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(label.name),
                trailing: isSelected 
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
                onTap: () => _toggleLabel(ref, label, isSelected),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
```

**Backend API**:
```php
// routes/api.php
Route::get('/labels', [LabelController::class, 'index']);
Route::post('/contacts/{uuid}/labels', [ContactController::class, 'updateLabels']);

// ContactController.php
public function updateLabels(Request $request, $uuid)
{
    $request->validate(['labels' => 'array', 'labels.*' => 'integer|exists:labels,id']);
    
    $contact = Contact::where('uuid', $uuid)->firstOrFail();
    $contact->labels()->sync($request->labels);
    
    return response()->json(['success' => true]);
}
```

---

### 3.6 Chat History / Activity Log
**Missing**: No way to see who sent messages, agent assignments, ticket history

**Implementation**:

**1. Activity Model**:
```dart
// lib/data/models/activity_model.dart
class ChatActivity {
  final int id;
  final String type;         // 'message_sent', 'assigned', 'status_changed', 'label_added'
  final String description;
  final Map<String, dynamic>? metadata;
  final String? agentName;
  final DateTime createdAt;
}
```

**2. Activity Screen**:
```dart
// lib/features/contacts/presentation/contact_activity_screen.dart
class ContactActivityScreen extends ConsumerWidget {
  final String contactUuid;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(contactActivitiesProvider(contactUuid));
    
    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: activitiesAsync.when(
        data: (activities) => ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ListTile(
              leading: _getActivityIcon(activity.type),
              title: Text(activity.description),
              subtitle: Text(
                '${activity.agentName ?? 'System'} • ${_formatTime(activity.createdAt)}',
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
  
  Widget _getActivityIcon(String type) {
    switch (type) {
      case 'message_sent': return const Icon(Icons.send, color: Colors.blue);
      case 'assigned': return const Icon(Icons.person_add, color: Colors.green);
      case 'status_changed': return const Icon(Icons.flag, color: Colors.orange);
      case 'label_added': return const Icon(Icons.label, color: Colors.purple);
      default: return const Icon(Icons.info);
    }
  }
}
```

**Backend API**:
```php
// routes/api.php
Route::get('/contacts/{uuid}/activity', [ContactController::class, 'activity']);

// ContactController.php
public function activity($uuid)
{
    $contact = Contact::where('uuid', $uuid)->firstOrFail();
    
    // Combine chat logs, ticket logs, label changes
    $activities = collect();
    
    // Message activities
    $messages = Chat::where('contact_id', $contact->id)
        ->where('type', 'outbound')
        ->with('user:id,name')
        ->get()
        ->map(fn($c) => [
            'type' => 'message_sent',
            'description' => 'Sent ' . $c->message_type . ' message',
            'agent_name' => $c->user?->name,
            'created_at' => $c->created_at,
        ]);
    
    // Ticket activities
    $ticketLogs = ChatTicketLog::whereHas('ticket', fn($q) => $q->where('contact_id', $contact->id))
        ->with('user:id,name')
        ->get()
        ->map(fn($l) => [
            'type' => $l->action,
            'description' => $l->description,
            'agent_name' => $l->user?->name,
            'created_at' => $l->created_at,
        ]);
    
    return $activities
        ->merge($messages)
        ->merge($ticketLogs)
        ->sortByDesc('created_at')
        ->values();
}
```

---

## 🟢 Phase 4: Low Priority / Polish

### 4.1 Message Search Within Chat
Search for specific messages in a conversation.

### 4.2 Message Reactions
Add emoji reactions to messages.

### 4.3 Reply to Specific Message
Quote/reply to a specific message in thread.

### 4.4 Forward Messages
Forward messages to other contacts.

### 4.5 Starred Messages
Mark important messages for quick access.

### 4.6 Chat Export
Export chat history as PDF/text.

### 4.7 Bulk Contact Actions
Select multiple contacts for bulk label/assign/delete.

### 4.8 Contact Import
Import contacts from CSV/phone contacts.

### 4.9 Analytics Dashboard
Message stats, response times, agent performance.

### 4.10 Offline Queue
Queue messages when offline, send when back online.

---

## 📁 Files to Create

| File | Purpose |
|------|---------|
| `lib/features/chat/presentation/new_chat_screen.dart` | Start new conversation |
| `lib/features/chat/presentation/widgets/voice_recorder.dart` | Voice message recording |
| `lib/features/chat/presentation/widgets/video_recorder.dart` | Video message recording |
| `lib/features/settings/presentation/quick_replies_screen.dart` | CRUD for quick replies |
| `lib/features/contacts/presentation/widgets/label_picker_sheet.dart` | Label picker |
| `lib/features/contacts/presentation/contact_activity_screen.dart` | Activity history |
| `lib/data/models/label_model.dart` | Label data model |
| `lib/data/models/activity_model.dart` | Activity data model |
| `lib/data/repositories/label_repository.dart` | Label API calls |
| `lib/data/repositories/activity_repository.dart` | Activity API calls |

---

## 🔧 Backend API Endpoints to Add

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/contacts` | Create new contact |
| POST | `/api/v1/contacts/{uuid}/init-chat` | Initialize chat with contact |
| GET | `/api/v1/labels` | List all labels |
| POST | `/api/v1/contacts/{uuid}/labels` | Update contact labels |
| GET | `/api/v1/contacts/{uuid}/activity` | Get contact activity log |
| POST | `/api/v1/messages/location` | Send location message |
| POST | `/api/v1/canned-replies` | Create quick reply |
| PUT | `/api/v1/canned-replies/{id}` | Update quick reply |
| DELETE | `/api/v1/canned-replies/{id}` | Delete quick reply |

---

## 📦 Dependencies to Add (pubspec.yaml)

```yaml
dependencies:
  record: ^5.0.4              # Voice recording
  geolocator: ^10.0.0         # Location services
  google_maps_flutter: ^2.5.0 # Map display (optional)
```

---

## ✅ Testing Checklist

### Critical Bugs
- [ ] New Chat button opens contact picker
- [ ] 24h window shows template-only mode
- [ ] Contacts always sorted by latest message
- [ ] Notifications play sound

### Features
- [ ] Template picker shows variable names, not numbers
- [ ] Template picker is scrollable
- [ ] Template shows live preview
- [ ] Language change applies immediately
- [ ] RTL works for Arabic
- [ ] Dark theme works
- [ ] System theme preference works
- [ ] Filters work correctly
- [ ] Voice recording works
- [ ] Labels can be viewed/edited
- [ ] Activity history shows agent info

---

## 🚀 Deployment Notes

1. Run migrations for new tables (if any)
2. Update API documentation
3. Test on both iOS and Android
4. Test RTL layout thoroughly
5. Test notification sound on various devices
6. Clear app cache when updating from old version
