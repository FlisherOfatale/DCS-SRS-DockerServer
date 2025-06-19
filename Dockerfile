# Use Ubuntu 24.04 LTS as the base image
FROM ubuntu/dotnet-deps:8.0

ENV DEBIAN_FRONTEND=noninteractive

# Set the working directory inside the container
# All subsequent commands will be executed from this directory
WORKDIR /app

# Copy the SRS server Linux CLI executable and startup script from the build context
# The source binary path was choosed to be future proof if the binary build become part of the same pipeline
# In order to build the container image properly, the docker build or pipeline must run in the context of the root of the repository
COPY --chown=101:101 --chmod=+x ./install-build/ServerCommandLine-Linux/SRS-Server-Commandline .

# Define the default command to run when the container starts
# The entrypoint script will handle the application startup
# Set the default command to run the server
ENTRYPOINT ["./SRS-Server-Commandline"]
