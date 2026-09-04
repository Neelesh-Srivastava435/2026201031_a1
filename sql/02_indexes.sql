-- ============================================================================
-- RideSync - Global Ride-Hailing Network
-- 02_indexes.sql: Partial Indexes, Foreign Key Indexes, & Query Optimization
-- ============================================================================

-- 1. Partial Unique Index: Active Rider Trip Constraint
-- Guarantees at storage-engine level that a rider cannot be in multiple active rides simultaneously.
DROP INDEX IF EXISTS idx_active_rider_trip;
CREATE UNIQUE INDEX idx_active_rider_trip 
ON trips (rider_id) 
WHERE status IN ('REQUESTED', 'IN_TRANSIT');

-- 2. Foreign Key & Analytics Supporting Indexes
CREATE INDEX IF NOT EXISTS idx_trips_vehicle_id_status ON trips (vehicle_id, status);
CREATE INDEX IF NOT EXISTS idx_trips_created_at ON trips (created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_audit_rider_timestamp ON wallet_audit_logs (rider_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_vehicles_is_active ON vehicles (is_active);
