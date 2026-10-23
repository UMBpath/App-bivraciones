import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const FCM_SERVER_KEY = "TU_FCM_SERVER_KEY_AQUI" // Reemplazar con tu server key de Firebase

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    // Obtener todos los FCM tokens
    const { data: tokens, error: tokensError } = await supabaseClient
      .from('fcm_tokens')
      .select('token')

    if (tokensError) {
      throw new Error(`Error obteniendo tokens: ${tokensError.message}`)
    }

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No hay tokens registrados' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    // Obtener datos del body
    const { letra } = await req.json()

    // Enviar mensaje FCM a cada token
    const results = await Promise.allSettled(
      tokens.map(async ({ token }) => {
        const response = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `key=${FCM_SERVER_KEY}`,
          },
          body: JSON.stringify({
            to: token,
            priority: 'high',
            content_available: true,
            data: {
              letra: letra,
            },
            android: {
              priority: 'high',
            },
          }),
        })

        return response.json()
      })
    )

    const successCount = results.filter(r => r.status === 'fulfilled').length
    const failureCount = results.filter(r => r.status === 'rejected').length

    return new Response(
      JSON.stringify({
        message: 'Notificaciones enviadas',
        success: successCount,
        failed: failureCount,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
