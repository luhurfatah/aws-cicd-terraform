const getUsers = async (event, pool, query) => {
    let page;
    if(query) {
         page  = query? query.page : undefined;
    }
   
    const limit = 6
    const offset = (page - 1) * limit
    const result = await pool.query('SELECT * FROM users')

    if (result[0].length === 0) {
        return {
            isBase64Encoded: false,
            headers: {},
            multiValueHeaders: {}, 
            statusCode: 400,
            body: JSON.stringify({}),
        };
    }

    if (!!page) {
        let data = result[0].slice(offset, offset+limit)
        return {
            isBase64Encoded: false,
            headers: {},
            multiValueHeaders: {}, 
            statusCode: 200,
            body: JSON.stringify({
                "page": page,
                "per_page": limit,
                "total": result[0].length,
                "total_pages": Math.ceil(result[0].length / limit),
                "data": data
            }),
        };
    } else {
        let data = result[0]
        return {
            isBase64Encoded: false,
            headers: {},
            multiValueHeaders: {}, 
            statusCode: 200,
            body: JSON.stringify({
                "page": page,
                "per_page": limit,
                "total": result[0].length,
                "total_pages": Math.ceil(result[0].length / limit),
                "data": data
            }),
        };

    }
};

const getUserById = async (event, pool, id) => {
    const result = await pool.query('SELECT * FROM users WHERE id=?', id)
    if (result[0].length == 0){
       
        return {
            isBase64Encoded: false,
            headers: {},
            multiValueHeaders: {}, 
            statusCode: 400,
            body: JSON.stringify({}),
        };
    } 
    let data = result[0][0]
    return {
        isBase64Encoded: false,
        headers: {},
        multiValueHeaders: {}, 
        statusCode: 200,
        body: JSON.stringify({
            "data" : {
                ...data
            }
        }),
    };
    
}

const createUser = async (event, pool) => {
    let { body } = event
    const user = JSON.parse(body)
    const [result] = await pool.query('INSERT INTO users (name, job, createdAt) VALUES (?, ?, CURRENT_TIMESTAMP)', [user.name, user.job])

    if (result.affectedRows === 1) {
        const [newUser] =   await pool.query('SELECT * FROM users WHERE id=?', result.insertId)
        if (newUser.length == 1) {
            return {
                isBase64Encoded: false,
                headers: {},
                multiValueHeaders: {}, 
                statusCode: 201,
                body: JSON.stringify(newUser[0])
            };
        }
        
    } else {
      return {
        isBase64Encoded: false,
        headers: {},
        multiValueHeaders: {}, 
        statusCode: 500,
        body: JSON.stringify({ message: 'Error creating user' }),
      };
    }
}

const updateUser = async (event, pool, id) => {
    let { body } = event
    const user = JSON.parse(body)
    const [result] = await pool.query('UPDATE users SET name = ?, job = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?', [user.name, user.job, id]);
    if (result.affectedRows === 1) {
        const [newUser] =   await pool.query('SELECT * FROM users WHERE id=?', id)
        if (newUser.length == 1) {
            return {
                isBase64Encoded: false,
                headers: {},
                multiValueHeaders: {}, 
                statusCode: 201,
                body: JSON.stringify( newUser[0])
            };
        }
        
    } else {
      return {
        isBase64Encoded: false,
        headers: {},
        multiValueHeaders: {},    
        statusCode: 500,
        body: JSON.stringify({ message: 'Error updating user' }),
      };
    }
}

const deleteUser = async (event, pool, id) => {
    const [result] = await pool.query('DELETE FROM users WHERE id = ?', [id]);

    if (result.affectedRows === 1) {
        return {
            statusCode: 204,
        };
    } else {
        return {
            statusCode: 500,
        };
    }
    
}

module.exports = {getUsers, getUserById, createUser, updateUser, deleteUser}



