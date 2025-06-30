# MyBrain API & WebSocket Documentation

## Overview

This documentation covers the complete API and WebSocket interface for the MyBrain application, including the new HashID implementation for secure ID obfuscation.

**Base URL**: `{{baseUrl}}/api/v1`

**Important**: All IDs in responses are now hashed strings (e.g., `"Xbr3k2mN"`) instead of integers. When making requests that require IDs, use these hashed values.

---

## Authentication

All protected endpoints use Bearer Token authentication:
```
Authorization: Bearer {{token}}
```

**Headers Required for All Requests**:
- `Authorization: Bearer {{token}}` (for authenticated endpoints)
- `Content-Type: application/json` (for JSON requests)
- `User-Timezone: {{timezone}}` (optional, e.g., "America/New_York")

---

## Authentication & Profile Management

### 1. Request Authentication Code

Send verification code to email address.

```http
POST /profiles/auth/request/
```

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Response:**
```json
{
  "detail": "Verification code sent."
}
```

### 2. Verify Code & Login/Register

Verify email with code and authenticate user.

```http
POST /profiles/auth/verify/
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "code": "123456",
  "device_info": {
    "device_name": "iPhone 14",
    "os_name": "iOS 17.0",
    "app_version": "1.0.0",
    "unique_device_id": "device_123_unique"
  }
}
```

**Response:**
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "device": {
    "id": "Kj9Lm2Np",
    "device_name": "iPhone 14",
    "os_name": "iOS 17.0",
    "app_version": "1.0.0",
    "unique_device_id": "device_123_unique",
    "created_at": "2025-01-01T10:00:00Z",
    "last_login": "2025-01-01T10:00:00Z"
  },
  "profile_complete": false,
  "profile": {
    "id": "Xbr3k2mN",
    "email": "user@example.com",
    "first_name": "",
    "last_name": "",
    "birthdate": null,
    "gender": null,
    "gender_display": null,
    "avatar_url": null,
    "onboarded": false,
    "is_active": true,
    "is_staff": false,
    "date_joined": "2025-01-01T10:00:00Z"
  }
}
```

### 3. Social Login - Google

Authenticate using Google ID token.

```http
POST /profiles/google-login/
```

**Request Body:**
```json
{
  "id_token": "google_id_token_here",
  "device_info": {
    "device_name": "iPhone 14",
    "os_name": "iOS 17.0",
    "app_version": "1.0.0",
    "unique_device_id": "device_123_unique"
  }
}
```

**Response:** Same format as verify code response.

### 4. Social Login - Apple

Authenticate using Apple Sign-In.

```http
POST /profiles/apple-login/
```

**Request Body:**
```json
{
  "user_id": "apple_user_id",
  "first_name": "John",
  "last_name": "Doe",
  "email": "user@privaterelay.appleid.com",
  "device_info": {
    "device_name": "iPhone 14",
    "os_name": "iOS 17.0",
    "app_version": "1.0.0",
    "unique_device_id": "device_123_unique"
  }
}
```

**Response:** Same format as verify code response.

### 5. Refresh Token

Refresh authentication token.

```http
POST /profiles/token/refresh/
```

**Request Body:**
```json
{
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 6. Get Profile Information

Get current user's profile.

```http
GET /profiles/profile/
```

**Response:**
```json
{
  "id": "Xbr3k2mN",
  "email": "user@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "birthdate": "1990-01-01",
  "gender": "M",
  "gender_display": "Male",
  "avatar_url": "https://api.example.com/profiles/avatar/hashed_token/",
  "onboarded": true,
  "is_active": true,
  "is_staff": false,
  "date_joined": "2025-01-01T10:00:00Z"
}
```

### 7. Update Profile

Update user profile information.

```http
PUT /profiles/profile/update/
```

**Request Body (Form Data or JSON):**
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "birthdate": "1990-01-01",
  "gender": "M",
  "onboarded": true
}
```

**With Avatar (Form Data):**
```
Content-Type: multipart/form-data

