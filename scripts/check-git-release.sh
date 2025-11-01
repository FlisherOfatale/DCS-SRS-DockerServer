#!/bin/bash
# Script to retrieve latest release tag from DCS SRS GitHub repository
# Based on patterns from check-for-update.yml workflow
set -e

# Get script directory for sourcing validation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source tag validation functions
if ! source "$SCRIPT_DIR/validate-tag.sh"; then
    echo "Error: Failed to load tag validation functions" >&2
    exit 1
fi

# Configuration - using environment variables for security
readonly SRS_REPO="ciribob/DCS-SimpleRadioStandalone"
readonly GITHUB_API_BASE="https://api.github.com"
readonly DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-flisher}"
readonly DOCKERHUB_REPO="dcs-srs-server"
readonly DOCKERHUB_API_BASE="https://hub.docker.com/v2/repositories"

# Security validation function
validate_security_environment() {
    local missing_vars=""
    
    # In CI environment, validate required secrets
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        if [ -z "$PAT_REPO_DISPATCH" ]; then
            missing_vars="$missing_vars PAT_REPO_DISPATCH"
        fi
        if [ -z "$DOCKERHUB_USERNAME" ]; then
            missing_vars="$missing_vars DOCKERHUB_USERNAME"
        fi
        if [ -z "$GITHUB_REPOSITORY" ]; then
            missing_vars="$missing_vars GITHUB_REPOSITORY"
        fi
    fi
    
    if [ -n "$missing_vars" ]; then
        echo "Error: Missing required environment variables in CI:$missing_vars" >&2
        return 1
    fi
    
    return 0
}

