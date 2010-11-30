@WebActors ?= {}

class Actor
  constructor: (@actor_id) ->
    @mailbox = new WebActors.Mailbox()
    @clauses = null
    @exit_handler = null
    @linked = {}

  link: (actor_id) ->
    @linked[actor_id] = true

  send: (message) ->
    @mailbox.postMessage(message)

  send_exit: (exited, exit_reason) ->
    if @exit_handler
      try
        message = @exit_handler(exited, exit_reason)
      catch e
        shutdown_actor @actor_id, e
        return
      send @actor_id, message
    else
      shutdown_actor @actor_id, exit_reason
  
current_actor = null
next_actor_id = 0
actors_by_id = {}

alloc_actor_id = ->
  next_actor_id++

shutdown_actor = (actor_id, exit_reason) ->
  actor = actors_by_id[actor_id]
  if actor
    delete actors_by_id[actor.actor_id]
    for actor_id of actor.linked
      propagate_exit actor_id, actor.actor_id, exit_reason

wrap_actor_cont = (actor, cont, args) ->
  -> 
    current_actor = actor
    actor.clauses = null
    exit_reason = null
    try
      cont.apply(this, args)
    catch e
      actor.clauses = null
      exit_reason = e
    finally
      if actor.clauses
        actor.mailbox.consumeOnce (message) ->
         for [pattern, cont] in actor.clauses
            captured = WebActors.match(pattern, message)
            if captured
              return wrap_actor_cont(actor, cont, captured)
          return null
      else
        shutdown_actor actor.actor_id, exit_reason
      current_actor = null

spawn = (body) ->
  actor_id = alloc_actor_id()
  actor = new Actor(actor_id)
  actors_by_id[actor_id] = actor
  setTimeout(wrap_actor_cont(actor, body, []), 0)
  actor_id

send = (actor_id, message) ->
  actor = actors_by_id[actor_id]
  if actor
    actor.send(message)

receive = (pattern, cont) ->
  actor = current_actor
  clause = [pattern, cont]
  if not actor.clauses
    actor.clauses = [clause]
  else
    actor.clauses.push clause

get_self = ->
  current_actor.actor_id

send_self = (message) ->
  send current_actor.actor_id, message

trap_exit = (handler) ->
  current_actor.exit_handler = handler

propagate_exit = (actor_id, exiting, exit_reason) ->
  actor = actors_by_id[actor_id]
  if actor
    actor.send_exit(exiting, exit_reason)

send_exit = (actor_id, exit_reason) ->
  propagate_exit actor_id, current_actor.actor_id, exit_reason

link = (actor_id) ->
  actor = actors_by_id[actor_id]
  if actor
    current_actor.link(actor_id)
    actor.link(current_actor.actor_id)
  else
    throw "No such actor"

@WebActors.spawn = spawn
@WebActors.send = send
@WebActors.receive = receive
@WebActors.get_self = get_self
@WebActors.send_self = send_self
@WebActors.trap_exit = trap_exit
@WebActors.send_exit = send_exit
@WebActors.link = link
