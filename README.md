# PMS API - Postman Collection & Documentation

Postman collection, Insomnia export, and Excel documentation for CRUD operations on the Policy entity of the PMS API.

## Credentials

Set `email` and `password` as Postman collection variables or environment variables before running.  
*A test account with rotated credentials is recommended — login details are not stored in the repo.*

## Base URL

`https://pms.srv1505121.hstgr.cloud/api/v1`

## Collections

### Import Instructions

| Tool | File | How to Import |
|------|------|---------------|
| Postman | `collections/postman_collection.json` | Postman → Import → Upload Files |
| Insomnia | `collections/insomnia_collection.yaml` | Insomnia → Preferences → Data → Import Data |

### Round-Trip Experience

Both files were created from scratch in Postman first, then round-tripped through Insomnia:

1. **Postman → Insomnia**: Imported `postman_collection.json` into Insomnia — tests, variables, and chaining all carried over intact.
2. **Insomnia → Postman**: Exported from Insomnia as Postman v2.1 JSON — the export was **incomplete**: all request bodies were merged into a single line, tests were dropped entirely, and some variable references broke.
3. **Final state**: Both files are maintained independently, matching exactly in request names, methods, bodies, headers, and test assertions. The Postman JSON is the authoritative source.

### Variables

| Variable                  | Description                          |
| ------------------------- | ------------------------------------ |
| `{{base_url}}`            | API base URL (set automatically)     |
| `{{auth_token}}`          | JWT token (set by Login request)     |
| `{{created_account_id}}`  | Account ID (set by Create Account)   |
| `{{created_policy_id}}`   | Policy ID (set by Create Policy)     |
| `{{created_endorsement_id}}` | Endorsement ID (set by Create Endorsement) |

## API Endpoints

### Account
| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| POST   | `/accounts` | Create a new account |
| GET    | `/accounts` | List all accounts |
| DELETE | `/accounts/:id` | Delete an account |

### Policy (Primary Entity)
| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| POST   | `/policies` | Create a policy |
| GET    | `/policies` | List all policies |
| GET    | `/policies/:id` | Get policy by ID |
| PUT    | `/policies/:id` | Full replacement (task requirement — API supports it) |
| PATCH  | `/policies/:id` | Update policy (full or partial) |
| DELETE | `/policies/:id` | Delete a policy |

### Endorsement (Secondary Entity)
| Method | Endpoint | Description |
| ------ | -------- | ----------- |
| POST   | `/policies/:policy_id/endorsements` | Create an endorsement |
| GET    | `/policies/:policy_id/endorsements` | List endorsements for a policy |
| DELETE | *(not supported — API returns 404)* | Delete endorsement |

## Request Chaining

The collection is ordered so that dependent values flow automatically:

```
Login → Create Account → Create Policy → Get/Create Endorsement → Get All Policies
→ Get Policy By ID → Update Policy (Full) → Update Policy (Partial)
→ Update Policy (PUT) → Get Endorsements → Delete Endorsement
→ Delete Policy → Get All Accounts → Delete Account
```

## Documentation

`docs/test_documentation.xlsx` contains two sheets:
1. **Test Outlines** — 12 test cases with expected results
2. **Request Catalog** — All 14 requests with actual status codes, response body previews, and cURL commands

## Notes

- The API supports **both PUT and PATCH** for updates
- Request bodies are wrapped: `{"policy":{...}}`, `{"account":{...}}`, `{"endorsement":{...}}`
- DELETE responses return **204 No Content** with an empty body
- The Endorsement DELETE endpoint is not implemented (returns 404)
- Credentials are not stored in the collection or repo — set them as variables before running
