#!/bin/bash

# Script de validation de l'intégration backend pour listmonk-mairies
# Teste les workflows d'import et de ciblage

set -e

echo "🚀 Validation de l'intégration backend listmonk-mairies"
echo "=================================================="

# Configuration
LISTMONK_URL="http://localhost:9000"
API_BASE="$LISTMONK_URL/api"
ADMIN_USER="admin"
ADMIN_PASS="listmonk"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Fonction pour attendre que le service soit prêt
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    log_info "Attente du démarrage de $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            log_success "$service_name est prêt"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_error "$service_name n'est pas accessible après $((max_attempts * 2)) secondes"
    return 1
}

# Fonction pour obtenir un token d'authentification
get_auth_token() {
    log_info "Authentification..."
    
    local response=$(curl -s -X POST "$API_BASE/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}")
    
    if echo "$response" | grep -q "token"; then
        local token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        echo "$token"
        log_success "Authentification réussie"
    else
        log_error "Échec de l'authentification"
        echo "$response"
        return 1
    fi
}

# Test 1: Vérification de l'état des services
test_services_health() {
    echo
    log_info "Test 1: Vérification de l'état des services"
    echo "----------------------------------------"
    
    # Test de l'application principale
    wait_for_service "$LISTMONK_URL/api/health" "Listmonk API"
    
    # Test de la base de données (via l'API health)
    if curl -s "$API_BASE/health" | grep -q "database.*ok"; then
        log_success "Base de données PostgreSQL accessible"
    else
        log_warning "État de la base de données incertain"
    fi
    
    # Test Redis (si configuré)
    if curl -s "$API_BASE/health" | grep -q "redis"; then
        log_success "Cache Redis accessible"
    else
        log_warning "Redis non configuré ou inaccessible"
    fi
}

# Test 2: Vérification des routes API mairies
test_mairies_api_routes() {
    echo
    log_info "Test 2: Vérification des routes API mairies"
    echo "----------------------------------------"
    
    local token=$(get_auth_token)
    if [ -z "$token" ]; then
        return 1
    fi
    
    local auth_header="Authorization: Bearer $token"
    
    # Test route départements
    log_info "Test de /api/mairies/departments"
    local dept_response=$(curl -s -H "$auth_header" "$API_BASE/mairies/departments")
    if echo "$dept_response" | grep -q "data"; then
        local dept_count=$(echo "$dept_response" | grep -o '"code":"[^"]*"' | wc -l)
        log_success "Route départements OK - $dept_count départements trouvés"
    else
        log_error "Route départements échouée"
        echo "$dept_response"
    fi
    
    # Test route recherche mairies
    log_info "Test de /api/mairies/search"
    local search_response=$(curl -s -H "$auth_header" "$API_BASE/mairies/search?limit=5")
    if echo "$search_response" | grep -q "data"; then
        local mairie_count=$(echo "$search_response" | grep -o '"name":"[^"]*"' | wc -l)
        log_success "Route recherche OK - $mairie_count mairies trouvées"
    else
        log_error "Route recherche échouée"
        echo "$search_response"
    fi
    
    # Test route template CSV
    log_info "Test de /api/mairies/csv-template"
    local template_response=$(curl -s -H "$auth_header" "$API_BASE/mairies/csv-template")
    if echo "$template_response" | grep -q "nom,email,population,departement"; then
        log_success "Template CSV OK"
    else
        log_error "Template CSV échoué"
        echo "$template_response"
    fi
    
    # Test route statistiques
    log_info "Test de /api/mairies/import/stats"
    local stats_response=$(curl -s -H "$auth_header" "$API_BASE/mairies/import/stats")
    if echo "$stats_response" | grep -q "total"; then
        log_success "Route statistiques OK"
    else
        log_warning "Route statistiques retourne une réponse inattendue"
        echo "$stats_response"
    fi
}

# Test 3: Vérification de la structure de base de données
test_database_structure() {
    echo
    log_info "Test 3: Vérification de la structure de base de données"
    echo "------------------------------------------------"
    
    # Test via l'API pour vérifier que les tables existent
    local token=$(get_auth_token)
    if [ -z "$token" ]; then
        return 1
    fi
    
    local auth_header="Authorization: Bearer $token"
    
    # Vérifier que les départements sont présents
    local dept_response=$(curl -s -H "$auth_header" "$API_BASE/mairies/departments")
    if echo "$dept_response" | grep -q '"code":"01"'; then
        log_success "Table departments peuplée correctement"
    else
        log_error "Table departments vide ou inaccessible"
    fi
    
    # Vérifier la structure via une recherche
    local search_response=$(curl -s -H "$auth_header" "$API_BASE/mairies/search?limit=1")
    if echo "$search_response" | grep -q '"total":'; then
        log_success "Table mairies accessible"
    else
        log_warning "Table mairies vide ou structure incorrecte"
    fi
}

