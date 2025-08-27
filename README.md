# ERPNext Automated Deployment Script

## Overview

This project provides a shell script to automate the installation of ERPNext on Ubuntu systems. The script handles both test and production environments, guiding you through the configuration process with interactive prompts.

## Features

- Interactive configuration for test or production environments
- Automated dependency installation
- Secure database setup with randomized passwords
- Production-ready configuration with Nginx and supervisor
- Comprehensive logging and credential management
- Support for the latest versions of all components

## Prerequisites

- Ubuntu 20.04 or later
- Minimum 4GB RAM (8GB recommended for production)
- Minimum 40GB disk space
- sudo privileges

## Usage

1. **Update the Linux**
   ```bash
     sudo apt update && sudo apt full-upgrade -y
   ```

1. **Download the script**
   ```bash
   sudo apt install curl
   curl -O https://raw.githubusercontent.com/talha50819/erpnext/blob/main/install_erpnext.sh
   chmod +x install_erpnext.sh
   ```

2. **Run the script**
   ```bash
   ./install_erpnext.sh
   ```

3. **Follow the interactive prompts**
   - Choose a Linux username (default: frappe)
   - Set MariaDB credentials
   - Select deployment type (test or production)
   - Configure domain name (for production)
   - Set administrator password

## Configuration Options

The script will prompt you for:

1. **Linux Username**: User account for running ERPNext
2. **MariaDB Username**: Database user (default: frappe)
3. **MariaDB Password**: Secure password (randomized by default)
4. **Deployment Type**: 
   - Test: Development environment with bench server
   - Production: Production environment with Nginx and supervisor
5. **Site Name**: 
   - Localhost for test environment
   - Domain name for production environment
6. **Admin Password**: ERPNext administrator password

## Post-Installation Steps

### For Test Environments
1. Navigate to the installation directory:
   ```bash
   cd frappe-bench
   ```
2. Start the development server:
   ```bash
   bench start
   ```
3. Access ERPNext at: http://localhost:8000

### For Production Environments
1. Configure your DNS to point your domain to the server IP
2. Set up SSL certificate:
   ```bash
   bench setup add-domain your-domain.com
   bench setup ssl-certificate
   ```
3. Monitor services:
   ```bash
   sudo supervisorctl status
   ```

## File Structure

After installation, the following structure is created:

```
/home/username/
├── frappe-bench/                 # Bench directory
│   ├── sites/
│   │   └── site-name/           # Your ERPNext site
│   └── apps/
│       ├── erpnext/             # ERPNext application
│       └── frappe/              # Frappe framework
├── erpnext_install_*.log        # Installation log
└── erpnext_credentials_*.txt    # Generated credentials
```

## Troubleshooting

### Common Issues

1. **Insufficient Memory**
   - Error: Installation fails or hangs
   - Solution: Increase swap space or add more RAM

2. **Port Conflicts**
   - Error: Services fail to start
   - Solution: Check for other services using ports 80, 443, 3306, 8000

3. **Database Connection Issues**
   - Verify MariaDB is running: `sudo systemctl status mariadb`
   - Check credentials in `common_site_config.json`

4. **Permission Issues**
   - Ensure your user has proper permissions:
   ```bash
   sudo chown -R <username>:<username> /home/<username>/frappe-bench
   ```

### Checking Logs

- Installation log: `erpnext_install_*.log`
- Application logs: `/home/frappe/frappe-bench/logs/`
- System logs: `/var/log/`

### Restarting Services

For production environments:
```bash
sudo supervisorctl restart all
sudo systemctl restart nginx
```

## Security Considerations

1. Change all default passwords after installation
2. Configure firewall rules to restrict access
3. Set up SSL certificates for production environments
4. Regularly update the system and applications
5. Implement backup procedures for database and application files

## Backup and Recovery

### Database Backup
```bash
cd /home/frappe/frappe-bench
bench backup --site your-site.com
```

### File System Backup
Backup the entire bench directory:
```bash
tar -czf erpnext-backup.tar.gz /home/frappe/frappe-bench
```

### Restore from Backup
```bash
cd /home/frappe/frappe-bench
bench restore --site your-site.com /path/to/backup.sql.gz
```

## Maintenance

### Updating ERPNext
```bash
cd /home/frappe/frappe-bench
bench update
```

### Checking System Status
```bash
bench doctor
sudo supervisorctl status
```

## Support Resources

- [Official ERPNext Documentation](https://docs.frappe.io/erpnext)
- [Frappe Framework Documentation](https://docs.frappe.io/framework)
- [Community Forum](https://discuss.frappe.io)
- [GitHub Issues](https://github.com/frappe/erpnext/issues)

## License

This script is released under the MIT License. ERPNext is released under the GNU General Public License v3.

## Contributing

Contributions to improve this script are welcome. Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Disclaimer

This script is provided as-is without any warranties. Always test in a non-production environment before deploying to production. The authors are not responsible for any data loss or system issues resulting from the use of this script.
