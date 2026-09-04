-- ============================================================================
-- RideSync - Global Ride-Hailing Network
-- 04_stored_procedures.sql: Workflow 1 - Atomic Transaction Stored Procedure
-- ============================================================================

-- Procedure: sp_book_trip_atomic
-- Purpose: Atomically books a trip by:
--   1. Checking vehicle active status
--   2. Verifying and debiting rider wallet balance (triggering wallet audit log)
--   3. Creating the trip entry in 'REQUESTED' state
--   4. Catching any failure, logging it, and rolling back the whole transaction
--
-- Isolation note: we use SELECT ... FOR UPDATE to take a row-level lock on the
-- rider being debited, rather than relying solely on REPEATABLE READ isolation.
-- This prevents two concurrent bookings for the same rider from both reading
-- a stale balance and both succeeding when only one should. It is a stricter
-- guarantee than REPEATABLE READ alone would give for this read-then-write
-- pattern, so it is used here in place of (not in addition to) that isolation
-- level. Document this choice in the README.
CREATE OR REPLACE PROCEDURE sp_book_trip_atomic(
    p_rider_id UUID,
    p_vehicle_id UUID,
    p_fare_amount NUMERIC(10, 2),
    OUT p_trip_id UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_balance NUMERIC(10, 2);
    v_vehicle_active BOOLEAN;
BEGIN
    -- 1. Check vehicle availability
    SELECT is_active INTO v_vehicle_active FROM vehicles WHERE id = p_vehicle_id;
    IF v_vehicle_active IS NULL OR v_vehicle_active = FALSE THEN
        RAISE EXCEPTION 'Vehicle % is inactive or does not exist.', p_vehicle_id;
    END IF;

    -- 2. Lock and verify rider balance
    SELECT wallet_balance INTO v_current_balance
    FROM riders
    WHERE id = p_rider_id
    FOR UPDATE;

    IF v_current_balance IS NULL THEN
        RAISE EXCEPTION 'Rider % does not exist.', p_rider_id;
    END IF;

    IF v_current_balance < p_fare_amount THEN
        RAISE EXCEPTION 'Insufficient balance: current %, required %', v_current_balance, p_fare_amount;
    END IF;

    -- 3. Deduct fare into escrow (this triggers trg_audit_wallet_balance)
    UPDATE riders
    SET wallet_balance = wallet_balance - p_fare_amount
    WHERE id = p_rider_id;

    -- 4. Generate trip UUID and insert trip record
    p_trip_id := gen_random_uuid();

    INSERT INTO trips (
        id,
        rider_id,
        vehicle_id,
        fare_amount,
        status,
        created_at
    ) VALUES (
        p_trip_id,
        p_rider_id,
        p_vehicle_id,
        p_fare_amount,
        'REQUESTED',
        CURRENT_TIMESTAMP
    );

    -- Commit happens automatically at the end of the procedure invocation

EXCEPTION
    WHEN OTHERS THEN
        -- Explicitly surface and roll back on any failure above: inactive
        -- vehicle, missing rider, insufficient balance, or a CHECK constraint
        -- violation. RAISE re-throws after logging so the caller still sees
        -- the original error and the calling transaction is rolled back.
        RAISE NOTICE 'Booking failed for rider % / vehicle %: %', p_rider_id, p_vehicle_id, SQLERRM;
        p_trip_id := NULL;
        RAISE;
END;
$$;
