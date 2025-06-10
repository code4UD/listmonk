package main

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/knadh/listmonk/internal/geo"
	"github.com/knadh/listmonk/internal/importer"
	"github.com/labstack/echo/v4"
)

// GetDepartments returns all French departments
func (a *App) GetDepartments(c echo.Context) error {
	departments, err := a.geoSvc.GetDepartments()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error fetching departments: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{departments})
}

// GetCommunes returns communes with optional filtering
func (a *App) GetCommunes(c echo.Context) error {
	// Parse query parameters
	var filter geo.TargetingFilter
	
	if deptCodes := c.QueryParam("department_codes"); deptCodes != "" {
		filter.DepartmentCodes = parseStringArray(deptCodes)
	}
	
	if regions := c.QueryParam("regions"); regions != "" {
		filter.Regions = parseStringArray(regions)
	}
	
	if communeNames := c.QueryParam("commune_names"); communeNames != "" {
		filter.CommuneNames = parseStringArray(communeNames)
	}
	
	if postalCodes := c.QueryParam("postal_codes"); postalCodes != "" {
		filter.PostalCodes = parseStringArray(postalCodes)
	}
	
	if popMinStr := c.QueryParam("population_min"); popMinStr != "" {
		if popMin, err := strconv.Atoi(popMinStr); err == nil {
			filter.PopulationMin = &popMin
		}
	}
	
	if popMaxStr := c.QueryParam("population_max"); popMaxStr != "" {
		if popMax, err := strconv.Atoi(popMaxStr); err == nil {
			filter.PopulationMax = &popMax
		}
	}
	
	// Parse pagination
	limit := 50 // default
	if limitStr := c.QueryParam("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 1000 {
			limit = l
		}
	}
	
	offset := 0
	if offsetStr := c.QueryParam("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}
	
	communes, err := a.geoSvc.GetCommunes(filter, limit, offset)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error fetching communes: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{communes})
}

// handleSearchCommunes searches for communes by name
func (a *App) SearchCommunes(c echo.Context) error {
	
	
	query := c.QueryParam("q")
	if query == "" {
		return echo.NewHTTPError(http.StatusBadRequest, "Query parameter 'q' is required")
	}
	
	filter := geo.TargetingFilter{
		CommuneNames: []string{query},
	}
	
	limit := 20 // default for search
	if limitStr := c.QueryParam("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}
	
	communes, err := a.geoSvc.GetCommunes(filter, limit, 0)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error searching communes: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{communes})
}

// handleGetGeoStats returns general geographic statistics
func (a *App) GetGeoStats(c echo.Context) error {
	
	
	stats, err := a.geoSvc.GetGeoStats()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error fetching geo stats: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{stats})
}

// handleTargetingPreview returns a preview of targeting results
func (a *App) TargetingPreview(c echo.Context) error {
	
	
	var filter geo.TargetingFilter
	if err := c.Bind(&filter); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, 
			fmt.Sprintf("Invalid targeting filter: %v", err))
	}
	
	preview, err := a.geoSvc.GetTargetingPreview(filter)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error generating targeting preview: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{preview})
}

// handleTargetingCount returns the count of subscribers matching targeting criteria
func (a *App) TargetingCount(c echo.Context) error {
	
	
	var filter geo.TargetingFilter
	if err := c.Bind(&filter); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, 
			fmt.Sprintf("Invalid targeting filter: %v", err))
	}
	
	count, err := a.geoSvc.CountTargetingRecipients(filter)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error counting targeting recipients: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{map[string]int{"count": count}})
}

// handleImportMairies handles CSV import of mairies data
func (a *App) ImportMairies(c echo.Context) error {
	
	
	// Get file from form
	file, err := c.FormFile("file")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "No file provided")
	}
	
	// Open file
	src, err := file.Open()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error opening file: %v", err))
	}
	defer src.Close()
	
	// Parse options
	createSubscribers := c.FormValue("create_subscribers") == "true"
	
	// Create importer
	importer := geo.NewCSVImporter(a.db, a.geoSvc)
	
	// Import data
	result, err := importer.ImportMairiesFromCSV(src, createSubscribers)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error importing data: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{result})
}

// handleGetSubscriberCommunes returns communes associated with a subscriber
func (a *App) GetSubscriberCommunes(c echo.Context) error {
	
	
	subscriberID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid subscriber ID")
	}
	
	communes, err := a.geoSvc.GetSubscriberCommunes(subscriberID)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error fetching subscriber communes: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{communes})
}

// handleAssociateSubscriberCommune associates a subscriber with a commune
func (a *App) AssociateSubscriberCommune(c echo.Context) error {
	
	
	subscriberID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid subscriber ID")
	}
	
	var req struct {
		CommuneID int `json:"commune_id"`
	}
	if err := c.Bind(&req); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid request body")
	}
	
	if err := a.geoSvc.AssociateSubscriberToCommune(subscriberID, req.CommuneID); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error associating subscriber to commune: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{"Association created successfully"})
}

