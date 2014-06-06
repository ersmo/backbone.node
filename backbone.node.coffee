do ($, Backbone, _) ->

  Backbone.$ = $ unless _.isFunction Backbone.$

  class Event

    _.extend Event::, Backbone.Events

  # globalNodes = {}

  class Backbone.Node extends Event

    constructor: ->
      @ancestor = null
      @cluster = {}
      @nodes = {}
      @initialize.apply this, arguments

    initialize: ->

    domainProxy: (eventName) ->
      => @domainPub eventName, arguments...

    domainPub: ->
      (@ancestor or this).$?.trigger arguments...

    setUp: (name, node) ->
      # console.log 'setUp ', name, node

    tearDown: (name, node) ->
      # console.log 'tearDown ', name, node

    _setCluster: (ancestor) ->
      @ancestor = ancestor
      @ancestor.cluster[@_node_name] = this
      node._setCluster ancestor for name, node of @nodes

    _delCluster: ->
      node._delCluster() for name, node of @nodes
      delete @cluster[name] for name, node of @cluster
      delete @ancestor.cluster[@_node_name]
      @ancestor = null

    parent: ->
      @_events?.bubble?[0].context

    _setUp: (name, node) ->
      # globalNodes[name] = node
      node._node_name = name
      node._setCluster this
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
      node._delCluster()
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


  class Backbone.Domain extends Event

    constructor: (@map = {}, autoStart = true) ->
      @initialize.apply this, arguments
      @startApp() if @map.application and autoStart

    initialize: ->

    getNode: (name) ->
      if name is 'application' then @application else @application.cluster[name]

    setNode: (parent, name, params = {}) ->
      block = @_defaultMapper name
      return unless block and block.require.call this
      node = new block.node _.extend params, block.params
      node._block_name = name
      @setNode node, child, params for child in block.children
      parent.set block.target, node

      this

    switchNode: (name, params = {}) ->
      return @startApp() if name is 'application'
      block = @_defaultMapper name
      return unless block and block.require.call this
      parent = @getNode block.target
      grand = parent.parent()

      @setNode grand, name, params
      grand._notify 'ready', name, params
      @trigger name + ':started'

      this

    startApp: ->
      block = @_defaultMapper 'application'
      return unless block

      @application = new block.node block.params
      @application.$ = this
      @setNode @application, child, block.params for child in block.children
      @trigger 'application:started'

      this

    _defaultMapper: (name) ->
      block = @map[name]
      switch typeof block
        when 'function'
          target: name
          node: block
          children: []
          params: {}
          require: -> true

        when 'object'
          block.target ?= name
          block.children ?= []
          block.children = [block.children] if typeof block.children is 'string'
          block.params ?= {}
          block.require ?= -> true
          block

        else false

  Event.extend = Backbone.Domain.extend = Backbone.Node.extend = Backbone.Model.extend
