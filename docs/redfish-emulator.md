# Redfish Emulator

This directory contains a Docker setup for running a Redfish emulator for integration testing.

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start the emulator
docker-compose -f docker-compose.emulator.yml up -d

# Check status
docker-compose -f docker-compose.emulator.yml ps

# View logs
docker-compose -f docker-compose.emulator.yml logs -f

# Stop the emulator
docker-compose -f docker-compose.emulator.yml down
```

### Using Docker CLI

```bash
# Build the image
docker build -t redfish-emulator:latest -f Dockerfile.emulator .

# Run the container
docker run -d \
  --name redfish-emulator \
  -p 9000:9000 \
  redfish-emulator:latest

# Check logs
docker logs -f redfish-emulator

# Stop the container
docker stop redfish-emulator
docker rm redfish-emulator
```

## Running Integration Tests

Once the emulator is running, you can execute integration tests:

```powershell
# Run all integration tests
Invoke-Build IntegrationTests

# Or run manually
Invoke-Pester -Path tests/Integration/ -Output Detailed
```

## Emulator Details

- **Base Image**: `python:3.11-slim`
- **Mockup Server**: DMTF Redfish-Mockup-Server
- **Sample Data**: DMTF public-rackmount1 mockup
- **Default Port**: 9000
- **Credentials**: Administrator / Password (mockup server defaults)

## Access Points

Once running, the emulator is accessible at:

- **Service Root**: http://localhost:9000/redfish/v1
- **Systems**: http://localhost:9000/redfish/v1/Systems
- **Chassis**: http://localhost:9000/redfish/v1/Chassis
- **Managers**: http://localhost:9000/redfish/v1/Managers

## Environment Variables

You can customize the emulator behavior with environment variables:

```bash
docker run -d \
  --name redfish-emulator \
  -p 9000:9000 \
  -e PORT=9000 \
  -e MOCKUP_DIR=/app/mockup/public-rackmount1 \
  redfish-emulator:latest
```

## Using Custom Mockup Data

To use your own mockup data:

```bash
docker run -d \
  --name redfish-emulator \
  -p 9000:9000 \
  -v /path/to/your/mockup:/app/mockup/custom \
  -e MOCKUP_DIR=/app/mockup/custom \
  redfish-emulator:latest
```

## Troubleshooting

### Emulator not responding

Check if the container is running:

```bash
docker ps
docker logs redfish-emulator
```

### Port already in use

Change the host port mapping:

```bash
docker run -d \
  --name redfish-emulator \
  -p 8080:9000 \
  redfish-emulator:latest
```

Then update your tests to use `http://localhost:8080`

### Health check failing

The health check verifies the emulator is responding. If it fails:

```bash
# Check the container logs
docker logs redfish-emulator

# Manually test the endpoint
curl http://localhost:9000/redfish/v1
```

## CI/CD Integration

For GitHub Actions or other CI/CD systems, see the workflow configuration in `.github/workflows/`.

The emulator can be started as a service:

```yaml
services:
  redfish-emulator:
    image: ghcr.io/your-org/redfish-emulator:latest
    ports:
      - 5000:9000
    options: >-
      --health-cmd "curl -f http://localhost:9000/redfish/v1 || exit 1"
      --health-interval 10s
      --health-timeout 5s
      --health-retries 3
```

## References

- [DMTF Redfish-Mockup-Server](https://github.com/DMTF/Redfish-Mockup-Server)
- [DMTF Redfish Schema](https://www.dmtf.org/standards/redfish)
- [Redfish API Documentation](https://redfish.dmtf.org/)
