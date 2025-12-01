# Use Microsoft's official .NET 9 SDK image
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src

# Copy source code
COPY external-repo/ ./

# Set build parameters and build the application
RUN OUTPUT_PATH="./install-build" && \
    rm -rf "$OUTPUT_PATH/ServerCommandLine-Linux" && \
    echo "Building Server CLI binary for Linux..." && \
    ls -altr "./ServerCommandLine/ServerCommandLine.csproj" && \
    echo "----" && \
    dotnet restore "./ServerCommandLine/ServerCommandLine.csproj" && \
    dotnet publish "./ServerCommandLine/ServerCommandLine.csproj" \
        --runtime linux-x64 \
        --output "$OUTPUT_PATH/ServerCommandLine-Linux" \
        --self-contained true \
        --configuration Release \
        /p:PublishReadyToRun=true \
        /p:PublishSingleFile=true \
        /p:DebugType=None \
        /p:DebugSymbols=false \
        /p:IncludeSourceRevisionInInformationalVersion=false && \
    find "$OUTPUT_PATH/ServerCommandLine-Linux" -name "*.dll" -type f -delete 2>/dev/null || true

FROM ubuntu/dotnet-deps:9.0 AS runtime
WORKDIR /app


COPY --from=build /src/./install-build/ServerCommandLine-Linux/SRS-Server-Commandline ./SRS-Server-Commandline-Linux

ENTRYPOINT [ "./SRS-Server-Commandline-linux" ]