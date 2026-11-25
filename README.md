# Mattermost Docker AMD64

Docker Compose setup for Mattermost Team Edition 12.1.0 on 64-bit Intel and AMD systems (`linux/amd64`). Based on [jonaaix/mattermost-docker-arm](https://github.com/jonaaix/mattermost-docker-arm).

## Getting Started

1. Copy the example files.
   ```bash
   cp .env.example .env
   cp compose.example.yaml compose.yaml
   ```

2. Set the database password, pgAdmin credentials, and Mattermost domain in `.env`. Point the domain at a Caddy Docker Proxy connected to the external `main-proxy` network.

3. Build and start the services.
   ```bash
   docker compose up -d --build
   ```

4. Open `https://<MM_DOMAIN>` in your browser.

## Update
Set `MM_PACKAGE` in the Dockerfile to the desired Linux AMD64 Team Edition download from the [Mattermost version archive](https://docs.mattermost.com/product-overview/version-archive). Review the [Mattermost upgrade notes](https://docs.mattermost.com/administration-guide/upgrade/important-upgrade-notes) before updating an existing deployment.

Rebuild and restart the containers.
```bash
docker compose up -d --build
```

## Backup Configuration
To enable backups to S3-compatible storage, configure the variables in your `.env` file.
Then add a cron job to your host system:
```bash
crontab -e

30 3 * * * /var/www/mattermost-docker-amd64/backup-s3.sh >> /var/www/mattermost-docker-amd64/mm_backup.log 2>&1
```

---

For advanced configurations or production setup, refer to the [official Mattermost documentation](https://docs.mattermost.com/).
