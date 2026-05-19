#!/bin/bash

# Keycloak OAuth2/OIDC Authorization Code Flow Test Script
# This script demonstrates the complete Authorization Code Flow

set -e

# Configuration
KEYCLOAK_URL="http://localhost:8080"
REALM="myrealm"
CLIENT_ID="my-app"
CLIENT_SECRET="my-app-secret-change-this"
REDIRECT_URI="http://localhost:3000/callback/"
USERNAME="${1:-dikwan}"
PASSWORD="${2:-admin}"

echo "========================================"
echo "Keycloak Authorization Code Flow Test"
echo "========================================"
echo ""
echo "Config:"
echo "  Keycloak URL: $KEYCLOAK_URL"
echo "  Realm: $REALM"
echo "  Client ID: $CLIENT_ID"
echo "  Username: $USERNAME"
echo ""

# Step 1: Get authorization code
echo "[Step 1] Getting authorization code..."
echo "Opening browser to login page..."
echo ""
LOGIN_URL="$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/auth?client_id=$CLIENT_ID&response_type=code&redirect_uri=$REDIRECT_URI&scope=openid%20profile%20email%20phone&state=abc123"
echo "URL: $LOGIN_URL"
echo ""
echo "Login with:"
echo "  Username: $USERNAME"
echo "  Password: $PASSWORD"
echo ""
read -p "Enter the authorization code from redirect URL (code=...): " AUTH_CODE

if [ -z "$AUTH_CODE" ]; then
    echo "Error: No authorization code provided"
    exit 1
fi

echo "✓ Authorization code: $AUTH_CODE"
echo ""

# Step 2: Exchange code for tokens
echo "[Step 2] Exchanging authorization code for tokens..."
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=$REDIRECT_URI" \
  -d "grant_type=authorization_code")

echo "$TOKEN_RESPONSE" | jq .

# Extract tokens
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token // empty')
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Failed to get access token"
    exit 1
fi

echo ""
echo "✓ Tokens received"
echo ""

# Step 3: Get user info
echo "[Step 3] Getting user information..."
USERINFO=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/userinfo")

echo "$USERINFO" | jq .
echo ""

# Step 4: Decode and display tokens
echo "[Step 4] Decoding tokens..."
echo ""
echo "Access Token (decoded):"
echo "$ACCESS_TOKEN" | jq -R 'split(".") | .[0:2] | map(@base64d | fromjson)' | jq .
echo ""

echo "ID Token (decoded):"
echo "$ID_TOKEN" | jq -R 'split(".") | .[0:2] | map(@base64d | fromjson)' | jq .
echo ""

# Step 5: Test token refresh (if refresh token available)
if [ ! -z "$REFRESH_TOKEN" ]; then
    echo "[Step 5] Testing token refresh..."
    REFRESH_RESPONSE=$(curl -s -X POST "$KEYCLOAK_URL/realms/$REALM/protocol/openid-connect/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "client_secret=$CLIENT_SECRET" \
      -d "refresh_token=$REFRESH_TOKEN" \
      -d "grant_type=refresh_token")
    
    echo "$REFRESH_RESPONSE" | jq .
    echo ""
fi

echo "========================================"
echo "✓ Authorization Code Flow Test Complete"
echo "========================================"
