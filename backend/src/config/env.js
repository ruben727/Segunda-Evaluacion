require('dotenv').config();

const env = {
  port: process.env.PORT || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseKey: process.env.SUPABASE_KEY,
};

const required = ['databaseUrl', 'jwtSecret'];
for (const key of required) {
  if (!env[key]) {
    // eslint-disable-next-line no-console
    console.warn(`[env] Falta la variable de entorno para "${key}". Revisa tu archivo .env`);
  }
}

module.exports = env;
