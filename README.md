backbone.node
=============

when backbone app becomes too big, break it to nodes, as if each node was a small backbone app.


Why
---
Backbonejs is simple, why not keep it simple even app grows big.

Installation
--------------

```javascript
    bower install --save backbone.node
```

Usage
-----

```coffeescript
# declare Node1
class Node1 extends Backbone.Node

  initialize: ->
    # do everything we usually do when create a backbone app here
    @testModel = new Backbone.Model
    @listenTo @testModel, 'change', @speakLoudly

  speakLoudly: ->
    # you can pub out a event so other node will get it
    @pub 'test:model:changed', @testModel

# declare Node2
class Node2 extends Backbone.Node

  initialize: ->
    # do everything we usually do when create a backbone app here
    @testCollection = new Backbone.Collection
    @on 'test:model:changed', @doSomething

  doSomething: (testModel) ->
    console.log 'yes, I got you!'

# declare Application
class Application extends Backbone.Node

  initialize: ->
    # right, use 'set' to connect a node, you can make a tree.

    # maybe node1 is accounted for #header
    @set 'node1', new Node1
    # maybe node2 is accounted for #main
    @set 'node2', new Node2

    # maybe some other nodes do storage or something else, no limit.


```

Issues
------

Whenever you got a idea or problem, Glad to Know from you.

License
----

MIT


**Free Software, Hell Yeah!**