# Function to get the latest release tag (including pre-releases)
get_latest_release_tag() {
    echo "Step 1: Fetching latest SRS release..." >&2
    
    local response
    response=$(curl --silent --show-error --fail \
        "${GITHUB_API_BASE}/repos/${SRS_REPO}/releases" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch releases from ${SRS_REPO}" >&2
        return 1
    fi
    
    local tag
    tag=$(echo "$response" | jq -r '.[0].tag_name')
    
    if [ "$tag" = "null" ] || [ -z "$tag" ]; then
        echo "Error: No valid tag found in releases" >&2
        return 1
    fi
    
    # Validate the retrieved tag format
    if ! validate_srs_tag "$tag"; then
        echo "Error: Latest SRS release tag failed validation: '$tag'" >&2
        return 1
    fi
    
    echo "✓ Latest validated SRS tag: $tag" >&2
    echo "$tag"
}

# Function to check if a Docker Hub tag exists
check_dockerhub_tag() {
    local tag_to_check="$1"
    
    if [ -z "$tag_to_check" ]; then
        echo "Error: Tag to check is required" >&2
        return 1
    fi
    
    # Silent check - no logging for individual tag checks
    local response
    response=$(curl --silent --show-error --fail \
        "${DOCKERHUB_API_BASE}/${DOCKERHUB_USERNAME}/${DOCKERHUB_REPO}/tags/${tag_to_check}/" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Tag does not exist: ${tag_to_check}" >&2
        return 1
    fi
    
    local existing_tag
    existing_tag=$(echo "$response" | jq -r '.name // empty')
    
    if [ "$existing_tag" = "$tag_to_check" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check multiple tag patterns for the latest SRS release
check_srs_tags() {
    local srs_tag="$1"
    
    if [ -z "$srs_tag" ]; then
        echo "Error: SRS tag is required for checking" >&2
        return 1
    fi
    
    # Validate the tag format first
    if ! validate_srs_tag "$srs_tag"; then
        echo "Error: Invalid SRS tag format for checking: '$srs_tag'" >&2
        return 1
    fi
    
    echo "Step 2: Checking Docker Hub for existing tags..." >&2
    
    # Check for plain TAG (primary pattern - transitioning from srs-TAG)
    if check_dockerhub_tag "$srs_tag"; then
        export TAG_EXISTS=true
    else
        export TAG_EXISTS=false
    fi
    
    # Check for ciribob-TAG pattern
    local ciribob_prefixed_tag="ciribob-${srs_tag}"
    if check_dockerhub_tag "$ciribob_prefixed_tag"; then
        export CIRIBOB_TAG_EXISTS=true
    else
        export CIRIBOB_TAG_EXISTS=false
    fi
}

# Function to trigger GitHub workflow via repository dispatch
trigger_workflow() {
    local event_type="$1"
    local srs_tag="$2"
    local tag_latest="${3:-false}"
    
    if [ -z "$event_type" ]; then
        echo "Error: Event type is required for workflow trigger" >&2
        return 1
    fi
    
    # Validate security environment before making API calls
    if ! validate_security_environment; then
        echo "Error: Security validation failed" >&2
        return 1
    fi
    
    # Check if we're in a GitHub Actions environment with required token
    if [ -z "$GITHUB_REPOSITORY" ] || [ -z "$PAT_REPO_DISPATCH" ]; then
        echo "        → [DRY RUN] Would trigger: $event_type" >&2
        return 0
    fi
    
    # Prepare payload based on event type
    local payload
    case "$event_type" in
        "ciribob-binary-to-dockerhub")
            payload="{\"event_type\":\"ciribob-binary-to-dockerhub\",\"client_payload\":{\"srs_tag\":\"$srs_tag\"}}"
            ;;
        "clean-build-to-dockerhub")
            payload="{\"event_type\":\"clean-build-to-dockerhub\",\"client_payload\":{\"srs_tag\":\"$srs_tag\",\"tag_latest\":\"$tag_latest\"}}"
            ;;
        *)
            echo "Error: Unknown event type: $event_type" >&2
            return 1
            ;;
    esac
    
    # Additional security: validate the tag in the payload matches our validation
    if ! validate_srs_tag "$srs_tag"; then
        echo "Error: Invalid SRS tag in payload: '$srs_tag'" >&2
        return 1
    fi
    
    # Trigger the workflow securely
    local response
    local http_status
    
    # Use --write-out to capture HTTP status code without exposing sensitive data
    http_status=$(curl --write-out "%{http_code}" --output /dev/null --silent \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $PAT_REPO_DISPATCH" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/dispatches" \
        -d "$payload")
    
    if [ "$http_status" -eq 204 ]; then
        echo "        → ✓ Triggered: $event_type" >&2
        return 0
    else
        echo "        → ✗ Failed: $event_type (HTTP $http_status)" >&2
        return 1
    fi
}

# Function to handle automated workflow triggering based on missing tags
handle_missing_tags() {
    local srs_tag="$1"
    
    if [ -z "$srs_tag" ]; then
        echo "Error: SRS tag is required for handling missing tags" >&2
        return 1
    fi
    
    echo "Step 3: Checking for required actions..." >&2
    
    # If ciribob-TAG doesn't exist, trigger ciribob binary workflow
    if [ "${CIRIBOB_TAG_EXISTS:-false}" = "false" ]; then
        echo "    Missing: ciribob-${srs_tag} → triggering ciribob-binary-to-dockerhub" >&2
        trigger_workflow "ciribob-binary-to-dockerhub" "$srs_tag"
    fi
    
    # If TAG doesn't exist, trigger clean build workflow
    if [ "${TAG_EXISTS:-false}" = "false" ]; then
        echo "    Missing: ${srs_tag} → triggering clean-build-to-dockerhub" >&2
        trigger_workflow "clean-build-to-dockerhub" "$srs_tag" "true"
    fi
    
    # If no actions needed
    if [ "${CIRIBOB_TAG_EXISTS:-false}" = "true" ] && [ "${TAG_EXISTS:-false}" = "true" ]; then
        echo "    All tags exist - no actions needed" >&2
    fi
}

# Main execution when script is called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Validate security environment first
    echo "Validating security environment..." >&2
    if ! validate_security_environment; then
        echo "Security validation failed - check required environment variables" >&2
        exit 1
    fi
    
    echo "Using Docker Hub username: $DOCKERHUB_USERNAME" >&2
    
    # Get the latest release tag
    if LATEST_TAG=$(get_latest_release_tag); then
        
        # Check for existing Docker Hub tags
        check_srs_tags "$LATEST_TAG"
        
        echo "" >&2
        echo "========================================" >&2
        echo "SUMMARY" >&2
        echo "========================================" >&2
        echo "SRS Release Tag: $LATEST_TAG" >&2
        echo "Docker Hub Status:" >&2
        echo "  • ${LATEST_TAG}: ${TAG_EXISTS:-false}" >&2
        echo "  • ciribob-${LATEST_TAG}: ${CIRIBOB_TAG_EXISTS:-false}" >&2
        echo "" >&2
        
        # Handle missing tags by triggering appropriate workflows
        handle_missing_tags "$LATEST_TAG"
        
        echo "" >&2
        echo "========================================" >&2
        echo "$LATEST_TAG"
    else
        echo "Failed to retrieve latest release tag" >&2
        exit 1
    fi
fi