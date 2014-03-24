do ($, Backbone, _) ->

  Backbone.$ = $ unless _.isFunction Backbone.$

  class Event

    _.extend Event::, Backbone.Events

  # globalNodes = {}

  class Backbone.Node extends Event

    constructor: ->
      @nodes = {}
      @initialize.apply this, arguments

    initialize: ->

    setUp: (name, node) ->
      # console.log 'setUp ', name, node

    tearDown: (name, node) ->
      # console.log 'tearDown ', name, node

    _setUp: (name, node) ->
      # globalNodes[name] = node
      @nodes[name] = node
      @setUp name, node
      @listenTo node, 'bubble', @pub

    _tearDown: (name, node) ->
      @stopListening node
      node.off()
      node.stopListening()
      node._tearDown childName, childNode for childName, childNode of node.nodes
      @tearDown name, node
      delete @nodes[name]
      # delete globalNodes[name]

    set: (name, node) ->
      @del name
      return unless name and node
      @_setUp name, node

    get: (names...) ->
      # _.map names, (name) -> globalNodes[name]

    del: (name) ->
      node = @nodes[name]
      return false unless node
      @_tearDown name, node

    _pub: ->
      @trigger 'bubble', arguments...

    pub: ->
      if _.result this, 'bubble'
        @_pub arguments...
      else
        @_notify arguments...

      this

    bubble: ->
      @_events?.bubble

    _notify: (args...) ->
      @trigger args...
      node._notify args... for name, node of @nodes

  Event.extend = Backbone.Node.extend = Backbone.Model.extend      