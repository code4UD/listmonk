# Architecture pour l'adaptation Mairies Françaises

## Vue d'ensemble

Cette documentation décrit l'architecture pour adapter listmonk aux besoins spécifiques des mairies françaises, en ajoutant des fonctionnalités de ciblage géographique et démographique.

## Modifications de la base de données

### Extension du schéma existant

Nous utiliserons le champ `attribs` JSONB existant des subscribers pour stocker les données géographiques, mais nous ajouterons également des tables dédiées pour optimiser les requêtes.

#### Nouvelles tables

```sql
-- Table pour les départements français
CREATE TABLE french_departments (
    id SERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,  -- 01-95, 2A, 2B, 971-978
    name VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table pour les communes/mairies
CREATE TABLE french_communes (
    id SERIAL PRIMARY KEY,
    insee_code VARCHAR(5) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    department_code VARCHAR(3) NOT NULL REFERENCES french_departments(code),
    population INTEGER NOT NULL DEFAULT 0,
    postal_codes VARCHAR(20)[], -- Peut avoir plusieurs codes postaux
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour optimiser les requêtes de filtrage
CREATE INDEX idx_communes_department ON french_communes(department_code);
CREATE INDEX idx_communes_population ON french_communes(population);
CREATE INDEX idx_communes_name ON french_communes(name);

-- Table de liaison pour associer les subscribers aux communes
CREATE TABLE subscriber_communes (
    subscriber_id INTEGER REFERENCES subscribers(id) ON DELETE CASCADE,
    commune_id INTEGER REFERENCES french_communes(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY(subscriber_id, commune_id)
);

-- Index pour optimiser les requêtes de ciblage
CREATE INDEX idx_sub_communes_subscriber ON subscriber_communes(subscriber_id);
CREATE INDEX idx_sub_communes_commune ON subscriber_communes(commune_id);
```

### Structure des attributs JSON pour les mairies

Dans le champ `attribs` des subscribers, nous stockerons :

```json
{
  "commune": {
    "insee_code": "75001",
    "name": "Paris 1er Arrondissement",
    "department_code": "75",
    "department_name": "Paris",
    "population": 16888,
    "postal_codes": ["75001"],
    "region": "Île-de-France"
  },
  "contact_type": "mairie",
  "contact_role": "maire" // ou "secretaire", "adjoint", etc.
}
```

## Backend (Go)

### Nouveaux modules

#### 1. Module `internal/geo` - Gestion des données géographiques

```go
// internal/geo/models.go
type Department struct {
    ID     int    `db:"id" json:"id"`
    Code   string `db:"code" json:"code"`
    Name   string `db:"name" json:"name"`
    Region string `db:"region" json:"region"`
    Base
}

type Commune struct {
    ID             int      `db:"id" json:"id"`
    InseeCode      string   `db:"insee_code" json:"insee_code"`
    Name           string   `db:"name" json:"name"`
    DepartmentCode string   `db:"department_code" json:"department_code"`
    Population     int      `db:"population" json:"population"`
    PostalCodes    []string `db:"postal_codes" json:"postal_codes"`
    Latitude       float64  `db:"latitude" json:"latitude"`
    Longitude      float64  `db:"longitude" json:"longitude"`
    Base
}

type TargetingFilter struct {
    DepartmentCodes []string `json:"department_codes"`
    PopulationMin   int      `json:"population_min"`
    PopulationMax   int      `json:"population_max"`
    Regions         []string `json:"regions"`
}
```

#### 2. Module `internal/importer` - Import des données CSV

```go
// internal/importer/csv.go
type MairieCSVRecord struct {
    CommuneName    string `csv:"nom_commune"`
    InseeCode      string `csv:"code_insee"`
    DepartmentCode string `csv:"code_departement"`
    Population     int    `csv:"population"`
    Email          string `csv:"email"`
    ContactName    string `csv:"nom_contact"`
    PostalCode     string `csv:"code_postal"`
}

func ImportMairiesFromCSV(filePath string) error {
    // Logique d'import avec validation
}
```

### Nouvelles APIs REST

#### Endpoints pour la gestion géographique

```
GET    /api/geo/departments           - Liste des départements
GET    /api/geo/communes              - Liste des communes (avec filtres)
GET    /api/geo/communes/search       - Recherche de communes
POST   /api/geo/import                - Import de données CSV
GET    /api/geo/stats                 - Statistiques géographiques
```

#### Endpoints pour le ciblage

```
POST   /api/targeting/preview         - Prévisualisation du ciblage
POST   /api/targeting/count           - Nombre de destinataires
GET    /api/targeting/filters         - Filtres disponibles
```

#### Extension des APIs existantes

```
GET    /api/subscribers?department=75&population_min=1000&population_max=5000
POST   /api/campaigns (avec targeting_filters dans le body)
```

## Frontend (Vue.js)

### Nouveaux composants

#### 1. Composant de carte géographique

```vue
<!-- src/components/GeoMap.vue -->
<template>
  <div class="geo-map">
    <l-map :zoom="zoom" :center="center">
      <l-tile-layer :url="tileUrl"></l-tile-layer>
      <l-geo-json 
        :geojson="departmentsGeoJson" 
        :options="geoJsonOptions"
        @click="onDepartmentClick">
      </l-geo-json>
    </l-map>
  </div>
</template>
```

#### 2. Composant de filtrage avancé

