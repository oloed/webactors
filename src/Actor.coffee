@WebActors ?= {}

class Actor
  constructor: (@actor_id) ->
    @mailbox = new WebActors.Mailbox()
  
current_actor = null
next_actor_id = 0
actors_by_id = {}

alloc_actor_id = ->
  next_actor_id++

wrap_actor_cont = (actor, cont, args) ->
  -> 
    current_actor = actor
    try
      cont.apply(this, args)
    finally
      if not actor.mailbox.hasConsumers()
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

receive = (pairs...) ->
  actor = current_actor
  actor.mailbox.consumeOnce (message) ->
    for pair in pairs
      [pattern, cont] = pair
      captured = WebActors.match(pattern, message)
      if captured
        return wrap_actor_cont(actor, cont, captured)
    return null

get_current = ->
  current_actor.actor_id

@WebActors.spawn = spawn
@WebActors.send = send
@WebActors.receive = receive
@WebActors.get_current = get_current
