{Range} = require 'text-buffer'
_ = require 'underscore-plus'
{Subscriber} = require 'emissary'
EmitterMixin = require('emissary').Emitter
{Emitter} = require 'event-kit'
Grim = require 'grim'

module.exports =
class DisplayBufferMarker
  EmitterMixin.includeInto(this)
  Subscriber.includeInto(this)

  bufferMarkerSubscription: null
  oldHeadBufferPosition: null
  oldHeadScreenPosition: null
  oldTailBufferPosition: null
  oldTailScreenPosition: null
  wasValid: true
  deferredChangeEvents: null

  constructor: ({@bufferMarker, @displayBuffer}) ->
    @emitter = new Emitter
    @id = @bufferMarker.id
    @oldHeadBufferPosition = @getHeadBufferPosition()
    @oldHeadScreenPosition = @getHeadScreenPosition()
    @oldTailBufferPosition = @getTailBufferPosition()
    @oldTailScreenPosition = @getTailScreenPosition()
    @wasValid = @isValid()

    @subscribe @bufferMarker.onDidDestroy => @destroyed()
    @subscribe @bufferMarker.onDidChange (event) => @notifyObservers(event)

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  on: (eventName) ->
    switch eventName
      when 'changed'
        Grim.deprecate("Use DisplayBufferMarker::onDidChange instead")
      when 'destroyed'
        Grim.deprecate("Use DisplayBufferMarker::onDidDestroy instead")

    EmitterMixin::on.apply(this, arguments)

  copy: (attributes) ->
    @displayBuffer.getMarker(@bufferMarker.copy(attributes).id)

  # Gets the screen range of the display marker.
  #
  # Returns a {Range}.
  getScreenRange: ->
    @displayBuffer.screenRangeForBufferRange(@getBufferRange(), wrapAtSoftNewlines: true)

  # Modifies the screen range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {Marker::setRange}
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@displayBuffer.bufferRangeForScreenRange(screenRange), options)

  # Gets the buffer range of the display marker.
  #
  # Returns a {Range}.
  getBufferRange: ->
    @bufferMarker.getRange()

  # Modifies the buffer range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {Marker::setRange}
  setBufferRange: (bufferRange, options) ->
    @bufferMarker.setRange(bufferRange, options)

  getPixelRange: ->
    @displayBuffer.pixelRangeForScreenRange(@getScreenRange(), false)

  # Retrieves the screen position of the marker's head.
  #
  # Returns a {Point}.
  getHeadScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getHeadBufferPosition(), wrapAtSoftNewlines: true)

  # Sets the screen position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer::bufferPositionForScreenPosition}
  setHeadScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setHeadBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Retrieves the buffer position of the marker's head.
  #
  # Returns a {Point}.
  getHeadBufferPosition: ->
    @bufferMarker.getHeadPosition()

  # Sets the buffer position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer::bufferPositionForScreenPosition}
  setHeadBufferPosition: (bufferPosition) ->
    @bufferMarker.setHeadPosition(bufferPosition)

  # Retrieves the screen position of the marker's tail.
  #
  # Returns a {Point}.
  getTailScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getTailBufferPosition(), wrapAtSoftNewlines: true)

  # Sets the screen position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer::bufferPositionForScreenPosition}
  setTailScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setTailBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Retrieves the buffer position of the marker's tail.
  #
  # Returns a {Point}.
  getTailBufferPosition: ->
    @bufferMarker.getTailPosition()

  # Sets the buffer position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer::bufferPositionForScreenPosition}
  setTailBufferPosition: (bufferPosition) ->
    @bufferMarker.setTailPosition(bufferPosition)

  # Retrieves the screen position of the marker's start. This will always be
  # less than or equal to the result of {DisplayBufferMarker::getEndScreenPosition}.
  #
  # Returns a {Point}.
  getStartScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getStartBufferPosition(), wrapAtSoftNewlines: true)

  # Retrieves the buffer position of the marker's start. This will always be
  # less than or equal to the result of {DisplayBufferMarker::getEndBufferPosition}.
  #
  # Returns a {Point}.
  getStartBufferPosition: ->
    @bufferMarker.getStartPosition()

  # Retrieves the screen position of the marker's end. This will always be
  # greater than or equal to the result of {DisplayBufferMarker::getStartScreenPosition}.
  #
  # Returns a {Point}.
  getEndScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getEndBufferPosition(), wrapAtSoftNewlines: true)

  # Retrieves the buffer position of the marker's end. This will always be
  # greater than or equal to the result of {DisplayBufferMarker::getStartBufferPosition}.
  #
  # Returns a {Point}.
  getEndBufferPosition: ->
    @bufferMarker.getEndPosition()

  # Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  plantTail: ->
    @bufferMarker.plantTail()

  # Removes the tail from the marker.
  clearTail: ->
    @bufferMarker.clearTail()

  hasTail: ->
    @bufferMarker.hasTail()

  # Returns whether the head precedes the tail in the buffer
  isReversed: ->
    @bufferMarker.isReversed()

  # Returns a {Boolean} indicating whether the marker is valid. Markers can be
  # invalidated when a region surrounding them in the buffer is changed.
  isValid: ->
    @bufferMarker.isValid()

  # Returns a {Boolean} indicating whether the marker has been destroyed. A marker
  # can be invalid without being destroyed, in which case undoing the invalidating
  # operation would restore the marker. Once a marker is destroyed by calling
  # {Marker::destroy}, no undo/redo operation can ever bring it back.
  isDestroyed: ->
    @bufferMarker.isDestroyed()

  getAttributes: ->
    @bufferMarker.getProperties()

  setAttributes: (attributes) ->
    @bufferMarker.setProperties(attributes)

  matchesAttributes: (attributes) ->
    attributes = @displayBuffer.translateToBufferMarkerParams(attributes)
    @bufferMarker.matchesAttributes(attributes)

  # Destroys the marker
  destroy: ->
    @bufferMarker.destroy()
    @unsubscribe()

  isEqual: (other) ->
    return false unless other instanceof @constructor
    @bufferMarker.isEqual(other.bufferMarker)

  compare: (other) ->
    @bufferMarker.compare(other.bufferMarker)

  # Returns a {String} representation of the marker
  inspect: ->
    "DisplayBufferMarker(id: #{@id}, bufferRange: #{@getBufferRange()})"

  destroyed: ->
    delete @displayBuffer.markers[@id]
    @emit 'destroyed'
    @emitter.emit 'did-destroy'
    @emitter.dispose()

  notifyObservers: ({textChanged}) ->
    textChanged ?= false

    newHeadBufferPosition = @getHeadBufferPosition()
    newHeadScreenPosition = @getHeadScreenPosition()
    newTailBufferPosition = @getTailBufferPosition()
    newTailScreenPosition = @getTailScreenPosition()
    isValid = @isValid()

    return if _.isEqual(isValid, @wasValid) and
      _.isEqual(newHeadBufferPosition, @oldHeadBufferPosition) and
      _.isEqual(newHeadScreenPosition, @oldHeadScreenPosition) and
      _.isEqual(newTailBufferPosition, @oldTailBufferPosition) and
      _.isEqual(newTailScreenPosition, @oldTailScreenPosition)

    changeEvent = {
      @oldHeadScreenPosition, newHeadScreenPosition,
      @oldTailScreenPosition, newTailScreenPosition,
      @oldHeadBufferPosition, newHeadBufferPosition,
      @oldTailBufferPosition, newTailBufferPosition,
      textChanged,
      isValid
    }

    if @deferredChangeEvents?
      @deferredChangeEvents.push(changeEvent)
    else
      @emit 'changed', changeEvent
      @emitter.emit 'did-change', changeEvent

    @oldHeadBufferPosition = newHeadBufferPosition
    @oldHeadScreenPosition = newHeadScreenPosition
    @oldTailBufferPosition = newTailBufferPosition
    @oldTailScreenPosition = newTailScreenPosition
    @wasValid = isValid

  pauseChangeEvents: ->
    @deferredChangeEvents = []

  resumeChangeEvents: ->
    if deferredChangeEvents = @deferredChangeEvents
      @deferredChangeEvents = null

      for event in deferredChangeEvents
        @emit 'changed', event
        @emitter.emit 'did-change', event
