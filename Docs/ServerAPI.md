# MyBrain API & WebSocket Documentation

## Overview

This documentation covers the complete API and WebSocket interface for the MyBrain application, including the HashID implementation for secure ID obfuscation.

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
  "avatar_url": "https://api.example.com/api/v1/profiles/avatar/hashed_token/",
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

**To Remove Avatar:**
```json
{
  "remove_avatar": "true"
}
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
      "id": 1,
      "name": "Podcasts",
      "description": "Audio content and interviews",
      "image": "/media/types/podcast.jpg"
    }
  ],
  "entertainment_genres": [
    {
      "id": 1,
      "name": "Technology",
      "description": "Tech news and innovation",
      "image": "/media/genres/tech.jpg"
    }
  ],
  "entertainment_contexts": [
    {
      "id": 1,
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
    {"type": 1, "liked": true},
    {"type": 2, "liked": false}
  ],
  "genres": [
    {"genre": 1, "liked": true},
    {"genre": 2, "liked": false}
  ],
  "contexts": [
    {"context": 1, "liked": true},
    {"context": 2, "liked": false}
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

**From Podcast URL:**
```json
{
  "content_type": "podcast",
  "source": "https://podcasts.apple.com/episode/123"
}
```

**From Podcast File (Form Data):**
```
Content-Type: multipart/form-data

