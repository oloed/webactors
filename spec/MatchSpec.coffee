describe "WebActors.match", ->
  it "should exactly match numbers", ->
    expect(WebActors.match(3, 2)).toBeFalsy()
    expect(WebActors.match(3, 3)).toBeTruthy()

  it "should exactly match strings", ->
    expect(WebActors.match("foobar", "barfoo")).toBeFalsy()
    expect(WebActors.match("foobar", "foobar")).toBeTruthy()

  it "should match null only with null", ->
    expect(WebActors.match(null, null)).toBeTruthy()
    expect(WebActors.match(null, {})).toBeFalsy()
    expect(WebActors.match(null, "3")).toBeFalsy()
    expect(WebActors.match(null, undefined)).toBeFalsy()

  it "should not match strings and numbers", ->
    expect(WebActors.match("3", 3)).toBeFalsy()
    expect(WebActors.match(3, "3")).toBeFalsy()

  it "should exactly match booleans", ->
    for b in [true, false]
      expect(WebActors.match(b, not b)).toBeFalsy()
      expect(WebActors.match(b, b)).toBeTruthy()

  it "should not match dissimilar arrays", ->
    expect(WebActors.match(["a", "b"], ["a", "a"])).toBeFalsy()
    expect(WebActors.match(["a", "b"], ["a", "b", "c"])).toBeFalsy()
    expect(WebActors.match(["a", "b"], ["a"])).toBeFalsy()

  it "should match identical arrays", ->
    expect(WebActors.match(["a", "b"], ["a", "b"])).toBeTruthy()

  it "should match subsets of object fields", ->
    expect(WebActors.match({a: 3}, {a: 3, b: 4})).toBeTruthy()

  it "should not match objects with missing fields", ->
    expect(WebActors.match({a: 3, b: 4}, {a: 3})).toBeFalsy()

  it "should support wildcards", ->
    expect(WebActors.match(WebActors.ANY, 42)).toBeTruthy()
    expect(WebActors.match(WebActors.ANY, "testing")).toBeTruthy()
    expect(WebActors.match(WebActors.ANY, true)).toBeTruthy()
    expect(WebActors.match(WebActors.ANY, false)).toBeTruthy()
    expect(WebActors.match(WebActors.ANY, undefined)).toBeTruthy()