// handleRemoveSubscriberCommune removes association between subscriber and commune
func (a *App) RemoveSubscriberCommune(c echo.Context) error {
	
	
	subscriberID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid subscriber ID")
	}
	
	communeID, err := strconv.Atoi(c.Param("commune_id"))
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "Invalid commune ID")
	}
	
	if err := a.geoSvc.RemoveSubscriberFromCommune(subscriberID, communeID); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error removing subscriber from commune: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{"Association removed successfully"})
}

// ValidateCSV validates a CSV file format without importing
func (a *App) ValidateCSV(c echo.Context) error {
	file, err := c.FormFile("file")
	if err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, "CSV file is required")
	}
	
	src, err := file.Open()
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error opening file: %v", err))
	}
	defer src.Close()
	
	csvImporter := importer.NewCSVImporter(a.db, a.geoSvc, a.log.Printf)
	
	result, err := csvImporter.ValidateCSVFormat(src)
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error validating CSV: %v", err))
	}
	
	return c.JSON(http.StatusOK, okResp{result})
}

// GetCSVTemplate returns a CSV template for importing municipality data
func (a *App) GetCSVTemplate(c echo.Context) error {
	csvImporter := importer.NewCSVImporter(a.db, a.geoSvc, a.log.Printf)
	template := csvImporter.GetImportTemplate()
	
	// Set headers for CSV download
	c.Response().Header().Set("Content-Type", "text/csv")
	c.Response().Header().Set("Content-Disposition", "attachment; filename=template_mairies.csv")
	
	// Write template directly as string
	_, err := c.Response().Write([]byte(template))
	if err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error writing CSV: %v", err))
	}
	
	return nil
}

// parseStringArray parses a comma-separated string into a slice of strings
func parseStringArray(s string) []string {
	if s == "" {
		return nil
	}
	
	parts := strings.Split(s, ",")
	result := make([]string, 0, len(parts))
	
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			result = append(result, trimmed)
		}
	}
	
	return result
}

// SearchMairies searches for mairies based on filters.
func (a *App) SearchMairies(c echo.Context) error {
	var (
		populationMin = c.QueryParam("populationMin")
		populationMax = c.QueryParam("populationMax")
		departments   = c.QueryParam("departments")
		page          = c.QueryParam("page")
		limit         = c.QueryParam("limit")
	)

	// Default pagination
	if page == "" {
		page = "1"
	}
	if limit == "" {
		limit = "20"
	}

	// Build query
	query := `SELECT id, nom_commune, code_insee, code_departement, population, 
	                 email, nom_contact, code_postal, latitude, longitude,
	                 COUNT(*) OVER() as total_count
	          FROM mairies WHERE 1=1`
	args := []interface{}{}
	argIndex := 1

	if populationMin != "" {
		query += fmt.Sprintf(" AND population >= $%d", argIndex)
		args = append(args, populationMin)
		argIndex++
	}

	if populationMax != "" {
		query += fmt.Sprintf(" AND population <= $%d", argIndex)
		args = append(args, populationMax)
		argIndex++
	}

	if departments != "" {
		depts := strings.Split(departments, ",")
		placeholders := make([]string, len(depts))
		for i, dept := range depts {
			placeholders[i] = fmt.Sprintf("$%d", argIndex)
			args = append(args, strings.TrimSpace(dept))
			argIndex++
		}
		query += fmt.Sprintf(" AND code_departement IN (%s)", strings.Join(placeholders, ","))
	}

	// Add pagination
	pageInt, _ := strconv.Atoi(page)
	limitInt, _ := strconv.Atoi(limit)
	offset := (pageInt - 1) * limitInt
	query += fmt.Sprintf(" ORDER BY nom_commune LIMIT $%d OFFSET $%d", argIndex, argIndex+1)
	args = append(args, limitInt, offset)

	rows, err := a.db.Query(query, args...)
	if err != nil {
		a.log.Printf("error searching mairies: %v", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "Database error")
	}
	defer rows.Close()

	var mairies []map[string]interface{}
	var totalCount int

	for rows.Next() {
		var m struct {
			ID              int     `json:"id"`
			NomCommune      string  `json:"nom_commune"`
			CodeInsee       string  `json:"code_insee"`
			CodeDepartement string  `json:"code_departement"`
			Population      int     `json:"population"`
			Email           string  `json:"email"`
			NomContact      string  `json:"nom_contact"`
			CodePostal      string  `json:"code_postal"`
			Latitude        float64 `json:"latitude"`
			Longitude       float64 `json:"longitude"`
			TotalCount      int     `json:"-"`
		}

		err := rows.Scan(&m.ID, &m.NomCommune, &m.CodeInsee, &m.CodeDepartement,
			&m.Population, &m.Email, &m.NomContact, &m.CodePostal,
			&m.Latitude, &m.Longitude, &m.TotalCount)
		if err != nil {
			continue
		}

		totalCount = m.TotalCount
		mairies = append(mairies, map[string]interface{}{
			"id":               m.ID,
			"nom_commune":      m.NomCommune,
			"code_insee":       m.CodeInsee,
			"code_departement": m.CodeDepartement,
			"population":       m.Population,
			"email":            m.Email,
			"nom_contact":      m.NomContact,
			"code_postal":      m.CodePostal,
			"latitude":         m.Latitude,
			"longitude":        m.Longitude,
		})
	}

	// Calculate statistics
	stats := map[string]interface{}{
		"byPopulation": map[string]int{
			"small":  0,
			"medium": 0,
			"large":  0,
		},
		"byDepartment": []map[string]interface{}{},
	}

	// Count by population ranges
	for _, mairie := range mairies {
		pop := mairie["population"].(int)
		if pop < 1000 {
			stats["byPopulation"].(map[string]int)["small"]++
		} else if pop <= 20000 {
			stats["byPopulation"].(map[string]int)["medium"]++
		} else {
			stats["byPopulation"].(map[string]int)["large"]++
		}
	}

	result := map[string]interface{}{
		"mairies":         mairies,
		"total":           totalCount,
		"totalPopulation": 0, // Calculate if needed
		"statistics":      stats,
	}

	return c.JSON(http.StatusOK, okResp{result})
}

