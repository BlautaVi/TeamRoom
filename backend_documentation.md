# TeamRoom Backend API Documentation

**Source**: [https://team-room-back.onrender.com/swagger-ui/index.html#](https://team-room-back.onrender.com/swagger-ui/index.html#)  
**OpenAPI Specification**: [https://team-room-back.onrender.com/v3/api-docs](https://team-room-back.onrender.com/v3/api-docs)

## Base Information

- **Title**: TeamRoom API
- **Description**: API документація для додатку TeamRoom
- **Version**: v1.0
- **Base URL**: `https://team-room-back.onrender.com`
- **OpenAPI Version**: 3.1.0

## Authentication

All protected endpoints require JWT Bearer token authentication:

```
Authorization: Bearer <jwt_token>p
```

**Note**: Enter JWT token WITHOUT the 'Bearer ' prefix in Swagger UI.

---

## API Endpoints

### 🔐 Authentication (Аутентифікація)

#### POST `/api/auth/register`
**Description**: Register new user account

**Request Body**:
```json
{
  "username": "string",     // 4-32 characters, unique, no spaces
  "email": "string",        // 3-254 characters, unique, valid email format
  "password": "string"       // 8-100 characters, must contain: 1 uppercase, 1 lowercase, 1 digit, 1 special character
}
```

**Example**:
```json
{
  "username": "nek1t_user",
  "email": "nek1t@gmail.com", 
  "password": "Password123$"
}
```

**Response**:
```json
{
  "message": "string",
  "username": "string"
}
```

**Status Codes**:
- `200` - User successfully registered
- `400` - Validation error
- `409` - Username/email already exists
- `500` - Internal server error

---

#### POST `/api/auth/login`
**Description**: Authenticate user and receive JWT token

**Request Body**:
```json
{
  "username": "string",
  "password": "string"
}
```

**Response**:
```json
{
  "jwt": "string",          // JWT Bearer Token for subsequent requests
  "username": "string"      // Authenticated user's username
}
```

**Status Codes**:
- `200` - Login successful
- `401` - Invalid credentials
- `500` - Internal server error

---

### 👤 User Management (Користувач)

#### DELETE `/api/user`
**Description**: Delete current user account (irreversible action)

**Headers**: `Authorization: Bearer <token>`

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - User successfully deleted
- `401` - Unauthorized (invalid/missing JWT)
- `403` - Forbidden (insufficient permissions)
- `500` - Internal server error

---

### 👤 User Profile (Профіль користувача)

#### GET `/api/profile`
**Description**: Get current user's profile information

**Headers**: `Authorization: Bearer <token>`

**Response**:
```json
{
  "firstName": "string",    // Required field
  "lastName": "string",     // Optional
  "biography": "string",    // Optional
  "photoUrl": "string"     // Optional, URI format
}
```

**Status Codes**:
- `200` - Profile successfully retrieved
- `401` - Unauthorized
- `404` - Profile not found for current user
- `500` - Internal server error

---

#### POST `/api/profile`
**Description**: Create profile for current user

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "firstName": "string",    // Required, max 32 characters
  "lastName": "string",     // Optional, max 32 characters  
  "biography": "string",    // Optional, max 100 characters
  "photoUrl": "string"      // Optional, URI format
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Profile successfully created
- `400` - Validation error
- `401` - Unauthorized
- `409` - Profile already exists for this user
- `500` - Internal server error

---

#### PUT `/api/profile`
**Description**: Fully update current user's profile (replaces all data)

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "firstName": "string",    // Required, max 32 characters
  "lastName": "string",     // Optional, max 32 characters
  "biography": "string",    // Optional, max 100 characters  
  "photoUrl": "string"      // Optional, URI format
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Profile successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `404` - Profile not found for update
- `500` - Internal server error

---

#### PATCH `/api/profile`
**Description**: Partially update current user's profile (only provided fields)

**Headers**: `Authorization: Bearer <token>`

**Request Body** (any combination of fields):
```json
{
  "firstName": "string",    // Optional, max 32 characters
  "lastName": "string",     // Optional, max 32 characters
  "biography": "string",    // Optional, max 100 characters
  "photoUrl": "string"      // Optional, URI format
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Profile successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `404` - Profile not found for update
- `500` - Internal server error

---

### 📁 Cloud Storage (Хмарне сховище)

#### GET `/api/cloud-storage/get-upload-link`
**Description**: Get upload URL for file upload to cloud storage

**Headers**: `Authorization: Bearer <token>`

**Query Parameters**:
- `purpose`: string (e.g., "profile-photo", "course-cover", "material-file")

**Response**:
```json
{
  "link": "string"          // Unique upload link for cloud storage
}
```

**Status Codes**:
- `200` - Upload link successfully generated
- `401` - Unauthorized
- `500` - Internal server error

---

#### GET `/api/cloud-storage/get-public-link`
**Description**: Get public access URL for uploaded file

**Headers**: `Authorization: Bearer <token>`

**Query Parameters**:
- `fileid`: integer - File ID from upload response

**Response**:
```json
{
  "link": "string"          // Public link for file access/download
}
```

**Status Codes**:
- `200` - Public link successfully generated
- `401` - Unauthorized
- `404` - File with specified fileid not found
- `500` - Internal server error

---

### 🎓 Courses (Курси)

#### GET `/api/course`
**Description**: Get all courses for current user

**Headers**: `Authorization: Bearer <token>`

**Response**:
```json
{
  "username": "string",
  "courses": [
    {
      "id": "integer",
      "name": "string",
      "photoUrl": "string",
      "isOpen": "boolean",
      "members": [
        {
          "username": "string",
          "role": "OWNER|PROFESSOR|LEADER|STUDENT|VIEWER",
          "createdAt": "string"
        }
      ]
    }
  ]
}
```

**Status Codes**:
- `200` - Courses list retrieved
- `401` - Unauthorized
- `500` - Internal server error

---

#### POST `/api/course`
**Description**: Create new course (user becomes OWNER)

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "name": "string",         // Required, max 100 characters
  "photoUrl": "string"      // Optional, URI format
}
```

**Response**:
```json
{
  "courseId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Course successfully created
- `400` - Validation error
- `401` - Unauthorized
- `500` - Internal server error

---

#### GET `/api/course/{id}`
**Description**: Get course information (requires VIEWER role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Response**:
```json
{
  "id": "integer",
  "name": "string",
  "photoUrl": "string",
  "isOpen": "boolean",
  "members": [
    {
      "username": "string",
      "role": "OWNER|PROFESSOR|LEADER|STUDENT|VIEWER",
      "createdAt": "string"
    }
  ]
}
```

**Status Codes**:
- `200` - Course data retrieved
- `401` - Unauthorized
- `403` - Forbidden (insufficient permissions)
- `404` - Course not found
- `500` - Internal server error

---

#### PUT `/api/course/{id}`
**Description**: Fully update course (requires PROFESSOR role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Request Body**:
```json
{
  "name": "string",         // Required, max 100 characters
  "photoUrl": "string"      // Optional, URI format
}
```

**Response**:
```json
{
  "courseId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Course successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### PATCH `/api/course/{id}`
**Description**: Partially update course (requires PROFESSOR role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Request Body** (any combination):
```json
{
  "name": "string",         // Optional, max 100 characters
  "photoUrl": "string"      // Optional, URI format
}
```

**Response**:
```json
{
  "courseId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Course successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### DELETE `/api/course/{id}`
**Description**: Delete course (requires OWNER role)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Response**:
```json
{
  "courseId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Course successfully deleted
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### POST `/api/course/{id}/open`
**Description**: Open course for new members (requires OWNER role)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Course successfully opened
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `409` - Conflict (course already open)
- `500` - Internal server error

---

### 👥 Course Members (Курси - Учасники)

#### POST `/api/course/{id}/members`
**Description**: Add member to course (requires LEADER role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Request Body**:
```json
{
  "username": "string",     // Required, 4-32 characters
  "role": "OWNER|PROFESSOR|LEADER|STUDENT|VIEWER"  // Required
}
```

**Response**:
```json
{
  "username": "string",
  "courseId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Member successfully added
- `400` - Validation error (user already in course / doesn't exist)
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### PUT `/api/course/{id}/members`
**Description**: Change member role (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Request Body**:
```json
{
  "username": "string",     // Required, 4-32 characters
  "role": "OWNER|PROFESSOR|LEADER|STUDENT|VIEWER"  // Required
}
```

**Response**:
```json
{
  "username": "string",
  "newRole": "string",
  "message": "string"
}
```

**Status Codes**:
- `200` - Member role successfully changed
- `400` - Error (user not a course member)
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### DELETE `/api/course/{id}/members`
**Description**: Remove member from course (requires LEADER role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Query Parameters**:
- `username`: string - Username to remove

**Response**:
```json
{
  "username": "string",
  "message": "string"
}
```

**Status Codes**:
- `200` - Member successfully removed
- `400` - Error (user not a course member)
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

### 📚 Course Materials (Матеріали курсу)

#### GET `/api/course/{id}/materials`
**Description**: Get all course materials (requires VIEWER role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Response**:
```json
{
  "materials": [
    {
      "id": "integer",
      "topic": "string",
      "textContent": "string",
      "createdAt": "string",
      "tags": [
        {
          "name": "string"
        }
      ],
      "media": [
        {
          "id": "integer",
          "name": "string",
          "fileUrl": "string"
        }
      ],
      "authorUsername": "string"
    }
  ]
}
```

**Status Codes**:
- `200` - Materials retrieved
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### POST `/api/course/{id}/materials`
**Description**: Create new course material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID

**Request Body**:
```json
{
  "topic": "string",        // Required, max 100 characters
  "textContent": "string",  // Optional
  "tags": [                 // Required
    {
      "name": "string"      // Max 20 characters
    }
  ],
  "media": [                // Required
    {
      "name": "string",     // Max 255 characters
      "fileUrl": "string"   // Required, URI format
    }
  ]
}
```

**Response**:
```json
{
  "id": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Material successfully created
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### GET `/api/course/{id}/materials/{materialId}`
**Description**: Get specific material (requires VIEWER role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID

**Response**: Same as material in materials list

**Status Codes**:
- `200` - Material retrieved
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or material not found
- `500` - Internal server error

---

#### PUT `/api/course/{id}/materials/{materialId}`
**Description**: Fully update material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID

**Request Body**:
```json
{
  "topic": "string",        // Required, max 100 characters
  "textContent": "string",  // Optional
  "tags": [                 // Required, replaces all existing tags
    {
      "name": "string"      // Max 20 characters
    }
  ],
  "media": [                // Required, replaces all existing media
    {
      "name": "string",     // Max 255 characters
      "fileUrl": "string"   // Required, URI format
    }
  ]
}
```

**Response**:
```json
{
  "id": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Material successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or material not found
- `500` - Internal server error

---

#### PATCH `/api/course/{id}/materials/{materialId}`
**Description**: Partially update material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID

**Request Body** (any combination):
```json
{
  "topic": "string",        // Optional, max 100 characters
  "textContent": "string",  // Optional
  "tags": [                 // Optional, replaces existing tags
    {
      "name": "string"       // Max 20 characters
    }
  ],
  "media": [                // Optional, replaces existing media
    {
      "name": "string",      // Max 255 characters
      "fileUrl": "string"    // Required, URI format
    }
  ]
}
```

**Response**:
```json
{
  "id": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Material successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or material not found
- `500` - Internal server error

---

#### DELETE `/api/course/{id}/materials/{materialId}`
**Description**: Delete material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID

**Response**:
```json
{
  "id": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Material successfully deleted
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or material not found
- `500` - Internal server error

---

### 🏷️ Material Tags (Матеріали курсу - Теги)

#### POST `/api/course/{id}/materials/{materialId}/tags`
**Description**: Add tag to material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID

**Request Body**:
```json
{
  "name": "string"          // Required, max 20 characters
}
```

**Response**:
```json
{
  "name": "string",
  "materialId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Tag successfully added
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or material not found
- `500` - Internal server error

---

#### DELETE `/api/course/{id}/materials/{materialId}/tags/{tagName}`
**Description**: Remove tag from material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID
- `tagName`: string - Tag name to remove

**Response**:
```json
{
  "name": "string",
  "materialId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Tag successfully removed
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course, material, or tag not found
- `500` - Internal server error

---

### 📎 Material Media (Матеріали курсу - Медіа)

#### POST `/api/course/{id}/materials/{materialId}/media`
**Description**: Add media file to material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID

**Request Body**:
```json
{
  "name": "string",         // Required, max 255 characters
  "fileUrl": "string"       // Required, URI format
}
```

**Response**:
```json
{
  "id": "integer",
  "materialId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Media successfully added
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or material not found
- `500` - Internal server error

---

#### PUT `/api/course/{id}/materials/{materialId}/media/{mediaId}`
**Description**: Rename media file (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID
- `mediaId`: integer - Media ID

**Request Body**:
```json
{
  "name": "string"          // Required, max 255 characters
}
```

**Response**:
```json
{
  "id": "integer",
  "materialId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Media successfully renamed
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course, material, or media not found
- `500` - Internal server error

---

#### DELETE `/api/course/{id}/materials/{materialId}/media/{mediaId}`
**Description**: Remove media file from material (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `id`: integer - Course ID
- `materialId`: integer - Material ID
- `mediaId`: integer - Media ID

**Response**:
```json
{
  "id": "integer",
  "materialId": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Media successfully removed
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course, material, or media not found
- `500` - Internal server error

---

### 📝 Course Assignments (Завдання курсу)

#### GET `/api/course/{courseId}/assignments`
**Description**: Get all course assignments (requires VIEWER role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID

**Response**:
```json
{
  "assignments": [
    {
      "id": "integer",
      "title": "string",
      "description": "string",
      "maxGrade": "integer",
      "createdAt": "string",
      "deadline": "string",
      "authorUsername": "string",
      "media": [
        {
          "id": "integer",
          "name": "string",
          "fileUrl": "string"
        }
      ]
    }
  ]
}
```

**Status Codes**:
- `200` - Assignments retrieved
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### POST `/api/course/{courseId}/assignments`
**Description**: Create new assignment (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID

**Request Body**:
```json
{
  "title": "string",        // Required, max 255 characters
  "description": "string",  // Optional
  "maxGrade": "integer",    // Required, minimum 0
  "deadline": "string"      // Required, ISO 8601 datetime format
}
```

**Response**:
```json
{
  "id": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Assignment successfully created
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course not found
- `500` - Internal server error

---

#### GET `/api/course/{courseId}/assignments/{assignmentId}`
**Description**: Get specific assignment (requires VIEWER role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID

**Response**: Same as assignment in assignments list

**Status Codes**:
- `200` - Assignment retrieved
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or assignment not found
- `500` - Internal server error

---

#### PUT `/api/course/{courseId}/assignments/{assignmentId}`
**Description**: Fully update assignment (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID

**Request Body**:
```json
{
  "title": "string",        // Required, max 255 characters
  "description": "string",  // Optional
  "maxGrade": "integer",    // Required, minimum 0
  "deadline": "string"      // Required, ISO 8601 datetime format
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Assignment successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or assignment not found
- `500` - Internal server error

---

#### PATCH `/api/course/{courseId}/assignments/{assignmentId}`
**Description**: Partially update assignment (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID

**Request Body** (any combination):
```json
{
  "title": "string",        // Optional, max 255 characters
  "description": "string",  // Optional
  "maxGrade": "integer",    // Optional, minimum 0
  "deadline": "string"      // Optional, ISO 8601 datetime format
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Assignment successfully updated
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or assignment not found
- `500` - Internal server error

---

#### DELETE `/api/course/{courseId}/assignments/{assignmentId}`
**Description**: Delete assignment (requires PROFESSOR role or higher, course must be open)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Assignment successfully deleted
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or assignment not found
- `500` - Internal server error

---

### 📤 Assignment Responses (Завдання, відповіді)

#### GET `/api/course/{courseId}/assignments/{assignmentId}/responses`
**Description**: Get all assignment responses (requires VIEWER role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID

**Response**:
```json
{
  "responses": [
    {
      "id": "integer",
      "authorUsername": "string",
      "isGraded": "boolean",
      "grade": "integer",
      "gradeComment": "string",
      "isReturned": "boolean",
      "returnComment": "string",
      "media": [
        {
          "id": "integer",
          "name": "string",
          "fileUrl": "string"
        }
      ]
    }
  ]
}
```

**Status Codes**:
- `200` - Responses retrieved
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or assignment not found
- `500` - Internal server error

---

#### POST `/api/course/{courseId}/assignments/{assignmentId}/responses`
**Description**: Submit assignment response (requires STUDENT role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID

**Request Body**:
```json
{
  "media": [                // Required
    {
      "name": "string",      // Required, max 255 characters
      "fileUrl": "string"    // Required, URI format
    }
  ]
}
```

**Response**:
```json
{
  "id": "integer",
  "message": "string"
}
```

**Status Codes**:
- `200` - Response successfully submitted
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course or assignment not found
- `500` - Internal server error

---

#### POST `/api/course/{courseId}/assignments/{assignmentId}/responses/{responseId}/grade`
**Description**: Grade assignment response (requires PROFESSOR role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID
- `responseId`: integer - Response ID

**Request Body**:
```json
{
  "grade": "integer",       // Required, minimum 0
  "gradeComment": "string"  // Optional
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Response successfully graded
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course, assignment, or response not found
- `500` - Internal server error

---

#### POST `/api/course/{courseId}/assignments/{assignmentId}/responses/{responseId}/return`
**Description**: Return assignment response for revision (requires PROFESSOR role or higher)

**Headers**: `Authorization: Bearer <token>`

**Path Parameters**:
- `courseId`: integer - Course ID
- `assignmentId`: integer - Assignment ID
- `responseId`: integer - Response ID

**Request Body**:
```json
{
  "returnComment": "string" // Optional
}
```

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Response successfully returned
- `400` - Validation error
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Course, assignment, or response not found
- `500` - Internal server error

---

### 🧪 Basic Access Tests (Базові Тести Доступу)

#### GET `/api/test/public`
**Description**: Test public access endpoint

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Public access successful

---

#### GET `/api/test/protected`
**Description**: Test protected access endpoint

**Headers**: `Authorization: Bearer <token>`

**Response**:
```json
{
  "message": "string"
}
```

**Status Codes**:
- `200` - Protected access successful
- `401` - Unauthorized

---

## Data Types & Schemas

### Error Response
```json
{
  "timestamp": "string",    // ISO 8601 datetime
  "status": "integer",      // HTTP status code
  "error": "string",        // Error reason
  "message": "string",      // Error message
  "details": [              // Optional validation details
    {
      "field": "string",
      "message": "string"
    }
  ]
}
```

### User Roles
- `OWNER` - Course owner (full access)
- `PROFESSOR` - Professor (can manage content and grade)
- `LEADER` - Leader (can manage members)
- `STUDENT` - Student (can submit assignments)
- `VIEWER` - Viewer (read-only access)

### Common Status Codes
- `200` - Success
- `400` - Bad Request (validation error)
- `401` - Unauthorized (invalid/missing JWT)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `409` - Conflict (duplicate resources)
- `500` - Internal Server Error

---

## Development Notes

- **Framework**: Spring Boot
- **Database**: PostgreSQL
- **Authentication**: JWT Bearer tokens
- **File Storage**: pCloud integration
- **API Documentation**: OpenAPI 3.1.0
- **CORS**: Configured for frontend domain

---

## Quick Reference

### Most Used Endpoints
```bash
# Authentication
POST /api/auth/login
POST /api/auth/register

# Profile Management
GET /api/profile
POST /api/profile
PUT /api/profile
PATCH /api/profile

# File Upload
GET /api/cloud-storage/get-upload-link?purpose=profile-photo
GET /api/cloud-storage/get-public-link?fileid={id}

# Courses
GET /api/course
POST /api/course
GET /api/course/{id}
PUT /api/course/{id}
PATCH /api/course/{id}
DELETE /api/course/{id}

# Course Members
POST /api/course/{id}/members
PUT /api/course/{id}/members
DELETE /api/course/{id}/members

# Materials
GET /api/course/{id}/materials
POST /api/course/{id}/materials
GET /api/course/{id}/materials/{materialId}
PUT /api/course/{id}/materials/{materialId}
PATCH /api/course/{id}/materials/{materialId}
DELETE /api/course/{id}/materials/{materialId}

# Assignments
GET /api/course/{courseId}/assignments
POST /api/course/{courseId}/assignments
GET /api/course/{courseId}/assignments/{assignmentId}
PUT /api/course/{courseId}/assignments/{assignmentId}
PATCH /api/course/{courseId}/assignments/{assignmentId}
DELETE /api/course/{courseId}/assignments/{assignmentId}
```

### Environment Variables
```bash
VITE_API_URL=https://team-room-back.onrender.com
```

---

*Last Updated: January 2025*  
*API Version: 1.0*  
*Source: [Swagger UI](https://team-room-back.onrender.com/swagger-ui/index.html#)*