describe "A WebActors Actor", ->
  $ARG = WebActors.$ARG
  ANY = WebActors.ANY

  it "should have a unique ID", ->
    actor_id_a = WebActors.spawn ->
    actor_id_b = WebActors.spawn ->
    expect(actor_id_a).not.toEqual(actor_id_b)

  it "should be able to access its own ID", ->
    got_id = null

    actor_id = WebActors.spawn ->
      got_id = WebActors.self()
      
    waitsFor -> got_id is actor_id

  it "should receive messages", ->
    expected = "foobar"
    received = []

    actor_id = WebActors.spawn ->
      WebActors.receive $ARG, (m) -> received.push(m)

    WebActors.send actor_id, expected

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([expected])

  it "should treat multiple receives as alternatives", ->
    received = []

    actor_id = WebActors.spawn ->
      WebActors.receive $ARG("foo"), (m) ->
        received.push(m)
        WebActors.receive $ARG("baz"), (m) ->
          received.push(m)
      WebActors.receive $ARG("bar"), (m) ->
        received.push(m)
        WebActors.receive $ARG("baz"), (m) ->
          received.push(m)

    WebActors.send actor_id, "bar"
    WebActors.send actor_id, "foo"
    WebActors.send actor_id, "baz"

    waitsFor -> received.length >= 2

    runs -> expect(received).toEqual(["bar", "baz"])

  it "should have shorthand for sending to self", ->
    completed = false

    WebActors.spawn ->
      WebActors.sendSelf "foo"
      WebActors.receive "foo", -> completed = true
    
    waitsFor -> completed

  it "should support exit notification", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      WebActors.receive $ARG, (m) ->
        received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.kill actor_a_id, "foobar"

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, "foobar"]])

  it "should send exit notifications when linked actors exit normally", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      WebActors.receive $ARG, (m) ->
        received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.link actor_a_id

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, null]])

  it "should propagate exit notifications across linked actors", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()
      WebActors.receive $ARG, (m) -> received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.link actor_a_id
      WebActors.receive ANY, ->

    actor_c_id = WebActors.spawn ->
      WebActors.kill actor_b_id, "foobar"

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, "foobar"]])

  it "should kill actors receiving untrapped exit notifications", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.receive $ARG, (m) -> received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.kill actor_a_id, "foobar"
      WebActors.send actor_a_id, "baz"

    setTimeout((-> received.push "watchdog"), 100)

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual(["watchdog"])

  it "should kill actor on trap failure", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()
      WebActors.receive "go", ->
        WebActors.kill actor_b_id, "testing"
        WebActors.receive $ARG, (m) -> received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.trapKill (killer_id, reason) -> throw "error"
      WebActors.link actor_a_id
      WebActors.send actor_a_id, "go"
      WebActors.receive "never happen", ->

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, "error"]])

  it "should get killed when attempting to link to non-existent actors", ->
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()
      actor_a_id = "root:foo"
      WebActors.link actor_a_id
      WebActors.receive [actor_a_id, ANY], -> passed = true

    waitsFor -> passed

  it "should get killed when attempting to link with dead actors", ->
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      actor_a_id = WebActors.spawnLinked ->
        WebActors.receive ANY, ->

      actor_b_id = WebActors.spawn ->
        WebActors.link actor_a_id

      WebActors.receive [actor_a_id, ANY], ->
        WebActors.link actor_b_id
        WebActors.receive [actor_b_id, ANY], -> passed = true

    waitsFor -> passed

  it "should produce a fatal exception as exit reason", ->
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()
      actor_a_id = WebActors.spawn ->
        WebActors.link root_id
        throw "foo"
      WebActors.receive [actor_a_id, "foo"], -> passed = true

    waitsFor -> passed

  it "should support unlinking actors", ->
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      actor_a_id = WebActors.spawn ->
        WebActors.link root_id
        WebActors.receive "go", ->
          WebActors.unlink actor_b_id
          WebActors.send actor_b_id, "go"
          WebActors.receive $ARG, ->

      actor_b_id = WebActors.spawn ->
        WebActors.link actor_a_id
        WebActors.send actor_a_id, "go"
        WebActors.receive "go", ->
      
      setTimeout((-> WebActors.send root_id, "watchdog"), 100)
      WebActors.receive "watchdog", -> passed = true
      WebActors.receive $ARG, ->

    waitsFor -> passed

  it "should support spawning with automatic linking", ->
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      actor_a_id = WebActors.spawnLinked ->
        WebActors.send root_id, "go"
      
      WebActors.receive "go", ->
        WebActors.receive [actor_a_id, null], -> passed = true
      WebActors.receive $ARG, ->

    waitsFor -> passed

  it "should support send-callbacks which accumulate arguments", ->
    passed = false

    WebActors.spawn ->
      cb = WebActors.sendback("foo")
      WebActors.sendSelf "bar"
      WebActors.receive "bar", ->
        cb("baz", 1, 2)
        WebActors.receive ["foo", "baz", 1, 2], -> passed = true
      WebActors.receive ANY, ->

    waitsFor -> passed

  it "should kill actor if trapKill raises", ->
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      actor_a_id = WebActors.spawnLinked ->
        WebActors.trapKill (killer_id, reason) -> throw "foobar"

        WebActors.send root_id, "go"

        WebActors.receive ANY, ->

      WebActors.receive "go", ->
        WebActors.kill actor_a_id, "hoge"
        WebActors.receive [actor_a_id, "foobar"], ->
          passed = true

    waitsFor -> passed

  it "should support kill from outside", ->
    ready = false
    passed = false

    root_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()
      ready = true
      WebActors.receive [null, "foobar"], ->
        passed = true

    waitsFor -> ready

    runs -> WebActors.kill root_id, "foobar"

    waitsFor -> passed

  it "should support kill before initial callback runs", ->
    ready = false
    got_kill = false
    body_run = false

    WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()

      actor_a_id = WebActors.spawnLinked ->
        body_run = true

      WebActors.kill actor_a_id, "foobar"

      WebActors.receive [actor_a_id, "foobar"], -> got_kill = true

      setTimeout((-> ready = true), 500)

    waitsFor -> ready

    runs ->
      expect(got_kill).toBeTruthy()
      expect(body_run).toBeFalsy()

  it "should run trapKill callbacks outside of actors", ->
    actor_id = undefined

    WebActors.spawn ->
      WebActors.trapKill (killer_id, reason) ->
        actor_id = WebActors.self()
        throw reason

      WebActors.spawnLinked ->

      WebActors.receive ANY, ->

    waitsFor -> actor_id is null

