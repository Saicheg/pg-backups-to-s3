# PostgreSQL Backup to S3

A Docker container that automatically backs up PostgreSQL databases and uploads them to Amazon S3.

## Disclaimer

This project was inspired by and builds upon the excellent work of [Musab520](https://github.com/Musab520) and their [pgbackup-sidecar](https://github.com/Musab520/pgbackup-sidecar) project. We extend our gratitude for the original implementation that served as the foundation for this enhanced version.

## Features

- Automated PostgreSQL database backups using `pg_dump`
- Upload backups to Amazon S3
- **Encryption support** with GPG or OpenSSL
- **Additional compression** options (gzip, bzip2, xz) beyond pg_dump's built-in compression
- Configurable backup schedule via cron
- Webhook notifications for backup status
- Robust error handling and logging

## Environment Variables

### Database Configuration (Required)
- `POSTGRES_HOST` - PostgreSQL server hostname
- `POSTGRES_PORT` - PostgreSQL server port (default: 5432)
- `POSTGRES_DB` - Database name to backup
- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password

### Backup Configuration (Required)
- `TITLE` - Title for webhook notifications
- `CRON_TIME` - Cron schedule for backups (e.g., "0 2 * * *" for daily at 2 AM)

### Encryption Configuration (Optional)
- `ENCRYPTION_KEY` - Encryption passphrase/key (if not set, backups will not be encrypted)
- `ENCRYPTION_METHOD` - Encryption method: `gpg` (default) or `openssl`

### Compression Configuration (Optional)
- `COMPRESSION_TYPE` - Additional compression: `none` (default), `gzip`, `bzip2`, or `xz`

**Note**: PostgreSQL's `--format=custom` already includes compression. Additional compression is applied on top of this for extra space savings, but may increase backup time.

### Cleanup Configuration (Optional)
- `CLEANUP_ENABLED` - Control whether to clean up local backup files after processing: `true` (default) or `false`

**Note**: When `true`, all local backup files are removed after processing. When `false`, only intermediate files are cleaned up and the final backup file is retained locally.

### S3 Configuration (Optional)
- `S3_BUCKET` - S3 bucket name for storing backups
- `S3_PREFIX` - S3 key prefix (default: "backups")
- `S3_OPTIONS` - Additional AWS CLI options (e.g., `--storage-class STANDARD_IA`)

**Note**: Local backup files are automatically cleaned up after processing, regardless of S3 configuration. This ensures your system doesn't accumulate backup files over time.

### Webhook Configuration (Optional)
- `WEBHOOK_URL` - URL to send backup status notifications

### AWS Authentication (Choose one method)

#### Method 1: Access Keys
```bash
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
```

#### Method 2: IAM Role (Recommended for EC2/ECS)
```bash
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/BackupRole
```

#### Method 3: Instance Profile
No additional environment variables needed when running on EC2 with an instance profile.


## Usage

For a complete working example, see the `docker-compose.yml` file in this repository which demonstrates all configuration options including database setup, encryption, compression, and optional S3 upload.

## Encryption and Compression

### Encryption Methods

#### GPG (Recommended)
- Uses AES256 cipher
- More secure and widely supported
- File extension: `.pgdump.gpg` or `.pgdump.gz.gpg` (if compressed)

#### OpenSSL
- Uses AES-256-CBC with salt
- Good compatibility
- File extension: `.pgdump.enc` or `.pgdump.gz.enc` (if compressed)

### Compression Options

1. **None** (default): Uses only pg_dump's built-in compression
2. **gzip**: Fast compression, good balance of speed and size
3. **bzip2**: Better compression ratio than gzip, slower
4. **xz**: Best compression ratio, slowest

### Processing Order

1. PostgreSQL dump (with built-in compression if using custom format)
2. Additional compression (if specified)
3. Encryption (if key provided)

### Decryption Examples

#### GPG Decryption
```bash
gpg --batch --yes --passphrase "your-passphrase" --decrypt backup.pgdump.gz.gpg | gunzip > backup.pgdump
```

#### OpenSSL Decryption
```bash
openssl enc -aes-256-cbc -d -in backup.pgdump.gz.enc -k "your-passphrase" | gunzip > backup.pgdump
```

## S3 Backup Structure

Backups are stored in S3 with the following structure:
```
# Unencrypted, no additional compression
s3://your-bucket/backups/hostname/2024-01-15T10:30:00+00:00.pgdump

# With gzip compression
s3://your-bucket/backups/hostname/2024-01-15T10:30:00+00:00.pgdump.gz

# With GPG encryption
s3://your-bucket/backups/hostname/2024-01-15T10:30:00+00:00.pgdump.gpg

# With both gzip compression and GPG encryption
s3://your-bucket/backups/hostname/2024-01-15T10:30:00+00:00.pgdump.gz.gpg
```

## IAM Permissions

Your AWS user or role needs the following S3 permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": "arn:aws:s3:::your-backup-bucket/*"
        }
    ]
}
```

## Security Best Practices

1. Use IAM roles instead of access keys when possible
2. Follow the principle of least privilege for S3 permissions
3. Enable S3 bucket encryption
4. Consider using AWS Secrets Manager for sensitive credentials
5. **Use strong encryption keys** for backup encryption
6. **Store encryption keys securely** - losing the key means losing access to your backups
7. **Test backup restoration** including decryption process

## Troubleshooting

1. **S3 Upload Fails**: Check AWS credentials and S3 bucket permissions
2. **Database Connection Issues**: Verify PostgreSQL host, port, and credentials
3. **Permission Errors**: Ensure the container has write access to `/opt/dumps`
4. **Encryption Failures**: Verify encryption key is set correctly and method is supported
5. **Compression Issues**: Check available disk space and compression tool availability

## Restoration Examples

### Simple Restoration (No Encryption/Compression)
```bash
pg_restore -h localhost -U postgres -d restored_db backup.pgdump
```

### With Additional Compression
```bash
# For gzip
gunzip backup.pgdump.gz
pg_restore -h localhost -U postgres -d restored_db backup.pgdump

# For bzip2
bunzip2 backup.pgdump.bz2
pg_restore -h localhost -U postgres -d restored_db backup.pgdump

# For xz
unxz backup.pgdump.xz
pg_restore -h localhost -U postgres -d restored_db backup.pgdump
```

### With Encryption and Compression
```bash
# GPG + gzip example
gpg --batch --yes --passphrase "your-passphrase" --decrypt backup.pgdump.gz.gpg | gunzip > backup.pgdump
pg_restore -h localhost -U postgres -d restored_db backup.pgdump

# OpenSSL + bzip2 example
openssl enc -aes-256-cbc -d -in backup.pgdump.bz2.enc -k "your-passphrase" | bunzip2 > backup.pgdump
pg_restore -h localhost -U postgres -d restored_db backup.pgdump
```