first_name: John
last_name: Doe
avatar: [image file]
```

**Response:** Updated profile object (same format as GET profile).

### 8. Upload Avatar

Upload or update user avatar.

```http
POST /profiles/profile/avatar/
Content-Type: multipart/form-data
```

**Request Body:**
```
avatar: [image file]
```

**Response:** Updated profile object with new avatar_url.

### 9. Delete Avatar

Remove user avatar.

```http
DELETE /profiles/profile/avatar/
```

**Response:** Updated profile object with avatar_url set to null.

### 10. Get Gender Choices

Get available gender options.

```http
GET /profiles/gender-choices/
```

**Response:**
```json
{
  "gender_choices": [
    {"value": "M", "label": "Male"},
    {"value": "F", "label": "Female"},
    {"value": "P", "label": "Prefer not to say"},
    {"value": "O", "label": "Other"}
  ]
}
```

### 11. List User Devices

Get all registered devices for current user.

```http
GET /profiles/devices/
```

**Response:**
```json
[
  {
    "id": "Kj9Lm2Np",
    "device_name": "iPhone 14",
    "os_name": "iOS 17.0",
    "app_version": "1.0.0",
    "unique_device_id": "device_123_unique",
    "created_at": "2025-01-01T10:00:00Z",
    "last_login": "2025-01-01T10:00:00Z"
  }
]
```

### 12. Terminate Device Sessions

Remove devices from user account.

```http
POST /profiles/devices/logout/
```

**Terminate specific device:**
```json
{
  "unique_device_id": "device_123_unique",
  "current_device_id": "current_device_456"
}
```

**Terminate all except current:**
```json
{
  "current_device_id": "current_device_456"
}
```

**Response:**
```json
{
  "detail": "Devices terminated successfully."
}
```

### 13. Logout

Logout from current device.

```http
POST /profiles/logout/
```

**Request Body:**
```json
{
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "unique_device_id": "device_123_unique"
}
```

**Response:**
```json
{
  "detail": "User logged out successfully."
}
```

### 14. Entertainment Preferences

Get entertainment options for onboarding.

```http
GET /profiles/entertainment/options/
```

**Response:**
```json
{
  "entertainment_types": [
    {
      "id": "Bp8Qr5Nt",
      "name": "Podcasts",
      "description": "Audio content and interviews",
      "image": "/media/types/podcast.jpg"
    }
  ],
  "entertainment_genres": [
    {
      "id": "Lm3Vx9Wz",
      "name": "Technology",
      "description": "Tech news and innovation",
      "image": "/media/genres/tech.jpg"
    }
  ],
  "entertainment_contexts": [
    {
      "id": "Qr7Yt2Kp",
      "name": "Commuting",
      "description": "Content for travel time",
      "image": "/media/contexts/commute.jpg"
    }
  ]
}
```

### 15. Update Entertainment Preferences

Set user preferences during onboarding.

```http
PUT /profiles/profile/update/
```

**Request Body:**
```json
{
  "types": [
    {"type": "Bp8Qr5Nt", "liked": true},
    {"type": "Cx4Wv8Yz", "liked": false}
  ],
  "genres": [
    {"genre": "Lm3Vx9Wz", "liked": true},
    {"genre": "Nt5Bq1Rx", "liked": false}
  ],
  "contexts": [
    {"context": "Qr7Yt2Kp", "liked": true},
    {"context": "Yz9Mp6Sv", "liked": false}
  ]
}
```

**Response:** Updated profile object with onboarded set to true.

---

## Thought Management

### 1. Create New Thought

Create a thought from URL, file, or text.

```http
POST /thoughts/create/
```

**From URL:**
```json
{
  "content_type": "url",
  "source": "https://example.com/article"
}
```

**From File (Form Data):**
```
Content-Type: multipart/form-data

