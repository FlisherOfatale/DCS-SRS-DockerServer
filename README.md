# DCS-SRS-DockerServer

DCS SRS Docker Container for the Linux CLI

---

## Objective

This project provides an **automated build system** for Docker images of the [DCS SimpleRadioStandalone (SRS) Server](https://github.com/ciribob/DCS-SimpleRadioStandalone) Linux CLI version.  
Built images are published to Docker Hub for easy deployment and updates.

## Benefits

- **Automated Build Pipeline:**  
  The `compiled-<srstag>` and `latest` tags are built automatically in the cloud using GitHub Actions, ensuring a fully automated and reproducible build process.
- **Traceability:**  
  Each Docker image can be traced directly back to the exact SRS source code commit or release tag it was built from, providing transparency and confidence in the build's origin.
- **Up-to-date Images:**  
  The automation ensures that new releases and recent commits are quickly available as Docker images for easy deployment.


## Docker Hub Repository

All images are published to:  
[https://hub.docker.com/r/flisher/dcs-srs-server](https://hub.docker.com/r/flisher/dcs-srs-server)

---

## Build Types & Tagging Convention

### 1. Based on SRS Released Binary

- **Tag format:**  
  `srs-<srstag>`
- **Example:**  
  `flisher/dcs-srs-server:srs-2.2.0.4`  
  This image is created by using the pre-compiled binary  included in the SRS release [2.2.0.4](https://github.com/ciribob/DCS-SimpleRadioStandalone/releases/tag/2.2.0.4).

### 2. Based on Latest Commit from SRS Master Branch

- **Tag format:**  
  `compiled-<date>-<shortsha>`
  `latest`
- **Example:**  
  `flisher/dcs-srs-server:compiled-20240531-abcdef1`  
  `flisher/dcs-srs-server:latest`  
  This image is built from the latest commit on the SRS master branch as of the build date.

-  **Caveats:**
  Since builds are triggered manually or a time-based schedule (not on every commit), **not all official SRS commits will have a corresponding Docker image**. Only the latest commit at each scheduled interval is built and published.

### 3. Based on SRS Release Tag (Compiled in CI)

- **Tag format:**  
  `compiled-<srstag>`
- **Example:**  
  `flisher/dcs-srs-server:compiled-2.2.0.4`  
  This image is built by compiling the SRS ServerCommandLine Linux binary **in the cloud as part of the workflow**, using the source code from the associated SRS release tag.

---

## Usage

### Pulling a version using a binary compiled from the latest source

```sh
docker pull flisher/dcs-srs-server:latest
```

### Pulling a Released version using a binary compiled from the source linked to that release

```sh
docker pull flisher/dcs-srs-server:compiled-2.2.0.4
```

### Pulling a Released version using the official binary

```sh
docker pull flisher/dcs-srs-server:srs-2.2.0.4
```
These should ideally be launhed from as a docker compose.  
This project isn't intented to provide all instruction, but simply provide Docker Images to suit various tastes.

## TODO
Nightly build that will rebuild an image with latest OS, but existing source
* nightly :latest will likely be published to :latest
* nightly :srs- and :compiled- based on the latest official release would likely be published to :srs-<tag>-latest and compiled-<tag>-latest

## Contact Information
I'm Flisher Ofatale on Discord.  
You can reach me on the official SRS Discord server: [https://discord.gg/Hb7rYey](https://discord.gg/Hb7rYey)

## Disclaimer
This project is **not an official project** of Ciribob, nor is it affiliated with or endorsed by him.

It is a personal effort to support DCS SRS ecosystem by providing automated and traceable Docker images for the Linux CLI version of the SRS server.

This project might be temporary and may cease to exist if an official image is provided as part an tracable pipeline.

---

## BREAKING CHANGE RON 2025-06-19
* The Docker image base was migrated from `ubuntu:24.04` to `ubuntu/dotnet-deps:8.0` to provide a lighter, .NET-ready environment for the SRS server. This change improves build speed and reduces image size, while ensuring compatibility with the .NET 8 runtime required by the latest SRS Linux CLI binaries.
* The work directory changed from /opt/srs to /app toi follow common practice, you may have to change the way you initiate the container to reflect this path change.

---