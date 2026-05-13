# Keycloak with Multiple LDAP Federation & Authorization Code Flow

This project sets up Keycloak with multiple LDAP sources and a pre-configured OAuth2/OpenID Connect client for Authorization Code Flow.

## Quick Start

### 1. Start the Services
```bash
docker-compose up -d
```

This starts:
- **Keycloak** (http://localhost:8080)
- **LDAP 1** (org1.local) with users: dikwan, zochen
- **LDAP 2** (org2.local) with users: dachen
- **phpLDAPadmin** (LDAP management UI)

### 2. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Keycloak Admin Console** | http://localhost:8080 | admin / admin |
| **LDAP phpAdmin** | http://localhost:389 | See docker-compose.yml |
| **Keycloak Realm** | myrealm | Pre-configured with LDAP federation |

## Authorization Code Flow Setup

The realm is pre-configured with an OAuth2/OpenID Connect client named **`my-app`** supporting Authorization Code Flow.

### Client Configuration

**Client ID:** `my-app`  
**Client Secret:** `my-app-secret-change-this` (⚠️ Change in production!)  
**Protocol:** OpenID Connect  
**Flow:** Authorization Code Flow (industry standard, most secure)

### OAuth2/OIDC Endpoints

Replace `{host}` with your Keycloak URL (e.g., `http://localhost:8080`):

```
Authorization Endpoint: {host}/realms/myrealm/protocol/openid-connect/auth
Token Endpoint:         {host}/realms/myrealm/protocol/openid-connect/token
Userinfo Endpoint:      {host}/realms/myrealm/protocol/openid-connect/userinfo
Logout Endpoint:        {host}/realms/myrealm/protocol/openid-connect/logout
JWKS Endpoint:          {host}/realms/myrealm/protocol/openid-connect/certs
```

### Step 1: User Login (Browser)

Open your browser and navigate to the authorization endpoint:

```
GET http://localhost:8080/realms/myrealm/protocol/openid-connect/auth?
  client_id=my-app
  &response_type=code
  &redirect_uri=http://localhost:3000/callback
  &scope=openid%20profile%20email
  &state=abc123
```

**Or use a direct link:**
```
http://localhost:8080/realms/myrealm/protocol/openid-connect/auth?client_id=my-app&response_type=code&redirect_uri=http://localhost:3000/callback&scope=openid%20profile%20email&state=abc123
```

**Login with:**
- Username: `dikwan` (or `zochen`, `dachen`)
- Password: `admin`

After successful login, you'll be redirected with an authorization code:
```
http://localhost:3000/callback?code=<AUTHORIZATION_CODE>&state=abc123
```

### Step 2: Exchange Authorization Code for Tokens (Backend)

From your backend, exchange the authorization code for tokens:

```bash
curl -X POST http://localhost:8080/realms/myrealm/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=my-app" \
  -d "client_secret=my-app-secret-change-this" \
  -d "code=<AUTHORIZATION_CODE>" \
  -d "redirect_uri=http://localhost:3000/callback" \
  -d "grant_type=authorization_code"
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "expires_in": 300,
  "refresh_token": "eyJhbGc...",
  "token_type": "Bearer",
  "id_token": "eyJhbGc...",
  "scope": "openid profile email"
}
```

### Step 3: Access Protected Resources

Use the `access_token` to call the userinfo endpoint:

```bash
curl -H "Authorization: Bearer <ACCESS_TOKEN>" \
  http://localhost:8080/realms/myrealm/protocol/openid-connect/userinfo
```

**Response:**
```json
{
  "sub": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "email_verified": false,
  "preferred_username": "dikwan",
  "given_name": "Dick",
  "family_name": "Kwan",
  "email": "dikwan@example.org"
}
```

## Available Users

### Organization 1 (LDAP 1)
- **dikwan** (Dick Kwan) - admin, developer
- **zochen** (Zoe Chen) - developer

### Organization 2 (LDAP 2)
- **dachen** (Dave Chen) - developer

**Default Password:** `admin`

## LDAP Bootstrap Files

Users are automatically created from:
- `./org1/bootstrap.ldif` - Users and groups for org1.local
- `./org2/bootstrap.ldif` - Users and groups for org2.local

## Keycloak Realm Configuration

`./realm-export/myrealm.json` contains:
- Realm settings (token lifespans, password policy)
- LDAP federation providers for org1 and org2
- OAuth2/OIDC client configuration with Authorization Code Flow enabled
- Protocol mappers for user claims

## Production Configuration

⚠️ **Before deploying to production:**

1. **Change the client secret:**
   - Admin Console → Clients → my-app → Credentials → Regenerate
   
2. **Update redirect URIs:**
   - Replace `http://localhost:3000` with your actual application URL

3. **Enable SSL/TLS:**
   - Update `sslRequired` in realm config or use `KC_HTTPS_*` env variables

4. **Update LDAP credentials:**
   - Use environment variables instead of hardcoded values

5. **Change admin credentials:**
   - Update `KC_BOOTSTRAP_ADMIN_USERNAME` and `KC_BOOTSTRAP_ADMIN_PASSWORD`

## Troubleshooting

**User not logging in?**
- Check LDAP connectivity in Keycloak Admin Console
- Verify user exists in bootstrap.ldif files
- Check user is in correct OU (ou=users)

**Invalid redirect_uri error?**
- Ensure redirect URI matches exactly in Client configuration
- URIs are case-sensitive and must include protocol and path

**Token validation fails?**
- Verify client secret matches in token request
- Check token hasn't expired (default 5 minutes)
- Validate JWT signature using JWKS endpoint

**LDAP errors?**
- Verify container networking: `docker network ls`
- Test LDAP with: `docker exec ldap01 ldapsearch -x -H ldap:// -D cn=admin,dc=org1,dc=local -w admin -b dc=org1,dc=local`
