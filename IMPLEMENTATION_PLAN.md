# PiChat Mobile App — Implementation Plan

> **Started**: April 28, 2026  
> **Goal**: Complete the app to production-ready quality  
> **Stack**: Flutter + Riverpod + GoRouter | Laravel backend at `app.pichat.io/api/v1`

---

## Progress Tracker

| # | Task | Priority | Status |
|---|------|----------|--------|
| 1 | New Chat Screen (start conversation) | 🔴 Critical | ☐ |
| 2 | 24-Hour WhatsApp Window enforcement | 🔴 Critical | ☐ |
| 3 | Fix contact list sorting by latest message | 🔴 Critical | ☐ |
| 4 | WebSocket — wire event to update UI | 🔴 Critical | ☐ |
| 5 | Contact save — call real API (backend exists) | 🟠 High | ☐ |
| 6 | Settings save — call real API (backend exists) | 🟠 High | ☐ |
| 7 | New Chat route in GoRouter | 🔴 Critical | ☐ |
| 8 | Contact model — add `lastInboundChatAt` field | 🔴 Critical | ☐ |
| 9 | Template picker UX improvements | 🟡 Medium | ☐ |
| 10 | Contact list UI — unread badge + avatar | 🟡 Medium | ☐ |

---

## Phase 1 — Critical Fixes 🔴

### Task 1 — New Chat Screen
**Files to create:**
- `lib/features/chat/presentation/new_chat_screen.dart`

**Files to modify:**
- `lib/core/router/app_router.dart` — add `/home/chats/new` route
- `lib/features/chat/presentation/chat_screen.dart` — wire the Chat button `onTap`
- `lib/data/repositories/contact_repository.dart` — add `createContact()` method

**What it does:**
- Phone number input with `+country` prefix
- Search existing contacts as you type
- If contact exists → navigate directly to their thread
- If contact is new → call `POST /api/v1/contacts/create`, then open thread

**Backend endpoint:** `POST /api/v1/contacts/create` ✅ (already exists in `ContactController::store`)

---

### Task 2 — 24-Hour Window Enforcement
**Files to modify:**
- `lib/data/models/contact_model.dart` — add `lastInboundChatAt` field
- `lib/features/chat/presentation/chat_threads.dart` — add `_isWithin24HourWindow()` + `_build24HourExpiredBanner()`, guard `_buildMessageInput()`

**What it does:**
- Parses `last_inbound_chat_at` from API
- If > 24 hours OR null → shows orange banner with "Send Template" button
- If within window → shows normal message input

**Backend field check:** `GET /api/v1/contacts/{uuid}/message-window` ✅ (already exists in `ChatController::getMessageWindow`)

---

### Task 3 — Contact List Sorting
**Files to modify:**
- `lib/features/chat/application/main_controller.dart` — sort `state` by `latestChatCreatedAt` desc after every load/update

**What it does:**
- After fetching contacts from API → sort descending by `latestChatCreatedAt`
- After WebSocket pushes a new message → re-sort the list

---

### Task 4 — WebSocket Event Handling
**Files to modify:**
- `lib/services/websocket_service.dart` — implement `NewChatEvent` handler
- `lib/core/services/` or inject `Ref` into `ReverbService` → call `mainDataProvider.notifier.updateContactWithNewMessage()`

**What it does:**
- On `NewChatEvent`, parse `event.data` as a `Chat` object
- Call `mainDataProvider.notifier.updateContactWithNewMessage(chat)`
- Also invalidate `messagesProvider` for that contact if they are currently open

**Event payload from backend (`NewChatEvent`):**
```json
{
  "id": 123,
  "contact_id": 45,
  "type": "inbound",
  "status": "open",
  "metadata": { "type": "text", "text": { "body": "Hello!" } },
  "created_at": "2026-04-28T12:00:00Z"
}
```

---

### Task 7 — GoRouter: `/home/chats/new` route
**Files to modify:**
- `lib/core/router/app_router.dart` — add route inside the `ShellRoute`

---

### Task 8 — Contact model: `lastInboundChatAt`
**Files to modify:**
- `lib/data/models/contact_model.dart` — add field + parse from JSON

---

## Phase 2 — High Priority Wiring 🟠

### Task 5 — Contact Save (real API)
**Files to modify:**
- `lib/data/repositories/contact_repository.dart` — add `updateContact(uuid, firstName, lastName)` method
- `lib/features/contacts/presentation/contact_details_screen.dart` — replace TODO stub with real call

