describe "WebActors.Router", ->
  router = null

  beforeEach ->
    router = new WebActors.Router()

  it "should support submitting messages", ->
    router.route_message "foobar", 123

  it "should support registering gateways", ->
    received = []
    router.route_message "foobar", "abc"
    router.register_gateway "foobar", (node, message) ->
      received.push [node, message]
    router.route_message "groms", "xyz"
    router.route_message "foobar", "def"
    expect(received).toEqual([["foobar", "def"]])

  it "should support unregistering gateways", ->
    received = []
    router.route_message "foobar", "abc"
    router.register_gateway "foobar", (node, message) ->
      received.push [node, message]
    router.route_message "foobar", "def"
    router.unregister_gateway "foobar"
    router.route_message "foobar", "ghi"
    expect(received).toEqual([["foobar", "def"]])

  it "should allow setting the default gateway", ->
    received = []
    router.route_message "foobar", "abc"
    router.set_default_gateway (node, message) ->
      received.push [node, message]
    router.route_message "foobar", "def"
    expect(received).toEqual([["foobar", "def"]])

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
    router.register_gateway "root", (node, message) ->
      received.push [node, message]
    router.set_default_gateway (node, message) ->
      received.push [node, message]
    WebActors.send "root:0", "foobar"
    expect(received).toEqual([])

  it "should route messages for other nodes", ->
    received = []
    router.register_gateway "hoge", (node, message) ->
      received.push [node, message]
    router.set_default_gateway (node, message) ->
      received.push "fail"
    WebActors.send "hoge:0", "foobar"
    expect(received).toEqual([["hoge", ["send", "hoge:0", "foobar"]]])

  it "should route messages for unknown nodes", ->
    received = []
    router.register_gateway "hoge", (node, message) ->
      received.push "fail"
    router.set_default_gateway (node, message) ->
      received.push [node, message]
    WebActors.send "hoge2:0", "foobar"
    expect(received).toEqual([["hoge2", ["send", "hoge2:0", "foobar"]]])

  it "should route kill messages", ->
    received = []
    router.register_gateway "hoge", (node, message) ->
      received.push [node, message]

    actor_id = WebActors.spawn ->
      WebActors.kill "hoge:0", "foobar"

    waitsFor -> received.length > 0

    runs ->
      expect(received).toEqual([
        ["hoge", ["kill", "hoge:0", actor_id, "foobar"]]])

  it "should route link messages", ->
    received = []
    router.register_gateway "hoge", (node, message) ->
      received.push [node, message]

    actor_id = WebActors.spawn ->
      WebActors.link "hoge:0"

    waitsFor -> received.length > 1

    runs ->
      expect(received).toEqual([
        ["hoge", ["link", "hoge:0", actor_id]],
        ["hoge", ["kill", "hoge:0", actor_id, null]]])

  it "should route unlink messages", ->
    received = []
    router.register_gateway "hoge", (node, message) ->
      received.push [node, message]

    actor_id = WebActors.spawn ->
      WebActors.link "hoge:0"
      WebActors.unlink "hoge:0"

    waitsFor -> received.length > 1

    runs ->
      expect(received).toEqual([
        ["hoge", ["link", "hoge:0", actor_id]],
        ["hoge", ["unlink", "hoge:0", actor_id]]])
