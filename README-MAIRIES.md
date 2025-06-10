# Listmonk pour les Mairies Françaises

[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://docker.com)
[![License](https://img.shields.io/badge/license-AGPL%20v3-blue.svg)](LICENSE)

Cette version de listmonk a été spécialement adaptée pour répondre aux besoins des communications ciblées vers les mairies françaises. Elle intègre des fonctionnalités de géolocalisation et de segmentation basées sur les données administratives françaises.

## 🎯 Fonctionnalités Spécifiques

### Ciblage Géographique
- **Filtrage par département** : Ciblage précis par codes départementaux (01-95, 2A, 2B, 971-978)
- **Filtrage par population** : Segmentation par tranches de population communale
- **Filtrage par région** : Ciblage par régions administratives françaises
- **Combinaison de filtres** : Requêtes complexes multi-critères

### Import et Gestion des Données
- **Import CSV automatisé** : Import en masse des données de mairies
- **Validation des données** : Contrôle de cohérence des codes INSEE et départementaux
- **Géocodage** : Support des coordonnées géographiques
- **Mise à jour incrémentale** : Gestion des mises à jour de données

### Interface Adaptée
- **Dashboard géographique** : Visualisation des données par région/département
- **Prévisualisation de ciblage** : Aperçu en temps réel du nombre de destinataires
- **Statistiques détaillées** : Métriques par département et tranche de population
- **Templates spécialisés** : Modèles d'e-mails adaptés aux communications officielles

## 🚀 Installation Rapide avec Docker

### Prérequis
- Docker et Docker Compose
- 2 GB de RAM minimum
- 5 GB d'espace disque

### Déploiement

1. **Cloner le repository**
```bash
git clone https://github.com/code4UD/listmonk.git
cd listmonk
```

2. **Configuration des variables d'environnement**
```bash
cp .env.example .env
# Éditer le fichier .env avec vos paramètres
```

3. **Lancement des services**
```bash
# Production
docker-compose -f docker-compose.mairies.yml up -d

# Développement (avec Adminer et Redis Commander)
docker-compose -f docker-compose.mairies.yml --profile dev up -d
```

4. **Accès à l'application**
- Interface principale : http://localhost:9000
- Adminer (dev) : http://localhost:8080
- Redis Commander (dev) : http://localhost:8081

### Configuration Initiale

1. **Première connexion**
   - Rendez-vous sur http://localhost:9000
   - Créez votre compte administrateur
   - Configurez vos paramètres SMTP

2. **Import des données géographiques**
   - Allez dans "Géographie" > "Import"
   - Téléchargez le fichier CSV des mairies
   - Lancez l'import avec création automatique des abonnés

## 📊 Utilisation

### Import de Données de Mairies

#### Format CSV Requis
```csv
nom_commune;code_insee;code_departement;population;email;nom_contact;code_postal;latitude;longitude
Aix-en-Provence;13001;13;145347;mairie@aixenprovence.fr;Jean Dupont;13100;43.5297;5.4474
```

#### Colonnes Obligatoires
- `nom_commune` : Nom de la commune
- `code_insee` : Code INSEE à 5 chiffres
- `code_departement` : Code département (01-95, 2A, 2B, 971-978)

#### Colonnes Optionnelles
- `population` : Nombre d'habitants
- `email` : Adresse e-mail de contact
- `nom_contact` : Nom du contact
- `code_postal` : Code postal
- `latitude` / `longitude` : Coordonnées GPS

### Création de Campagnes Ciblées

1. **Nouvelle campagne**
   - Créez une nouvelle campagne
   - Allez dans l'onglet "Ciblage Géographique"

2. **Configuration du ciblage**
   ```json
   {
     "department_codes": ["75", "92", "93", "94"],
     "population_min": 1000,
     "population_max": 50000,
     "regions": ["Île-de-France"]
   }
   ```

3. **Prévisualisation**
   - Utilisez la prévisualisation pour voir le nombre de destinataires
   - Vérifiez la répartition géographique

### API REST

#### Endpoints Géographiques

```bash
# Départements
GET /api/geo/departments

# Communes avec filtres
GET /api/geo/communes?department_codes=75,92&population_min=1000

# Recherche de communes
GET /api/geo/communes/search?q=Paris

# Statistiques géographiques
GET /api/geo/stats

# Prévisualisation de ciblage
POST /api/targeting/preview
{
  "department_codes": ["75", "92"],
  "population_min": 1000,
  "population_max": 50000
}

# Comptage de destinataires
POST /api/targeting/count
{
  "department_codes": ["75"],
  "population_min": 5000
}
```

#### Import de données

```bash
# Import CSV
POST /api/geo/import
Content-Type: multipart/form-data
- file: fichier.csv
- create_subscribers: true
```

## 🔧 Configuration Avancée

### Variables d'Environnement

```bash
# Application
LISTMONK_app__address=0.0.0.0:9000
LISTMONK_app__admin_username=admin
LISTMONK_app__admin_password=changeme

# Base de données
LISTMONK_db__host=listmonk_mairies_db
LISTMONK_db__user=listmonk_mairies
LISTMONK_db__password=secure_password
LISTMONK_db__database=listmonk_mairies

# Redis (cache)
LISTMONK_redis__host=listmonk_mairies_redis
LISTMONK_redis__port=6379

# Fonctionnalités géographiques
LISTMONK_geo__enabled=true
LISTMONK_geo__cache_ttl=3600
```

### Optimisation des Performances

#### Base de Données
```sql
-- Index personnalisés pour les requêtes géographiques
CREATE INDEX CONCURRENTLY idx_communes_pop_dept 
ON french_communes(population, department_code);

CREATE INDEX CONCURRENTLY idx_subscribers_geo_attribs 
ON subscribers USING GIN ((attribs->'commune'));
```

#### Cache Redis
```bash
# Configuration Redis optimisée
redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
```

## 📈 Monitoring et Métriques

### Métriques Spécifiques
- Nombre de mairies par département
- Taux d'ouverture par tranche de population
- Performance des requêtes de ciblage géographique
- Utilisation du cache Redis

### Logs
```bash
# Logs de l'application
docker-compose -f docker-compose.mairies.yml logs -f app

# Logs de la base de données
docker-compose -f docker-compose.mairies.yml logs -f db

# Logs Redis
docker-compose -f docker-compose.mairies.yml logs -f redis
```

## 🛠️ Développement

### Environnement de Développement

```bash
# Cloner et configurer
git clone https://github.com/code4UD/listmonk.git
cd listmonk

# Lancer en mode développement
docker-compose -f docker-compose.mairies.yml --profile dev up -d

# Accès aux outils de développement
# - Adminer: http://localhost:8080
# - Redis Commander: http://localhost:8081
```

### Structure du Code

```
internal/
├── geo/                 # Module géographique
│   ├── models.go       # Modèles de données
│   ├── geo.go          # Service principal
│   └── importer.go     # Import CSV
cmd/
├── geo.go              # Handlers HTTP
└── main.go             # Application principale
migrations/
└── v5.1.0_geo_tables.sql  # Migration base de données
```

### Tests

```bash
# Tests unitaires
go test ./internal/geo/...

# Tests d'intégration
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

## 🔒 Sécurité

### Validation des Données
- Validation stricte des codes INSEE
- Vérification des codes départements
- Sanitisation des données CSV importées
- Contrôle d'accès par permissions

### Bonnes Pratiques
- Utilisation de mots de passe forts
- Chiffrement des communications (HTTPS)
- Sauvegarde régulière des données
- Mise à jour des dépendances

## 📚 Documentation

### Guides Utilisateur
- [Guide d'import des données](docs/import-guide.md)
- [Tutoriel de ciblage géographique](docs/targeting-guide.md)
- [FAQ Mairies](docs/faq-mairies.md)

### Documentation Technique
- [API Documentation](docs/api.md)
- [Guide de déploiement](docs/deployment.md)
- [Procédures de maintenance](docs/maintenance.md)

## 🤝 Contribution

### Signaler un Bug
1. Vérifiez que le bug n'a pas déjà été signalé
2. Créez une issue avec le template approprié
3. Incluez les logs et la configuration

### Proposer une Fonctionnalité
1. Discutez de l'idée dans une issue
2. Créez une pull request avec les tests
3. Documentez les changements

### Développement Local
```bash
# Fork du repository
git clone https://github.com/votre-username/listmonk.git

# Créer une branche
git checkout -b feature/nouvelle-fonctionnalite

# Développer et tester
make test

# Soumettre la pull request
```

## 📄 Licence

Ce projet est sous licence AGPL v3. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🆘 Support

### Communauté
- [Issues GitHub](https://github.com/code4UD/listmonk/issues)
- [Discussions](https://github.com/code4UD/listmonk/discussions)

### Support Commercial
Pour un support professionnel ou des développements spécifiques :
- Email : contact@code4ud.fr
- Site web : https://code4ud.fr

## 🙏 Remerciements

- [Listmonk original](https://github.com/knadh/listmonk) par Kailash Nadh
- Communauté open source
- Contributeurs du projet

---

**Note** : Cette version est spécialement adaptée pour les besoins français. Pour la version originale de listmonk, consultez le [repository officiel](https://github.com/knadh/listmonk).