content_type: podcast
file: [audio file - mp3, m4a, wav, etc.]
```

**Response:**
```json
{
  "id": "Rp9Wq3Kv",
  "name": "Article Title",
  "description": "An interesting article about technology",
  "content_type": "url",
  "cover": "/media/thoughts/[user_id]/url_Rp9Wq3Kv/cover.png",
  "status": "processed",
  "progress": {
    "total": 5,
    "completed": 2,
    "remaining": 3
  },
  "created_at": "2025-01-01T10:00:00Z",
  "updated_at": "2025-01-01T10:00:00Z"
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
    "cover": "/media/thoughts/[user_id]/url_Rp9Wq3Kv/cover.png",
    "model_3d": "/media/thoughts/puser_id]/url_Rp9Wq3Kv/model.usdz",
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
GET /thoughts/{{hashed_thought_id}}/stream/master.m3u8
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

## WebSocket Messages Reference

### 1. Connection Messages

#### Connection Success
```json
{
  "type": "connection_response",
  "status": "success",
  "message": "Welcome to My Brain!",
  "data": {
    "user": "user_first_name"
  }
}
```

#### Connection Failure
```json
{
  "type": "connection_response",
  "status": "error",
  "message": "Authentication failed",
  "data": {}
}
```

### 2. Action Response Messages

#### Unknown Action
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

#### Invalid JSON
```json
{
  "type": "action_response",
  "status": "error",
  "message": "Invalid JSON",
  "data": {}
}
```

#### General Exception
```json
{
  "type": "action_response",
  "status": "error",
  "message": "An error occurred",
  "data": {
    "exception": "error_details"
  }
}
```

### 3. Thought Status Messages

#### Thought Status Success
```json
{
  "type": "thought_status",
  "status": "success",
  "message": "Thought status retrieved successfully",
  "data": {
    "id": "hashed_thought_id",
    "name": "Thought Name",
    "description": "Thought description",
    "content_type": "url",
    "cover": "cover_url",
    "model_3d": "model_url",
    "status": "processed",
    "progress": {
      "total": 5,
      "completed": 2,
      "remaining": 3
    },
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### Thought Status Errors
```json
{
  "type": "thought_status",
  "status": "error",
  "message": "Thought ID is required",
  "data": null
}
```

```json
{
  "type": "thought_status",
  "status": "error",
  "message": "Invalid thought ID",
  "data": null
}
```

```json
{
  "type": "thought_status",
  "status": "error",
  "message": "Thought not found",
  "data": null
}
```

```json
{
  "type": "thought_status",
  "status": "error",
  "message": "Failed to retrieve thought status: {error_details}",
  "data": null
}
```

### 4. Chapter Processing Messages

#### Audio Chapter Response (`chapter_audio`)
For chapters with audio generation (`generate_audio: true`).

**Success:**
```json
{
  "type": "chapter_audio",
  "status": "success",
  "message": "Audio chapter processing completed",
  "data": {
    "chapter_number": 1,
    "title": "Chapter Title",
    "audio_duration": 86.7,
    "generation_time": 12.5,
    "words": [
      {
        "text": "The",
        "start": 0.1,
        "end": 0.3
      },
      {
        "text": "future",
        "start": 0.3,
        "end": 0.6
      },
      {
        "text": "is",
        "start": 0.6,
        "end": 0.7
      },
      {
        "text": "now",
        "start": 0.7,
        "end": 1.0
      }
    ]
  }
}
```

**Error:**
```json
{
  "type": "chapter_audio",
  "status": "error",
  "message": "Failed to retrieve next chapter: {error_details}",
  "data": null
}
```

#### Text Chapter Response (`chapter_text`)
For chapters with text content (`generate_audio: false` or not specified).

**Success:**
```json
{
  "type": "chapter_text",
  "status": "success",
  "message": "Text chapter processing completed",
  "data": {
    "chapter_number": 1,
    "title": "Chapter Title",
    "content": "HTML formatted content",
    "content_with_image": "HTML content with images",
    "generation_time": 8.3
  }
}
```

**Error:**
```json
{
  "type": "chapter_text",
  "status": "error",
  "message": "Failed to retrieve next chapter: {error_details}",
  "data": null
}
```

#### Chapter Complete (`chapter_complete`)
When no more chapters are available.

```json
{
  "type": "chapter_complete",
  "status": "info",
  "message": "No more chapters available",
  "data": {
    "thought_id": "hashed_thought_id",
    "complete": true
  }
}
```

#### Common Chapter Processing Errors
Both `chapter_audio` and `chapter_text` can return these error types:

```json
{
  "type": "chapter_audio|chapter_text",
  "status": "error",
  "message": "Thought ID is required",
  "data": null
}
```

```json
{
  "type": "chapter_audio|chapter_text",
  "status": "error",
  "message": "Invalid thought ID",
  "data": null
}
```

### 5. Feedback Messages

#### Feedback Success
```json
{
  "type": "feedback_response",
  "status": "success",
  "message": "Feedback received",
  "data": {
    "thought_id": "hashed_thought_id",
    "chapter_number": 1,
    "word": "example_word"
  }
}
```

#### Feedback Errors
```json
{
  "type": "feedback_response",
  "status": "error",
  "message": "Missing required feedback fields",
  "data": null
}
```

```json
{
  "type": "feedback_response",
  "status": "error",
  "message": "Invalid thought ID",
  "data": null
}
```

```json
{
  "type": "feedback_response",
  "status": "error",
  "message": "Failed to process feedback: {error_details}",
  "data": null
}
```

### 6. Streaming Links Messages

#### Streaming Links Success
```json
{
  "type": "streaming_links",
  "status": "success",
  "message": "Streaming links retrieved successfully",
  "data": {
    "master_playlist": "/api/v1/thoughts/31/stream/master.m3u8",
    "audio_playlist": "/api/v1/thoughts/31/stream/audio.m3u8",
    "subtitles_playlist": "/api/v1/thoughts/31/stream/subtitles.m3u8"
  }
}
```

#### No More Chapters (Streaming)
```json
{
  "type": "chapter_complete",
  "status": "info",
  "message": "No more chapters available",
  "data": {
    "thought_id": "hashed_thought_id",
    "complete": true
  }
}
```

#### Streaming Links Errors
```json
{
  "type": "streaming_links",
  "status": "error",
  "message": "Thought ID is required",
  "data": null
}
```

```json
{
  "type": "streaming_links",
  "status": "error",
  "message": "Invalid thought ID", 
  "data": null
}
```

```json
{
  "type": "streaming_links",
  "status": "error",
  "message": "Failed to retrieve streaming links: {error_details}",
  "data": null
}
```

### 7. Thought Status Updates

These messages are sent asynchronously from background Celery tasks to notify clients of thought processing progress.

#### Processing Status Update
```json
{
  "type": "thought_update",
  "status": "success",
  "message": "Thought status: {current_status}",
  "data": {
    "thought": {
      "id": "hashed_thought_id",
      "name": "Thought Name",
      "cover": "cover_url",
      "model_3d": "model_url",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "status": "extracted|enriched|processed"
    }
  }
}
```

#### Processing Error Update
```json
{
  "type": "thought_update",
  "status": "success",
  "message": "Content extraction failed: {error_details}",
  "data": {
    "thought": {
      "id": "hashed_thought_id",
      "name": "Thought Name", 
      "cover": "cover_url",
      "model_3d": "model_url",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "status": "extraction_failed|enrichment_failed|processing_failed"
    }
  }
}
```

### Available Actions

#### 1. Get Thought Status

Retrieve the current status and data for a specific thought.

**Send:**
```json
{
  "action": "thought_status",
  "data": {
    "thought_id": "Rp9Wq3Kv"
  }
}
```

**Response:** See Thought Status Messages above.

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

**Response:** 
- If `generate_audio: true` → `chapter_audio` message type
- If `generate_audio: false` → `chapter_text` message type  
- If no more chapters → `chapter_complete` message type

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

**Response:** See Feedback Messages above.

#### 4. Get Streaming Links

Get HLS streaming URLs for audio playback. This action will first generate an audio chapter, then return streaming links.

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
1. First sends a `chapter_audio` message with the generated chapter
2. Then sends a `streaming_links` message with the URLs
3. If no more chapters, sends `chapter_complete` message

### Words Array Format

The `words` array in `chapter_audio` responses contains word-level subtitle data:

- **`text`**: The spoken word as a string
- **`start`**: Timestamp in seconds (float) when the word begins
- **`end`**: Timestamp in seconds (float) when the word ends
- Words are sorted chronologically by start time
- Timestamps are relative to the beginning of the chapter audio

### Status Values

- **success**: Operation completed successfully
- **error**: Operation failed due to an error
- **info**: Informational message (e.g., no more content available)

### Common Status Messages

- `pending`: Initial state when created
- `extracted`: Raw content has been extracted from source  
- `enriched`: AI-generated metadata has been added
- `processed`: Content has been fully processed into chapters
- `extraction_failed`: Failed during content extraction
- `enrichment_failed`: Failed during metadata enrichment  
- `processing_failed`: Failed during chapter processing

---
