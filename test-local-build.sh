#!/bin/bash
# This script is intended to be run in a local environment to test the build.sh script.
# It clones the ciribob/DCS-SimpleRadioStandalone repository, builds the ServerCommandLine binary for Linux,
# and builds the Docker container for dcs-srs-server.

set -e

# Clone the external repo (shallow clone)
echo "Cloning ciribob/DCS-SimpleRadioStandalone into ./external-repos..."
rm -rf ./external-repos
git clone --depth 1 https://github.com/ciribob/DCS-SimpleRadioStandalone.git ./external-repos

# Build the Linux server binary
echo "Building Server CLI binary for Linux..."
chmod +x ./build.sh
./build.sh

# Build the Docker container
# You can now test a local container build using the following command:
# It's not included in this file as I test local build withing WSL and build docker image outside of it
# docker build -t dcs-srs-server -f Dockerfile .
