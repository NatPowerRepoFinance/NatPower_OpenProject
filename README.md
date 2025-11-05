# OpenProject Projects API Documentation

Complete guide for using the OpenProject Projects API v3, including API key generation, authentication, and all available endpoints.

## Table of Contents

1. [Getting Started](#getting-started)
2. [API Key Generation](#api-key-generation)
3. [Authentication](#authentication)
4. [Base URL](#base-url)
5. [Project Endpoints](#project-endpoints)
   - [List Projects](#list-projects)
   - [Get Project](#get-project)
   - [Create Project](#create-project)
   - [Update Project](#update-project)
   - [Update Project Details](#update-project-details)
   - [Delete Project](#delete-project)
6. [Field Reference](#field-reference)
7. [Error Handling](#error-handling)
8. [Examples](#examples)

---

## Getting Started

The OpenProject API v3 allows you to interact with projects programmatically. All requests require authentication using an API key.

---

## API Key Generation

### Step 1: Enable API Access

1. Log in to your OpenProject instance
2. Navigate to **My account** → **Access tokens**
3. Ensure API tokens are enabled by your administrator (check **Administration** → **API and webhooks**)

### Step 2: Generate API Key

1. Go to **My account** → **Access tokens**
2. In the **API** section, click **Generate** (or **Reset** if you already have a key)
3. **Important**: Copy and save your API key immediately. It will only be shown once!
4. You can optionally provide a name for your token

**Note**: Only one API key can exist per user at any time. Generating a new key will invalidate the previous one.

---

## Authentication

OpenProject API uses **Basic Authentication** with a special username format:

- **Username**: `apikey` (literal text, not your login username)
- **Password**: Your API key (the token you generated)

### Authentication Header Format

```
Authorization: Basic <base64_encoded_credentials>
```

Where credentials are: `apikey:YOUR_API_KEY`

### Example with cURL

```bash
curl -u apikey:YOUR_API_KEY \
  https://your-instance.openproject.org/api/v3/projects
```

### Example with Postman

1. Go to **Authorization** tab
2. Select **Basic Auth** type
3. **Username**: `apikey`
4. **Password**: Paste your API key

### Example with Bearer Token (Alternative)

You can also use Bearer token authentication:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://your-instance.openproject.org/api/v3/projects
```

---

## Base URL

```
https://your-instance.openproject.org/api/v3
```

For local development:
```
http://localhost:3000/api/v3
```

---

## Project Endpoints

### List Projects

Retrieve a list of all projects you have access to.

**Endpoint:** `GET /api/v3/projects`

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Query Parameters:**
- `pageSize` (optional): Number of results per page (default: 20)
- `offset` (optional): Page offset for pagination

**Example Request:**
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://your-instance.openproject.org/api/v3/projects
```

**Example Response:**
```json
{
  "_type": "Collection",
  "count": 10,
  "total": 10,
  "pageSize": 20,
  "offset": 1,
  "_embedded": {
    "elements": [
      {
        "_type": "Project",
        "id": 1,
        "identifier": "my-project",
        "name": "My Project",
        "projectCode": "P0001",
        "projectStatus": "Active",
        "projectStage": "Opportunity",
        ...
      }
    ]
  }
}
```

---

### Get Project

Retrieve details of a specific project.

**Endpoint:** `GET /api/v3/projects/{id}`

**Path Parameters:**
- `id` (required): Project ID or identifier

**Example Request:**
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://your-instance.openproject.org/api/v3/projects/1
```

**Example Response:**
```json
{
  "_type": "Project",
  "id": 1,
  "identifier": "my-project",
  "name": "My Project",
  "description": {
    "format": "plain",
    "raw": "Project description",
    "html": "<p>Project description</p>"
  },
  "public": false,
  "active": true,
  "projectCode": "P0001",
  "projectSiteName": "My Site",
  "projectFinancialCode": "FIN123456",
  "projectSpvName": "NP SPV 11",
  "projectDivision": "NPLUK",
  "projectStatus": "Active",
  "projectStage": "Opportunity",
  "projectGisObjectId": "00000000-0000-0000-0000-000000000000",
  "projectGisDatabaseId": "00000000-0000-0000-0000-000000000000",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

---

### Create Project

Create a new project.

**Endpoint:** `POST /api/v3/projects`

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Request Body:**

**Minimal Required Fields:**
```json
{
  "name": "Solar Farm Alpha",
  "identifier": "solar-farm-alpha",
  "public": false,
  "projectDivision": "NPLUK",
  "projectStatus": "Active",
  "projectStage": "Opportunity"
}
```

**Complete Request with All Fields:**
```json
{
  "name": "Solar Farm Alpha",
  "identifier": "solar-farm-alpha",
  "public": false,
  "description": {
    "format": "plain",
    "raw": "A new solar energy project",
    "html": "<p>A new solar energy project</p>"
  },
  "projectCode": "",
  "projectSiteName": "Alpha Solar Site",
  "projectFinancialCode": "SOL123456",
  "projectSpvName": "NP SPV 11",
  "projectDivision": "NPLUK",
  "projectStatus": "Active",
  "projectStage": "Opportunity",
  "projectGisObjectId": "00000000-0000-0000-0000-000000000001",
  "projectGisDatabaseId": "00000000-0000-0000-0000-000000000002"
}
```

**Example Request:**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My New Project",
    "identifier": "my-new-project",
    "public": false,
    "projectDivision": "NPLUK",
    "projectStatus": "Active",
    "projectStage": "Opportunity"
  }' \
  https://your-instance.openproject.org/api/v3/projects
```

**Note:** 
- `projectCode` is auto-generated if not provided (format: P####)
- `projectSiteName` defaults to `name` if not provided
- `projectDivision`, `projectStatus`, and `projectStage` are required

**Example Response (201 Created):**
```json
{
  "_type": "Project",
  "id": 123,
  "identifier": "solar-farm-alpha",
  "name": "Solar Farm Alpha",
  "projectCode": "P0001",
  "projectSiteName": "Alpha Solar Site",
  "projectStatus": "Active",
  "projectStage": "Opportunity",
  "projectDivision": "NPLUK",
}
```

---

### Update Project

Update an existing project (all fields).

**Endpoint:** `PATCH /api/v3/projects/{id}`

**Path Parameters:**
- `id` (required): Project ID or identifier

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Request Body (Partial Update - only include fields you want to change):**
```json
{
  "name": "Updated Project Name",
  "projectStatus": "On Hold",
  "projectStage": "Construction",
  "projectDivision": "NPMUK"
}
```

**Example Request:**
```bash
curl -X PATCH \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Project Name",
    "projectStatus": "On Hold",
    "projectStage": "Construction"
  }' \
  https://your-instance.openproject.org/api/v3/projects/1
```

**Example Response (200 OK):**
```json
{
  "_type": "Project",
  "id": 1,
  "name": "Updated Project Name",
  "projectStatus": "On Hold",
  "projectStage": "Construction",
}
```

---

### Update Project Details

Update only project detail fields (recommended for updating project-specific fields).

**Endpoint:** `PATCH /api/v3/projects/{id}/details`

**Path Parameters:**
- `id` (required): Project ID or identifier

**Headers:**
```
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

**Request Body (All fields are optional - only include what you want to update):**
```json
{
  "projectSiteName": "New Site Name",
  "projectFinancialCode": "FIN987654",
  "projectSpvName": "NP SPV 15",
  "projectDivision": "NPHUK",
  "projectStatus": "Archive",
  "projectStage": "Operation",
  "projectGisObjectId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "projectGisDatabaseId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
}
```

**Example Request:**
```bash
curl -X PATCH \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "projectStatus": "On Hold",
    "projectStage": "Planning and Permitting",
    "projectDivision": "NPHIT"
  }' \
  https://your-instance.openproject.org/api/v3/projects/1/details
```

**Example Response (200 OK):**
```json
{
  "_type": "ProjectDetails",
  "projectCode": "P0001",
  "projectSiteName": "New Site Name",
  "projectFinancialCode": "FIN987654",
  "projectSpvName": "NP SPV 15",
  "projectDivision": "NPHUK",
  "projectStatus": "Archive",
  "projectStage": "Operation",
}
```

---

### Delete Project

Delete a project (requires admin permissions).

**Endpoint:** `DELETE /api/v3/projects/{id}`

**Path Parameters:**
- `id` (required): Project ID or identifier

**Example Request:**
```bash
curl -X DELETE \
  -H "Authorization: Bearer YOUR_API_KEY" \
  https://your-instance.openproject.org/api/v3/projects/1
```

**Example Response (204 No Content):** No response body

---


## Field Reference

### Required Fields

| Field | Type | Description | Auto-Generated |
|-------|------|-------------|----------------|
| `name` | String (max 255) | Project name | No |
| `identifier` | String (max 100) | URL-friendly identifier | No |
| `projectCode` | String (5 chars) | Auto-generated code (P####) | Yes |
| `projectSiteName` | String (max 50) | Site name | Yes (defaults to name) |
| `projectStatus` | String | Project status | No |
| `projectStage` | String | Project stage | No |
| `projectDivision` | String | Company division code | No |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `public` | Boolean | Whether project is public (default: false) |
| `description` | Object | Formatted description with `format`, `raw`, `html` |
| `projectFinancialCode` | String (max 9) | Financial budget code |
| `projectSpvName` | String | SPV name from lookup table |
| `projectGisObjectId` | UUID | GIS object identifier |
| `projectGisDatabaseId` | UUID | GIS database identifier |

### Allowed Values

#### Project Status (`projectStatus`)
- `"Active"`
- `"On Hold"`
- `"Archive"`
- `"Deleted"`

#### Project Stage (`projectStage`)
- `"Opportunity"`
- `"Prospect"`
- `"Preparation and Agreement"`
- `"Development and Pre-planning"`
- `"Planning and Permitting"`
- `"Ready to Build"`
- `"Construction"`
- `"Operation"`

#### Project Division (`projectDivision`)
- `"NPLUK"` - NatPower UK Onshore
- `"NPMUK"` - NatPower UK Marine
- `"NPHUK"` - NatPower UK Hydrogen
- `"NPLIT"` - NatPower IT Onshore
- `"NPMIT"` - NatPower IT Marine
- `"NPHIT"` - NatPower IT Hydrogen
- `"NPDKZ"` - NatPower Kazakhstan Hydro
- `"WKMHK"` - WK NatPower Hong Kong

#### Project SPV Name (`projectSpvName`)
- `"NP SPV 11"`, `"NP SPV 13"`, `"NP SPV 14"`, `"NP SPV 15"`, `"NP SPV 16"`, `"NP SPV 17"`, `"NP SPV 18"`, `"NP SPV 20"`, `"NP SPV 26"`, `"NP SPV 27"`, `"NP SPV 29"`, `"NP SPV 30"`, `"NP SPV 34"`, `"NP SPV 41"`, `"NP SPV 42"`, `"NP SPV 43"`, `"NP SPV 44"`, `"NP SPV 45"`, `"NP SPV 46"`, `"NP SPV 47"`, `"NP SPV 48"`, `"NP SPV 49"`, `"NP SPV 50"`

---

## Error Handling

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success (GET, PATCH) |
| 201 | Created (POST) |
| 204 | No Content (DELETE) |
| 400 | Bad Request - Invalid request format |
| 401 | Unauthorized - Invalid or missing API key |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource doesn't exist |
| 422 | Unprocessable Entity - Validation error |

### Error Response Format

```json
{
  "_type": "Error",
  "errorIdentifier": "urn:openproject-org:api:v3:errors:PropertyConstraintViolation",
  "message": "Project status is not included in the list",
  "_embedded": {
    "details": {
      "attribute": "projectStatus"
    }
  },
  "errors": {
    "projectStatus": ["is not included in the list"],
    "projectDivision": ["can't be blank"]
  }
}
```

### Common Errors

**Missing Required Field:**
```json
{
  "message": "Project division can't be blank",
  "errors": {
    "projectDivision": ["can't be blank"]
  }
}
```

**Invalid Lookup Value:**
```json
{
  "message": "Project status is not included in the list",
  "errors": {
    "projectStatus": ["is not included in the list"]
  }
}
```

**Invalid API Key:**
```json
{
  "_type": "Error",
  "errorIdentifier": "urn:openproject-org:api:v3:errors:Unauthenticated",
  "message": "You need to be authenticated to access this resource."
}
```

---


## Additional Resources

- [OpenProject API Documentation](https://www.openproject.org/docs/api/)
- [OpenProject Community Forum](https://community.openproject.org/)
- [OpenProject GitHub Repository](https://github.com/opf/openproject)

---

**Last Updated:** 2024-11-03

