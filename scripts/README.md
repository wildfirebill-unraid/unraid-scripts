# Unraid Scripts Collection

A collection of 50+ useful, functional, and unique scripts for Unraid server management.

## Categories

### System Maintenance (5 scripts)
| Script | Description |
|--------|-------------|
| `cleanup_docker_logs.sh` | Clean Docker container logs older than N days |
| `trim_ssd_cache.sh` | Run fstrim on SSD cache pool |
| `rotate_syslog.sh` | Rotate and compress system logs |
| `check_disk_space.sh` | Monitor disk space with alerts |
| `cleanup_old_kernels.sh` | Remove old kernel packages |

### Docker Management (5 scripts)
| Script | Description |
|--------|-------------|
| `update_docker_images.sh` | Update all Docker images and recreate containers |
| `restart_unhealthy_containers.sh` | Auto-restart unhealthy containers with limits |
| `backup_docker_configs.sh` | Backup container configs, labels, and volumes |
| `docker_resource_monitor.sh` | Monitor CPU/memory usage per container |
| `prune_docker_system.sh` | Comprehensive Docker system cleanup |

### Backup (5 scripts)
| Script | Description |
|--------|-------------|
| `rsync_backup.sh` | Rsync backup with hardlink rotation |
| `borg_backup.sh` | BorgBackup with encryption and pruning |
| `snapshot_btrfs.sh` | Create Btrfs snapshots with retention |
| `backup_appdata.sh` | Backup appdata with container stop/start |
| `verify_backup_integrity.sh` | Verify backup integrity with checksums |

### Disk/Array Management (5 scripts)
| Script | Description |
|--------|-------------|
| `check_smart_status.sh` | Check SMART status of all disks |
| `parity_check_schedule.sh` | Schedule and monitor parity checks |
| `disk_temperature_monitor.sh` | Monitor disk temperatures with alerts |
| `array_usage_report.sh` | Generate detailed array usage report |
| `balance_btrfs.sh` | Balance Btrfs filesystem to reclaim space |

### Monitoring (5 scripts)
| Script | Description |
|--------|-------------|
| `system_health_check.sh` | Comprehensive system health check |
| `service_monitor.sh` | Monitor services with auto-restart |
| `network_monitor.sh` | Monitor network connectivity and bandwidth |
| `docker_health_dashboard.sh` | Generate HTML dashboard for Docker health |
| `log_alert_monitor.sh` | Monitor logs for patterns and alert |

### Notifications (5 scripts)
| Script | Description |
|--------|-------------|
| `notify.sh` | Unified notification sender (Gotify, ntfy, Discord, Slack, Email, Pushover) |
| `daily_summary.sh` | Send daily system summary |
| `alert_on_threshold.sh` | Alert when metrics exceed thresholds |
| `backup_notification.sh` | Notify on backup success/failure |
| `parity_notification.sh` | Notify on parity check events |

### File Organization (5 scripts)
| Script | Description |
|--------|-------------|
| `organize_downloads.sh` | Organize downloads by file type/date |
| `deduplicate_files.sh` | Find and remove duplicate files |
| `cleanup_empty_dirs.sh` | Remove empty directories recursively |
| `rename_media_files.sh` | Rename media files using metadata |
| `archive_old_files.sh` | Archive files older than N days |

### Security (5 scripts)
| Script | Description |
|--------|-------------|
| `ssh_hardening.sh` | Harden SSH configuration |
| `fail2ban_status.sh` | Check and manage fail2ban |
| `audit_sudoers.sh` | Audit sudoers configuration |
| `check_open_ports.sh` | Scan for open ports |
| `file_integrity_monitor.sh` | Monitor file integrity |

### Performance (5 scripts)
| Script | Description |
|--------|-------------|
| `cpu_governor.sh` | Manage CPU frequency scaling governor |
| `memory_pressure_monitor.sh` | Monitor memory pressure and take action |
| `io_scheduler.sh` | Set I/O scheduler for block devices |
| `network_tuning.sh` | Apply network performance tuning |
| `docker_performance_tune.sh` | Tune Docker daemon for performance |

### Media Management (5 scripts)
| Script | Description |
|--------|-------------|
| `media_library_scan.sh` | Scan media library and generate report |
| `transcode_media.sh` | Transcode media files using ffmpeg |
| `organize_tv_shows.sh` | Organize TV shows into Show/Season/Episode |
| `organize_movies.sh` | Organize movies into Movie (Year) folders |
| `extract_subtitles.sh` | Extract embedded subtitles from media |

### Utilities (5 scripts)
| Script | Description |
|--------|-------------|
| `system_info.sh` | Collect comprehensive system information |
| `cron_job_manager.sh` | Manage cron jobs for Unraid |
| `service_manager.sh` | Manage systemd services |
| `backup_rotation.sh` | Manage backup rotation policies |
| `health_check_report.sh` | Generate comprehensive health check report (HTML/Text/JSON) |

## Usage

All scripts are executable and follow a consistent pattern:
```bash
./script_name.sh --help          # Show usage
./script_name.sh --option value  # Run with options
```

Common options:
- `--dry-run` / `--execute` - Preview vs execute changes
- `--format text|json|html` - Output format
- `--channel gotify|ntfy|discord|slack|email` - Notification channel
- `--output /path` - Output file path

## Requirements

Most scripts require:
- Bash 4+
- Standard Linux utilities (find, awk, sed, etc.)
- Some require additional tools: `docker`, `smartctl`, `ffmpeg`, `mediainfo`, `exiftool`, `bc`, `jq`, `nmap`, `ethtool`

## Installation

```bash
git clone <this-repo> /path/to/scripts
chmod +x /path/to/scripts/**/*.sh
```

Add to cron for automated runs:
```bash
# Daily health check at 6 AM
0 6 * * * /path/to/scripts/monitoring/system_health_check.sh --format html --output /mnt/user/health_report.html

# Weekly backup rotation
0 2 * * 0 /path/to/scripts/utilities/backup_rotation.sh --path /mnt/user/backups --execute
```

## Notification Setup

Configure environment variables for `notify.sh`:
```bash
export GOTIFY_URL="https://gotify.example.com"
export GOTIFY_TOKEN="your-token"
export NTFY_TOPIC="your-topic"
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
export SLACK_WEBHOOK="https://hooks.slack.com/services/..."
export EMAIL_TO="admin@example.com"
export EMAIL_FROM="server@example.com"
export PUSHOVER_TOKEN="your-token"
export PUSHOVER_USER="your-user"
```

## License

MIT License - Feel free to use, modify, and distribute.