content_type: pdf
file: [uploaded file]
```

**From Text:**
```json
{
  "content_type": "txt",
  "source": "Your text content here..."
}
```

**Response:**
```json
{
  "id": "Rp9Wq3Kv",
  "name": "Article Title",
  "cover": "/media/thoughts/Xbr3k2mN/url_Rp9Wq3Kv/cover.png",
  "model_3d": null,
  "created_at": "2025-01-01T10:00:00Z",
  "updated_at": "2025-01-01T10:00:00Z",
  "status": "pending"
}
```

### 2. List All Thoughts

Get all thoughts for the authenticated user.

```http
GET /thoughts/
```

**Response:**
```json
[
  {
    "id": "Rp9Wq3Kv",
    "name": "My Article",
    "description": "An interesting article about technology",
    "content_type": "url",
    "cover": "/media/thoughts/Xbr3k2mN/url_Rp9Wq3Kv/cover.png",
    "model_3d": "/media/thoughts/Xbr3k2mN/url_Rp9Wq3Kv/model.usdz",
    "status": "processed",
    "progress": {
      "total": 5,
      "completed": 2,
      "remaining": 3
    },
    "created_at": "2025-01-01T10:00:00Z",
    "updated_at": "2025-01-01T10:00:00Z"
  }
]
```

### 3. Get Thought Status

Get detailed status and chapters for a specific thought.

```http
GET /thoughts/{{hashed_thought_id}}/
```

**Response:**
```json
{
  "thought_id": "Rp9Wq3Kv",
  "thought_name": "My Article",
  "status": "in_progress",
  "progress": {
    "total": 5,
    "completed": 2,
    "remaining": 3
  },
  "chapters": [
    {
      "chapter_number": 1,
      "title": "Introduction",
      "content": "<p>Chapter content with HTML formatting...</p>",
      "status": "completed"
    },
    {
      "chapter_number": 2,
      "title": "Main Topic",
      "content": "<p>More chapter content...</p>",
      "status": "reading"
    },
    {
      "chapter_number": 3,
      "title": "Conclusion",
      "content": null,
      "status": "created"
    }
  ]
}
```

### 4. Reset Reading Progress

Reset thought progress and clear all chapter statuses.

```http
POST /thoughts/{{hashed_thought_id}}/reset/
```

**Response:**
```json
{
  "status": "success",
  "message": "Reading progress and streaming content have been reset",
  "data": {}
}
```

### 5. Retry Failed Thought

Retry processing a thought that failed.

```http
POST /thoughts/{{hashed_thought_id}}/retry/
```

**Response:**
```json
{
  "status": "success",
  "message": "Retry process started",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "original_status": "processing_failed"
  }
}
```

### 6. Summarize Completed Chapters

Create a summary chapter of all completed chapters.

```http
POST /thoughts/{{hashed_thought_id}}/summarize/
```

**Response:**
```json
{
  "status": "success",
  "message": "Summary chapter created"
}
```

### 7. Pass Chapters

Mark chapters up to a specific number as completed and create a summary.

```http
POST /thoughts/{{hashed_thought_id}}/pass/
```

**Request Body:**
```json
{
  "up_to_chapter": 3
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Chapters up to 3 passed and summary created."
}
```

### 8. Get Feedback Data

Get all user feedback for a thought.

```http
GET /thoughts/{{hashed_thought_id}}/feedbacks/
```

**Response:**
```json
{
  "status": "success",
  "message": "Retrieved 25 feedback entries",
  "feedbacks": {
    "1": {"interesting": 0.8},
    "2": {"complex": 0.3},
    "3": {"engaging": 0.9}
  }
}
```

### 9. Get Bookmarks

Get high-engagement feedback entries (bookmarks).

```http
GET /thoughts/{{hashed_thought_id}}/bookmarks/
```

**Response:**
```json
{
  "status": "success",
  "message": "Found 8 bookmarks above average (0.65)",
  "bookmarks": {
    "1": {"interesting": 0.8},
    "3": {"engaging": 0.9},
    "7": {"insightful": 0.85}
  }
}
```

### 10. Get Retention Issues

Get low-engagement feedback entries.

```http
GET /thoughts/{{hashed_thought_id}}/retentions/
```

**Response:**
```json
{
  "status": "success",
  "message": "Found 5 retention issues below average (0.65)",
  "retentions": {
    "2": {"complex": 0.3},
    "5": {"boring": 0.2},
    "9": {"confusing": 0.4}
  }
}
```

### 11. Soft Delete Thought

Mark a thought as deleted (soft delete).

```http
DELETE /thoughts/{{hashed_thought_id}}/delete/
```

**Response:**
```json
{
  "status": "success",
  "message": "Thought soft-deleted successfully."
}
```

### 12. Audio Streaming

Get HLS playlist for thought audio streaming.

```http
GET /thoughts/{{hashed_thought_id}}/stream/playlist.m3u8
```

**Response:** HLS Master Playlist (M3U8 format)

**Other streaming endpoints:**
- `/thoughts/{{hashed_thought_id}}/stream/audio.m3u8` - Audio-only playlist
- `/thoughts/{{hashed_thought_id}}/stream/subtitles.m3u8` - Subtitles playlist
- `/thoughts/{{hashed_thought_id}}/stream/{{segment_file}}` - Individual segments (.ts or .vtt files)

---

## WebSocket API

### Connection

**URL:** `ws://{{baseUrl}}/thoughts/`

