const mysql = require('mysql2/promise');
const { parseEvent,getDBSecret } = require('./helper');
const { getUsers, getUserById, createUser, updateUser, deleteUser } = require('./handler');


exports.handler = async (event) => {
  const secret = await getDBSecret()
  const dbConfig = {
  host: secret.db_host,
  user: secret.username,
  password: secret.password,
  database: secret.db_name
};

  const pool = mysql.createPool(dbConfig);
  await pool.query('CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255), job VARCHAR(255), createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updatedAt TIMESTAMP)');

  try {
    const { method, route, query, id } = parseEvent(event);

    switch (`${method}:${route}`) {
      case 'get:/api/users':
        return await getUsers(event, pool, query);
      case 'get:/api/users/:id':
        return await getUserById(event, pool, id);
      case 'post:/api/users':
        return await createUser(event, pool);
      case 'put:/api/users/:id':
        return await updateUser(event, pool, id);
      case 'patch:/api/users/:id':
        return await updateUser(event, pool, id);
      case 'delete:/api/users/:id':
        return await deleteUser(event, pool, id);
      default:
        return {
          statusCode: 400,
          body: JSON.stringify({ message: 'Invalid route or method' }),
        };
    }
  } finally {
    await pool.end();
  }
};


