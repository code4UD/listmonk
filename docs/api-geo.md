# API Géographique - Listmonk Mairies

Cette documentation décrit les endpoints spécifiques aux fonctionnalités géographiques de listmonk-mairies.

## Authentification

Toutes les APIs nécessitent une authentification. Utilisez l'un des moyens suivants :

### Session Cookie
```bash
# Connexion
curl -X POST http://localhost:9000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'
```

### Token API (recommandé)
```bash
# Utilisation du token dans les headers
curl -H "Authorization: Bearer YOUR_API_TOKEN" \
  http://localhost:9000/api/geo/departments
```

## Endpoints Géographiques

### 1. Départements

#### Lister tous les départements
```http
GET /api/geo/departments
```

**Réponse :**
```json
{
  "data": [
    {
      "id": 1,
      "code": "01",
      "name": "Ain",
      "region": "Auvergne-Rhône-Alpes",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### 2. Communes

#### Lister les communes avec filtres
```http
GET /api/geo/communes?department_codes=75,92&population_min=1000&population_max=50000&limit=50&offset=0
```

**Paramètres de requête :**
- `department_codes` : Codes départements séparés par des virgules
- `population_min` : Population minimale
- `population_max` : Population maximale
- `regions` : Régions séparées par des virgules
- `commune_names` : Noms de communes (recherche partielle)
- `postal_codes` : Codes postaux séparés par des virgules
- `limit` : Nombre maximum de résultats (défaut: 50, max: 1000)
- `offset` : Décalage pour la pagination

**Réponse :**
```json
{
  "data": [
    {
      "id": 1,
      "insee_code": "75001",
      "name": "Paris 1er Arrondissement",
      "department_code": "75",
      "population": 16888,
      "postal_codes": ["75001"],
      "latitude": 48.8606,
      "longitude": 2.3376,
      "department_name": "Paris",
      "region": "Île-de-France",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### Rechercher des communes
```http
GET /api/geo/communes/search?q=Paris&limit=20
```

**Paramètres :**
- `q` : Terme de recherche (obligatoire)
- `limit` : Nombre maximum de résultats (défaut: 20, max: 100)

### 3. Statistiques Géographiques

#### Obtenir les statistiques générales
```http
GET /api/geo/stats
```

**Réponse :**
```json
{
  "data": {
    "total_departments": 101,
    "total_communes": 34968,
    "total_subscribers": 15420,
    "communes_with_subscribers": 8234,
    "coverage_percentage": 23.56,
    "total_population": 67422241,
    "average_population": 1928.4,
    "median_population": 450,
    "region_stats": [
      {
        "region": "Île-de-France",
        "departments": 8,
        "communes": 1276,
        "subscribers": 892,
        "total_population": 12278210,
        "coverage_percent": 69.87
      }
    ]
  }
}
```

## Endpoints de Ciblage

### 1. Prévisualisation de Ciblage

#### Prévisualiser une campagne ciblée
```http
POST /api/targeting/preview
Content-Type: application/json

{
  "department_codes": ["75", "92", "93", "94"],
  "population_min": 1000,
  "population_max": 50000,
  "regions": ["Île-de-France"]
}
```

**Réponse :**
```json
{
  "data": {
    "count": 1247,
    "filters": {
      "department_codes": ["75", "92", "93", "94"],
      "population_min": 1000,
      "population_max": 50000,
      "regions": ["Île-de-France"]
    },
    "sample_communes": [
      {
        "id": 1,
        "insee_code": "75001",
        "name": "Paris 1er Arrondissement",
        "department_code": "75",
        "population": 16888
      }
    ],
    "statistics": {
      "total_communes": 156,
      "total_subscribers": 1247,
      "by_department": {
        "75": 20,
        "92": 36,
        "93": 40,
        "94": 47
      },
      "by_region": {
        "Île-de-France": 143
      },
      "by_population_range": {
        "1000-1999": 45,
        "2000-4999": 67,
        "5000-9999": 28,
        "10000-19999": 12,
        "20000-49999": 4
      },
      "average_population": 8456.7
    },
    "estimated_reach": 1247,
    "population_total": 1319347
  }
}
```

### 2. Comptage de Destinataires

#### Compter les destinataires pour un ciblage
```http
POST /api/targeting/count
Content-Type: application/json

{
  "department_codes": ["75"],
  "population_min": 5000
}
```

**Réponse :**
```json
{
  "data": {
    "count": 892
  }
}
```

## Endpoints d'Import

### 1. Import de Données CSV

#### Importer un fichier CSV de mairies
```http
POST /api/geo/import
Content-Type: multipart/form-data

file: [fichier CSV]
create_subscribers: true
```

**Paramètres :**
- `file` : Fichier CSV (obligatoire)
- `create_subscribers` : Créer automatiquement les abonnés (défaut: false)

**Format CSV attendu :**
```csv
nom_commune;code_insee;code_departement;population;email;nom_contact;code_postal;latitude;longitude
Aix-en-Provence;13001;13;145347;mairie@aixenprovence.fr;Jean Dupont;13100;43.5297;5.4474
```

**Colonnes obligatoires :**
- `nom_commune` : Nom de la commune
- `code_insee` : Code INSEE (5 caractères)
- `code_departement` : Code département

**Colonnes optionnelles :**
- `population` : Nombre d'habitants
- `email` : Adresse e-mail
- `nom_contact` : Nom du contact
- `code_postal` : Code postal
- `latitude` : Latitude (décimal)
- `longitude` : Longitude (décimal)

**Réponse :**
```json
{
  "data": {
    "total_records": 1000,
    "imported_records": 987,
    "skipped_records": 8,
    "error_records": 5,
    "errors": [
      "Line 15: Invalid INSEE code: 7500A",
      "Line 23: Invalid email format: invalid-email"
    ],
    "duration": "2.345s",
    "start_time": "2024-01-01T10:00:00Z",
    "end_time": "2024-01-01T10:00:02Z"
  }
}
```

## Endpoints Abonnés-Communes

### 1. Communes d'un Abonné

#### Obtenir les communes associées à un abonné
```http
GET /api/subscribers/{id}/communes
```

**Réponse :**
```json
{
  "data": [
    {
      "id": 1,
      "insee_code": "75001",
      "name": "Paris 1er Arrondissement",
      "department_code": "75",
      "population": 16888,
      "department_name": "Paris",
      "region": "Île-de-France"
    }
  ]
}
```

### 2. Associer un Abonné à une Commune

#### Créer une association abonné-commune
```http
POST /api/subscribers/{id}/communes
Content-Type: application/json

{
  "commune_id": 123
}
```

**Réponse :**
```json
{
  "data": "Association created successfully"
}
```

### 3. Supprimer une Association

#### Supprimer l'association abonné-commune
```http
DELETE /api/subscribers/{id}/communes/{commune_id}
```

**Réponse :**
```json
{
  "data": "Association removed successfully"
}
```

## Codes d'Erreur

### Erreurs Communes

| Code | Message | Description |
|------|---------|-------------|
| 400 | Bad Request | Paramètres invalides |
| 401 | Unauthorized | Authentification requise |
| 403 | Forbidden | Permissions insuffisantes |
| 404 | Not Found | Ressource non trouvée |
| 500 | Internal Server Error | Erreur serveur |

### Erreurs Spécifiques

#### Import CSV
- `invalid_csv_format` : Format CSV invalide
- `missing_required_columns` : Colonnes obligatoires manquantes
- `invalid_insee_code` : Code INSEE invalide
- `invalid_department_code` : Code département invalide
- `invalid_email_format` : Format d'e-mail invalide

#### Ciblage
- `invalid_targeting_filter` : Filtre de ciblage invalide
- `population_range_invalid` : Plage de population invalide
- `department_not_found` : Département non trouvé

## Exemples d'Utilisation

### Ciblage par Département et Population

```bash
# Compter les mairies d'Île-de-France avec plus de 10 000 habitants
curl -X POST http://localhost:9000/api/targeting/count \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "regions": ["Île-de-France"],
    "population_min": 10000
  }'
```

### Import de Données

```bash
# Importer un fichier CSV avec création d'abonnés
curl -X POST http://localhost:9000/api/geo/import \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@mairies.csv" \
  -F "create_subscribers=true"
```

### Recherche de Communes

```bash
# Rechercher toutes les communes contenant "Saint"
curl "http://localhost:9000/api/geo/communes/search?q=Saint&limit=50" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Filtrage Complexe

```bash
# Communes de 1000 à 5000 habitants dans le Nord et le Pas-de-Calais
curl "http://localhost:9000/api/geo/communes?department_codes=59,62&population_min=1000&population_max=5000&limit=100" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Limites et Quotas

- **Taille maximum des fichiers CSV** : 50 MB
- **Nombre maximum de résultats par requête** : 1000
- **Timeout des requêtes d'import** : 5 minutes
- **Cache TTL** : 1 heure pour les requêtes de statistiques

## Bonnes Pratiques

1. **Pagination** : Utilisez `limit` et `offset` pour les grandes listes
2. **Cache** : Les statistiques sont mises en cache, utilisez-les pour les dashboards
3. **Validation** : Validez toujours les codes INSEE et départements
4. **Monitoring** : Surveillez les imports pour détecter les erreurs
5. **Sécurité** : Utilisez HTTPS en production et des tokens API forts