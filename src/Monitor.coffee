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

spawnMonitor = (worker_id, do_cleanup) ->
  monitor_id = WebActors.spawn ->
    WebActors.trapKill (killer_id, reason) ->
      ["exited", killer_id]
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

    track_exit = (actor_id) ->
      worker_links.remove(actor_id)
      WebActors.unlink actor_id

    # track outstanding links with actors in the worker
    monitor_loop = ->
      WebActors.receive "terminate", ->
        do_cleanup()
        WebActors.sendSelf "terminated"
        termination_loop()

      WebActors.receive {event_name: "link"}, (event) ->
        track_link(event.target_id, event.peer_id)
        monitor_loop()

      WebActors.receive {event_name: "unlink"}, (event) ->
        track_unlink(event.target_id, event.peer_id)
        monitor_loop()

      WebActors.receive ["exited", WebActors.ANY], (m) ->
        actor_id = m[1]
        track_exit(actor_id)
        if actor_id is worker_id
          WebActors.sendSelf "terminate"
        monitor_loop()

    # catch up on outstanding link/unlink events,
    # then synthesize kills and exit
    termination_loop = ->
      WebActors.receive {event_name: "link"}, (event) ->
        track_link(event.target_id, event.peer_id)
        termination_loop()

      WebActors.receive {event_name: "unlink"}, (event) ->
        track_unlink(event.target_id, event.peer_id)
        termination_loop()

      WebActors.receive "terminated", ->
        # synthesize kills from actors in terminated worker
        for actor_id, links of worker_links.links
          for peer_id, flag of links
            message = "Worker #{worker_id} terminated"
            synthesize_kill(peer_id, actor_id, message)

    monitor_loop()

WebActors._spawnMonitor = spawnMonitor