**Required Headers:**
- `Authorization: Bearer {{token}}`
- `User-Timezone: {{timezone}}`

### Connection Flow

1. **Connect to WebSocket**
2. **Receive connection confirmation**
3. **Send actions and receive responses**
4. **Receive real-time updates**

### Message Format

All WebSocket messages use this JSON structure:

**Outgoing (Client → Server):**
```json
{
  "action": "action_name",
  "data": {
    "key": "value"
  }
}
```

**Incoming (Server → Client):**
```json
{
  "type": "message_type",
  "status": "success|error|info",
  "message": "Human readable message",
  "data": {
    "response_data": "value"
  }
}
```

### Connection Events

**Connection Success:**
```json
{
  "type": "connection_response",
  "status": "success",
  "message": "Welcome to My Brain!",
  "data": {
    "user": "John"
  }
}
```

**Connection Error:**
```json
{
  "type": "connection_response",
  "status": "error",
  "message": "Authentication failed"
}
```

### Available Actions

#### 1. List Thoughts

Get all thoughts for the user.

**Send:**
```json
{
  "action": "list_thoughts"
}
```

**Response:**
```json
{
  "type": "thoughts_list",
  "status": "success",
  "message": "Thoughts retrieved successfully",
  "data": {
    "thoughts": [
      {
        "id": "Rp9Wq3Kv",
        "name": "My Article",
        "description": "Article description",
        "content_type": "url",
        "cover": "/media/cover.png",
        "status": "processed",
        "created_at": "2025-01-01T10:00:00Z",
        "updated_at": "2025-01-01T10:00:00Z"
      }
    ]
  }
}
```

#### 2. Get Next Chapter

Process and retrieve the next chapter of a thought.

**Send:**
```json
{
  "action": "next_chapter",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "generate_audio": false
  }
}
```

**Response (Text Content):**
```json
{
  "type": "chapter_response",
  "status": "success",
  "message": "Chapter processing completed",
  "data": {
    "chapter_number": 1,
    "title": "Introduction",
    "content": "<p>Chapter content with <strong>formatting</strong>...</p>",
    "content_with_image": "<p>Content with images included...</p>",
    "generation_time": 2.5
  }
}
```

**Response (Audio Content):**
```json
{
  "type": "chapter_response",
  "status": "success",
  "message": "Chapter processing completed",
  "data": {
    "chapter_number": 1,
    "title": "Introduction",
    "audio_duration": 86.7,
    "generation_time": 4.2
  }
}
```

**No More Chapters:**
```json
{
  "type": "chapter_response",
  "status": "info",
  "message": "No more chapters available",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "complete": true
  }
}
```

#### 3. Submit Feedback

Submit user engagement feedback for content.

**Send:**
```json
{
  "action": "feedback",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "chapter_number": 1,
    "word": "interesting_concept",
    "value": 0.8
  }
}
```

**Response:**
```json
{
  "type": "feedback_response",
  "status": "success",
  "message": "Feedback received",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "chapter_number": 1,
    "word": "interesting_concept"
  }
}
```

#### 4. Get Thought Chapters

Retrieve all chapters for a specific thought.

**Send:**
```json
{
  "action": "thought_chapters",
  "data": {
    "thought_id": "Rp9Wq3Kv"
  }
}
```

**Response:**
```json
{
  "type": "thought_chapters",
  "status": "success",
  "message": "Chapters retrieved successfully",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "thought_name": "My Article",
    "thought_status": "processed",
    "chapters": [
      {
        "chapter_number": 1,
        "title": "Introduction",
        "content": "<p>Chapter content...</p>",
        "status": "completed"
      }
    ]
  }
}
```

#### 5. Get Streaming Links

Get HLS streaming URLs for audio playback.

**Send:**
```json
{
  "action": "streaming_links",
  "data": {
    "thought_id": "Rp9Wq3Kv"
  }
}
```

**Response:**
```json
{
  "type": "streaming_links",
  "status": "success",
  "message": "Streaming links retrieved successfully",
  "data": {
    "master_playlist": "/api/v1/thoughts/Rp9Wq3Kv/stream/playlist.m3u8",
    "audio_playlist": "/api/v1/thoughts/Rp9Wq3Kv/stream/audio.m3u8",
    "subtitles_playlist": "/api/v1/thoughts/Rp9Wq3Kv/stream/subtitles.m3u8"
  }
}
```

