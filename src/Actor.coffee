WebActors = if require? and exports?
              exports
            else
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
    @running = false
    @state = {}
    @receivers = []
    @kill_handler = null
    @linked = {}

  link: (actor_id) ->
    @linked[actor_id] = true

  unlink: (actor_id) ->
    delete @linked[actor_id]

  consume_message: (message) ->
    for receiver in @receivers
      cont = receiver(message)
      if cont
        @receivers = []
        setTimeout(@wrap_cont(cont), 0)
        return true
    return false

  send: (message) ->
    return if not @running and @consume_message(message)
    @mailbox.push(message)

  kill: (killer_id, reason) ->
    if @kill_handler
      saved_actor = current_actor
      current_actor = NULL_ACTOR
      try
        message = @kill_handler(killer_id, reason)
        WebActors.send @actor_id, message
      catch e
        @shutdown(e)
      finally
        current_actor = saved_actor
    else
      @shutdown(reason)

  trapKill: (handler) ->
    @kill_handler = handler

  receive: (pattern, cont) ->
    return if @killed
    receiver = (message) ->
      captured = WebActors.match(pattern, message)
      if captured 
        -> cont.call(this, message)
      else
        null
    @receivers.push receiver

  start: (body) ->
    register_actor @actor_id, this
    setTimeout(@wrap_cont(body), 0)

  shutdown: (reason) ->
    @killed = true
    @receivers = []
    unregister_actor @actor_id
    linked = @linked
    @linked = null
    for actor_id of linked
      actor = lookup_actor(actor_id)
      actor.kill(@actor_id, reason)

  wrap_cont: (cont) ->
    actor = this
    -> 
      return if actor.killed
      reason = null
      current_actor = actor
      actor.running = true
      try
        cont.call(actor.state)
      catch e
        message = "Actor #{actor.actor_id}: #{e}"
        console.error(message)
        reason = e
      finally
        current_actor = NULL_ACTOR
        actor.running = false
        unless actor.killed
          if actor.receivers.length > 0
            for index in [0...actor.mailbox.length]
              if actor.consume_message(actor.mailbox[index])
                actor.mailbox.splice(index, 1)
          else
            actor.shutdown(reason)

class ForwardingActor
  constructor: (@actor_id, @callback) ->

  send: (message) ->
    @callback {target_id:@actor_id, event_name:"send", message:message}

  link: (other_id) ->
    @callback {target_id:@actor_id, event_name:"link", peer_id:other_id}

  unlink: (other_id) ->
    @callback {target_id:@actor_id, event_name:"unlink", peer_id:other_id}

  kill: (killer_id, reason) ->
    @callback {target_id:@actor_id, event_name:"kill", killer_id:killer_id, reason:reason}

next_actor_serial = 0
actors_by_id = {}
local_prefix = "actor:"
default_gateway = null
gateways_by_prefix = {}

getLocalPrefix = -> local_prefix.substr(0, local_prefix.length-1)

setLocalPrefix = (prefix) ->
  local_prefix = "#{prefix}:"

alloc_actor_id = ->
  "#{local_prefix}#{next_actor_serial++}"

allocateChildPrefix = (key) ->
  "#{local_prefix}#{key}#{next_actor_serial++}"

lookup_actor = (actor_id) ->
  actor = actors_by_id[actor_id]
  return actor if actor
  longest_prefix = ""
  if actor_id.substr(0, local_prefix.length) is local_prefix
    longest_prefix = local_prefix
  for prefix, callback of gateways_by_prefix 
    # prefixes in the map include the trailing ':' separator
    if actor_id.substr(0, prefix.length) is prefix
      if prefix.length > longest_prefix.length
        longest_prefix = prefix
  if longest_prefix.length > 0
    if longest_prefix is local_prefix
      return new DeadActor(actor_id)
    else
      callback = gateways_by_prefix[longest_prefix]
      return new ForwardingActor(actor_id, callback)
  else
    if default_gateway
      return new ForwardingActor(actor_id, default_gateway)
    else
      return new DeadActor(actor_id)

register_actor = (actor_id, actor) ->
  actors_by_id[actor_id] = actor

unregister_actor = (actor_id) ->
  delete actors_by_id[actor_id]

registerGateway = (prefix, callback) ->
  prefix = "#{prefix}:"
  gateways_by_prefix[prefix] = callback
  undefined

unregisterGateway = (prefix) ->
  prefix = "#{prefix}:"
  delete gateways_by_prefix[prefix]

setDefaultGateway = (callback) ->
  default_gateway = callback

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
  undefined

receive = (pattern, cont) ->
  actor = current_actor
  current_actor.receive(pattern, cont)
  undefined

self = ->
  current_actor.actor_id

sendSelf = (message) ->
  send current_actor.actor_id, message

trapKill = (handler) ->
  current_actor.trapKill handler
  undefined

kill = (actor_id, reason) ->
  actor = lookup_actor(actor_id)
  actor.kill(current_actor.actor_id, reason)
  undefined

link = (actor_id) ->
  current_actor.link(actor_id)
  actor = lookup_actor(actor_id)
  actor.link(current_actor.actor_id)
  undefined

unlink = (actor_id) ->
  current_actor.unlink(actor_id)
  actor = lookup_actor(actor_id)
  actor.unlink(current_actor.actor_id)
  undefined

injectEvent = (event) ->
  target = lookup_actor(event.target_id)
  event_name = event.event_name
  if event_name is "send"
    target.send(event.message)
  else if event_name is "link"
    target.link(event.peer_id)
  else if event_name is "unlink"
    target.unlink(event.peer_id)
  else if event_name is "kill"
    target.kill(event.killer_id, event.reason)
  undefined

WebActors.spawn = spawn
WebActors.spawnLinked = spawnLinked
WebActors.send = send
WebActors.receive = receive
WebActors.self = self
WebActors.sendSelf = sendSelf
WebActors.trapKill = trapKill
WebActors.kill = kill
WebActors.link = link
WebActors.unlink = unlink
WebActors.injectEvent = injectEvent
WebActors.registerGateway = registerGateway
WebActors.unregisterGateway = unregisterGateway
WebActors.setDefaultGateway = setDefaultGateway
WebActors.getLocalPrefix = getLocalPrefix
WebActors.setLocalPrefix = setLocalPrefix
WebActors.allocateChildPrefix = allocateChildPrefix
