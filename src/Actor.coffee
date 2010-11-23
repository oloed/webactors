@WebActors ?= {}

class Actor
  constructor: (@actor_id) ->
    @mailbox = new WebActors.Mailbox()
    @clauses = null
  
current_actor = null
next_actor_id = 0
actors_by_id = {}

alloc_actor_id = ->
  next_actor_id++

wrap_actor_cont = (actor, cont, args) ->
  -> 
    current_actor = actor
    actor.clauses = null
    try
      cont.apply(this, args)
    catch e
      alert e + e.stack
    finally
      if actor.clauses
        actor.mailbox.consumeOnce (message) ->
          for [pattern, cont] in actor.clauses
            captured = WebActors.match(pattern, message)
            if captured
              return wrap_actor_cont(actor, cont, captured)
          return null
      else
        # reap dead actor
        delete actors_by_id[actor.actor_id]
      current_actor = null

spawn = (body) ->
  actor_id = alloc_actor_id()
  actor = new Actor(actor_id)
  actors_by_id[actor_id] = actor
  setTimeout(wrap_actor_cont(actor, body, []), 0)
  actor_id

send = (actor_id, message) ->
  actor = actors_by_id[actor_id]
  actor.mailbox.postMessage(message)

receive = (pattern, cont) ->
  actor = current_actor
  clause = [pattern, cont]
  if not actor.clauses
    actor.clauses = [clause]
  else
    actor.clauses.push clause

get_self = ->
  current_actor.actor_id

@WebActors.spawn = spawn
@WebActors.send = send
@WebActors.receive = receive
@WebActors.get_self = get_self
@WebActors.send_self = (message) -> send get_self(), message
