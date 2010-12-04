@WebActors ?= {}

current_actor = null
next_actor_id = 0
actors_by_id = {}

alloc_actor_id = ->
  next_actor_id++

lookup_actor = (actor_id) ->
  actors_by_id[actor_id]

register_actor = (actor_id, actor) ->
  actors_by_id[actor_id] = actor

unregister_actor = (actor_id) ->
  delete actors_by_id[actor_id]

class Actor
  constructor: (@actor_id) ->
    @mailbox = new WebActors.Mailbox()
    @state = {}
    @clauses = null
    @kill_handler = null
    @linked = {}

  link: (actor_id) ->
    @linked[actor_id] = true

  unlink: (actor_id) ->
    delete @linked[actor_id]

  send: (message) ->
    @mailbox.postMessage(message)

  kill: (killed, reason) ->
    if @kill_handler
      try
        message = @kill_handler(killed, reason)
      catch e
        shutdown_actor @actor_id, e
        return
      send @actor_id, message
    else
      shutdown_actor @actor_id, reason

  notify_linked: (reason) ->
    for actor_id of @linked
      propagate_kill actor_id, @actor_id, reason
  
shutdown_actor = (actor_id, reason) ->
  actor = lookup_actor(actor_id)
  if actor
    unregister_actor(actor.actor_id)
    actor.notify_linked(reason)

wrap_actor_cont = (actor, cont, args) ->
  -> 
    actor.clauses = null
    reason = null
    current_actor = actor
    try
      cont.apply(actor.state, args)
    catch e
      actor.clauses = null
      reason = e
    finally
      current_actor = null
      if actor.clauses
        actor.mailbox.consumeOnce (message) ->
         for [pattern, cont] in actor.clauses
            captured = WebActors.match(pattern, message)
            if captured
              return wrap_actor_cont(actor, cont, captured)
          return null
      else
        shutdown_actor actor.actor_id, reason

spawn = (body) ->
  actor_id = alloc_actor_id()
  actor = new Actor(actor_id)
  register_actor(actor_id, actor)
  setTimeout(wrap_actor_cont(actor, body, []), 0)
  actor_id

spawn_linked = (body) ->
  actor_id = spawn body
  link actor_id
  actor_id

send = (actor_id, message) ->
  actor = lookup_actor(actor_id)
  if actor
    actor.send(message)

receive = (pattern, cont) ->
  actor = current_actor
  clause = [pattern, cont]
  if not actor.clauses
    actor.clauses = [clause]
  else
    actor.clauses.push clause

self = ->
  current_actor.actor_id

send_self = (message) ->
  send current_actor.actor_id, message

trap_kill = (handler) ->
  current_actor.kill_handler = handler

propagate_kill = (actor_id, killing, reason) ->
  actor = lookup_actor(actor_id)
  if actor
    actor.kill(killing, reason)

kill = (actor_id, reason) ->
  propagate_kill actor_id, current_actor.actor_id, reason

link = (actor_id) ->
  actor = lookup_actor(actor_id)
  if actor
    current_actor.link(actor_id)
    actor.link(current_actor.actor_id)
  else
    throw "No such actor"

unlink = (actor_id) ->
  actor = lookup_actor(actor_id)
  if actor
    current_actor.unlink(actor_id)
    actor.unlink(current_actor.actor_id)

sendback = (curried_args...) ->
  actor_id = self()
  (callback_args...) ->
    send actor_id, curried_args.concat(callback_args)

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
