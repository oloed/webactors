WebActors = if require? and exports?
              exports
            else
              @WebActors ?= {}

spawnWorker = (script_url) ->
  worker_prefix = WebActors.allocateChildPrefix("worker")
  worker_id = "#{worker_prefix}:0"

  worker = new Worker(script_url)
  worker.postMessage(worker_prefix)

  worker.onmessage = (event) ->
    WebActors.injectEvent.apply(WebActors, event.data)
  WebActors.registerGateway worker_prefix, (args...) ->
    worker.postMessage(args)

  worker_id

initWorker = (body) -> 
  self.onmessage = (event) ->
    local_prefix = event.data
    WebActors.setLocalPrefix local_prefix

    self.onmessage = (event) ->
      WebActors.injectEvent.apply(WebActors, event.data)
    WebActors.setDefaultGateway (args...) ->
      self.postMessage(args)

    WebActors.spawn ->
      body.apply(this)

WebActors.spawnWorker = spawnWorker
WebActors.initWorker = initWorker
