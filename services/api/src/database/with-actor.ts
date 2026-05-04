import type { Pool, PoolClient } from 'pg';

/**
 * Runs `fn` inside a transaction with `owanbe.actor_user_id` set for audit triggers (004).
 */
export async function withActor<T>(
  pool: Pool,
  actorUserId: string,
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`SELECT set_config('owanbe.actor_user_id', $1, true)`, [actorUserId]);
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}
