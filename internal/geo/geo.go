package geo

import (
	"database/sql"
	"fmt"
	"strings"

	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
)

// Service handles geographic operations
type Service struct {
	db *sqlx.DB
}

// NewService creates a new geographic service
func NewService(db *sqlx.DB) *Service {
	return &Service{db: db}
}

// GetDepartments returns all French departments
func (s *Service) GetDepartments() ([]Department, error) {
	var departments []Department
	query := `SELECT id, code, name, region, created_at, updated_at FROM french_departments ORDER BY code`
	
	if err := s.db.Select(&departments, query); err != nil {
		return nil, fmt.Errorf("error fetching departments: %w", err)
	}
	
	return departments, nil
}

// GetDepartmentByCode returns a department by its code
func (s *Service) GetDepartmentByCode(code string) (*Department, error) {
	var dept Department
	query := `SELECT id, code, name, region, created_at, updated_at FROM french_departments WHERE code = $1`
	
	if err := s.db.Get(&dept, query, code); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("department with code %s not found", code)
		}
		return nil, fmt.Errorf("error fetching department: %w", err)
	}
	
	return &dept, nil
}

// GetCommunes returns communes with optional filtering
func (s *Service) GetCommunes(filter TargetingFilter, limit, offset int) ([]Commune, error) {
	var communes []Commune
	var args []interface{}
	var conditions []string
	argIndex := 1

	query := `
		SELECT c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM french_communes c
		LEFT JOIN french_departments d ON c.department_code = d.code
	`

	// Build WHERE conditions
	if len(filter.DepartmentCodes) > 0 {
		conditions = append(conditions, fmt.Sprintf("c.department_code = ANY($%d)", argIndex))
		args = append(args, pq.Array(filter.DepartmentCodes))
		argIndex++
	}

	if filter.PopulationMin != nil {
		conditions = append(conditions, fmt.Sprintf("c.population >= $%d", argIndex))
		args = append(args, *filter.PopulationMin)
		argIndex++
	}

	if filter.PopulationMax != nil {
		conditions = append(conditions, fmt.Sprintf("c.population <= $%d", argIndex))
		args = append(args, *filter.PopulationMax)
		argIndex++
	}

	if len(filter.Regions) > 0 {
		conditions = append(conditions, fmt.Sprintf("d.region = ANY($%d)", argIndex))
		args = append(args, pq.Array(filter.Regions))
		argIndex++
	}

	if len(filter.CommuneNames) > 0 {
		nameConditions := make([]string, len(filter.CommuneNames))
		for i, name := range filter.CommuneNames {
			nameConditions[i] = fmt.Sprintf("c.name ILIKE $%d", argIndex)
			args = append(args, "%"+name+"%")
			argIndex++
		}
		conditions = append(conditions, "("+strings.Join(nameConditions, " OR ")+")")
	}

	if len(filter.PostalCodes) > 0 {
		conditions = append(conditions, fmt.Sprintf("c.postal_codes && $%d", argIndex))
		args = append(args, pq.Array(filter.PostalCodes))
		argIndex++
	}

	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	query += " ORDER BY c.name"

	if limit > 0 {
		query += fmt.Sprintf(" LIMIT $%d", argIndex)
		args = append(args, limit)
		argIndex++
	}

	if offset > 0 {
		query += fmt.Sprintf(" OFFSET $%d", argIndex)
		args = append(args, offset)
	}

	if err := s.db.Select(&communes, query, args...); err != nil {
		return nil, fmt.Errorf("error fetching communes: %w", err)
	}

	return communes, nil
}

// GetCommuneByInseeCode returns a commune by its INSEE code
func (s *Service) GetCommuneByInseeCode(inseeCode string) (*Commune, error) {
	var commune Commune
	query := `
		SELECT c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM french_communes c
		LEFT JOIN french_departments d ON c.department_code = d.code
		WHERE c.insee_code = $1
	`
	
	if err := s.db.Get(&commune, query, inseeCode); err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("commune with INSEE code %s not found", inseeCode)
		}
		return nil, fmt.Errorf("error fetching commune: %w", err)
	}
	
	return &commune, nil
}

