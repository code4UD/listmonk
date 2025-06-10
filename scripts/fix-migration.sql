-- Script pour corriger la migration et créer les bonnes tables

-- Supprimer les anciennes tables si elles existent
DROP TABLE IF EXISTS subscriber_communes CASCADE;
DROP TABLE IF EXISTS french_communes CASCADE;
DROP TABLE IF EXISTS french_departments CASCADE;
DROP VIEW IF EXISTS targeting_view CASCADE;
DROP FUNCTION IF EXISTS count_targeting_recipients CASCADE;

-- Créer les nouvelles tables avec les bons noms
-- Table pour les départements français
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,  -- 01-95, 2A, 2B, 971-978
    name VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table pour les communes/mairies
CREATE TABLE IF NOT EXISTS mairies (
    id SERIAL PRIMARY KEY,
    insee_code VARCHAR(5),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    department_code VARCHAR(3) NOT NULL REFERENCES departments(code),
    population INTEGER NOT NULL DEFAULT 0,
    postal_codes VARCHAR(20)[], -- Peut avoir plusieurs codes postaux
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour optimiser les requêtes de filtrage
CREATE INDEX IF NOT EXISTS idx_mairies_department ON mairies(department_code);
CREATE INDEX IF NOT EXISTS idx_mairies_population ON mairies(population);
CREATE INDEX IF NOT EXISTS idx_mairies_name ON mairies(name);
CREATE INDEX IF NOT EXISTS idx_mairies_insee ON mairies(insee_code);
CREATE INDEX IF NOT EXISTS idx_mairies_email ON mairies(email);

-- Table de liaison pour associer les subscribers aux communes
CREATE TABLE IF NOT EXISTS subscriber_mairies (
    subscriber_id INTEGER REFERENCES subscribers(id) ON DELETE CASCADE,
    mairie_id INTEGER REFERENCES mairies(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY(subscriber_id, mairie_id)
);

-- Index pour optimiser les requêtes de ciblage
CREATE INDEX IF NOT EXISTS idx_sub_mairies_subscriber ON subscriber_mairies(subscriber_id);
CREATE INDEX IF NOT EXISTS idx_sub_mairies_mairie ON subscriber_mairies(mairie_id);

-- Insertion des données de base des départements français
INSERT INTO departments (code, name, region) VALUES
-- Métropole
('01', 'Ain', 'Auvergne-Rhône-Alpes'),
('02', 'Aisne', 'Hauts-de-France'),
('03', 'Allier', 'Auvergne-Rhône-Alpes'),
('04', 'Alpes-de-Haute-Provence', 'Provence-Alpes-Côte d''Azur'),
('05', 'Hautes-Alpes', 'Provence-Alpes-Côte d''Azur'),
('06', 'Alpes-Maritimes', 'Provence-Alpes-Côte d''Azur'),
('07', 'Ardèche', 'Auvergne-Rhône-Alpes'),
('08', 'Ardennes', 'Grand Est'),
('09', 'Ariège', 'Occitanie'),
('10', 'Aube', 'Grand Est'),
('11', 'Aude', 'Occitanie'),
('12', 'Aveyron', 'Occitanie'),
('13', 'Bouches-du-Rhône', 'Provence-Alpes-Côte d''Azur'),
('14', 'Calvados', 'Normandie'),
('15', 'Cantal', 'Auvergne-Rhône-Alpes'),
('16', 'Charente', 'Nouvelle-Aquitaine'),
('17', 'Charente-Maritime', 'Nouvelle-Aquitaine'),
('18', 'Cher', 'Centre-Val de Loire'),
('19', 'Corrèze', 'Nouvelle-Aquitaine'),
('2A', 'Corse-du-Sud', 'Corse'),
('2B', 'Haute-Corse', 'Corse'),
('21', 'Côte-d''Or', 'Bourgogne-Franche-Comté'),
('22', 'Côtes-d''Armor', 'Bretagne'),
('23', 'Creuse', 'Nouvelle-Aquitaine'),
('24', 'Dordogne', 'Nouvelle-Aquitaine'),
('25', 'Doubs', 'Bourgogne-Franche-Comté'),
('26', 'Drôme', 'Auvergne-Rhône-Alpes'),
('27', 'Eure', 'Normandie'),
('28', 'Eure-et-Loir', 'Centre-Val de Loire'),
('29', 'Finistère', 'Bretagne'),
('30', 'Gard', 'Occitanie'),
('31', 'Haute-Garonne', 'Occitanie'),
('32', 'Gers', 'Occitanie'),
('33', 'Gironde', 'Nouvelle-Aquitaine'),
('34', 'Hérault', 'Occitanie'),
('35', 'Ille-et-Vilaine', 'Bretagne'),
('36', 'Indre', 'Centre-Val de Loire'),
('37', 'Indre-et-Loire', 'Centre-Val de Loire'),
('38', 'Isère', 'Auvergne-Rhône-Alpes'),
('39', 'Jura', 'Bourgogne-Franche-Comté'),
('40', 'Landes', 'Nouvelle-Aquitaine'),
('41', 'Loir-et-Cher', 'Centre-Val de Loire'),
('42', 'Loire', 'Auvergne-Rhône-Alpes'),
('43', 'Haute-Loire', 'Auvergne-Rhône-Alpes'),
('44', 'Loire-Atlantique', 'Pays de la Loire'),
('45', 'Loiret', 'Centre-Val de Loire'),
('46', 'Lot', 'Occitanie'),
('47', 'Lot-et-Garonne', 'Nouvelle-Aquitaine'),
('48', 'Lozère', 'Occitanie'),
('49', 'Maine-et-Loire', 'Pays de la Loire'),
('50', 'Manche', 'Normandie'),
('51', 'Marne', 'Grand Est'),
('52', 'Haute-Marne', 'Grand Est'),
('53', 'Mayenne', 'Pays de la Loire'),
('54', 'Meurthe-et-Moselle', 'Grand Est'),
('55', 'Meuse', 'Grand Est'),
('56', 'Morbihan', 'Bretagne'),
('57', 'Moselle', 'Grand Est'),
('58', 'Nièvre', 'Bourgogne-Franche-Comté'),
('59', 'Nord', 'Hauts-de-France'),
('60', 'Oise', 'Hauts-de-France'),
('61', 'Orne', 'Normandie'),
('62', 'Pas-de-Calais', 'Hauts-de-France'),
('63', 'Puy-de-Dôme', 'Auvergne-Rhône-Alpes'),
('64', 'Pyrénées-Atlantiques', 'Nouvelle-Aquitaine'),
('65', 'Hautes-Pyrénées', 'Occitanie'),
('66', 'Pyrénées-Orientales', 'Occitanie'),
('67', 'Bas-Rhin', 'Grand Est'),
('68', 'Haut-Rhin', 'Grand Est'),
('69', 'Rhône', 'Auvergne-Rhône-Alpes'),
('70', 'Haute-Saône', 'Bourgogne-Franche-Comté'),
('71', 'Saône-et-Loire', 'Bourgogne-Franche-Comté'),
('72', 'Sarthe', 'Pays de la Loire'),
('73', 'Savoie', 'Auvergne-Rhône-Alpes'),
('74', 'Haute-Savoie', 'Auvergne-Rhône-Alpes'),
('75', 'Paris', 'Île-de-France'),
('76', 'Seine-Maritime', 'Normandie'),
('77', 'Seine-et-Marne', 'Île-de-France'),
('78', 'Yvelines', 'Île-de-France'),
('79', 'Deux-Sèvres', 'Nouvelle-Aquitaine'),
('80', 'Somme', 'Hauts-de-France'),
('81', 'Tarn', 'Occitanie'),
('82', 'Tarn-et-Garonne', 'Occitanie'),
('83', 'Var', 'Provence-Alpes-Côte d''Azur'),
('84', 'Vaucluse', 'Provence-Alpes-Côte d''Azur'),
('85', 'Vendée', 'Pays de la Loire'),
('86', 'Vienne', 'Nouvelle-Aquitaine'),
('87', 'Haute-Vienne', 'Nouvelle-Aquitaine'),
('88', 'Vosges', 'Grand Est'),
('89', 'Yonne', 'Bourgogne-Franche-Comté'),
('90', 'Territoire de Belfort', 'Bourgogne-Franche-Comté'),
('91', 'Essonne', 'Île-de-France'),
('92', 'Hauts-de-Seine', 'Île-de-France'),
('93', 'Seine-Saint-Denis', 'Île-de-France'),
('94', 'Val-de-Marne', 'Île-de-France'),
('95', 'Val-d''Oise', 'Île-de-France'),
-- Outre-mer
('971', 'Guadeloupe', 'Guadeloupe'),
('972', 'Martinique', 'Martinique'),
('973', 'Guyane', 'Guyane'),
('974', 'La Réunion', 'La Réunion'),
('975', 'Saint-Pierre-et-Miquelon', 'Saint-Pierre-et-Miquelon'),
('976', 'Mayotte', 'Mayotte'),
('977', 'Saint-Barthélemy', 'Saint-Barthélemy'),
('978', 'Saint-Martin', 'Saint-Martin')
ON CONFLICT (code) DO NOTHING;

-- Ajout de quelques mairies de test
INSERT INTO mairies (name, email, department_code, population) VALUES
('Mairie de Paris', 'contact@paris.fr', '75', 2161000),
('Mairie de Marseille', 'contact@marseille.fr', '13', 870000),
('Mairie de Lyon', 'contact@lyon.fr', '69', 515000),
('Mairie de Toulouse', 'contact@toulouse.fr', '31', 479000),
('Mairie de Nice', 'contact@nice.fr', '06', 342000),
('Mairie de Nantes', 'contact@nantes.fr', '44', 309000),
('Mairie de Montpellier', 'contact@montpellier.fr', '34', 285000),
('Mairie de Strasbourg', 'contact@strasbourg.fr', '67', 280000),
('Mairie de Bordeaux', 'contact@bordeaux.fr', '33', 254000),
('Mairie de Lille', 'contact@lille.fr', '59', 232000)
ON CONFLICT DO NOTHING;

-- Ajout d'une vue pour faciliter les requêtes de ciblage
CREATE OR REPLACE VIEW targeting_view AS
SELECT 
    s.id as subscriber_id,
    s.email,
    s.name,
    s.status,
    m.id as mairie_id,
    m.name as mairie_name,
    m.insee_code,
    m.population,
    m.department_code,
    d.name as department_name,
    d.region
FROM subscribers s
LEFT JOIN subscriber_mairies sm ON s.id = sm.subscriber_id
LEFT JOIN mairies m ON sm.mairie_id = m.id
LEFT JOIN departments d ON m.department_code = d.code;

-- Fonction pour calculer le nombre de destinataires selon des critères
CREATE OR REPLACE FUNCTION count_targeting_recipients(
    dept_codes TEXT[] DEFAULT NULL,
    pop_min INTEGER DEFAULT NULL,
    pop_max INTEGER DEFAULT NULL,
    regions TEXT[] DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    result INTEGER;
BEGIN
    SELECT COUNT(DISTINCT s.id) INTO result
    FROM subscribers s
    LEFT JOIN subscriber_mairies sm ON s.id = sm.subscriber_id
    LEFT JOIN mairies m ON sm.mairie_id = m.id
    LEFT JOIN departments d ON m.department_code = d.code
    WHERE s.status = 'enabled'
    AND (dept_codes IS NULL OR m.department_code = ANY(dept_codes))
    AND (pop_min IS NULL OR m.population >= pop_min)
    AND (pop_max IS NULL OR m.population <= pop_max)
    AND (regions IS NULL OR d.region = ANY(regions));
    
    RETURN COALESCE(result, 0);
END;
$$ LANGUAGE plpgsql;