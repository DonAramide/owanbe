const { Client } = require('../services/api/node_modules/pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';

const USER_ROLES = [
  // attendee@owanbe.dev gets client role
  { email: 'attendee@owanbe.dev', role: 'client' },
  // organizer@owanbe.dev gets organizer role
  { email: 'organizer@owanbe.dev', role: 'organizer' },
  // vendor@owanbe.dev gets vendor role
  { email: 'vendor@owanbe.dev', role: 'vendor' },
  // admin@owanbe.dev gets platform_admin / admin_super
  { email: 'admin@owanbe.dev', role: 'platform_admin' },
  // superadmin@owanbe.dev gets super_admin
  { email: 'superadmin@owanbe.dev', role: 'super_admin' },
];

async function run() {
  const client = new Client({ connectionString: DATABASE_URL });
  await client.connect();
  console.log('Connected to database.');

  try {
    for (const mapping of USER_ROLES) {
      console.log(`Ensuring user "${mapping.email}" has role "${mapping.role}"...`);
      await client.query(`
        INSERT INTO user_roles (user_id, role_id)
        SELECT u.id, r.id
        FROM users u
        JOIN roles r ON r.code = $2
        WHERE u.email_normalized = lower(trim($1))
        ON CONFLICT (user_id, role_id) DO NOTHING;
      `, [mapping.email, mapping.role]);
    }
    console.log('Success! All local development roles have been configured.');
  } catch (err) {
    console.error('Error running script:', err);
  } finally {
    await client.end();
  }
}

run().catch(console.error);
