-- Crear tabla para guardar FCM Tokens
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índice para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON fcm_tokens(token);

-- Habilitar RLS (Row Level Security)
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Política para permitir insertar tokens
CREATE POLICY "Allow token insertion"
  ON fcm_tokens
  FOR INSERT
  WITH CHECK (true);

-- Política para permitir actualizar tokens
CREATE POLICY "Allow token update"
  ON fcm_tokens
  FOR UPDATE
  USING (true);

-- Política para permitir leer tokens (para Edge Function)
CREATE POLICY "Allow token read"
  ON fcm_tokens
  FOR SELECT
  USING (true);
