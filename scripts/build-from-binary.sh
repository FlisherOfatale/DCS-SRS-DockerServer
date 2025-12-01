#!/bin/bash
# Script to build Docker images from ciribob's precompiled SRS binaries
# Downloads the binary from GitHub releases and packages it into a Docker image
set -e

# Get script directory for sourcing validation functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source tag validation functions
if ! source "$SCRIPT_DIR/validate-tag.sh"; then
    echo "Error: Failed to load tag validation functions" >&2
    exit 1
fi

# Configuration
readonly SRS_REPO="ciribob/DCS-SimpleRadioStandalone"
readonly GITHUB_API_BASE="https://api.github.com"
readonly DOCKERFILE_DEFAULT="Dockerfile-dotNet8"
readonly CONTEXT_DEFAULT="."
readonly DOCKERHUB_USERNAME_DEFAULT="flisher"
readonly OUTPUT_DIR="install-build/ServerCommandLine-Linux"

# Security validation function
validate_binary_build_environment() {
    # Use default username if not provided
    if [ -z "$DOCKERHUB_USERNAME" ]; then
        export DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME_DEFAULT"
        echo "Using default Docker Hub username: $DOCKERHUB_USERNAME" >&2
    fi
    
    # In CI environment, check for Docker Hub token (only if push is enabled)
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        if [ -z "$DOCKERHUB_TOKEN" ] && [ "$PUSH_ENABLED" = "true" ]; then
            echo "Error: DOCKERHUB_TOKEN required for CI push" >&2
            return 1
        fi
    fi
    
    return 0
}

