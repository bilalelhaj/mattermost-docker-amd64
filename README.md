# Mattermost Docker AMD64

Docker Compose setup for Mattermost Team Edition 12.1.0 on 64-bit Intel and AMD systems (`linux/amd64`). Based on [jonaaix/mattermost-docker-arm](https://github.com/jonaaix/mattermost-docker-arm).

## Getting Started

1. Copy the example files.
   ```bash
   cp .env.example .env
   cp compose.example.yaml compose.yaml
   ```

2. Set the database password, pgAdmin credentials, and Mattermost domain in `.env`. Point the domain at a Caddy Docker Proxy connected to the external `main-proxy` network.

3. Start the services.
   ```bash
   docker compose up -d
   ```

4. Open `https://<MM_DOMAIN>` in your browser.

## Update
Set the `mattermost/mattermost-team-edition` image tag in `compose.yaml` to the desired version from [Docker Hub](https://hub.docker.com/r/mattermost/mattermost-team-edition/tags). Review the [Mattermost upgrade notes](https://docs.mattermost.com/administration-guide/upgrade/important-upgrade-notes) before updating an existing deployment.

Pull the updated image and restart Mattermost.
```bash
docker compose pull mm
docker compose up -d mm
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
