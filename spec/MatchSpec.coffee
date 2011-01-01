describe "WebActors.match", ->
  it "should exactly match numbers", ->
    expect(WebActors.match(3, 2)).toEqual null
    expect(WebActors.match(3, 3)).toEqual []

  it "should exactly match strings", ->
    expect(WebActors.match("foobar", "barfoo")).toEqual null
    expect(WebActors.match("foobar", "foobar")).toEqual []

  it "should exactly match booleans", ->
    for b in [true, false]
      expect(WebActors.match(b, not b)).toEqual null
      expect(WebActors.match(b, b)).toEqual []

  it "should not match dissimilar arrays", ->
    expect(WebActors.match(["a", "b"], ["a", "a"])).toEqual null
    expect(WebActors.match(["a", "b"], ["a", "b", "c"])).toEqual null
    expect(WebActors.match(["a", "b"], ["a"])).toEqual null

  it "should match identical arrays", ->
    expect(WebActors.match(["a", "b"], ["a", "b"])).toEqual []

  it "should support simple $VAR", ->
    expect(WebActors.match(WebActors.$VAR, 42)).toEqual [42]

  it "should support restricted $VAR", ->
    expect(WebActors.match(WebActors.$VAR(42), 38)).toEqual null
    expect(WebActors.match(WebActors.$VAR(42), 42)).toEqual [42]

  it "should support restricted $VAR for strings", ->
    expect(WebActors.match(WebActors.$VAR("foo"), "bar")).toEqual null
    expect(WebActors.match(WebActors.$VAR("foo"), "foo")).toEqual ["foo"]

  it "should support destructuring $VAR", ->
    expect(WebActors.match([WebActors.$VAR, "b", WebActors.$VAR], ["a", "b", "c"])).toEqual ["a", "c"]

  it "should support wildcards", ->
    expect(WebActors.match(WebActors.ANY, 42)).toEqual []
    expect(WebActors.match(WebActors.ANY, "testing")).toEqual []
