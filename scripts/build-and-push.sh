#!/bin/bash
# Script to build and push Docker images for DCS SRS Server
# Handles both tagged releases and latest commits
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
readonly DOCKERFILE_DEFAULT="Dockerfile"
readonly CONTEXT_DEFAULT="."
readonly DOCKERHUB_USERNAME_DEFAULT="flisher"

# Security validation function
validate_build_environment() {
    local missing_vars=""
    
    # Use default username if not provided
    if [ -z "$DOCKERHUB_USERNAME" ]; then
        export DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME_DEFAULT"
        echo "Using default Docker Hub username: $DOCKERHUB_USERNAME" >&2
    fi
    
    # In CI environment, check for Docker Hub token (only if push is enabled)
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        if [ -z "$DOCKERHUB_TOKEN" ] && [ "$PUSH_ENABLED" = "true" ]; then
            missing_vars="$missing_vars DOCKERHUB_TOKEN"
        fi
    fi
    
    if [ -n "$missing_vars" ]; then
        echo "Error: Missing required environment variables for CI push:$missing_vars" >&2
        return 1
    fi
    
    return 0
}

# Function to checkout SRS repository
checkout_srs_repo() {
    local srs_tag="$1"
    local target_dir="external-repo"
    
    echo "Step 1: Checking out SRS repository..." >&2
    
    # Remove existing directory if it exists
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    
    # Clone the repository
    if [ -n "$srs_tag" ]; then
        echo "    Checking out tag: $srs_tag" >&2
        git clone --depth 1 --branch "$srs_tag" "https://github.com/${SRS_REPO}.git" "$target_dir"
    else
        echo "    Checking out latest master commit" >&2
        git clone --depth 1 "https://github.com/${SRS_REPO}.git" "$target_dir"
    fi
    
    # Get the actual commit SHA
    local commit_sha
    commit_sha=$(git -C "$target_dir" rev-parse --short HEAD)
    export SRS_COMMIT_SHA="$commit_sha"
    
    echo "    Commit SHA: $commit_sha" >&2
}

# Function to generate Docker tags based on build type
generate_docker_tags() {
    local srs_tag="$1"
    local tag_latest="${2:-false}"
    local username="$3"
    
    if [ -z "$username" ]; then
        echo "Error: Docker Hub username is required" >&2
        return 1
    fi
    
    echo "Step 2: Generating Docker tags..." >&2
    
    local tags=""
    
    if [ -n "$srs_tag" ]; then
        # Building from a specific tag - use the tag name directly (new pattern)
        tags="${username}/dcs-srs-server:${srs_tag}"
        echo "    Primary tag: ${srs_tag}" >&2
    else
        # Building from master - use date-commit pattern
        local date_tag
        date_tag=$(date +%Y%m%d)
        tags="${username}/dcs-srs-server:${date_tag}-${SRS_COMMIT_SHA}"
        echo "    Primary tag: ${date_tag}-${SRS_COMMIT_SHA}" >&2
    fi
    
    # Add latest tag if requested
    if [ "$tag_latest" = "true" ]; then
        tags="$tags,${username}/dcs-srs-server:latest"
        echo "    Also tagging as: latest" >&2
    fi
    
    export DOCKER_TAGS="$tags"
    echo "$tags"
}

# Function to build and push Docker image
build_and_push() {
    local dockerfile="${1:-$DOCKERFILE_DEFAULT}"
    local context="${2:-$CONTEXT_DEFAULT}"
    local push_enabled="${3:-false}"
    
    if [ -z "$DOCKER_TAGS" ]; then
        echo "Error: DOCKER_TAGS environment variable not set" >&2
        return 1
    fi
    
    echo "Step 3: Building Docker image..." >&2
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
    TAG_LATEST="false"
    PUSH_ENABLED="false"
    
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
                echo "                If not provided, builds from latest master commit"
                echo ""
                echo "Options:"
                echo "  --publish     Push images to Docker Hub (default: build only)"
                echo "  --latest      Also tag as 'latest' (default: false)"
                echo "  --help, -h    Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                          # Build latest commit, no push"
                echo "  $0 2.3.2.2                 # Build specific tag, no push"
                echo "  $0 2.3.2.2 --publish       # Build and push specific tag"
                echo "  $0 --publish --latest       # Build latest commit, push with latest tag"
                echo "  $0 2.3.2.2 --publish --latest  # Build specific tag, push with latest tag"
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
    echo "DCS SRS DOCKER BUILD" >&2
    echo "========================================" >&2
    echo "SRS Tag: ${SRS_TAG:-"(latest commit)"}" >&2
    echo "Tag as latest: $TAG_LATEST" >&2
    echo "Push enabled: $PUSH_ENABLED" >&2
    echo "" >&2
    
    # Validate environment
    if ! validate_build_environment; then
        echo "Environment validation failed" >&2
        exit 1
    fi
    
    # Checkout SRS repository
    if ! checkout_srs_repo "$SRS_TAG"; then
        echo "Failed to checkout SRS repository" >&2
        exit 1
    fi
    
    # Generate Docker tags
    if ! generate_docker_tags "$SRS_TAG" "$TAG_LATEST" "$DOCKERHUB_USERNAME"; then
        echo "Failed to generate Docker tags" >&2
        exit 1
    fi
    
    # Build and push
    if ! build_and_push "$DOCKERFILE_DEFAULT" "$CONTEXT_DEFAULT" "$PUSH_ENABLED"; then
        echo "Build and push failed" >&2
        exit 1
    fi
    
    echo "" >&2
    echo "========================================" >&2
    echo "BUILD COMPLETED SUCCESSFULLY" >&2
    echo "Tags created: $DOCKER_TAGS" >&2
    echo "========================================" >&2
fi