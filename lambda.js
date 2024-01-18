const { Client } = require("pg"); 
const dns = require("dns") 

const DB_USERNAME = process.env.DB_USERNAME || "" 
const DB_PASS = process.env.DB_PASSWORD || "" 
const DB_HOST = process.env.DB_HOST || "" 
const DB_PORT = process.env.DB_PORT || "5432" 
const DB_DATABASE = process.env.DB_DATABASE || "postgres" 

const dbInitScript = `CREATE TABLE IF NOT EXISTS requests( 
 id serial primary key, 
 message text, 
 target text, 
 ip text, 
 timestamp TIMESTAMP 
);` 

exports.handler = async (event) => { 
  try{ 
     validateEnv("DB_USERNAME", DB_USERNAME) 
     validateEnv("DB_PASSWORD", DB_PASS) 
     validateEnv("DB_HOST", DB_HOST) 
     validateEnv("DB_PORT", DB_PORT) 
     validateEnv("DB_DATABASE", DB_DATABASE) 
  }catch (e){ 
     console.error(e) 
     return { 
        statusCode: 500, 
        body : e, 
     } 
  } 
  console.log("Lambda input: ",event); 
  let message = ""; 
  let target = ""; 
  if(event.body){ 
     let body = JSON.parse(event.body); 
     message = body.message; 
     target = body.target; 
  }else{ 
     message = event.message 
     target = event.target 
  } 
  const client = new Client(buildDbConfig()); 
  try { 
     console.log("Establishing database connection ...") 
     await client.connect(); 
     console.log("Database client connected") 
     await ensureDbSchema(client); 
     console.log(`Resolving domain ${target} to ip address ...`) 
     const ip = await getDomainIP(target) 
     console.log("Domain to ip resolved: "+ip)

    await insertRow(client, message, target,ip,new Date()) 
 } catch(e){ 
    console.error("Error ",e) 
    return { 
       statusCode: 200, 
       body : "An error has happened"+e, 
    }; 
 } finally { 
    await client.end(); 
 } 
 return { 
    statusCode: 200, 
    body : "Record inserted! Thank you for your report!", 
 }; 
}; 

async function insertRow(client, message, target, ip, timestamp){ 
 const res = await client.query( 
    "insert into requests (message, target, ip, timestamp) values ($1, $2, $3, $4)", 
    [message, target, ip, timestamp] 
 ); 
 console.log("Insert result: ",res); 
 return res 

} 
async function getDomainIP(domain) { 
 try { 
    const ipAddresses = await dns.promises.resolve(domain); 
    return ipAddresses[0]; 
 } catch (error) { 
    return "failed"; 
 } 
} 

async function ensureDbSchema(client){ 
 return client.query(dbInitScript) 
} 

function buildDbConfig(){ 
 return   { 
    user: DB_USERNAME, 
    password: DB_PASS, 
    host: DB_HOST, 
    port: parseInt(DB_PORT), 
    database: DB_DATABASE, 
    ssl: { rejectUnauthorized: false }, 
 }; 
} 

function validateEnv(envName, envValue){ 
 if(!envValue){ 
    console.error(`No ${envName} configured!`); 
    throw `No ${envName} configured!`; 
 } 
}