#### 6. Retry Thought Processing

Retry a failed thought.

**Send:**
```json
{
  "action": "retry_thought",
  "data": {
    "thought_id": "Rp9Wq3Kv"
  }
}
```

**Response:**
```json
{
  "type": "retry_response",
  "status": "success",
  "message": "Retry process started",
  "data": {
    "thought_id": "Rp9Wq3Kv",
    "original_status": "processing_failed"
  }
}
```

### Real-time Status Updates

The server automatically sends status updates during thought processing:

**Processing Status Updates:**
```json
{
  "type": "thought_update",
  "status": "success",
  "message": "Thought status: extracted",
  "data": {
    "thought": {
      "id": "Rp9Wq3Kv",
      "status": "extracted",
      "name": "My Article",
      "cover": "/media/cover.png",
      "created_at": "2025-01-01T10:00:00Z",
      "updated_at": "2025-01-01T10:00:00Z"
    }
  }
}
```

**Status Values:**
- `pending` - Initial state when created
- `extracted` - Raw content extracted from source
- `enriched` - AI-generated metadata added
- `processed` - Content processed into chapters
- `extraction_failed` - Failed during content extraction
- `enrichment_failed` - Failed during metadata enrichment
- `processing_failed` - Failed during chapter processing

### Error Handling

**Invalid Action:**
```json
{
  "type": "action_response",
  "status": "error",
  "message": "Unknown action",
  "data": {
    "action": "invalid_action_name"
  }
}
```

**Invalid JSON:**
```json
{
  "type": "action_response",
  "status": "error",
  "message": "Invalid JSON",
  "data": {}
}
```

**Server Error:**
```json
{
  "type": "action_response",
  "status": "error",
  "message": "An error occurred",
  "data": {
    "exception": "Detailed error message"
  }
}
```

**Invalid HashID:**
```json
{
  "type": "chapter_response",
  "status": "error",
  "message": "Invalid thought ID",
  "data": null
}
```

---

## HashID Implementation

### Overview

All database IDs are now returned as hashed strings instead of integers for security and obfuscation.

### Examples

**Before (Regular IDs):**
```json
{
  "id": 123,
  "user_id": 456,
  "thought_id": 789
}
```

**After (Hashed IDs):**
```json
{
  "id": "Xbr3k2mN",
  "user_id": "Kj9Lm2Np", 
  "thought_id": "Rp9Wq3Kv"
}
```

### URL Structure

**Before:**
- `/api/v1/thoughts/123/`
- `/api/v1/thoughts/123/feedbacks/`

**After:**
- `/api/v1/thoughts/Rp9Wq3Kv/`
- `/api/v1/thoughts/Rp9Wq3Kv/feedbacks/`

### Client Implementation

When making API requests, always use the hashed IDs returned in responses:

```javascript
// Get thought from list
const thought = thoughtsList[0];
const thoughtId = thought.id; // "Rp9Wq3Kv"

// Use in subsequent requests
fetch(`/api/v1/thoughts/${thoughtId}/`)
  .then(response => response.json())
  .then(data => {
    // data.thought_id will be "Rp9Wq3Kv"
    // data.chapters[0].id will be hashed as well
  });
```

### WebSocket Usage

Use hashed IDs in WebSocket messages:

```javascript
websocket.send(JSON.stringify({
  action: "next_chapter",
  data: {
    thought_id: "Rp9Wq3Kv"  // Use hashed ID
  }
}));
```

### Backward Compatibility

The system maintains backward compatibility:
- If a request contains a regular integer ID, it will still work
- New responses will always contain hashed IDs
- Gradually migrate to using hashed IDs for all requests

---

## Error Codes & Status Messages

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors, invalid data)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (invalid ID or resource)
- `429` - Too Many Requests (rate limiting)
- `500` - Internal Server Error

### Common Error Responses

**Validation Error:**
```json
{
  "email": ["This field is required."],
  "code": ["Enter a valid verification code."]
}
```

**Authentication Error:**
```json
{
  "detail": "Authentication credentials were not provided."
}
```

**Invalid HashID:**
```json
{
  "detail": "Invalid ID format"
}
```

**Rate Limiting:**
```json
{
  "detail": "Request was throttled. Expected available in 60 seconds."
}
```
