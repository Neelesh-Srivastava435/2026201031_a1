-- ============================================================================
-- RideSync - Global Ride-Hailing Network
-- 05_materialized_views.sql: Vehicle Lifetime Statistics & Concurrent Refresh
-- ============================================================================

-- Drop materialized view if exists
DROP MATERIALIZED VIEW IF EXISTS mv_vehicle_lifetime_earnings;

-- Materialized View joining vehicles with lifetime completed trip count & total earnings
CREATE MATERIALIZED VIEW mv_vehicle_lifetime_earnings AS
SELECT 
    v.id AS vehicle_id,
    v.license_plate,
    v.class,
    v.is_active,
    COUNT(t.id) AS lifetime_trip_count,
    COALESCE(SUM(t.fare_amount), 0.00) AS total_earnings,
    COALESCE(AVG(t.fare_amount), 0.00) AS avg_fare_per_trip,
    MAX(t.completed_at) AS last_trip_at,
    CURRENT_TIMESTAMP AS last_refreshed_at
FROM 
    vehicles v
LEFT JOIN 
    trips t ON v.id = t.vehicle_id AND t.status = 'COMPLETED'
GROUP BY 
    v.id, v.license_plate, v.class, v.is_active;

-- Unique index required for REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX idx_mv_vehicle_lifetime_id ON mv_vehicle_lifetime_earnings (vehicle_id);

-- Helper function to refresh the materialized view concurrently
CREATE OR REPLACE FUNCTION fn_refresh_vehicle_earnings_mv()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vehicle_lifetime_earnings;
END;
$$ LANGUAGE plpgsql;
