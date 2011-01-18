WebActors = if require? and exports?
              exports
            else
              @WebActors ?= {}

class LinkMap
  constructor: ->
    @links = {}
    @link_counts = {}

  _link: (a, b) ->
    links = @links[a]
    unless links
      links = {}
      @links[a] = links
    unless links[b]
      links[b] = true
      link_count = (@link_counts[a] or 0) + 1
      @link_counts[a] = link_count

  _unlink: (a, b) ->
    links = @links[a]
    if links and links[b]
      delete links[b]
      link_count = @link_counts[a] - 1
      if link_count is 0
        delete @links[a]
        delete @link_counts[a]
      else
        @link_counts[a] = 0

  link: (local_id, peer_id) ->
    @_link(local_id, peer_id)
    @_link(peer_id, local_id)

  unlink: (local_id, peer_id) ->
    @_unlink(local_id, peer_id)
    @_unlink(peer_id, local_id)

  has_links: (actor_id) ->
    !!@links[actor_id]

  remove: (actor_id) ->
    links = @links[actor_id]
    if links
      delete @links[actor_id]
      delete @link_counts[actor_id]
      for peer_id, flag of links
        @_unlink(peer_id, actor_id)

synthesize_kill = (target_id, killer_id, reason) ->
  event =
    target_id: target_id
    event_name: "kill"
    killer_id: killer_id
    reason: reason
  WebActors._injectEvent event

monitors_by_worker = {}

spawnWorker = (script_url) ->
  worker_prefix = WebActors._allocateChildPrefix("worker")
  worker_id = "#{worker_prefix}:0"

  worker = new Worker(script_url)

  # launch a monitor to handle termination and cleanup
  monitor_id = WebActors.spawn ->
    WebActors.trapKill (killer_id, reason) ->
      ["killed", killer_id]
    WebActors.link worker_id

    worker_links = new LinkMap()

    track_link = (a, b) ->
      unless worker_links.has_links(a)
        WebActors.link a
      unless worker_links.has_links(b)
        WebActors.link b
      worker_links.link(a, b)

    track_unlink = (a, b) ->
      worker_links.unlink(a, b)
      unless worker_links.has_links(a)
        WebActors.unlink a
      unless worker_links.has_links(b)
        WebActors.unlink b

    track_link_events = (event) ->
      if event.event_name is "link"
        track_link(event.target_id, event.peer_id)
      else if event.event_name is "unlink"
        track_unlink(event.target_id, event.peer_id)

    track_exit = (actor_id) ->
      worker_links.remove(actor_id)
      WebActors.unlink actor_id

    # catch up on outstanding events, then synthesize kills and exit
    termination_loop = ->
      WebActors.receive ["from_worker", WebActors.ANY], (m) ->
        event = m[1]
        track_link_events(event)
        WebActors._injectEvent(event)
        termination_loop()

      WebActors.receive ["to_worker", WebActors.ANY], (m) ->
        event = m[1]
        track_link_events(event)
        termination_loop()

      WebActors.receive "terminated", ->
        for actor_id, links of worker_links.links
          for peer_id, flag of links
            synthesize_kill(peer_id, actor_id, null)

    # track outstanding links to actors in worker
    monitor_loop = ->
      WebActors.receive "terminate", ->
        delete monitors_by_worker[worker_id]

        # shut down routing to the worker
        WebActors._unregisterGateway worker_prefix

        # terminate the worker and enter cleanup phase
        worker.terminate()
        WebActors.sendSelf "terminated"
        termination_loop()

      WebActors.receive ["from_worker", WebActors.ANY], (m) ->
        event = m[1]
        track_link_events(event)
        WebActors._injectEvent(event)
        monitor_loop()

      WebActors.receive ["to_worker", WebActors.ANY], (m) ->
        event = m[1]
        track_link_events(event)
        worker.postMessage(event)
        monitor_loop()

      WebActors.receive ["killed", WebActors.ANY], (m) ->
        actor_id = m[1]
        track_exit(actor_id)
        if actor_id is worker_id
          WebActors.sendSelf "terminate"
        monitor_loop()

    monitor_loop()

  monitors_by_worker[worker_id] = monitor_id

  # set up event routing to/from the worker via the monitor
  worker.onmessage = (event) ->
    event = event.data
    if event.event_name is "worker.error"
      WebActors._reportError(event.message)
    else
      WebActors.send monitor_id, ["from_worker", event]

  WebActors._registerGateway worker_prefix, (event) ->
    WebActors.send monitor_id, ["to_worker", event]

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
    WebActors.send monitor_id, "terminate"

WebActors.spawnWorker = spawnWorker
WebActors.spawnLinkedWorker = spawnLinkedWorker
WebActors.initWorker = initWorker
WebActors.terminateWorker = terminateWorker
