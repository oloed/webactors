NOTHING = "(nothing)"

describe "Mailbox", ->
  describe "a one-shot consumer", ->
    mailbox = null
  
    beforeEach ->
      mailbox = new WebActors.Mailbox()
  
    it "should (asynchronously) consume messages already posted", ->
      expected = "foobar"
      received = NOTHING
  
      mailbox.postMessage expected
      mailbox.consumeOnce (message) ->
        -> received = message
      expect(received).toEqual NOTHING
  
      waitsFor -> received is expected
  
    it "should wait (asynchronously) for a message to be posted", ->
      expected = "foobar"
      received = NOTHING
  
      mailbox.consumeOnce (message) ->
        -> received = message
      expect(received).toEqual(NOTHING)
      mailbox.postMessage expected
      expect(received).toEqual(NOTHING)
  
      waitsFor -> received is expected
  
    it "should only consume a given message once", ->
      expected = ["a", "b"]
      received = []
  
      for m in expected
        mailbox.postMessage m
        mailbox.consumeOnce (message) ->
          -> received.push message
  
      waitsFor -> received.length >= 2
  
      runs -> expect(received).toEqual expected
  
    it "should only consume once, period", ->
      received = []
  
      mailbox.consumeOnce (message) ->
        -> received.push message
      mailbox.consumeOnce (message) ->
        -> received.push message + 2

      mailbox.postMessage 0
      mailbox.postMessage 1

      waitsFor -> received.length >= 2

      runs -> expect(received).toEqual [0, 3]

    it "should receive messages in order", ->
      expected = ["a", "b"]
      received = []

      for m in expected
        mailbox.postMessage m

      mailbox.consumeOnce (message) ->
        -> received.push message
      mailbox.consumeOnce (message) ->
        -> received.push message

      waitsFor -> received.length >= 2

      runs -> expect(received).toEqual expected

    it "should selectively receive messages", ->
      received = []

      mailbox.postMessage "a"
      mailbox.postMessage "b"

      mailbox.consumeOnce (message) ->
        if message is "b"
          -> received.push message

      mailbox.consumeOnce (message) ->
        if message is "a"
          -> received.push message

      waitsFor -> received.length >= 2

      runs -> expect(received).toEqual ["b", "a"]

  it "indicates whether it has consumers", ->
    mailbox = new WebActors.Mailbox()

    expect(mailbox.hasConsumers()).toEqual(false) 

    mailbox.consumeOnce (message) ->
      return null

    expect(mailbox.hasConsumers()).toEqual(true) 
