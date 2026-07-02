const { Client } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';

async function run() {
  console.log(`Connecting to database: ${DATABASE_URL.replace(/:[^:@]+@/, ':***@')}`);
  const client = new Client({ connectionString: DATABASE_URL });
  try {
    await client.connect();
    
    console.log('Ensuring all users have the "vendor" role...');
    const res = await client.query(`
      INSERT INTO user_roles (user_id, role_id)
      SELECT u.id, r.id
      FROM users u
      CROSS JOIN roles r
      WHERE r.code = 'vendor'
      ON CONFLICT (user_id, role_id) DO NOTHING;
    `);
    console.log(`Success! Linked users to the "vendor" role.`);
  } catch (err) {
    console.error('Error executing query:', err);
  } finally {
    await client.end();
  }
}

run();
