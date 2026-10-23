-- Trigger para llamar a la Edge Function cuando se inserta una vibración
CREATE OR REPLACE FUNCTION send_fcm_on_vibracion_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- Llamar a la Edge Function
  PERFORM net.http_post(
    url := 'https://TU_PROYECTO_SUPABASE.supabase.co/functions/v1/send-fcm-notification',
    headers := jsonb_build_object(
      'Authorization', 'Bearer TU_ANON_KEY',
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('letra', NEW.letra)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger
DROP TRIGGER IF EXISTS on_vibracion_insert ON vibraciones;
CREATE TRIGGER on_vibracion_insert
  AFTER INSERT ON vibraciones
  FOR EACH ROW
  EXECUTE FUNCTION send_fcm_on_vibracion_insert();
