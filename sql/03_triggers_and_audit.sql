-- ============================================================================
-- RideSync - Global Ride-Hailing Network
-- 03_triggers_and_audit.sql: Audit Log Triggers on Rider Wallet Balance
-- ============================================================================

-- Function to handle wallet balance updates and append immutable audit log
CREATE OR REPLACE FUNCTION fn_audit_wallet_balance_change()
RETURNS TRIGGER AS $$
DECLARE
    v_diff NUMERIC(10, 2);
    v_action VARCHAR(50);
BEGIN
    IF OLD.wallet_balance IS DISTINCT FROM NEW.wallet_balance THEN
        v_diff := NEW.wallet_balance - OLD.wallet_balance;
        
        IF v_diff > 0 THEN
            v_action := 'TOPUP_OR_REFUND';
        ELSE
            v_action := 'DEBIT_OR_ESCROW';
        END IF;

        INSERT INTO wallet_audit_logs (
            id,
            rider_id,
            amount_changed,
            action_type,
            balance_before,
            balance_after,
            timestamp
        ) VALUES (
            gen_random_uuid(),
            NEW.id,
            v_diff,
            v_action,
            OLD.wallet_balance,
            NEW.wallet_balance,
            CURRENT_TIMESTAMP
        );

        NEW.updated_at := CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger firing AFTER UPDATE of wallet_balance on riders table
DROP TRIGGER IF EXISTS trg_audit_wallet_balance ON riders;
CREATE TRIGGER trg_audit_wallet_balance
AFTER UPDATE OF wallet_balance ON riders
FOR EACH ROW
EXECUTE FUNCTION fn_audit_wallet_balance_change();
