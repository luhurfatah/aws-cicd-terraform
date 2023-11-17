const {SecretsManagerClient, GetSecretValueCommand} = require ("@aws-sdk/client-secrets-manager")
const parseEvent = (event) => {
    const {path,httpMethod, queryStringParameters } = event;
    const match = path? path.match(/^\/api\/users(?:\/(\d+))?/) : ''
    const id = match && match[1] ? match[1] : null;
    const route = id ? '/api/users/:id' : '/api/users';
    const method = httpMethod? httpMethod.toLowerCase() : undefined;
    const query = queryStringParameters? queryStringParameters : undefined
    return { method, route, id, query };
};

const getDBSecret = async () => {
    const secret_name = "<SECRET_NAME>";
  
    const client = new SecretsManagerClient({
      region: "ap-southeast-1",
    });
  
    let response;
  
    try {
      response = await client.send(
        new GetSecretValueCommand({
          SecretId: secret_name,
          VersionStage: "AWSCURRENT",
        })
      );
    } catch (error) {
      throw error;
    }
  
    const secret = JSON.parse(response.SecretString);
    return secret["db_credentials"];
  };

module.exports =  {parseEvent, getDBSecret}