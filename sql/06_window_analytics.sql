-- ============================================================================
-- RideSync - Global Ride-Hailing Network
-- 06_window_analytics.sql: Workflow 2 - 7-Day Moving Average & Dense Ranking
-- ============================================================================

-- Query: Calculate the 7-day moving average of fare revenue per vehicle
-- and rank vehicles across the platform using DENSE_RANK().
--
-- ASSUMPTION: The 7-day window is over the vehicle's last 7 days that had at
-- least one completed trip, not the last 7 calendar days. A vehicle idle for
-- part of that span simply has fewer rows contributing to its average rather
-- than zero-revenue days being counted. Document this in the README.

WITH daily_vehicle_revenue AS (
    -- Step 1: Aggregate daily revenue per vehicle for completed trips
    SELECT 
        v.id AS vehicle_id,
        v.license_plate,
        v.class,
        DATE_TRUNC('day', t.created_at)::DATE AS trip_date,
        COUNT(t.id) AS daily_trips,
        SUM(t.fare_amount) AS daily_fare_revenue
    FROM 
        vehicles v
    JOIN 
        trips t ON v.id = t.vehicle_id
    WHERE 
        t.status = 'COMPLETED'
    GROUP BY 
        v.id, v.license_plate, v.class, DATE_TRUNC('day', t.created_at)::DATE
),
moving_average_calc AS (
    -- Step 2: Compute 7-day trailing moving average using window functions
    SELECT 
        vehicle_id,
        license_plate,
        class,
        trip_date,
        daily_fare_revenue,
        ROUND(
            AVG(daily_fare_revenue) OVER (
                PARTITION BY vehicle_id 
                ORDER BY trip_date 
                ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
            ), 
            2
        ) AS seven_day_moving_avg_revenue
    FROM 
        daily_vehicle_revenue
)
-- Step 3: Rank vehicles per day or globally based on 7-day moving average performance
SELECT 
    trip_date,
    vehicle_id,
    license_plate,
    class,
    daily_fare_revenue,
    seven_day_moving_avg_revenue,
    DENSE_RANK() OVER (
        PARTITION BY trip_date 
        ORDER BY seven_day_moving_avg_revenue DESC
    ) AS daily_performance_rank
FROM 
    moving_average_calc
ORDER BY 
    trip_date DESC, 
    daily_performance_rank ASC;
