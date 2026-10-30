// Crea cuentas de admin, supervisor y técnico. Solo la puede usar un
// superadmin con la cuenta activa.
//
// POST /functions/v1/crear-usuario
// Authorization: Bearer <access token del superadmin>
// {
//   "email": "tecnico@empresa.com",
//   "password": "contraseña inicial (mínimo 8)",
//   "nombre": "Juan Pérez",
//   "rol": "tecnico",                 // admin | supervisor | tecnico
//   "inicio_vigencia": "2026-11-01",  // opcional, por defecto hoy (hora de México)
//   "fin_vigencia": "2026-12-15"
// }
//
// Respuesta 201: { "perfil": { id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia } }
// Errores: 400 datos inválidos, 401 sin sesión, 403 no es superadmin,
//          409 el correo ya existe, 500 error del servidor.

import { createClient } from 'npm:@supabase/supabase-js@2'

const ROLES = ['admin', 'supervisor', 'tecnico']
const FECHA = /^\d{4}-\d{2}-\d{2}$/
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

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

function hoyMx() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Mexico_City' }).format(new Date())
}

function esFecha(s: unknown): s is string {
  if (typeof s !== 'string' || !FECHA.test(s)) return false
  const d = new Date(`${s}T00:00:00Z`)
  return !isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s
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
  if (!esSuperadmin) return responder(403, { error: 'Solo el superadmin puede crear cuentas' })

  // ----- 2. Datos de la cuenta nueva ------------------------------------
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    return responder(400, { error: 'El cuerpo debe ser JSON' })
  }

  const email = String(body.email ?? '').trim().toLowerCase()
  const password = String(body.password ?? '')
  const nombre = String(body.nombre ?? '').trim()
  const rol = String(body.rol ?? '')
  const inicio = body.inicio_vigencia ?? hoyMx()
  const fin = body.fin_vigencia

  const errores: string[] = []
  if (!EMAIL.test(email)) errores.push('email inválido')
  if (password.length < 8) errores.push('la contraseña debe tener al menos 8 caracteres')
  if (!nombre) errores.push('falta el nombre')
  if (!ROLES.includes(rol)) errores.push(`rol debe ser ${ROLES.join(', ')}`)
  if (!esFecha(inicio)) errores.push('inicio_vigencia debe ser AAAA-MM-DD')
  if (!esFecha(fin)) errores.push('fin_vigencia es obligatoria y debe ser AAAA-MM-DD')
  else if (esFecha(inicio) && fin < inicio) errores.push('fin_vigencia no puede ser antes de inicio_vigencia')
  if (errores.length) return responder(400, { error: 'Datos inválidos', detalles: errores })

  // ----- 3. Crear la cuenta ---------------------------------------------
  // app_metadata no lo puede editar el usuario; el trigger crear_perfil lo lee.
  const { data: creado, error: errCrear } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { nombre },
    app_metadata: { rol, inicio_vigencia: inicio, fin_vigencia: fin, creado_por: sesion.user.id },
  })
  if (errCrear || !creado.user) {
    if (errCrear?.code === 'email_exists' || errCrear?.status === 422) {
      return responder(409, { error: 'Ya existe una cuenta con ese correo' })
    }
    return responder(500, { error: 'No se pudo crear la cuenta', detalle: errCrear?.message })
  }

  // El trigger ya creó el perfil; esto fija los valores aunque Auth guarde
  // app_metadata después de insertar el usuario.
  const { data: perfil, error: errPerfil } = await admin
    .from('perfil')
    .update({
      nombre,
      rol,
      activo: true,
      inicio_vigencia: inicio,
      fin_vigencia: fin,
      creado_por: sesion.user.id,
    })
    .eq('id', creado.user.id)
    .select('id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia')
    .single()

  if (errPerfil) {
    // Sin perfil la cuenta no sirve: se deshace para poder reintentar.
    await admin.auth.admin.deleteUser(creado.user.id)
    return responder(500, { error: 'No se pudo guardar el perfil', detalle: errPerfil.message })
  }

  return responder(201, { perfil })
})
