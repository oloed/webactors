@WebActors ?= {}

class NullActor
  constructor: ->
    @actor_id = null

  link: (actor_id) ->
    throw "No current actor"

  unlink: (actor_id) ->
    throw "No current actor"

  send: (message) ->

  kill: (killer_id, reason) ->

  trap_kill: (handler) ->
    throw "No current actor"

  receive: (pattern, cont) ->
    throw "No current actor"

NULL_ACTOR = new NullActor()
current_actor = NULL_ACTOR

class DeadActor
  constructor: (@actor_id) ->

  link: (actor_id) ->
    actor = new RemoteActor(actor_id)
    actor.kill(@actor_id, "actor is dead or unreachable")

  unlink: (actor_id) ->

  send: (message) ->
    WebActors._report_actor_error("Discarding message to actor #{@actor_id}")

  kill: (killer_id, reason) ->

class RemoteActor
  constructor: (@actor_id) ->

  route: (verb, param) ->
    get_router().route_message(@actor_id, verb, param)

  link: (actor_id) ->
    @route "link", actor_id

  unlink: (actor_id) ->
    @route "unlink", actor_id

  send: (message) ->
    @route "send", message

  kill: (killer_id, reason) ->
    @route "kill", [killer_id, reason]

class LocalActor
  constructor: (@actor_id) ->
    @mailbox = []
    @killed = false
    @state = {}
    @clauses = []
    @kill_handler = null
    @linked = {}

  link: (actor_id) ->
    @linked[actor_id] = true

  unlink: (actor_id) ->
    delete @linked[actor_id]

  _consume_message: (message) ->
    for [pattern, cont] in @clauses
      captured = WebActors.match(pattern, message)
      if captured
        @clauses = []
        setTimeout(@wrap_cont(cont, captured), 0)
        return true
    return false

  send: (message) ->
    unless @_consume_message(message)
      @mailbox.push(message)

  kill: (killer_id, reason) ->
    if @kill_handler
      saved_actor = current_actor
      current_actor = NULL_ACTOR
      try
        @kill_handler(killer_id, reason)
      catch e
        @shutdown(e)
      finally
        current_actor = saved_actor
    else
      @shutdown(reason)

  trap_kill: (handler) ->
    @kill_handler = handler

  receive: (pattern, cont) ->
    unless @killed
      clause = [pattern, cont]
      @clauses.push clause

  start: (body) ->
    register_actor @actor_id, this
    setTimeout(@wrap_cont(body, []), 0)

  shutdown: (reason) ->
    @killed = true
    @clauses = []
    unregister_actor @actor_id
    linked = @linked
    @linked = null
    for actor_id of linked
      actor = lookup_actor(actor_id)
      actor.kill(@actor_id, reason)

  wrap_cont: (cont, args) ->
    actor = this
    -> 
      return if actor.killed
      reason = null
      current_actor = actor
      try
        cont.apply(actor.state, args)
      catch e
        message = "Actor #{actor.actor_id}: #{e}"
        WebActors._report_actor_error(message)
        reason = e
      finally
        current_actor = NULL_ACTOR
        unless actor.killed
          if actor.clauses.length > 0
            for index in [0...actor.mailbox.length]
              if actor._consume_message(actor.mailbox[index])
                actor.mailbox.splice(index, 1)
          else
            actor.shutdown(reason)
  
next_actor_serial = 0
local_prefix_string = ""
actors_by_id = {}

set_local_prefix = (prefix) ->
  local_prefix_string = "#{prefix}:"

alloc_actor_id = ->
  "#{local_prefix_string}#{next_actor_serial++}"

lookup_actor = (actor_id) ->
  actors_by_id[actor_id] or new RemoteActor(actor_id)

register_actor = (actor_id, actor) ->
  actors_by_id[actor_id] = actor

unregister_actor = (actor_id) ->
  delete actors_by_id[actor_id]

router_configured = false
get_router = ->
  router = WebActors._router
  if not router_configured
    router.set_default_gateway (actor_id, verb, param) ->
      actor = actors_by_id[actor_id] or new DeadActor(actor_id)
      if verb is "send" or verb is "link" or verb is "unlink"
        actor[verb](param)
      else if verb is "kill"
        [killer_id, reason] = param
        actor.kill(killer_id, reason)
      else
        console.error("Unknown verb '#{verb}' directed at actor #{actor_id}")
    router_configured = true
  router

spawn = (body) ->
  actor_id = alloc_actor_id()
  actor = new LocalActor(actor_id)
  actor.start(body)
  actor_id

spawn_linked = (body) ->
  actor_id = spawn body
  link actor_id
  actor_id

send = (actor_id, message) ->
  actor = lookup_actor(actor_id)
  actor.send(message)

receive = (pattern, cont) ->
  actor = current_actor
  current_actor.receive(pattern, cont)

self = ->
  current_actor.actor_id

send_self = (message) ->
  send current_actor.actor_id, message

trap_kill = (handler) ->
  current_actor.trap_kill handler

kill = (actor_id, reason) ->
  actor = lookup_actor(actor_id)
  actor.kill(current_actor.actor_id, reason)

link = (actor_id) ->
  current_actor.link(actor_id)
  actor = lookup_actor(actor_id)
  actor.link(current_actor.actor_id)

unlink = (actor_id) ->
  current_actor.unlink(actor_id)
  actor = lookup_actor(actor_id)
  actor.unlink(current_actor.actor_id)

_sendback = (actor_id, curried_args) ->
  (callback_args...) ->
    send actor_id, curried_args.concat(callback_args)

sendback = (curried_args...) ->
  _sendback(self(), curried_args)

sendback_to = (actor_id, curried_args...) ->
  _sendback(actor_id, curried_args)

@WebActors.spawn = spawn
@WebActors.spawn_linked = spawn_linked
@WebActors.send = send
@WebActors.receive = receive
@WebActors.self = self
@WebActors.send_self = send_self
@WebActors.trap_kill = trap_kill
@WebActors.kill = kill
@WebActors.link = link
@WebActors.unlink = unlink
@WebActors.sendback = sendback
@WebActors.sendback_to = sendback_to
@WebActors._set_local_prefix = set_local_prefix
@WebActors._report_actor_error = (message) -> console.error(message)
