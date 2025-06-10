-- Script d'initialisation pour les tables des mairies françaises
-- Ce script sera exécuté automatiquement lors de l'initialisation de la base de données

-- Create departments table
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    region VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create mairies table
CREATE TABLE IF NOT EXISTS mairies (
    id SERIAL PRIMARY KEY,
    nom_commune VARCHAR(255) NOT NULL,
    code_insee VARCHAR(10) NOT NULL UNIQUE,
    code_departement VARCHAR(3) NOT NULL,
    population INTEGER DEFAULT 0,
    email VARCHAR(255),
    nom_contact VARCHAR(255),
    code_postal VARCHAR(10),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (code_departement) REFERENCES departments(code)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_mairies_departement ON mairies(code_departement);
CREATE INDEX IF NOT EXISTS idx_mairies_population ON mairies(population);
CREATE INDEX IF NOT EXISTS idx_mairies_email ON mairies(email);
CREATE INDEX IF NOT EXISTS idx_mairies_location ON mairies(latitude, longitude);

-- Insert French departments data
INSERT INTO departments (code, name, region) VALUES
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
    ('2A', 'Corse-du-Sud', 'Corse'),
    ('2B', 'Haute-Corse', 'Corse'),
    ('971', 'Guadeloupe', 'Guadeloupe'),
    ('972', 'Martinique', 'Martinique'),
    ('973', 'Guyane', 'Guyane'),
    ('974', 'La Réunion', 'La Réunion'),
    ('976', 'Mayotte', 'Mayotte')
ON CONFLICT (code) DO NOTHING;

-- Insert some sample mairies data for testing
INSERT INTO mairies (nom_commune, code_insee, code_departement, population, email, nom_contact, code_postal, latitude, longitude) VALUES
    ('Paris', '75056', '75', 2161000, 'contact@paris.fr', 'Mairie de Paris', '75001', 48.8566, 2.3522),
    ('Marseille', '13055', '13', 861635, 'contact@marseille.fr', 'Mairie de Marseille', '13001', 43.2965, 5.3698),
    ('Lyon', '69123', '69', 515695, 'contact@lyon.fr', 'Mairie de Lyon', '69001', 45.7640, 4.8357),
    ('Toulouse', '31555', '31', 471941, 'contact@toulouse.fr', 'Mairie de Toulouse', '31000', 43.6047, 1.4442),
    ('Nice', '06088', '06', 342637, 'contact@nice.fr', 'Mairie de Nice', '06000', 43.7102, 7.2620),
    ('Nantes', '44109', '44', 309346, 'contact@nantes.fr', 'Mairie de Nantes', '44000', 47.2184, -1.5536),
    ('Montpellier', '34172', '34', 285121, 'contact@montpellier.fr', 'Mairie de Montpellier', '34000', 43.6110, 3.8767),
    ('Strasbourg', '67482', '67', 280966, 'contact@strasbourg.fr', 'Mairie de Strasbourg', '67000', 48.5734, 7.7521),
    ('Bordeaux', '33063', '33', 254436, 'contact@bordeaux.fr', 'Mairie de Bordeaux', '33000', 44.8378, -0.5792),
    ('Lille', '59350', '59', 232741, 'contact@lille.fr', 'Mairie de Lille', '59000', 50.6292, 3.0573)
ON CONFLICT (code_insee) DO NOTHING;

-- Log completion
SELECT 'Tables mairies et departments créées avec succès' as status;