do ($, Backbone, _) ->

  Backbone.$ = $ unless _.isFunction Backbone.$

  class Resource extends Backbone.Model
    defaults:
      name: ''
      target: ''
      node: ''
      type: ''

  class Resources extends Backbone.Collection

    model: Resource

    initialize: ->
      @on 'add', @whenAdd
      @resources = {}

    whenAdd: (model) ->
      {name, type} = model.toJSON()
      event = name + ':' + type
      @trigger event, model

    getResource: (name, target, node, type) ->
      {name, target, node, type}

    findDefine: (name, target, node) ->
      @findWhere @getResource name, target, node._node_name,  'define'

    findRequire: (name, target, node) ->
      @findWhere @getResource name, target, node._node_name,  'require'

    addResources: (node) ->
      @addNode node
      @addNode child for childName, child of node.nodes

    removeResources: (node) ->
      @removeNode child for childName, child of node.nodes
      @removeNode node

    addNode: (node) ->
      @addDefines node, _.result(node, 'defines')
      @addRequires node, _.result(node, 'requires')

    addDefines: (node, defines) ->
      return unless _.isObject defines
      @addDefine name, target, node for name, target of defines

    addRequires: (node, requires) ->
      return unless _.isObject requires
      @addRequire name, target, node for name, target of requires

    addDefine: (name, target, node) ->
      define = @findWhere name: name, type: 'define'
      @remove define if define
      # console.log 'define:', name, 'from', node._node_name
      @resources[name] = node[target]
      @updateDefine name, target, node
      @add  @getResource name, target, node._node_name,  'define'

    addRequire: (name, target, node) ->
      return @laterRequire name, target, node unless @resources[name]
      # console.log 'require', name, 'from', node._node_name
      node[target] = @resources[name]
      node.trigger target + ':required'
      @add @getResource name, target, node._node_name,  'require'

    laterRequire: (name, target, node) ->
      @once name + ':define', => @addRequire name, target, node

    updateDefine: (name, target, node) ->
      @resources[name] = node[target]
      users = @where name:name, type: 'require'
      @_updateDefine user, name  for user in users

    _updateDefine: (user, name) ->
      @trigger 'node:execute', user.get('node'), (node) =>
        return unless node
        last = node[user.get 'target']
        current = @resources[name]
        @moveListening node, last, current
        node[user.get 'target'] = @resources[name]

    removeNode: (node) ->
      @removeDefines node, _.result(node, 'defines')
      @removeRequires node, _.result(node, 'requires')

    removeDefines: (node, defines) ->
      return unless _.isObject defines
      @removeDefine name, target, node for name, target of defines

    removeRequires: (node, requires) ->
      return unless _.isObject requires
      @removeRequire name, target, node for name, target of requires

    removeDefine: (name, target, node) ->
      # console.log 'remove:define:', name, 'from', node._node_name
      node[target] = null
      @updateDefine name, target, node
      @remove @findDefine name, target, node

    removeRequire: (name, target, node) ->
      # console.log 'remove:require:', name, 'from', node._node_name
      node[target] = null
      node.trigger target + ':removed'
      @remove @findRequire name, target, node

  class Event

    _.extend Event::, Backbone.Events

    moveListening: (listener, last, current) ->
      return unless _.isObject last._events
      for name, events of last._events
        for _event in events when _event.ctx is listener
          listener.listenTo current, name, _event.callback

      listener.stopListening last

      this

  # globalNodes = {}

  class Backbone.Node extends Event

    constructor: ->
      @ancestor = null
      @cluster = {}
      @nodes = {}
      @initialize.apply this, arguments


    defines: {}

    requires: {}

    initialize: ->

    domainProxy: (eventName) ->
      => @domainPub eventName, arguments...

    domainPub: ->
      (@ancestor or this).$?.trigger arguments...

    listenWhen: (events, callback, context = this) ->
      i = 0
      events = events.split /\s+/
      temp = ->
        i++
        callback.call context if i is events.length

      for _event in events
        [target, event_name] = _event.split /:(.+)?/
        throw new Error 'target and name required' unless context[target] and event_name
        @listenTo context[target], event_name, temp

      this

    listenWhenOnce: (events, callback, context = this) ->
      i = 0
      events = events.split /\s+/
      temp = ->
        i++
        callback.call context if i is events.length

      for _event in events
        [target, event_name] = _event.split '.'
        @listenToOnce context[target], event_name, temp

      this

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
      # console.log '_tearDown', node
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

    _execute: (func, args...) ->
      @[func]? args...
      node._execute func, args... for name, node of @nodes

    _ready: ->
      @_checkRequiresMeeted()
      @ready arguments...

    _checkRequiresMeeted: ->
      for name, target of _.result this, 'requires'
        throw new Error name + ' failed to require as ' + target unless this[target]

    ready: ->

  class Backbone.Domain extends Event

    constructor: (@map = {}, autoStart = true) ->
      @resources = new Resources
      @listenTo @resources, 'node:execute', @executeNode
      @initialize.apply this, arguments
      @startApp() if @map.application and autoStart

    initialize: ->

    executeNode: (name, callback) ->
      callback @getNode name

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
      # console.log parent
      grand = parent.parent()
      @resources.removeResources parent
      @setNode grand, name, params

      current = @getNode block.target
      # console.log current
      # console.log @application
      @resources.addResources current
      grand._execute '_ready', name, params
      @trigger name + ':started'

      this

    startApp: ->
      block = @_defaultMapper 'application'
      return unless block
      @resources.removeResources @application if @application
      @application = new block.node block.params
      @application._node_name = 'application'
      @application.$ = this
      @setNode @application, child, block.params for child in block.children
      @resources.addResources @application
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
