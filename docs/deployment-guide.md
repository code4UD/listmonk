# Guide de Déploiement - Listmonk Mairies

Ce guide vous accompagne dans le déploiement de listmonk-mairies en production.

## 🎯 Prérequis

### Système
- **OS** : Linux (Ubuntu 20.04+ recommandé)
- **RAM** : 4 GB minimum, 8 GB recommandé
- **Stockage** : 20 GB minimum, SSD recommandé
- **CPU** : 2 cœurs minimum, 4 cœurs recommandé

### Logiciels
- Docker 20.10+
- Docker Compose 2.0+
- Git
- Nginx (pour le reverse proxy)
- Certbot (pour SSL)

## 🚀 Installation Rapide

### 1. Préparation du Serveur

```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation de Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Installation de Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Redémarrage de session pour appliquer les groupes
newgrp docker
```

### 2. Déploiement de l'Application

```bash
# Clonage du repository
git clone https://github.com/code4UD/listmonk.git
cd listmonk

# Configuration
cp .env.example .env
nano .env  # Éditer la configuration

# Lancement
make setup
```

## ⚙️ Configuration Détaillée

### Variables d'Environnement Critiques

```bash
# .env
# =================================================================
# OBLIGATOIRE : Configuration SMTP
# =================================================================
LISTMONK_smtp__host=smtp.your-provider.com
LISTMONK_smtp__port=587
LISTMONK_smtp__username=your-email@domain.com
LISTMONK_smtp__password=your-smtp-password
LISTMONK_smtp__tls_enabled=true

# =================================================================
# OBLIGATOIRE : Configuration de l'application
# =================================================================
LISTMONK_app__from_email=noreply@your-domain.com
LISTMONK_app__site_name="Mairies Communication"
LISTMONK_ADMIN_USER=admin
LISTMONK_ADMIN_PASSWORD=your-secure-password

# =================================================================
# OBLIGATOIRE : Base de données
# =================================================================
POSTGRES_USER=listmonk_prod
POSTGRES_PASSWORD=very-secure-db-password
POSTGRES_DB=listmonk_mairies_prod

# =================================================================
# RECOMMANDÉ : Sécurité
# =================================================================
LISTMONK_privacy__individual_tracking=false
LISTMONK_app__enable_public_subscription_page=false
LISTMONK_app__check_updates=false
```

### Configuration Nginx

```nginx
# /etc/nginx/sites-available/listmonk-mairies
server {
    listen 80;
    server_name your-domain.com;
    
    # Redirection HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
    
    # Main proxy
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # API Rate Limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Login Rate Limiting
    location /api/auth/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://127.0.0.1:9000;
    }
    
    # Upload size limit
    client_max_body_size 100M;
    
    # Logs
    access_log /var/log/nginx/listmonk-mairies.access.log;
    error_log /var/log/nginx/listmonk-mairies.error.log;
}
```

### Configuration SSL avec Let's Encrypt

```bash
# Installation de Certbot
sudo apt install certbot python3-certbot-nginx

# Obtention du certificat
sudo certbot --nginx -d your-domain.com

# Test de renouvellement automatique
sudo certbot renew --dry-run

# Cron pour renouvellement automatique
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

## 🔒 Sécurité

### Firewall

```bash
# Configuration UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Vérification
sudo ufw status
```

### Fail2Ban

```bash
# Installation
sudo apt install fail2ban

# Configuration pour Nginx
sudo tee /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/listmonk-mairies.error.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/listmonk-mairies.error.log
maxretry = 10
EOF

# Redémarrage
sudo systemctl restart fail2ban
```

### Sauvegardes Automatiques

```bash
# Script de sauvegarde
sudo tee /usr/local/bin/backup-listmonk.sh << 'EOF'
#!/bin/bash
set -e

BACKUP_DIR="/var/backups/listmonk"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Création du répertoire de sauvegarde
mkdir -p $BACKUP_DIR

# Sauvegarde de la base de données
cd /path/to/listmonk
docker-compose -f docker-compose.mairies.yml exec -T db pg_dump -U listmonk_prod listmonk_mairies_prod | gzip > $BACKUP_DIR/db_backup_$DATE.sql.gz

# Sauvegarde des uploads
tar -czf $BACKUP_DIR/uploads_backup_$DATE.tar.gz uploads/

# Sauvegarde de la configuration
cp .env $BACKUP_DIR/env_backup_$DATE

# Nettoyage des anciennes sauvegardes
find $BACKUP_DIR -name "*.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "env_backup_*" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
EOF

# Permissions
sudo chmod +x /usr/local/bin/backup-listmonk.sh

# Cron pour sauvegarde quotidienne à 2h du matin
echo "0 2 * * * /usr/local/bin/backup-listmonk.sh" | sudo crontab -
```

## 📊 Monitoring

### Monitoring avec Prometheus et Grafana

```yaml
# monitoring/docker-compose.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"

volumes:
  prometheus_data:
  grafana_data:
```

### Configuration Prometheus

```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'listmonk'
    static_configs:
      - targets: ['localhost:9000']
    metrics_path: '/api/health'
    
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
      
  - job_name: 'postgres'
    static_configs:
      - targets: ['localhost:5432']
```

### Alertes

```bash
# Script d'alerte simple
sudo tee /usr/local/bin/check-listmonk.sh << 'EOF'
#!/bin/bash