describe "WebActors.injectEvent", ->
  it "should inject message events", ->
    received = []

    actor_id = WebActors.spawn ->
      WebActors.receive WebActors.$ARG, (message) ->
        received.push(message)

    WebActors.injectEvent [actor_id, "send", "foobar"]

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual(["foobar"])

  it "should inject link events", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback("blah")
      WebActors.receive WebActors.$ARG, (message) ->
        received.push(message)

    actor_b_id = WebActors.spawn ->
      WebActors.injectEvent [actor_b_id, "link", actor_a_id]

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["blah", actor_b_id, null]])

  it "should inject unlink events", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback("blah")
      WebActors.receive WebActors.$ARG, (message) ->
        received.push(message)

    actor_b_id = WebActors.spawn ->
      WebActors.link actor_a_id
      WebActors.injectEvent [actor_b_id, "unlink", actor_a_id]

    setTimeout((-> WebActors.send(actor_a_id, "passed")), 0.5)

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual(["passed"])

  it "should inject kill events", ->
    received = []
    ready = false

    actor_id = WebActors.spawn ->
      WebActors.trapKill WebActors.sendback("blah")
      ready = true
      WebActors.receive WebActors.$ARG, (message) ->
        received.push(message)

    waitsFor -> ready

    runs -> WebActors.injectEvent [actor_id, "kill", "foobar", "baz"]

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["blah", "foobar", "baz"]])

