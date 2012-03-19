# Hosted Neo4J NodeJS Example (in CoffeeScript)

Try it like this (ripped and cleaned up from [Seven Databases in Seven Weeks](http://sevenweeks.org))
    
    neo4j_url = require('url').parse(process.env.NEO4J_URL)
    
    neo4j = require('./neo4j/caching_client').createClient({
      port: neo4j_url.port
      host: neo4j_url.hostname
      username : process.env.NEO4J_LOGIN
      password : process.env.NEO4J_PASSWORD
    })

    neo4j.runCypher 'START x = node(0) RETURN x', (err, output, res)->
      if err
        console.log err.message
      else
        console.log output

Used in [ApperJack](http://www.apperjack.com).