// CreateCommune creates a new commune
func (s *Service) CreateCommune(commune *Commune) error {
	query := `
		INSERT INTO french_communes (insee_code, name, department_code, population, postal_codes, latitude, longitude)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, created_at, updated_at
	`
	
	err := s.db.QueryRow(query, commune.InseeCode, commune.Name, commune.DepartmentCode, 
		commune.Population, pq.Array(commune.PostalCodes), commune.Latitude, commune.Longitude).
		Scan(&commune.ID, &commune.CreatedAt, &commune.UpdatedAt)
	
	if err != nil {
		return fmt.Errorf("error creating commune: %w", err)
	}
	
	return nil
}

// UpdateCommune updates an existing commune
func (s *Service) UpdateCommune(commune *Commune) error {
	query := `
		UPDATE french_communes 
		SET name = $2, department_code = $3, population = $4, postal_codes = $5, 
		    latitude = $6, longitude = $7, updated_at = NOW()
		WHERE id = $1
	`
	
	result, err := s.db.Exec(query, commune.ID, commune.Name, commune.DepartmentCode, 
		commune.Population, pq.Array(commune.PostalCodes), commune.Latitude, commune.Longitude)
	
	if err != nil {
		return fmt.Errorf("error updating commune: %w", err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("error checking affected rows: %w", err)
	}
	
	if rowsAffected == 0 {
		return fmt.Errorf("commune with ID %d not found", commune.ID)
	}
	
	return nil
}

// AssociateSubscriberToCommune associates a subscriber with a commune
func (s *Service) AssociateSubscriberToCommune(subscriberID, communeID int) error {
	query := `
		INSERT INTO subscriber_communes (subscriber_id, commune_id)
		VALUES ($1, $2)
		ON CONFLICT (subscriber_id, commune_id) DO NOTHING
	`
	
	_, err := s.db.Exec(query, subscriberID, communeID)
	if err != nil {
		return fmt.Errorf("error associating subscriber to commune: %w", err)
	}
	
	return nil
}

// RemoveSubscriberFromCommune removes the association between a subscriber and a commune
func (s *Service) RemoveSubscriberFromCommune(subscriberID, communeID int) error {
	query := `DELETE FROM subscriber_communes WHERE subscriber_id = $1 AND commune_id = $2`
	
	_, err := s.db.Exec(query, subscriberID, communeID)
	if err != nil {
		return fmt.Errorf("error removing subscriber from commune: %w", err)
	}
	
	return nil
}

// GetSubscriberCommunes returns all communes associated with a subscriber
func (s *Service) GetSubscriberCommunes(subscriberID int) ([]Commune, error) {
	var communes []Commune
	query := `
		SELECT c.id, c.insee_code, c.name, c.department_code, c.population, 
		       c.postal_codes, c.latitude, c.longitude, c.created_at, c.updated_at,
		       d.name as department_name, d.region
		FROM french_communes c
		LEFT JOIN french_departments d ON c.department_code = d.code
		INNER JOIN subscriber_communes sc ON c.id = sc.commune_id
		WHERE sc.subscriber_id = $1
		ORDER BY c.name
	`
	
	if err := s.db.Select(&communes, query, subscriberID); err != nil {
		return nil, fmt.Errorf("error fetching subscriber communes: %w", err)
	}
	
	return communes, nil
}

// CountTargetingRecipients counts the number of subscribers matching the targeting criteria
func (s *Service) CountTargetingRecipients(filter TargetingFilter) (int, error) {
	var count int
	var args []interface{}
	var conditions []string
	argIndex := 1

	query := `
		SELECT COUNT(DISTINCT s.id)
		FROM subscribers s
		LEFT JOIN subscriber_communes sc ON s.id = sc.subscriber_id
		LEFT JOIN french_communes c ON sc.commune_id = c.id
		LEFT JOIN french_departments d ON c.department_code = d.code
		WHERE s.status = 'enabled'
	`

	// Build WHERE conditions
	if len(filter.DepartmentCodes) > 0 {
		conditions = append(conditions, fmt.Sprintf("c.department_code = ANY($%d)", argIndex))
		args = append(args, pq.Array(filter.DepartmentCodes))
		argIndex++
	}

	if filter.PopulationMin != nil {
		conditions = append(conditions, fmt.Sprintf("c.population >= $%d", argIndex))
		args = append(args, *filter.PopulationMin)
		argIndex++
	}

	if filter.PopulationMax != nil {
		conditions = append(conditions, fmt.Sprintf("c.population <= $%d", argIndex))
		args = append(args, *filter.PopulationMax)
		argIndex++
	}

	if len(filter.Regions) > 0 {
		conditions = append(conditions, fmt.Sprintf("d.region = ANY($%d)", argIndex))
		args = append(args, pq.Array(filter.Regions))
		argIndex++
	}

	if len(conditions) > 0 {
		query += " AND " + strings.Join(conditions, " AND ")
	}

	if err := s.db.Get(&count, query, args...); err != nil {
		return 0, fmt.Errorf("error counting targeting recipients: %w", err)
	}

	return count, nil
}

// GetTargetingPreview returns a preview of targeting results
func (s *Service) GetTargetingPreview(filter TargetingFilter) (*TargetingPreview, error) {
	count, err := s.CountTargetingRecipients(filter)
	if err != nil {
		return nil, err
	}

	// Get sample communes (limit to 10 for preview)
	sampleCommunes, err := s.GetCommunes(filter, 10, 0)
	if err != nil {
		return nil, err
	}

	// Get statistics
	stats, err := s.GetTargetingStats(filter)
	if err != nil {
		return nil, err
	}

	// Calculate total population
	var totalPopulation int64
	for _, commune := range sampleCommunes {
		totalPopulation += int64(commune.Population)
	}

	preview := &TargetingPreview{
		Count:           count,
		Filters:         filter,
		SampleCommunes:  sampleCommunes,
		Statistics:      *stats,
		EstimatedReach:  count,
		PopulationTotal: totalPopulation,
	}

	return preview, nil
}

// GetTargetingStats returns statistics for targeting filters
func (s *Service) GetTargetingStats(filter TargetingFilter) (*TargetingStats, error) {
	stats := &TargetingStats{
		ByDepartment:      make(map[string]int),
		ByRegion:          make(map[string]int),
		ByPopulationRange: make(map[string]int),
	}

	// Get total counts
	communes, err := s.GetCommunes(filter, 0, 0)
	if err != nil {
		return nil, err
	}

	stats.TotalCommunes = len(communes)

	// Calculate statistics
	var totalPopulation int64
	for _, commune := range communes {
		totalPopulation += int64(commune.Population)
		
		// Count by department
		stats.ByDepartment[commune.DepartmentCode]++
		
		// Count by region
		if commune.Region != "" {
			stats.ByRegion[commune.Region]++
		}
		
		// Count by population range
		popRange := getPopulationRange(commune.Population)
		stats.ByPopulationRange[popRange]++
	}

	if stats.TotalCommunes > 0 {
		stats.AveragePopulation = float64(totalPopulation) / float64(stats.TotalCommunes)
	}

	// Get subscriber count
	stats.TotalSubscribers, err = s.CountTargetingRecipients(filter)
	if err != nil {
		return nil, err
	}

	return stats, nil
}

// GetGeoStats returns general geographic statistics
func (s *Service) GetGeoStats() (*GeoStats, error) {
	stats := &GeoStats{}

	// Get basic counts
	if err := s.db.Get(&stats.TotalDepartments, "SELECT COUNT(*) FROM french_departments"); err != nil {
		return nil, fmt.Errorf("error counting departments: %w", err)
	}

	if err := s.db.Get(&stats.TotalCommunes, "SELECT COUNT(*) FROM french_communes"); err != nil {
		return nil, fmt.Errorf("error counting communes: %w", err)
	}

	if err := s.db.Get(&stats.TotalSubscribers, "SELECT COUNT(*) FROM subscribers WHERE status = 'enabled'"); err != nil {
		return nil, fmt.Errorf("error counting subscribers: %w", err)
	}

	// Get communes with subscribers
	query := `
		SELECT COUNT(DISTINCT c.id)
		FROM french_communes c
		INNER JOIN subscriber_communes sc ON c.id = sc.commune_id
		INNER JOIN subscribers s ON sc.subscriber_id = s.id
		WHERE s.status = 'enabled'
	`
	if err := s.db.Get(&stats.CommunesWithSubscribers, query); err != nil {
		return nil, fmt.Errorf("error counting communes with subscribers: %w", err)
	}

	// Calculate coverage percentage
	if stats.TotalCommunes > 0 {
		stats.CoveragePercentage = float64(stats.CommunesWithSubscribers) / float64(stats.TotalCommunes) * 100
	}

	// Get population statistics
	query = `
		SELECT 
			COALESCE(SUM(population), 0) as total_population,
			COALESCE(AVG(population), 0) as average_population
		FROM french_communes
	`
	var avgPop sql.NullFloat64
	if err := s.db.QueryRow(query).Scan(&stats.TotalPopulation, &avgPop); err != nil {
		return nil, fmt.Errorf("error getting population stats: %w", err)
	}
	if avgPop.Valid {
		stats.AveragePopulation = avgPop.Float64
	}

	// Get median population
	query = `
		SELECT population 
		FROM french_communes 
		ORDER BY population 
		OFFSET (SELECT COUNT(*) FROM french_communes) / 2 
		LIMIT 1
	`
	if err := s.db.Get(&stats.MedianPopulation, query); err != nil {
		// If no median found, set to 0
		stats.MedianPopulation = 0
	}

	// Get regional statistics
	query = `
		SELECT 
			d.region,
			COUNT(DISTINCT d.id) as departments,
			COUNT(DISTINCT c.id) as communes,
			COUNT(DISTINCT s.id) as subscribers,
			COALESCE(SUM(c.population), 0) as total_population
		FROM french_departments d
		LEFT JOIN french_communes c ON d.code = c.department_code
		LEFT JOIN subscriber_communes sc ON c.id = sc.commune_id
		LEFT JOIN subscribers s ON sc.subscriber_id = s.id AND s.status = 'enabled'
		GROUP BY d.region
		ORDER BY d.region
	`
	
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("error getting regional stats: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var regionStat RegionStat
		if err := rows.Scan(&regionStat.Region, &regionStat.Departments, 
			&regionStat.Communes, &regionStat.Subscribers, &regionStat.TotalPopulation); err != nil {
			return nil, fmt.Errorf("error scanning regional stat: %w", err)
		}
		
		// Calculate coverage percentage for this region
		if regionStat.Communes > 0 {
			// Count communes with subscribers in this region
			var communesWithSubs int
			subQuery := `
				SELECT COUNT(DISTINCT c.id)
				FROM french_communes c
				INNER JOIN french_departments d ON c.department_code = d.code
				INNER JOIN subscriber_communes sc ON c.id = sc.commune_id
				INNER JOIN subscribers s ON sc.subscriber_id = s.id
				WHERE d.region = $1 AND s.status = 'enabled'
			`
			if err := s.db.Get(&communesWithSubs, subQuery, regionStat.Region); err == nil {
				regionStat.CoveragePercent = float64(communesWithSubs) / float64(regionStat.Communes) * 100
			}
		}
		
		stats.RegionStats = append(stats.RegionStats, regionStat)
	}

	return stats, nil
}

// getPopulationRange returns a string representation of the population range
func getPopulationRange(population int) string {
	switch {
	case population < 500:
		return "< 500"
	case population < 1000:
		return "500-999"
	case population < 2000:
		return "1000-1999"
	case population < 5000:
		return "2000-4999"
	case population < 10000:
		return "5000-9999"
	case population < 20000:
		return "10000-19999"
	case population < 50000:
		return "20000-49999"
	case population < 100000:
		return "50000-99999"
	default:
		return "100000+"
	}
}