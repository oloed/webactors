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
