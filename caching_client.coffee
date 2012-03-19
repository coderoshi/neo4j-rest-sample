http = require('http')
events = require('events')
esc = require('querystring').escape
redis = require('redis')
neo4j = require('./driver')

exports.createClient = (options, redis_options)->
  options = options || {}
  redis_options = redis_options || {}
  neo4jClient = neo4j.createClient(options)
  if redis_options['redisClient']
    redisClient = redis_options['redisClient']
  else
    redisClient = redis.createClient(redis_options)
  pending = new events.EventEmitter()
  
  pending.setMaxListeners(0)   # unlimited
  neo4jClient.expiry = options.expiry || 300  # default 5 min

  # Run a cypher query against the server.
  neo4jClient.runCypher = (query, callback)->
    path = ['cypher']
    neo4jClient.post(path, { query : query }, callback)

  # Run a gremlin script against the server.
  neo4jClient.runGremlin = (script, callback)->
    path = ['ext/GremlinPlugin/graphdb/execute_script']
    neo4jClient.post(path, { script : script }, callback)

  # lookup a key/value node by index.
  neo4jClient.lookupNode = (index, key, value, callback)->
    path = ['index/node', esc(index), esc(key), esc(value)]
    neo4jClient.get(path, callback)

  # create a key/value node and index it.
  neo4jClient.createNode = (index, key, value, callback)->
    input = {}
    input[key] = value
    neo4jClient.post 'node', input, (obj)->
      data = { uri: obj.self, key: key, value: value }
      neo4jClient.post(['index/node', esc(index)], data, callback)

  # lookup a node or create/index and cache it
  neo4jClient.lookupOrCreateNode = (index, key, value, callback)->
    
    cacheKey = "lookup:#{index}:#{key}:#{value}"
    ex = neo4jClient.expiry
    
    # only one pending lookup for a given index/key/value allowed at a time
    unless pending.listeners(cacheKey).length
      # check redis first
      redisClient.get cacheKey, (err, text)->
        if !err and text
          # found in redis cache, use it and refresh
          pending.emit(cacheKey, JSON.parse(text))
          redisClient.expire(cacheKey, ex)
        else
          # missed redis cache, lookup in neo4j index
          neo4jClient.lookupNode index, key, value, (list, res)->
            if list and list.length
              # found in index, use it and cache
              pending.emit(cacheKey, list[0])
              redisClient.setex(cacheKey, ex, JSON.stringify(list[0]))
            else
              # missed index, create it and cache it
              neo4jClient.createNode index, key, value, (obj)->
                pending.emit(cacheKey, obj)
                redisClient.setex(cacheKey, ex, JSON.stringify(obj))

    pending.once(cacheKey, callback)
  
  # create a relationship between two nodes
  neo4jClient.createRelationship = (fromNode, toNode, type, callback)->
    fromPath = (fromNode || '').replace(/^.*?\/db\/data\//, '')
    neo4jClient.post [fromPath, 'relationships'], {to: toNode, type: type}, callback
  
  neo4jClient
