error = console.error
http = require('http')

exports.createClient = (options)->
  options = options || {}
  running = 0
  backlog = []
  host = options.host || 'localhost'
  port = options.port || 7474
  limit = options.limit || 10

  headers = {'Content-Type':'application/json'}
  if options.username && options.password
    auth = new Buffer("#{options.username}:#{options.password}").toString('base64')
    auth = "Basic #{auth}"
    headers['Authorization'] = auth
  
  dequeue = () ->
    if backlog.length and running < limit
      req.apply null, backlog.shift()
  
  req = (method, path, data, callback)->
    running += 1
    http.request({
      host: host
      port: port
      path: '/db/data/' + (if path.join then path.join('/') else path)
      headers: headers
      method: method
    }, (res)->
      buffer = ''
      res.on 'data', (chunk)-> buffer += chunk
      res.on 'end', ()->
        if callback and buffer != ''
          try
            output = JSON.parse(buffer)
          catch err
            error err
          if output.exception
            callback(new Error(output.exception), null, res)
          else
            callback(null, output, res)
        running -= 1
        dequeue()
    ).on('error', ()->
      running -= 1
      backlog.push([method, path, data, callback])
      dequeue()
    ).end(if data then JSON.stringify(data) else undefined)
  
  return {
    get: (path, callback)->
      backlog.push(['GET', path, null, callback])
      dequeue()
    post: (path, data, callback)->
      backlog.push(['POST', path, data, callback])
      dequeue()
  }
