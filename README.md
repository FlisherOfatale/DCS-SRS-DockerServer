# DCS SimpleRadio Standalone (SRS) Docker Server

[![Docker Pulls](https://img.shields.io/docker/pulls/flisher/dcs-srs-server)](https://hub.docker.com/r/flisher/dcs-srs-server)
[![Docker Image Size](https://img.shields.io/docker/image-size/flisher/dcs-srs-server/latest)](https://hub.docker.com/r/flisher/dcs-srs-server)
[![GitHub](https://img.shields.io/github/license/FlisherOfatale/DCS-SRS-DockerServer)](https://github.com/FlisherOfatale/DCS-SRS-DockerServer/blob/main/LICENSE)

A containerized version of the **DCS SimpleRadio Standalone (SRS) Server** for easy deployment and management. This Docker image provides a lightweight, secure way to run SRS servers for DCS World multiplayer missions.

## Quick Start

```bash
# Run SRS server with default settings
docker run -d -p 5002:5002/udp --name srs-server flisher/dcs-srs-server:latest

# Run with custom frequency and coalition passwords
docker run -d -p 5002:5002/udp \
  -e FREQ=251.0 \
  -e COALITION_PASSWORD_BLUE=blue123 \
  -e COALITION_PASSWORD_RED=red456 \
  --name srs-server \
  flisher/dcs-srs-server:latest
```

## Available Tags

### Release Tags
- **`latest`** - Latest stable release (built from source)
- **`X.X.X.X`** - Specific SRS version (e.g., `2.3.2.2`)

### Ciribob Binary Tags  
- **`ciribob-latest`** - Latest ciribob precompiled binary
- **`ciribob-X.X.X.X`** - Specific version using ciribob's precompiled binaries

**Tag Selection Guide:**
- Use `latest` or `X.X.X.X` for production (compiled from source, most reliable)
- Use `ciribob-latest` or `ciribob-X.X.X.X` for quick deployment (precompiled binaries)

## Image Variants

### Source-Built Images (`latest`, `X.X.X.X`)
- Built from the official SRS source code
- Full compilation in Docker environment

### Binary Images (`ciribob-latest`, `ciribob-X.X.X.X`)  
- Uses precompiled binaries from ciribob's releases from his computer

### Custom Configuration
```bash
# Mount custom server configuration
docker run -d -p 5002:5002/udp \
  -v /path/to/config:/app/config \
  flisher/dcs-srs-server:latest
```

### Docker Compose Example
```yml
services:
  srs:
    restart: unless-stopped  # Add this line for auto-restart
    image: flisher/dcs-srs-server:latest
    ports:
      - "5002:5002/udp"
      - "5002:5002/tcp"
    command: ["./SRS-Server-Commandline-Linux", "--enableEAM=true", "--coalitionSecurity=true", "--eamBluePassword=BLUE", "--eamRedPassword=RED", "--consoleLogs", "--showTransmitterName=true"]
```

## Related Links

- **GitHub Repository**: [FlisherOfatale/DCS-SRS-DockerServer](https://github.com/FlisherOfatale/DCS-SRS-DockerServer)
- **Original SRS Project**: [ciribob/DCS-SimpleRadioStandalone](https://github.com/ciribob/DCS-SimpleRadioStandalone)
- **DCS World**: [Digital Combat Simulator](https://www.digitalcombatsimulator.com/)
- **Docker Hub**: [flisher/dcs-srs-server](https://hub.docker.com/r/flisher/dcs-srs-server)

## Security Features

- **Minimal attack surface** (Ubuntu-based, essential packages only)
- **Non-root execution** (runs as unprivileged user)
- **No shell access** (security-focused container design)

## License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/FlisherOfatale/DCS-SRS-DockerServer/blob/main/LICENSE) file for details.

---

## Need Help?

- **GitHub Issues**: [Report problems or ask questions](https://github.com/FlisherOfatale/DCS-SRS-DockerServer/issues)
- **Documentation**: [Full setup guide and examples](https://github.com/FlisherOfatale/DCS-SRS-DockerServer)
- **SRS Documentation**: [Official SRS guides](https://github.com/ciribob/DCS-SimpleRadioStandalone/wiki)
- **Discord**: Flisher Ofatale on the [SRS Discord server](https://discord.gg/Hb7rYey)

## Disclaimer

This project is **not an official project** of Ciribob, nor is it affiliated with or officially endorsed by him. It is a personal effort to support the DCS SRS ecosystem by providing automated and traceable Docker images for the Linux CLI version of the SRS server.

---

## Recent Changes

### BREAKIN CHANGE ON 2025-12-01
- **Renamed Executable** from `SRS-Server-Commandline` to `SRS-Server-Commandline-Linux` to match new official Ciribob name


### MAJOR CHANGE ON 2025-10-31
- **New comprehensive tagging structure** with clear variant separation
- **Enhanced security** with ultra-strict tag validation
- **Improved automation** with daily checks and auto-builds
- **Consistent tagging** across source-built and binary variants

### BREAKING CHANGE ON 2025-06-19
- **Base image migration** from `ubuntu:24.04` to `ubuntu/dotnet-deps:8.0`
- **Improved performance** with lighter, .NET-ready environment
- **Working directory change** from `/opt/srs` to `/app` (follows best practices)
- **Faster builds** and reduced image size

*This Docker image is an unofficial containerization of DCS SimpleRadio Standalone. SRS is developed and maintained by [ciribob](https://github.com/ciribob).*