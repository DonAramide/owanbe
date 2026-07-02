const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const DATABASE_URL = process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/owanbe';

async function run() {
  console.log(`Connecting to database to apply migration: ${DATABASE_URL.replace(/:[^:@]+@/, ':***@')}`);
  const client = new Client({ connectionString: DATABASE_URL });
  try {
    await client.connect();
    const sqlPath = path.join(__dirname, '..', 'infra', 'db', '044_ai_negotiation_engine.sql');
    const sqlContent = fs.readFileSync(sqlPath, 'utf8');
    
    console.log('Applying 044_ai_negotiation_engine.sql...');
    await client.query(sqlContent);
    console.log('Migration successfully applied!');
  } catch (err) {
    console.error('Error applying migration:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

run();