# Test 4: Test du workflow d'import CSV
test_csv_import_workflow() {
    echo
    log_info "Test 4: Workflow d'import CSV"
    echo "----------------------------"
    
    local token=$(get_auth_token)
    if [ -z "$token" ]; then
        return 1
    fi
    
    local auth_header="Authorization: Bearer $token"
    
    # Créer un fichier CSV de test
    local test_csv="/tmp/test_mairies.csv"
    cat > "$test_csv" << EOF
nom,email,population,departement
Mairie Test 1,test1@mairie.fr,1500,01
Mairie Test 2,test2@mairie.fr,3000,75
Mairie Test 3,test3@mairie.fr,500,13
EOF
    
    log_info "Fichier CSV de test créé"
    
    # Test de validation du format
    log_info "Test de validation du format CSV"
    local validation_response=$(curl -s -X POST \
        -H "$auth_header" \
        -F "file=@$test_csv" \
        "$API_BASE/mairies/import/validate")
    
    if echo "$validation_response" | grep -q "valid.*true"; then
        log_success "Validation CSV réussie"
    else
        log_warning "Validation CSV échouée ou format inattendu"
        echo "$validation_response"
    fi
    
    # Nettoyage
    rm -f "$test_csv"
}

# Test 5: Test du workflow de ciblage
test_targeting_workflow() {
    echo
    log_info "Test 5: Workflow de ciblage"
    echo "---------------------------"
    
    local token=$(get_auth_token)
    if [ -z "$token" ]; then
        return 1
    fi
    
    local auth_header="Authorization: Bearer $token"
    
    # Test de filtrage par population
    log_info "Test de filtrage par population"
    local pop_response=$(curl -s -H "$auth_header" \
        "$API_BASE/mairies/search?min_population=1000&max_population=5000&limit=10")
    
    if echo "$pop_response" | grep -q "data"; then
        log_success "Filtrage par population fonctionnel"
    else
        log_error "Filtrage par population échoué"
    fi
    
    # Test de filtrage par département
    log_info "Test de filtrage par département"
    local dept_response=$(curl -s -H "$auth_header" \
        "$API_BASE/mairies/search?departments=75,92&limit=10")
    
    if echo "$dept_response" | grep -q "data"; then
        log_success "Filtrage par département fonctionnel"
    else
        log_error "Filtrage par département échoué"
    fi
    
    # Test d'export
    log_info "Test d'export des résultats"
    local export_response=$(curl -s -H "$auth_header" \
        "$API_BASE/mairies/export?format=csv&limit=5")
    
    if echo "$export_response" | grep -q "nom,email"; then
        log_success "Export CSV fonctionnel"
    else
        log_warning "Export CSV format inattendu"
    fi
}

# Test 6: Test de l'interface frontend
test_frontend_integration() {
    echo
    log_info "Test 6: Intégration frontend"
    echo "----------------------------"
    
    # Test de la page d'import
    log_info "Test de la page d'import des mairies"
    local import_page=$(curl -s "$LISTMONK_URL/mairies/import")
    if echo "$import_page" | grep -q "mairies.*import"; then
        log_success "Page d'import accessible"
    else
        log_warning "Page d'import non trouvée ou contenu inattendu"
    fi
    
    # Test de la page de ciblage
    log_info "Test de la page de ciblage"
    local targeting_page=$(curl -s "$LISTMONK_URL/mairies/targeting")
    if echo "$targeting_page" | grep -q "mairies.*targeting"; then
        log_success "Page de ciblage accessible"
    else
        log_warning "Page de ciblage non trouvée ou contenu inattendu"
    fi
    
    # Test des assets frontend
    log_info "Test des assets frontend"
    if curl -s "$LISTMONK_URL/frontend/dist/assets/" | grep -q "css\|js"; then
        log_success "Assets frontend disponibles"
    else
        log_warning "Assets frontend non trouvés"
    fi
}

# Fonction principale
main() {
    echo "Début de la validation à $(date)"
    echo
    
    # Vérifier que Docker Compose est en cours d'exécution
    if ! docker compose -f docker-compose.mairies.yml ps | grep -q "Up"; then
        log_error "Les services Docker ne semblent pas être en cours d'exécution"
        log_info "Lancez d'abord: docker compose -f docker-compose.mairies.yml up -d"
        exit 1
    fi
    
    # Exécuter tous les tests
    test_services_health
    test_mairies_api_routes
    test_database_structure
    test_csv_import_workflow
    test_targeting_workflow
    test_frontend_integration
    
    echo
    echo "=================================================="
    log_success "Validation terminée à $(date)"
    echo
    log_info "Pour tester manuellement:"
    echo "  - Interface web: $LISTMONK_URL"
    echo "  - Import mairies: $LISTMONK_URL/mairies/import"
    echo "  - Ciblage: $LISTMONK_URL/mairies/targeting"
    echo "  - API docs: $API_BASE/docs"
    echo
}

# Exécution du script
main "$@"