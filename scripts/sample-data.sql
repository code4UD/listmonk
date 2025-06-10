-- Sample data for testing the French municipalities features
-- This script inserts sample communes and subscribers for testing

-- Insert sample communes for testing
INSERT INTO french_communes (insee_code, name, department_code, population, postal_codes, latitude, longitude) VALUES
-- Paris area
('75001', 'Paris 1er Arrondissement', '75', 16888, ARRAY['75001'], 48.8606, 2.3376),
('75020', 'Paris 20e Arrondissement', '75', 196926, ARRAY['75020'], 48.8631, 2.3969),
('92001', 'Antony', '92', 62760, ARRAY['92160'], 48.7543, 2.2978),
('92002', 'Asnières-sur-Seine', '92', 86742, ARRAY['92600'], 48.9146, 2.2874),
('93001', 'Aubervilliers', '93', 86742, ARRAY['93300'], 48.9146, 2.3874),

-- Lyon area
('69001', 'Lyon 1er Arrondissement', '69', 29463, ARRAY['69001'], 45.7640, 4.8357),
('69002', 'Lyon 2e Arrondissement', '69', 31894, ARRAY['69002'], 45.7578, 4.8320),
('69123', 'Villeurbanne', '69', 149019, ARRAY['69100'], 45.7665, 4.8795),

-- Marseille area
('13001', 'Marseille 1er Arrondissement', '13', 158454, ARRAY['13001'], 43.2965, 5.3698),
('13055', 'Marseille', '13', 870018, ARRAY['13001', '13002', '13003', '13004', '13005', '13006', '13007', '13008', '13009', '13010', '13011', '13012', '13013', '13014', '13015', '13016'], 43.2965, 5.3698),

-- Small communes for testing population filters
('01001', 'L''Abergement-Clémenciat', '01', 767, ARRAY['01400'], 46.1547, 4.9267),
('01002', 'L''Abergement-de-Varey', '01', 205, ARRAY['01640'], 45.8267, 5.4267),
('02001', 'Abbécourt', '02', 89, ARRAY['02300'], 49.3267, 3.4267),
('03001', 'Abrest', '03', 2847, ARRAY['03200'], 46.1267, 3.4267),

-- Corsica
('2A001', 'Afa', '2A', 2847, ARRAY['20167'], 41.9267, 8.7267),
('2B001', 'Aghione', '2B', 189, ARRAY['20270'], 42.2267, 9.3267),

-- Overseas
('97101', 'Les Abymes', '971', 56388, ARRAY['97139'], 16.2667, -61.5000),
('97201', 'Fort-de-France', '972', 80041, ARRAY['97200'], 14.6037, -61.0594)

ON CONFLICT (insee_code) DO UPDATE SET
    name = EXCLUDED.name,
    population = EXCLUDED.population,
    postal_codes = EXCLUDED.postal_codes,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    updated_at = NOW();

-- Insert sample subscribers (mairies)
INSERT INTO subscribers (uuid, email, name, attribs, status) VALUES
(gen_random_uuid(), 'mairie@paris1.fr', 'Mairie du 1er arrondissement de Paris', 
 '{"commune": {"insee_code": "75001", "name": "Paris 1er Arrondissement", "department_code": "75", "population": 16888}, "contact_type": "mairie", "contact_role": "maire"}', 'enabled'),

(gen_random_uuid(), 'contact@antony92.fr', 'Mairie d''Antony', 
 '{"commune": {"insee_code": "92001", "name": "Antony", "department_code": "92", "population": 62760}, "contact_type": "mairie", "contact_role": "secretaire"}', 'enabled'),

(gen_random_uuid(), 'mairie@lyon1.fr', 'Mairie du 1er arrondissement de Lyon', 
 '{"commune": {"insee_code": "69001", "name": "Lyon 1er Arrondissement", "department_code": "69", "population": 29463}, "contact_type": "mairie", "contact_role": "maire"}', 'enabled'),

(gen_random_uuid(), 'contact@villeurbanne.fr', 'Mairie de Villeurbanne', 
 '{"commune": {"insee_code": "69123", "name": "Villeurbanne", "department_code": "69", "population": 149019}, "contact_type": "mairie", "contact_role": "adjoint"}', 'enabled'),

(gen_random_uuid(), 'mairie@marseille.fr', 'Mairie de Marseille', 
 '{"commune": {"insee_code": "13055", "name": "Marseille", "department_code": "13", "population": 870018}, "contact_type": "mairie", "contact_role": "maire"}', 'enabled'),