// ExportMairies exports search results as CSV.
func (a *App) ExportMairies(c echo.Context) error {
	// Use same search logic as SearchMairies but without pagination
	var (
		populationMin = c.QueryParam("populationMin")
		populationMax = c.QueryParam("populationMax")
		departments   = c.QueryParam("departments")
	)

	query := `SELECT nom_commune, code_insee, code_departement, population, 
	                 email, nom_contact, code_postal, latitude, longitude
	          FROM mairies WHERE 1=1`
	args := []interface{}{}
	argIndex := 1

	if populationMin != "" {
		query += fmt.Sprintf(" AND population >= $%d", argIndex)
		args = append(args, populationMin)
		argIndex++
	}

	if populationMax != "" {
		query += fmt.Sprintf(" AND population <= $%d", argIndex)
		args = append(args, populationMax)
		argIndex++
	}

	if departments != "" {
		depts := strings.Split(departments, ",")
		placeholders := make([]string, len(depts))
		for i, dept := range depts {
			placeholders[i] = fmt.Sprintf("$%d", argIndex)
			args = append(args, strings.TrimSpace(dept))
			argIndex++
		}
		query += fmt.Sprintf(" AND code_departement IN (%s)", strings.Join(placeholders, ","))
	}

	query += " ORDER BY nom_commune"

	rows, err := a.db.Query(query, args...)
	if err != nil {
		a.log.Printf("error exporting mairies: %v", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "Database error")
	}
	defer rows.Close()

	// Build CSV
	var csvData strings.Builder
	csvData.WriteString("nom_commune,code_insee,code_departement,population,email,nom_contact,code_postal,latitude,longitude\n")

	for rows.Next() {
		var nom, insee, dept, email, contact, postal string
		var population int
		var lat, lng float64

		err := rows.Scan(&nom, &insee, &dept, &population, &email, &contact, &postal, &lat, &lng)
		if err != nil {
			continue
		}

		csvData.WriteString(fmt.Sprintf("%q,%q,%q,%d,%q,%q,%q,%.6f,%.6f\n",
			nom, insee, dept, population, email, contact, postal, lat, lng))
	}

	c.Response().Header().Set("Content-Type", "text/csv")
	c.Response().Header().Set("Content-Disposition", "attachment; filename=mairies-export.csv")
	return c.String(http.StatusOK, csvData.String())
}

// GetImportStats returns statistics about the last import.
func (a *App) GetImportStats(c echo.Context) error {
	// Query import statistics from a log table or calculate from current data
	var stats struct {
		Date     string `json:"date"`
		Imported int    `json:"imported"`
		Updated  int    `json:"updated"`
		Errors   int    `json:"errors"`
	}

	// For now, return basic stats from the mairies table
	var count int
	err := a.db.QueryRow("SELECT COUNT(*) FROM mairies").Scan(&count)
	if err != nil {
		a.log.Printf("error getting import stats: %v", err)
		return echo.NewHTTPError(http.StatusInternalServerError, "Database error")
	}

	stats.Date = time.Now().Format("2006-01-02 15:04:05")
	stats.Imported = count
	stats.Updated = 0
	stats.Errors = 0

	return c.JSON(http.StatusOK, okResp{stats})
}