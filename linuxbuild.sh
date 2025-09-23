#!/bin/bash

OUTPUT_PATH=${1:-"./install-build"}

COMMON_PARAMS=(
    "--configuration" "Release"
    "/p:PublishReadyToRun=true"
    "/p:PublishSingleFile=true"
    "/p:DebugType=None"
    "/p:DebugSymbols=false"
    "/p:IncludeSourceRevisionInInformationalVersion=false"
)


rm -rf "$OUTPUT_PATH/ServerCommandLine-Linux"

echo "Building Server CLI binary for Linux..."
ls -altr "./ServerCommandLine/ServerCommandLine.csproj"
echo "----"


#dotnet clean "./ServerCommandLine/ServerCommandLine.csproj"

dotnet restore "./ServerCommandLine/ServerCommandLine.csproj"

dotnet publish "./ServerCommandLine/ServerCommandLine.csproj" \
    --runtime linux-x64 \
    --output "$OUTPUT_PATH/ServerCommandLine-Linux" \
    --self-contained true \
    "${COMMON_PARAMS[@]}"
find "$OUTPUT_PATH/ServerCommandLine-Linux" -name "*.dll" -type f -delete 2>/dev/null || true