**Backend endpoint:** `PUT /api/v1/contacts/{uuid}` ✅ (already exists in `ContactController::update`)

---

### Task 6 — Settings Save (real API)
**Files to modify:**
- `lib/data/repositories/settings_repository.dart` — add `updateSettings(map)` and `getSettings()` methods
- `lib/features/settings/presentation/settings_screen.dart` — call save on toggle/change, load on init

**Backend endpoints:**
- `GET /api/v1/user/settings` ✅
- `PUT /api/v1/user/settings` ✅

---

## Phase 3 — UX Improvements 🟡

### Task 9 — Template Picker UX
**Files to modify:**
- `lib/features/templates/presentation/template_picker_screen.dart`

**Improvements:**
- Show actual variable names from template metadata instead of "Variable 1, 2, 3"
- Fix overflow on long lists (ensure `Expanded` + `ListView` wrapping)
- Add template preview card below selection

---

### Task 10 — Contact List UI Polish
**Files to modify:**
- `lib/features/chat/widgets/contactItem.dart`

**Improvements:**
- Unread count badge (already has `unreadCount` on Contact model)
- Display last message time properly (relative: "2m ago", "Yesterday", etc.)
- Status chip (open / pending / closed)

---

## Implementation Order

```
Task 8  →  Task 3  (model first, then sorting)
Task 7  →  Task 1  (route first, then screen)
Task 4             (WebSocket, independent)
Task 2             (24h window, depends on Task 8)
Task 5             (contact save, independent)
Task 6             (settings save, independent)
Task 9             (template UX, independent)
Task 10            (UI polish, independent)
```

---

## Key File Reference

| File | Purpose |
|------|---------|
| `lib/core/router/app_router.dart` | GoRouter routes |
| `lib/features/chat/presentation/chat_screen.dart` | Contact list + New Chat button |
| `lib/features/chat/presentation/chat_threads.dart` | Chat thread + message input |
| `lib/features/contacts/presentation/contact_details_screen.dart` | Contact view/edit |
| `lib/features/settings/presentation/settings_screen.dart` | Settings UI |
| `lib/features/templates/presentation/template_picker_screen.dart` | Template picker |
| `lib/features/chat/application/main_controller.dart` | Contacts state controller |
| `lib/data/repositories/contact_repository.dart` | Contact API calls |
| `lib/data/repositories/settings_repository.dart` | Settings API calls |
| `lib/data/models/contact_model.dart` | Contact data model |
| `lib/services/websocket_service.dart` | Reverb WebSocket |
| `lib/core/constants/app_constants.dart` | API base URL |

---

## Backend Status (all endpoints exist ✅)

| Endpoint | Controller | Status |
|----------|-----------|--------|
| `POST /api/v1/contacts/create` | `ContactController::store` | ✅ |
| `PUT /api/v1/contacts/{uuid}` | `ContactController::update` | ✅ |
| `GET /api/v1/contacts/{uuid}/message-window` | `ChatController::getMessageWindow` | ✅ |
| `GET /api/v1/user/settings` | `UserController::getSettings` | ✅ |
| `PUT /api/v1/user/settings` | `UserController::updateSettings` | ✅ |
| `POST /api/v1/contacts/{uuid}/assign` | `TicketController::assignToAgent` | ✅ |
| `PATCH /api/v1/contacts/{uuid}/ticket/status` | `TicketController::updateStatus` | ✅ |

> **Good news**: No new backend work needed! All endpoints are already implemented.

---

## Current Session Progress

- [x] Task 8 — Add `lastInboundChatAt` to Contact model
- [x] Task 3 — Fix contact list sorting (sort by `latestChatCreatedAt` desc)
- [x] Task 7 — Add `/home/chats/new` route to GoRouter
- [x] Task 1 — Create `new_chat_screen.dart` with search + new contact form
- [x] Task 4 — Add `addOrUpdateContact()` to MainController
- [x] Task 2 — Add `createContact()` + `updateContact()` + `searchContacts()` to ContactRepository
- [x] Task 5 — Fix WebSocket org ID (was hardcoded `"1"`, now reads from `organizationProvider`)
- [x] Task 6 — Enforce 24-hour window in `chat_threads.dart` with orange banner + "Send Template" CTA
- [x] Task contact save — Wire `_saveContact()` to `contactRepository.updateContact()`
- [x] Task settings — Settings already wired correctly; confirmed working
- [x] Task 9 — Template picker: live preview + better variable labels + scrollable inputs
- [x] Task 10 — Contact list UI polish: initials avatar, bold unread, status dot, primary color badge
