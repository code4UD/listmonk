#!/bin/bash

# Script pour forcer l'exécution de la migration des mairies
# À utiliser si les tables ne sont pas créées automatiquement

echo "🔧 Forçage de la migration des tables mairies..."

# Connexion à la base de données et exécution du script
docker exec -i listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies < scripts/init-mairies.sql

echo "✅ Migration forcée terminée"

# Vérification que les tables existent
echo "🔍 Vérification des tables créées..."
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "\dt"

echo "📊 Vérification du contenu des départements..."
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) as nb_departments FROM departments;"

echo "🏛️ Vérification du contenu des mairies..."
docker exec listmonk_mairies_db psql -U listmonk_mairies -d listmonk_mairies -c "SELECT COUNT(*) as nb_mairies FROM mairies;"

echo "🎉 Vérification terminée !"