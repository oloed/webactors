     _   _     _   ___      _
    |*|_|*|___|*|_|*  |___ |*|_ ___ ___ ___
    | | | |*_ |   | | |* _|   _|*  |* _|*__|
    | | | | __| | |   | |_ | |_| | | | |__ |
    |_____|___|___|_|_|___||___|___|_| |___|

WebActors is a simple library for managing concurrency
in JavaScript programs. It's based on Erlang's
adaptation of the Actor Model.

For an introduction to actors in general, and WebActors in
particular, scroll down to the section entitled
"Tutorial".

# Building

## Build Requirements

WebActors doesn't have any special run-time requirements -- it's just
a single JavaScript file -- but it requires node.js, npm, and the
"coffee-script" and "jsmin" npm packages for development.

## Running Cake

Running `cake build` with no arguments will build
everything. 

The output files are:

  * dist/webactors.js - uncompressed version
  * dist/webactors.min.js - minfied version

The two should be functionally-equivalent.

# API Reference

WebActors defines a single object in the top-level
namespace, unsurprisingly called WebActors.  It has a
number of properties and methods attached to it.

## Actors

### WebActors.spawn(body) -> actor_id

The `spawn` method spawns a new actor, returning
its id.

The actor will termiate after `body` returns,
unless `body` suspends the actor by calling
`receive`.

### WebActors.spawn_linked(body) -> actor_id

The `spawn_linked` method is similar to
`spawn`, except that it atomically links the
spawned actor with the current actor.

### WebActors.self()

The `self` method returns the id of the current
actor.

### WebActors.send(actor_id, message)

Sends a message to another actor asynchronously. The
message is put in the receiving actor's mailbox, to
be retrieved with `receive`.

### WebActors.send_self(message)

Like `send`, but sends a message to the current
actor's mailbox.

### WebActors.receive(pattern, cont)

Sets up a one-shot handler to be called if a message
matching the given pattern arrives.  The pattern will
be structurally matched against candidate messages
using `match`; a list of captured subvalues will
be passed to the supplied continuation callback.

The set of outstanding receives for an actor is
cleared each time the actor successfully receives
a message.

If an actor doesn't establish any receives before
returning to the event loop, or if it raises an
uncaught exception, the actor will terminate.

### WebActors.link(actor_id)

The `link` method links the current actor with
the given actor, provided there wasn't already an existing
link between them.

`link` will raise an error if the named actor is
dead or doesn't exist.

### WebActors.unlink(actor_id)

The `unlink` method unlinks the current actor
from the given actor, if there was an existing link between
the two.

`unlink` _won't_ raise an error if no actor with
the given id exists.

### WebActors.trap_exit(fn)

Normally, when an actor receives an exit notification,
it will immediately exit.  `trap_exit` allows
for more nuanced behavior than the default, converting the
notification to a regular message.

This passed-in function receives two arguments: the id of
the originating (not the receiving!) actor, and the reason
to exit.  It should return a message to be delivered to
the receiving actor.

### WebActors.send_exit(actor_id, exit_reason)

The `send_exit` method sends an exit notification to the
given actor whether or not it is linked.

### WebActors.sendback(args...) -> cb

Constructs a callback that sends a message to the actor
that constructed it.  Useful for waiting with setTimeout.

The message sent will consist of the arguments to
`sendback` concatented with any arguments passed
to the callback when it is called.

## Pattern Matching

### WebActors.match(pattern, value) -> result

`match` performs structural matching on JavaScript values.
It takes a pattern and a value, returning an array of
captured subvalues if the match is successful, or null
otherwise.

### WebActors.any or WebActors.$_

`$_` matches any value without capturing it.

### WebActors.capture or WebActors.$$

`$$` matches and captures any value; the match
may be further constrained by passing an argument to
`$$` as a function.

= Tutorial

## Actors Explained

An "actor" is pretty much just a regular process or
thread with a mailbox attached.  In programming styles
based on the Actor Model, threads communicate with each
other by posting immutable messages to each others'
mailboxes, rather than by reading and writing fields of
mutually-shared objects.

Writing concurrent programs using message-passing can take
some getting used to, but actors can make programs simpler,
and they are also relatively safe from many common
programming errors.

## Actors in JavaScript

JavaScript has neither processes nor threads (nor
coroutines), but in the absence of these, actors can still
be modeled by a chain of callbacks.  Indeed, actor-based
programming can be a good way to manage the inherent
complexities of callback-driven programming.

### Creating Actors and Sending Messages

The `WebActors.spawn` function is used to
create a new actor.  This function takes a callback to run
in the new actor's context, and returns an id representing
the newly created actor.  This id can be used to submit
messages to the new actor's mailbox.

 var actor = WebActors.spawn(a_callback); // create an actor
 WebActors.send(actor, "a message"); // send it a message

### Receiving Messages

To receive messages, use the `WebActors.receive`
function.  It takes a pattern and a callback to be invoked
when a matching message is received.

    function a_callback() {
      // $$ matches anything
      WebActors.receive(WebActors.$$, function (message) {
        alert(message);
      });
    }

If an actor callback sets up a new callback via receive,
then the actor will continue with the new callback once
a matching message becomes available.  Otherwise, if a
callback "breaks the chain", then the actor will terminate
as soon as the callback finishes.

In the above example, the actor sets up a callback to
receive one message. That callback, in turn, doesn't set
up any further callbacks, so the actor terminates at
that point.

### Saving Some Typing

If you aren't already in the habit of doing so, it can
be useful (and occasionally more readable) to define local
aliases for functions defined on library objects.

    (function () {
    var spawn = WebActors.spawn;
    var receive = WebActors.receive;
    var send = WebActors.send;
    var $$ = WebActors.$$;

    function a_callback() {
      // $$ matches anything
      WebActors.receive($$, function (message) {
        alert(message);
      });
    }

    actor = spawn(a_callback); // create an actor
    send(actor, "a message"); // send it a message

    })();

(Be careful with this -- sometimes code may be easier to
read if you spell things out.)

Subsequent code samples will assume that such aliases have
already been defined.

### Multiple Receives

An actor can also choose between alternatives based on
the specific message received.

    receive("go left", function () {
      alert("You fall off a cliff.");
    });
    receive("go right", function () {
      alert("You fall into a pit.");
    });

In this case, if the actor receives "go left", it will
print the message about falling off a cliff.  If the actor
receives "go right", it will print the message about
falling into a pit.

Note that if both messages are available simultaneously
(perhaps because they were already waiting in the
mailbox), only one alternative (the first that matches)
will be chosen.

### Receive Loops
