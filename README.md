# DCS-SRS-DockerServer

DCS SRS Docker Container for the Linux CLI

---

## Objective

This project provides an **automated build system** for Docker images of the [DCS SimpleRadioStandalone (SRS) Server](https://github.com/ciribob/DCS-SimpleRadioStandalone) Linux CLI version.  

Built images are published to Docker Hub for easy deployment and updates.
These images can be found on [https://hub.docker.com/r/flisher/dcs-srs-server](https://hub.docker.com/r/flisher/dcs-srs-server)

## Benefits

- **Automated Build Pipeline:**  
  The `flisher/dcs-srs-server:latest` version is the recommended one. 
  It's built automatically in the cloud using GitHub Actions every night, ensuring a fully automated and reproducible build process.

- **Traceability:**  
  Each Docker image can be traced directly back to the exact SRS source code commit or release tag it was built from, providing transparency and confidence in the build's origin.

## Docker Hub Repository

All images are published to:  
[https://hub.docker.com/r/flisher/dcs-srs-server](https://hub.docker.com/r/flisher/dcs-srs-server)

---

## Build Types & Tagging Convention

### 1. Recommended - CI / CD built version 
- **Tag format:**  
- `latest` is the latest ci/cd built version based on the latest release tag
- `n.n.n.n` is the pinned version using the ci/cd built version from that release tag

### 2. Alternate version - Using released binary
- `ciribob-latest-` 
- `ciribob-<n.n.n.n>` 
---

## Usage

### Pulling a version using a binary compiled from the latest source

```sh
docker pull flisher/dcs-srs-server:latest
```

These should ideally be launhed from as a docker compose.  
This project isn't intented to provide all instruction, but simply provide Docker Images to suit various tastes.

## Contact Information
I'm Flisher Ofatale on Discord.  
You can reach me on the official SRS Discord server: [https://discord.gg/Hb7rYey](https://discord.gg/Hb7rYey)

## Disclaimer
This project is **not an official project** of Ciribob, nor is it affiliated with or officially endorsed by him.

It is a personal effort to support DCS SRS ecosystem by providing automated and traceable Docker images for the Linux CLI version of the SRS server.

This project might be temporary and may cease to exist if an official image is provided as part an tracable pipeline.
This project is intended to support recent image and cleanup of very old pinned version might happen on DockerHub is space ever become a constraint.

---

## MAJOR CHANGE ON 2025-10-31
* New tagging structure to comprehensive image tags.

## BREAKING CHANGE ON 2025-06-19
* The Docker image base was migrated from `ubuntu:24.04` to `ubuntu/dotnet-deps:8.0` to provide a lighter, .NET-ready environment for the SRS server. This change improves build speed and reduces image size, while ensuring compatibility with the .NET 8 runtime required by the latest SRS Linux CLI binaries.
* The work directory changed from /opt/srs to /app toi follow common practice, you may have to change the way you initiate the container to reflect this path change.

---