describe "WebActors routing", ->
  afterEach ->
    WebActors.unregisterGateway "foo"
    WebActors.unregisterGateway "foo:bar"

  it "should allow unregistering unregistered prefixes", ->
    WebActors.unregisterGateway "blah"

  it "should allow registering gateways by prefix", ->
    received = []

    WebActors.registerGateway "foo", (args...) ->
      received.push args
    WebActors.send "hoge:0", "1234"
    WebActors.send "foo:0", "abc123"

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["foo:0", "send", "abc123"]])

  it "should route on partial prefixes", ->
    received = []

    WebActors.registerGateway "foo", (args...) ->
      received.push args
    WebActors.send "hoge:0", "1234"
    WebActors.send "foo:bar:0", "abc123"

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["foo:bar:0", "send", "abc123"]])

  it "should give priority to longer prefixes", ->
    received = []

    WebActors.registerGateway "foo", (args...) ->
      received.push ["short"].concat(args)
    WebActors.registerGateway "foo:bar", (args...) ->
      received.push ["long"].concat(args)
    WebActors.send "hoge:0", "1234"
    WebActors.send "foo:0", "xyz789"
    WebActors.send "foo:bar:0", "abc123"

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["short", "foo:0", "send", "xyz789"],
                                      ["long", "foo:bar:0", "send", "abc123"]])

  it "should route link and kill events", ->
    received = []

    WebActors.registerGateway "foo", (args...) ->
      received.push args
    actor_id = WebActors.spawn ->
      WebActors.link "foo:0"

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["foo:0", "link", actor_id],
                                      ["foo:0", "kill", actor_id, null]])

  it "should route unlink events", ->
    received = []

    WebActors.registerGateway "foo", (args...) ->
      received.push args
    actor_id = WebActors.spawn ->
      WebActors.link "foo:0"
      WebActors.unlink "foo:0"

    waitsFor -> received.length > 0

    runs -> expect(received).toEqual([["foo:0", "link", actor_id],
                                      ["foo:0", "unlink", actor_id]])

describe "WebActors.setDefaultGateway", ->
  afterEach ->
    WebActors.setDefaultGateway null
    WebActors.unregisterGateway "foo"

  it "should affect routing for unknown prefixes", ->
    received = []

    WebActors.registerGateway "foo", (args...) ->
      received.push ["gateway"].concat(args)
    WebActors.setDefaultGateway (args...) ->
      received.push ["default"].concat(args)

    WebActors.send "#{WebActors.getLocalPrefix()}:bogus", "abc"
    WebActors.send "foo:0", "def"
    WebActors.send "bar:0", "ghi"

    waitsFor -> received.length > 1

    runs ->
      expect(received).toEqual([["gateway", "foo:0", "send", "def"],
                                ["default", "bar:0", "send", "ghi"]])

  it "should restore default behavior when null is passed", ->
    WebActors.setDefaultGateway (args...) ->
    WebActors.setDefaultGateway null

    passed = false

    WebActors.spawn ->
      WebActors.trapKill WebActors.sendback()
      WebActors.link "junk:bogus"
      WebActors.receive ["junk:bogus", WebActors.ANY], ->
        passed = true

    waitsFor -> passed

describe "WebActors.getLocalPrefix", ->
  it "should return the prefix being used for local actors", ->
    actor_id = WebActors.spawn ->
    local_prefix = WebActors.getLocalPrefix()
    local_prefix = "#{local_prefix}:"
    expect(actor_id.substr(0, local_prefix.length)).toEqual(local_prefix)

describe "WebActors.setLocalPrefix", ->
  afterEach ->
    WebActors.setLocalPrefix "actor"

  it "should change the prefix used for local actors", ->
    ready = false
    local_prefix = "foo"
    WebActors.setLocalPrefix local_prefix
    actor_id = WebActors.spawn ->
      ready = true

    waitsFor -> ready

    runs ->
      local_prefix = "#{local_prefix}:"
      expect(actor_id.substr(0, local_prefix.length)).toEqual(local_prefix)

describe "WebActors.allocateChildPrefix", ->
  it "should return a prefix based on a key and the local prefix", ->
    key = "zorg"
    local_prefix = WebActors.getLocalPrefix()
    local_prefix = "#{local_prefix}:"
    child_prefix = WebActors.allocateChildPrefix(key)
    expect(child_prefix.substr(0, local_prefix.length)).toEqual(local_prefix)
    expect(child_prefix.indexOf(key)).toBeGreaterThan(local_prefix.length-1)

  it "should return locally-unique prefixes", ->
    key = "zorg"
    child_prefix_a = WebActors.allocateChildPrefix(key)
    child_prefix_b = WebActors.allocateChildPrefix(key)
    expect(child_prefix_a).toNotEqual(child_prefix_b)
