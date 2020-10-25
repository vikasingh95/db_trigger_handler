-- Function to send notifications
CREATE OR REPLACE FUNCTION notify(channel VARCHAR(100), notify_data jsonb DEFAULT '{}'::jsonb)
  RETURNS void AS
$$
BEGIN
    PERFORM pg_notify(channel, notify_data::text);
END;
$$
LANGUAGE 'plpgsql';

-- Function to notify shipment changes
CREATE OR REPLACE FUNCTION notify_shipment_changes()
  RETURNS trigger AS
$$
DECLARE
  channel VARCHAR(50) := '';
  notify_data jsonb := '{}'::jsonb;
BEGIN
  IF TG_OP ilike('INSERT')
  THEN
    channel := 'shipment_created';
    notify_data := json_build_object('id', NEW.id);
    PERFORM pg_notify(channel, notify_data::text);
    RETURN NEW;
  ELSIF TG_OP ilike('UPDATE') and
  (OLD.seller_due_date IS DISTINCT FROM NEW.seller_due_date
   or OLD.total_seller_invoice_amount IS DISTINCT FROM NEW.total_seller_invoice_amount
   or OLD.actual_charges IS DISTINCT FROM NEW.actual_charges
   or OLD.total_buyer_invoice_amount IS DISTINCT FROM NEW.total_buyer_invoice_amount
   or OLD.seller_extra_charges IS DISTINCT FROM NEW.seller_extra_charges
   or OLD.seller_invoice_no IS DISTINCT FROM NEW.seller_invoice_no
   or (OLD.status IS DISTINCT FROM NEW.status and NEW.status = 3))
  THEN
    channel := 'shipment_updated';
    notify_data := json_build_object('id', NEW.id);
    PERFORM pg_notify(channel, notify_data::text);
    RETURN NEW;
  ELSIF TG_OP ilike('UPDATE') and
  (OLD.items_change_snapshot <> '"{}"' and
  OLD.items_change_snapshot IS DISTINCT FROM NEW.items_change_snapshot)
  THEN
    channel := 'shipment_dpir_changed';
    notify_data := json_build_object('id', NEW.id);
    PERFORM pg_notify(channel, notify_data::text);
    RETURN NEW;
  ELSIF TG_OP ilike('DELETE')
  THEN
    channel := 'shipment_cancelled';
    notify_data := json_build_object('id', OLD.id);
    PERFORM pg_notify(channel, notify_data::text);
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$
LANGUAGE 'plpgsql';

CREATE TRIGGER shipment_changed AFTER INSERT OR UPDATE OR DELETE
ON supply_chain.shipments
FOR EACH ROW
EXECUTE PROCEDURE notify_shipment_changes();

-- Test sending notification
DO $$
DECLARE
BEGIN
    PERFORM notify('shipment_created', '{}'::jsonb);
END;
$$
LANGUAGE 'plpgsql';