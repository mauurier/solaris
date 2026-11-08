// Pone una contraseña nueva a una cuenta de admin, supervisor o técnico que
// olvidó la suya. Solo la puede usar un superadmin con la cuenta activa; la
// app genera la contraseña temporal y se la muestra una vez.
//
// POST /functions/v1/cambiar-contrasena
// Authorization: Bearer <access token del superadmin>
// {
//   "id_usuario": "uuid del perfil",
//   "password": "contraseña nueva (mínimo 8)"
// }
//
// Respuesta 200: { "ok": true }
// Errores: 400 datos inválidos, 401 sin sesión, 403 no es superadmin o la
//          cuenta es de un superadmin, 404 la cuenta no existe, 500 error del servidor.

import { createClient } from 'npm:@supabase/supabase-js@2'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function responder(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}

// Usa las llaves nuevas (sb_publishable / sb_secret) y, si no hay, las legacy.
function llave(nueva: string, legacy: string) {
  const json = Deno.env.get(nueva)
  if (json) {
    const k = JSON.parse(json)['default']
    if (k) return k as string
  }
  return Deno.env.get(legacy)!
}

const url = Deno.env.get('SUPABASE_URL')!
const publishable = llave('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY')
const secret = llave('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY')
const sinSesion = { persistSession: false, autoRefreshToken: false }

// Cliente con permisos totales: solo vive aquí, nunca en la app.
const admin = createClient(url, secret, { auth: sinSesion })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return responder(405, { error: 'Usa POST' })

  // ----- 1. Quién llama -------------------------------------------------
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '')
  if (!token) return responder(401, { error: 'Falta iniciar sesión' })

  const { data: sesion, error: errSesion } = await admin.auth.getUser(token)
  if (errSesion || !sesion.user) return responder(401, { error: 'Sesión inválida o vencida' })

  // es_superadmin() revisa rol, activo y vigencia con la sesión de quien llama.
  const comoUsuario = createClient(url, publishable, {
    auth: sinSesion,
    global: { headers: { Authorization: `Bearer ${token}` } },
  })
  const { data: esSuperadmin, error: errRol } = await comoUsuario.rpc('es_superadmin')
  if (errRol) return responder(500, { error: 'No se pudo revisar el rol', detalle: errRol.message })
  if (!esSuperadmin) return responder(403, { error: 'Solo el superadmin puede cambiar contraseñas' })

  // ----- 2. Datos -------------------------------------------------------
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return responder(400, { error: 'El cuerpo debe ser JSON' })
  }

  const id = String(body.id_usuario ?? '')
  const password = String(body.password ?? '')
  const errores: string[] = []
  if (!UUID.test(id)) errores.push('id_usuario inválido')
  if (password.length < 8) errores.push('la contraseña debe tener al menos 8 caracteres')
  if (errores.length) return responder(400, { error: 'Datos inválidos', detalles: errores })

  // ----- 3. A quién -----------------------------------------------------
  const { data: perfil, error: errPerfil } = await admin
    .from('perfil')
    .select('id, rol, eliminado_en')
    .eq('id', id)
    .maybeSingle()
  if (errPerfil) return responder(500, { error: 'No se pudo leer la cuenta', detalle: errPerfil.message })
  if (!perfil || perfil.eliminado_en) return responder(404, { error: 'La cuenta no existe' })
  // Un superadmin cambia la suya desde Supabase, no desde la app.
  if (perfil.rol === 'superadmin') {
    return responder(403, { error: 'La contraseña de un superadmin no se cambia desde la app' })
  }

  // ----- 4. Cambiarla ---------------------------------------------------
  const { error: errCambio } = await admin.auth.admin.updateUserById(id, { password })
  if (errCambio) return responder(500, { error: 'No se pudo cambiar la contraseña', detalle: errCambio.message })

  return responder(200, { ok: true })
})
