#!/bin/bash

# This script builds ServerCommandLine binary for Linux
# This script assume the external repository is already cloned into the `external-repos` directory.
# This script is intended to be run in a GitHub Actions workflow, but can also be tested locally using the `test-local-build.sh` script.
#
set -e

outputPath="./install-build"
externalRepoPath="./external-repos"

# Server Command Line - Linux
echo "Publishing ServerCommandLine for Linux..."

rm -rf "$outputPath/ServerCommandLine-Linux"
dotnet clean "./$externalRepoPath/ServerCommandLine/ServerCommandLine.csproj"
dotnet publish "./$externalRepoPath/ServerCommandLine/ServerCommandLine.csproj" \
    --framework net8.0 \
    --runtime linux-x64 \
    --output "$outputPath/ServerCommandLine-Linux" \
    --self-contained true \
    --configuration Release \
    /p:PublishReadyToRun=true \
    /p:PublishSingleFile=true \
    /p:DebugType=None \
    /p:DebugSymbols=false \
    /p:IncludeSourceRevisionInInformationalVersion=false \
    /p:SourceLinkCreate=false

find "$outputPath/ServerCommandLine-Linux" -name '*.dll' -delete