(gen_random_uuid(), 'mairie@abergement-clemenciat.fr', 'Mairie de L''Abergement-Clémenciat', 
 '{"commune": {"insee_code": "01001", "name": "L''Abergement-Clémenciat", "department_code": "01", "population": 767}, "contact_type": "mairie", "contact_role": "maire"}', 'enabled'),

(gen_random_uuid(), 'contact@abrest.fr', 'Mairie d''Abrest', 
 '{"commune": {"insee_code": "03001", "name": "Abrest", "department_code": "03", "population": 2847}, "contact_type": "mairie", "contact_role": "secretaire"}', 'enabled'),

(gen_random_uuid(), 'mairie@afa.corsica', 'Mairie d''Afa', 
 '{"commune": {"insee_code": "2A001", "name": "Afa", "department_code": "2A", "population": 2847}, "contact_type": "mairie", "contact_role": "maire"}', 'enabled'),

(gen_random_uuid(), 'mairie@lesabymes.gp', 'Mairie des Abymes', 
 '{"commune": {"insee_code": "97101", "name": "Les Abymes", "department_code": "971", "population": 56388}, "contact_type": "mairie", "contact_role": "maire"}', 'enabled'),

(gen_random_uuid(), 'contact@fortdefrance.mq', 'Mairie de Fort-de-France', 
 '{"commune": {"insee_code": "97201", "name": "Fort-de-France", "department_code": "972", "population": 80041}, "contact_type": "mairie", "contact_role": "adjoint"}', 'enabled')

ON CONFLICT (email) DO NOTHING;

-- Associate subscribers with communes
INSERT INTO subscriber_communes (subscriber_id, commune_id)
SELECT s.id, c.id
FROM subscribers s
JOIN french_communes c ON (s.attribs->>'commune')::jsonb->>'insee_code' = c.insee_code
WHERE s.attribs->>'contact_type' = 'mairie'
ON CONFLICT (subscriber_id, commune_id) DO NOTHING;

-- Create a sample list for French municipalities
INSERT INTO lists (uuid, name, type, optin, description) VALUES
(gen_random_uuid(), 'Mairies de France', 'private', 'single', 'Liste des mairies françaises pour les communications officielles')
ON CONFLICT (name) DO NOTHING;

-- Add all mairie subscribers to the list
INSERT INTO subscriber_lists (subscriber_id, list_id, status)
SELECT s.id, l.id, 'confirmed'
FROM subscribers s
CROSS JOIN lists l
WHERE s.attribs->>'contact_type' = 'mairie'
AND l.name = 'Mairies de France'
ON CONFLICT (subscriber_id, list_id) DO NOTHING;

-- Insert sample campaign template for municipalities
INSERT INTO templates (name, type, subject, body, is_default) VALUES
('Template Mairies', 'campaign', 'Communication aux mairies françaises', 
'<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>{{ .Campaign.Subject }}</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <header style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #1e3a8a;">{{ .Campaign.Subject }}</h1>
        </header>
        
        <main>
            <p>Madame la Maire, Monsieur le Maire,</p>
            
            <div style="background-color: #f8fafc; padding: 20px; border-left: 4px solid #3b82f6; margin: 20px 0;">
                {{ .Campaign.Body }}
            </div>
            
            <p>Nous vous remercions pour votre attention.</p>
            
            <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
                <p><strong>Informations de votre commune :</strong></p>
                <ul style="list-style: none; padding: 0;">
                    {{ if .Subscriber.Attribs.commune }}
                    <li>📍 Commune : {{ .Subscriber.Attribs.commune.name }}</li>
                    <li>🏛️ Département : {{ .Subscriber.Attribs.commune.department_code }}</li>
                    <li>👥 Population : {{ .Subscriber.Attribs.commune.population }} habitants</li>
                    {{ end }}
                </ul>
            </div>
        </main>
        
        <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb; text-align: center; font-size: 12px; color: #6b7280;">
            <p>{{ .Campaign.FromEmail }}</p>
            <p><a href="{{ UnsubscribeURL }}" style="color: #6b7280;">Se désabonner</a></p>
        </footer>
    </div>
</body>
</html>', false)
ON CONFLICT (name) DO NOTHING;

-- Add some analytics data for testing
INSERT INTO campaign_views (campaign_id, subscriber_id, created_at) 
SELECT 1, s.id, NOW() - INTERVAL '1 day' * (random() * 30)
FROM subscribers s 
WHERE s.attribs->>'contact_type' = 'mairie'
AND random() < 0.3  -- 30% open rate
ON CONFLICT DO NOTHING;

-- Update statistics
ANALYZE french_departments;
ANALYZE french_communes;
ANALYZE subscriber_communes;
ANALYZE subscribers;