# Function to get the latest SRS release tag
get_latest_srs_release() {
    echo "Step 1: Getting latest SRS release tag..." >&2
    
    local response
    response=$(curl --silent --show-error --fail \
        "https://api.github.com/repos/ciribob/DCS-SimpleRadioStandalone/releases" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch releases from ciribob/DCS-SimpleRadioStandalone" >&2
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
    
    echo "    Latest release: $tag" >&2
    echo "$tag"
}

# Function to download SRS binary from GitHub releases
download_srs_binary() {
    local srs_tag="$1"
    
    if [ -z "$srs_tag" ]; then
        echo "Error: SRS tag is required for binary download" >&2
        return 1
    fi
    
    # Validate tag format first
    if ! validate_srs_tag "$srs_tag"; then
        return 1
    fi
    
    echo "Step 2: Downloading SRS binary..." >&2
    echo "    Tag: $srs_tag" >&2
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Download binary
    local url="https://github.com/${SRS_REPO}/releases/download/${srs_tag}/SRS-Server-Commandline-Linux"
    echo "    URL: $url" >&2
    
    local temp_file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    
    if ! curl --silent --show-error --fail --location "$url" -o "$temp_file"; then
        echo "Error: Failed to download SRS binary from tag: $srs_tag" >&2
        return 1
    fi
    
    # Verify download
    if [ ! -s "$temp_file" ]; then
        echo "Error: Downloaded file is empty" >&2
        return 1
    fi
    
    # Move to final location and set permissions
    mv "$temp_file" "$OUTPUT_DIR/SRS-Server-Commandline-Linux"
    chmod +x "$OUTPUT_DIR/SRS-Server-Commandline-Linux"
    
    local file_size
    file_size=$(stat -c%s "$OUTPUT_DIR/SRS-Server-Commandline-Linux" 2>/dev/null || stat -f%z "$OUTPUT_DIR/SRS-Server-Commandline-Linux" 2>/dev/null || echo "unknown")
    echo "    ✓ Downloaded binary ($file_size bytes)" >&2
}

# Function to generate Docker tags for binary builds
generate_binary_tags() {
    local srs_tag="$1"
    local username="$2"
    local tag_latest="${3:-false}"
    
    if [ -z "$srs_tag" ] || [ -z "$username" ]; then
        echo "Error: SRS tag and username are required" >&2
        return 1
    fi
    
    echo "Step 3: Generating Docker tags..." >&2
    
    # Use ciribob- prefix for binary builds to distinguish from compiled builds
    local tags="${username}/dcs-srs-server:ciribob-${srs_tag}"
    echo "    Primary tag: ciribob-${srs_tag}" >&2
    
    # Add ciribob-latest tag if requested
    if [ "$tag_latest" = "true" ]; then
        tags="$tags,${username}/dcs-srs-server:ciribob-latest"
        echo "    Also tagging as: ciribob-latest" >&2
    fi
    
    export DOCKER_TAGS="$tags"
    echo "$tags"
}

# Function to build and push Docker image
build_and_push_binary() {
    local dockerfile="${1:-$DOCKERFILE_DEFAULT}"
    local context="${2:-$CONTEXT_DEFAULT}"
    local push_enabled="${3:-false}"
    
    if [ -z "$DOCKER_TAGS" ]; then
        echo "Error: DOCKER_TAGS environment variable not set" >&2
        return 1
    fi
    
    echo "Step 4: Building Docker image..." >&2
    echo "    Dockerfile: $dockerfile" >&2
    echo "    Context: $context" >&2
    echo "    Tags: $DOCKER_TAGS" >&2
    echo "    Push enabled: $push_enabled" >&2
    
    # Convert comma-separated tags to individual -t arguments
    local tag_args=""
    IFS=',' read -ra TAG_ARRAY <<< "$DOCKER_TAGS"
    for tag in "${TAG_ARRAY[@]}"; do
        tag=$(echo "$tag" | xargs)  # Trim whitespace
        tag_args="$tag_args -t $tag"
    done
    
    # Build the image
    echo "    Building image..." >&2
    if ! docker build $tag_args -f "$dockerfile" "$context"; then
        echo "Error: Docker build failed" >&2
        return 1
    fi
    
    echo "    ✓ Build completed successfully" >&2
    
    # Push if enabled
    if [ "$push_enabled" = "true" ]; then
        echo "    Pushing to Docker Hub..." >&2
        local push_success=0
        local push_total=0
        
        for tag in "${TAG_ARRAY[@]}"; do
            tag=$(echo "$tag" | xargs)  # Trim whitespace
            ((push_total++))
            echo "      Pushing: $tag" >&2
            
            if docker push "$tag"; then
                echo "      ✓ Pushed: $tag" >&2
                ((push_success++))
            else
                echo "      ✗ Failed: $tag" >&2
            fi
        done
        
        if [ $push_success -eq $push_total ]; then
            echo "    ✓ All images pushed successfully" >&2
        else
            echo "    ✗ Some pushes failed ($push_success/$push_total)" >&2
            return 1
        fi
    else
        echo "    Push disabled - build only" >&2
    fi
}

# Main execution when script is called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Parse command line arguments
    SRS_TAG=""
    PUSH_ENABLED="false"
    TAG_LATEST="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --publish)
                PUSH_ENABLED="true"
                shift
                ;;
            --latest)
                TAG_LATEST="true"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [TAG] [--publish] [--latest]"
                echo ""
                echo "Arguments:"
                echo "  TAG           Optional SRS release tag (e.g., 2.3.2.2)"
                echo "                If not provided, uses latest SRS release"
                echo ""
                echo "Options:"
                echo "  --publish     Push images to Docker Hub (default: build only)"
                echo "  --latest      Also tag as 'ciribob-latest' (default: false)"
                echo "  --help, -h    Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                          # Build latest release, no push"
                echo "  $0 2.3.2.2                 # Build specific release, no push"
                echo "  $0 2.3.2.2 --publish       # Build and push specific release"
                echo "  $0 --publish --latest       # Build and push latest release with ciribob-latest tag"
                echo "  $0 2.3.2.2 --publish --latest  # Build specific release, push with ciribob-latest tag"
                echo ""
                echo "Note: This script downloads precompiled binaries from ciribob's"
                echo "      GitHub releases and packages them into Docker images."
                echo "      Tags are created with 'ciribob-' prefix (e.g., ciribob-2.3.2.2, ciribob-latest)"
                exit 0
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
            *)
                if [ -z "$SRS_TAG" ]; then
                    # Validate the tag format
                    if ! validate_srs_tag "$1"; then
                        exit 1
                    fi
                    SRS_TAG="$1"
                else
                    echo "Error: Multiple tags provided. Only one tag is allowed." >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    echo "========================================" >&2
    echo "DCS SRS BINARY BUILD" >&2
    echo "========================================" >&2
    echo "SRS Tag: ${SRS_TAG:-"(latest release)"}" >&2
    echo "Tag as ciribob-latest: $TAG_LATEST" >&2
    echo "Push enabled: $PUSH_ENABLED" >&2
    echo "" >&2
    
    # Validate environment
    if ! validate_binary_build_environment; then
        echo "Environment validation failed" >&2
        exit 1
    fi
    
    # Get SRS tag if not provided
    if [ -z "$SRS_TAG" ]; then
        if ! SRS_TAG=$(get_latest_srs_release); then
            echo "Failed to get latest SRS release" >&2
            exit 1
        fi
    fi
    
    # Download SRS binary
    if ! download_srs_binary "$SRS_TAG"; then
        echo "Failed to download SRS binary" >&2
        exit 1
    fi
    
    # Generate Docker tags
    if ! generate_binary_tags "$SRS_TAG" "$DOCKERHUB_USERNAME" "$TAG_LATEST"; then
        echo "Failed to generate Docker tags" >&2
        exit 1
    fi
    
    # Build and push
    if ! build_and_push_binary "$DOCKERFILE_DEFAULT" "$CONTEXT_DEFAULT" "$PUSH_ENABLED"; then
        echo "Build and push failed" >&2
        exit 1
    fi
    
    echo "" >&2
    echo "========================================" >&2
    echo "BINARY BUILD COMPLETED SUCCESSFULLY" >&2
    echo "Tags created: $DOCKER_TAGS" >&2
    echo "========================================" >&2
fi