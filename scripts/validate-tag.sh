#!/bin/bash
# Simple SRS tag format validation
# Only checks if tag matches X.X.X.X format where X is a single digit

# Function to validate SRS tag format
validate_srs_tag() {
    local tag="$1"
    
    # Allow empty tags
    if [ -z "$tag" ]; then
        return 0
    fi
    
    # Only accept format X.X.X.X where X is a single digit (0-9)
    if [[ "$tag" =~ ^[0-9]\.[0-9]\.[0-9]\.[0-9]$ ]]; then
        return 0
    else
        echo "ERROR: Invalid tag format. Expected: X.X.X.X (single digits only)" >&2
        echo "Received: '$tag'" >&2
        return 1
    fi
}