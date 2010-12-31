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

  trapKill: (handler) ->
    throw "No current actor"

  receive: (pattern, cont) ->
    throw "No current actor"

NULL_ACTOR = new NullActor()
current_actor = NULL_ACTOR

class DeadActor
  constructor: (@actor_id) ->

  link: (actor_id) ->
    actor = lookup_actor(actor_id)
    actor.kill(@actor_id, "actor is dead or unreachable")

  unlink: (actor_id) ->

  send: (message) ->
    console.error("Discarding message to actor #{@actor_id}")

  kill: (killer_id, reason) ->

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

  trapKill: (handler) ->
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
        console.error(message)
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
actors_by_id = {}

alloc_actor_id = ->
  String(next_actor_serial++)

lookup_actor = (actor_id) ->
  actors_by_id[actor_id] or new DeadActor(actor_id)

register_actor = (actor_id, actor) ->
  actors_by_id[actor_id] = actor

unregister_actor = (actor_id) ->
  delete actors_by_id[actor_id]

spawn = (body) ->
  actor_id = alloc_actor_id()
  actor = new LocalActor(actor_id)
  actor.start(body)
  actor_id

spawnLinked = (body) ->
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

sendSelf = (message) ->
  send current_actor.actor_id, message

trapKill = (handler) ->
  current_actor.trapKill handler

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

sendbackTo = (actor_id, curried_args...) ->
  _sendback(actor_id, curried_args)

injectEvent = (actor_id, verb, args...) ->
  actor = lookup_actor(actor_id)
  actor[verb].apply(actor, args)
  undefined

@WebActors.spawn = spawn
@WebActors.spawnLinked = spawnLinked
@WebActors.send = send
@WebActors.receive = receive
@WebActors.self = self
@WebActors.sendSelf = sendSelf
@WebActors.trapKill = trapKill
@WebActors.kill = kill
@WebActors.link = link
@WebActors.unlink = unlink
@WebActors.sendback = sendback
@WebActors.sendbackTo = sendbackTo
@WebActors.injectEvent = injectEvent
