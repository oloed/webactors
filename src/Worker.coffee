WebActors = if require? and exports?
              exports
            else
              @WebActors ?= {}

monitors_by_worker = {}

spawnWorker = (script_url) ->
  worker_prefix = WebActors._allocateChildPrefix("worker")
  worker_id = "#{worker_prefix}:0"

  worker = new Worker(script_url)

  # launch a monitor to handle termination and cleanup
  monitor_id = WebActors._spawnMonitor worker_id, ->
    # shut down routing to the worker
    WebActors._unregisterGateway worker_prefix
    # terminate the worker
    worker.terminate()

  monitors_by_worker[worker_id] = monitor_id

  # set up event routing to/from the worker

  worker.onmessage = (event) ->
    event = event.data
    event_name = event.event_name
    if event_name is "worker.error"
      WebActors._reportError(event.message)
    else
      if event_name is "link" or event_name is "unlink"
        WebActors.send monitor_id, event
      WebActors._injectEvent(event)

  WebActors._registerGateway worker_prefix, (event) ->
    event_name = event.event_name
    if event_name is "link" or event_name is "unlink"
      WebActors.send monitor_id, event
    worker.postMessage(event)

  # kick off the worker
  worker.postMessage(worker_prefix)

  worker_id

spawnLinkedWorker = (script_url) ->
  worker_id = spawnWorker(script_url)
  WebActors.link(worker_id)
  worker_id

initWorker = (body) -> 
  WebActors._setErrorHandler (message) ->
    error_event =
      event_name: "worker.error"
      message: message
    self.postMessage(error_event)

  self.onmessage = (event) ->
    local_prefix = event.data
    WebActors._setLocalPrefix local_prefix

    self.onmessage = (event) ->
      WebActors._injectEvent(event.data)
    WebActors._setDefaultGateway (event) ->
      self.postMessage(event)

    WebActors.spawn ->
      body.apply(this)

terminateWorker = (worker_id) ->
  monitor_id = monitors_by_worker[worker_id]
  if monitor_id
    delete monitors_by_worker[worker_id]
    WebActors.send monitor_id, "terminate"

WebActors.spawnWorker = spawnWorker
WebActors.spawnLinkedWorker = spawnLinkedWorker
WebActors.initWorker = initWorker
WebActors.terminateWorker = terminateWorker