# Vérification de l'application
if ! curl -f http://localhost:9000/api/health > /dev/null 2>&1; then
    echo "ALERT: Listmonk application is down" | mail -s "Listmonk Alert" admin@your-domain.com
fi

# Vérification de l'espace disque
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "ALERT: Disk usage is ${DISK_USAGE}%" | mail -s "Disk Space Alert" admin@your-domain.com
fi

# Vérification de la mémoire
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ $MEM_USAGE -gt 90 ]; then
    echo "ALERT: Memory usage is ${MEM_USAGE}%" | mail -s "Memory Alert" admin@your-domain.com
fi
EOF

# Permissions et cron
sudo chmod +x /usr/local/bin/check-listmonk.sh
echo "*/5 * * * * /usr/local/bin/check-listmonk.sh" | sudo crontab -
```

## 🔄 Mise à Jour

### Procédure de Mise à Jour

```bash
# Script de mise à jour
sudo tee /usr/local/bin/update-listmonk.sh << 'EOF'
#!/bin/bash
set -e

echo "Starting Listmonk update..."

# Sauvegarde avant mise à jour
/usr/local/bin/backup-listmonk.sh

# Arrêt de l'application
cd /path/to/listmonk
make stop

# Mise à jour du code
git pull origin main

# Reconstruction de l'image
make build

# Redémarrage
make run

# Vérification
sleep 30
if curl -f http://localhost:9000/api/health > /dev/null 2>&1; then
    echo "Update completed successfully"
else
    echo "Update failed - check logs"
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/update-listmonk.sh
```

### Rollback

```bash
# Script de rollback
sudo tee /usr/local/bin/rollback-listmonk.sh << 'EOF'
#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_date>"
    echo "Available backups:"
    ls -la /var/backups/listmonk/db_backup_*.sql.gz
    exit 1
fi

BACKUP_DATE=$1
BACKUP_DIR="/var/backups/listmonk"

echo "Rolling back to $BACKUP_DATE..."

# Arrêt de l'application
cd /path/to/listmonk
make stop

# Restauration de la base de données
gunzip -c $BACKUP_DIR/db_backup_$BACKUP_DATE.sql.gz | docker-compose -f docker-compose.mairies.yml exec -T db psql -U listmonk_prod -d listmonk_mairies_prod

# Restauration des uploads
tar -xzf $BACKUP_DIR/uploads_backup_$BACKUP_DATE.tar.gz

# Redémarrage
make run

echo "Rollback completed"
EOF

sudo chmod +x /usr/local/bin/rollback-listmonk.sh
```

## 🎛️ Optimisation des Performances

### Configuration PostgreSQL

```bash
# Optimisation PostgreSQL pour production
sudo tee -a /var/lib/docker/volumes/listmonk_postgres_data/_data/postgresql.conf << 'EOF'
# Optimisations pour listmonk-mairies
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
max_parallel_maintenance_workers = 4
EOF
```

### Configuration Redis

```bash
# Optimisation Redis
sudo tee redis.conf << 'EOF'
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
tcp-keepalive 300
timeout 0
tcp-backlog 511
databases 16
EOF
```

## 📋 Checklist de Déploiement

### Avant le Déploiement

- [ ] Serveur configuré avec les prérequis
- [ ] Nom de domaine configuré
- [ ] Certificat SSL obtenu
- [ ] Configuration SMTP testée
- [ ] Sauvegardes configurées
- [ ] Monitoring configuré
- [ ] Firewall configuré

### Après le Déploiement

- [ ] Application accessible via HTTPS
- [ ] Connexion admin fonctionnelle
- [ ] Import de données testé
- [ ] Envoi d'e-mails testé
- [ ] Sauvegardes testées
- [ ] Monitoring fonctionnel
- [ ] Alertes configurées

### Tests de Production

```bash
# Test de santé
curl -f https://your-domain.com/api/health

# Test d'authentification
curl -X POST https://your-domain.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your-password"}'

# Test d'import (avec un petit fichier)
curl -X POST https://your-domain.com/api/geo/import \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@test-mairies.csv" \
  -F "create_subscribers=false"
```

## 🆘 Dépannage

### Problèmes Courants

#### Application ne démarre pas
```bash
# Vérifier les logs
make logs

# Vérifier la configuration
docker-compose -f docker-compose.mairies.yml config

# Vérifier les ports
sudo netstat -tlnp | grep :9000
```

#### Base de données inaccessible
```bash
# Vérifier le statut PostgreSQL
make logs-db

# Test de connexion
docker-compose -f docker-compose.mairies.yml exec db psql -U listmonk_prod -d listmonk_mairies_prod -c "SELECT 1;"
```

#### Problèmes d'e-mail
```bash
# Test SMTP
docker-compose -f docker-compose.mairies.yml exec app ./listmonk --test-smtp
```

### Logs Utiles

```bash
# Logs de l'application
tail -f /var/log/nginx/listmonk-mairies.access.log
tail -f /var/log/nginx/listmonk-mairies.error.log

# Logs Docker
docker-compose -f docker-compose.mairies.yml logs -f

# Logs système
journalctl -u docker -f
```

## 📞 Support

Pour obtenir de l'aide :

1. **Documentation** : Consultez d'abord la documentation complète
2. **Issues GitHub** : Créez une issue avec les détails du problème
3. **Support commercial** : contact@code4ud.fr pour un support professionnel

---

Ce guide couvre les aspects essentiels du déploiement en production. Adaptez les configurations selon vos besoins spécifiques et votre infrastructure.