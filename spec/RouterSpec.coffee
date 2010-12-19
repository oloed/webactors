describe "WebActors.Router", ->
  router = null

  beforeEach ->
    router = new WebActors.Router()

  it "should support submitting messages", ->
    router.route_message "foobar", 123

  it "should support registering gateways", ->
    received = []
    router.route_message "foobar:0", "abc", null
    router.register_gateway "foobar", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    router.route_message "groms:0", "xyz", null
    router.route_message "foobar:0", "def", null
    expect(received).toEqual([["foobar:0", "def", null]])

  it "should support unregistering gateways", ->
    received = []
    router.route_message "foobar:0", "abc", null
    router.register_gateway "foobar", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    router.route_message "foobar:0", "def", null
    router.unregister_gateway "foobar"
    router.route_message "foobar:0", "ghi", null
    expect(received).toEqual([["foobar:0", "def", null]])

  it "should allow setting the default gateway", ->
    received = []
    router.route_message "foobar:0", "abc", null
    router.set_default_gateway (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    router.route_message "foobar:0", "def", null
    expect(received).toEqual([["foobar:0", "def", null]])

describe "WebActors routing", ->
  saved_router = null
  router = null

  beforeEach ->
    saved_router = WebActors._router
    router = new WebActors.Router()
    WebActors._router = router

  afterEach ->
    WebActors._router = saved_router

  it "should not route messages for local actors", ->
    received = []
    router.register_gateway "root", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    router.set_default_gateway (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    WebActors.send "root:0", "foobar"
    expect(received).toEqual([])

  it "should route messages for other nodes", ->
    received = []
    router.register_gateway "hoge", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    router.set_default_gateway (actor_id, verb, param) ->
      received.push "fail"
    WebActors.send "hoge:0", "foobar"
    expect(received).toEqual([["hoge:0", "send", "foobar"]])

  it "should route messages for unknown nodes", ->
    received = []
    router.register_gateway "hoge", (actor_id, verb, param) ->
      received.push "fail"
    router.set_default_gateway (actor_id, verb, param) ->
      received.push [actor_id, verb, param]
    WebActors.send "hoge2:0", "foobar"
    expect(received).toEqual([["hoge2:0", "send", "foobar"]])

  it "should route kill messages", ->
    received = []
    router.register_gateway "hoge", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]

    actor_id = WebActors.spawn ->
      WebActors.kill "hoge:0", "foobar"

    waitsFor -> received.length > 0

    runs ->
      expect(received).toEqual([
        ["hoge:0", "kill", [actor_id, "foobar"]]])

  it "should route link messages", ->
    received = []
    router.register_gateway "hoge", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]

    actor_id = WebActors.spawn ->
      WebActors.link "hoge:0"

    waitsFor -> received.length > 1

    runs ->
      expect(received).toEqual([
        ["hoge:0", "link", actor_id],
        ["hoge:0", "kill", [actor_id, null]]])

  it "should route unlink messages", ->
    received = []
    router.register_gateway "hoge", (actor_id, verb, param) ->
      received.push [actor_id, verb, param]

    actor_id = WebActors.spawn ->
      WebActors.link "hoge:0"
      WebActors.unlink "hoge:0"

    waitsFor -> received.length > 1

    runs ->
      expect(received).toEqual([
        ["hoge:0", "link", actor_id],
        ["hoge:0", "unlink", actor_id]])