```vue
<!-- src/components/TargetingFilters.vue -->
<template>
  <div class="targeting-filters">
    <b-field label="Départements">
      <b-taginput 
        v-model="selectedDepartments"
        :data="availableDepartments"
        autocomplete
        field="name"
        placeholder="Sélectionner des départements">
      </b-taginput>
    </b-field>
    
    <b-field label="Population">
      <b-slider 
        v-model="populationRange"
        :min="0"
        :max="3000000"
        range>
      </b-slider>
    </b-field>
  </div>
</template>
```

#### 3. Dashboard géographique

```vue
<!-- src/views/GeoDashboard.vue -->
<template>
  <div class="geo-dashboard">
    <div class="columns">
      <div class="column is-8">
        <GeoMap :data="mapData" @selection-change="updateStats" />
      </div>
      <div class="column is-4">
        <GeoStats :stats="geoStats" />
        <TargetingPreview :filters="currentFilters" />
      </div>
    </div>
  </div>
</template>
```

### Modifications des vues existantes

#### Extension de la création de campagne

```vue
<!-- src/views/Campaign.vue - ajout d'un onglet ciblage -->
<b-tabs v-model="activeTab">
  <b-tab-item label="Contenu">
    <!-- Contenu existant -->
  </b-tab-item>
  <b-tab-item label="Ciblage Géographique">
    <TargetingFilters 
      v-model="campaign.targeting_filters"
      @change="updateTargetingPreview" />
    <TargetingPreview :count="targetingCount" :filters="campaign.targeting_filters" />
  </b-tab-item>
  <b-tab-item label="Listes">
    <!-- Sélection de listes existante -->
  </b-tab-item>
</b-tabs>
```

## Configuration Docker

### Dockerfile multi-stage optimisé

```dockerfile
# Build stage pour le frontend
FROM node:18-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production
COPY frontend/ ./
RUN npm run build

# Build stage pour le backend
FROM golang:1.24-alpine AS backend-builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist
RUN go build -ldflags="-s -w" -o listmonk ./cmd

# Production stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /listmonk
COPY --from=backend-builder /app/listmonk .
COPY --from=backend-builder /app/config.toml.sample .
COPY --from=backend-builder /app/queries.sql .
COPY --from=backend-builder /app/schema.sql .
EXPOSE 9000
CMD ["./listmonk"]
```

### Docker Compose avec Redis pour le cache

```yaml
version: '3.8'

services:
  app:
    build: .
    container_name: listmonk_mairies_app
    restart: unless-stopped
    ports:
      - "9000:9000"
    depends_on:
      - db
      - redis
    environment:
      LISTMONK_app__address: 0.0.0.0:9000
      LISTMONK_db__host: listmonk_db
      LISTMONK_redis__host: listmonk_redis
      # ... autres variables

  db:
    image: postgres:17-alpine
    container_name: listmonk_mairies_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: listmonk_mairies
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-geo-data.sql:/docker-entrypoint-initdb.d/init-geo-data.sql

  redis:
    image: redis:7-alpine
    container_name: listmonk_mairies_redis
    restart: unless-stopped
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

## Stratégie de cache

### Cache Redis pour les requêtes géographiques

```go
// internal/cache/geo.go
type GeoCache struct {
    redis *redis.Client
}

func (c *GeoCache) GetDepartmentCommunes(deptCode string) ([]Commune, error) {
    key := fmt.Sprintf("dept:communes:%s", deptCode)
    // Logique de cache avec TTL de 1 heure
}

func (c *GeoCache) GetTargetingCount(filters TargetingFilter) (int, error) {
    key := fmt.Sprintf("targeting:count:%s", filters.Hash())
    // Cache des comptages avec TTL de 15 minutes
}
```

## Migration et déploiement

### Script de migration

```sql
-- migrations/v5.1.0_geo_tables.sql
-- Création des tables géographiques
-- Import des données de base (départements)
-- Index optimisés
```

### Script d'import initial

```bash
#!/bin/bash
# scripts/import-mairies-data.sh
# Import du fichier CSV des mairies
# Validation des données
# Mise à jour des index
```

## Tests

### Tests unitaires pour les nouvelles fonctionnalités

```go
// internal/geo/geo_test.go
func TestTargetingFilters(t *testing.T) {
    // Tests des filtres de ciblage
}

func TestCSVImport(t *testing.T) {
    // Tests d'import CSV
}
```

### Tests d'intégration Docker

```bash
# tests/docker/test-geo-features.sh
# Tests des fonctionnalités géographiques en environnement Docker
```

## Métriques et monitoring

### Nouvelles métriques spécifiques

- Nombre de mairies par département
- Taux d'ouverture par tranche de population
- Performance des requêtes de ciblage géographique
- Utilisation du cache Redis

### Dashboard de monitoring

Extension du dashboard existant avec :
- Carte de France interactive
- Statistiques par région/département
- Métriques de performance des requêtes géographiques

## Sécurité

### Validation des données

- Validation stricte des codes INSEE
- Vérification des codes départements
- Sanitisation des données CSV importées

### Contrôle d'accès

- Permissions spécifiques pour l'import de données
- Audit trail des modifications géographiques

## Documentation

### Documentation utilisateur

- Guide d'import des données de mairies
- Tutoriel de ciblage géographique
- FAQ spécifique aux mairies françaises

### Documentation technique

- API documentation pour les nouveaux endpoints
- Guide de déploiement Docker
- Procédures de maintenance et mise à jour