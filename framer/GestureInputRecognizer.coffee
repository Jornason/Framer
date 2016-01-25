Utils = require "./Utils"

{DOMEventManager} = require "./DOMEventManager"

class exports.GestureInputRecognizer
	
	constructor: ->
		@em = new DOMEventManager()
		@em.wrap(window).addEventListener("touchstart", @touchstart)

	destroy: ->
		@em.removeAllListeners()

	cancel: ->
		window.clearTimeout(@session.pressTimer)
		@session = null
	
	touchstart: (event) =>
		@em.wrap(window).addEventListener("touchmove", @touchmove)
		@em.wrap(window).addEventListener("touchend", @touchend)
		@session =
			startEvent: @_getGestureEvent(event)
			startTime: Date.now()
			pressTimer: window.setTimeout(@longpress, 250)
			started: {}
		event = @_getGestureEvent(event)
		@tapstart(event)
		@_process(event)

	touchmove: (event) =>
		@_process(@_getGestureEvent(event))
		
	touchend: (event) =>
		@em.wrap(window).removeEventListener("touchmove", @touchmove)
		@em.wrap(window).removeEventListener("touchend", @touchend)
		event = @_getGestureEvent(event)
		@_process(event)

		for eventName, value of @session.started
			@["#{eventName}end"](event)

		@tap(event)
		@tapend(event)
		@cancel()

	# Tap

	tap: => @_dispatchEvent("tap", event)
	tapstart: => @_dispatchEvent("tapstart", event)
	tapend: => @_dispatchEvent("tapend", event)

	# Press

	longpress: =>
		return unless @session
		return if @session.longpressStartEvent
		event = @_getGestureEvent(@session.startEvent)
		@session.longpressStartEvent = event
		@_dispatchEvent("longpress", event)

	# Pan

	panstart: (event) =>
		@session.started.pan = event
		@_dispatchEvent("panstart", event, @session.started.pan.target)

	pan: (event) =>
		@_dispatchEvent("pan", event, @session.started.pan.target)
		direction = @_getDirection(event.delta)
		@["pan#{direction}"](event) if direction
		
	panend: (event) =>
		@_dispatchEvent("panend", event, @session.started.pan.target)
		@session.started.pan = null

	panup: (event) => @_dispatchEvent("panup", event, @session.started.pan.target)
	pandown: (event) => @_dispatchEvent("pandown", event, @session.started.pan.target)
	panleft: (event) => @_dispatchEvent("panleft", event, @session.started.pan.target)
	panright: (event) => @_dispatchEvent("panright", event, @session.started.pan.target)

	# Pinch

	pinchstart: (event) =>
		@session.started.pinch = event
		@scalestart(event, @session.started.pinch.target)
		@rotatestart(event, @session.started.pinch.target)
		@_dispatchEvent("pinchstart", event)

	pinch: (event) =>
		@_dispatchEvent("pinch", event)
		@scale(event, @session.started.pinch.target)
		@rotate(event, @session.started.pinch.target)
		
	pinchend: (event) =>
		@_dispatchEvent("pinchend", event)
		@scaleend(event, @session.started.pinch.target)
		@rotateend(event, @session.started.pinch.target)
		@session.started.pinch = null


	scalestart: (event) => @_dispatchEvent("scalestart", event)
	scale: (event) => @_dispatchEvent("scale", event)
	scaleend: (event) => @_dispatchEvent("scaleend", event)

	rotatestart: (event) => @_dispatchEvent("rotatestart", event)
	rotate: (event) => @_dispatchEvent("rotate", event)
	rotateend: (event) => @_dispatchEvent("rotateend", event)

	# Swipe
	
	swipestart: (event) =>
		@_dispatchEvent("swipestart", event)
		@session.started.swipe = event
		@swipedirectionstart(event)

	swipe: (event) =>
		@_dispatchEvent("swipe", event)
		@swipedirection(event)

	swipeend: (event) =>
		@_dispatchEvent("swipeend", event)


	swipedirectionstart: (event) =>
		return unless event.direction
		return if @session.started.swipedirection 
		@session.started.swipedirection = event
		direction = @session.started.swipedirection.direction
		@_dispatchEvent("swipe#{direction}start", event)

		swipeEdge = @_edgeForSwipeDirection(direction)
		maxX = Utils.frameGetMaxX(Screen.canvasFrame)
		maxY = Utils.frameGetMaxY(Screen.canvasFrame)

		if swipeEdge is "top" and 0 < event.start.y - Screen.canvasFrame.y < 30
			@edgeswipedirectionstart(event)
		if swipeEdge is "right" and maxX - 30 < event.start.x < maxX
			@edgeswipedirectionstart(event)
		if swipeEdge is "bottom" and maxY - 30 < event.start.y < maxY
			@edgeswipedirectionstart(event)
		if swipeEdge is "left" and 0 < event.start.x - Screen.canvasFrame.x < 30
			@edgeswipedirectionstart(event)

	swipedirection: (event) =>
		direction = @session.started.swipedirection.direction
		@_dispatchEvent("swipe#{direction}", event)

	swipedirectionend: (event) =>
		direction = @session.started.swipedirection.direction
		@_dispatchEvent("swipe#{direction}end", event)




	edgeswipedirectionstart: (event) =>
		return if @session.started.edgeswipedirection
		@session.started.edgeswipedirection = event
		swipeEdge = @_edgeForSwipeDirection(@session.started.edgeswipedirection.direction)
		Screen.emit("edgeswipestart", @_createEvent("edgeswipestart", event))
		Screen.emit("edgeswipe#{swipeEdge}start", @_createEvent("edgeswipe#{swipeEdge}start", event))

	edgeswipedirection: (event) =>
		swipeEdge = @_edgeForSwipeDirection(@session.started.edgeswipedirection.direction)
		Screen.emit("edgeswipe", @_createEvent("edgeswipe", event))
		Screen.emit("edgeswipe#{swipeEdge}", @_createEvent("edgeswipe#{swipeEdge}", event))

	edgeswipedirectionend: (event) =>
		swipeEdge = @_edgeForSwipeDirection(@session.started.edgeswipedirection.direction)
		Screen.emit("edgeswipeend", @_createEvent("edgeswipeend", event))
		Screen.emit("edgeswipe#{swipeEdge}end", @_createEvent("edgeswipe#{swipeEdge}end", event))

	_edgeForSwipeDirection: (direction) ->
		return "top" if direction is "down"
		return "right" if direction is "left"
		return "bottom" if direction is "up"
		return "left" if direction is "right"
		

	# swipeend: -> @_dispatchEvent("swipeend", event)

	# swipeup: (event) ->

	# 	if not @session.started.swipeup
	# 		@session.started.swipeup = event
	# 		@_dispatchEvent("swipeup", event)

	# 	@_dispatchEvent("swipeup", event)
	# 	maxY = Utils.frameGetMaxY(Screen.canvasFrame)
	# 	if maxY - 30 < event.start.y < maxY
	# 		event = @_createEvent("edgeswipebottom", event)
	# 		Screen.emit("edgeswipe", event)
	# 		Screen.emit("edgeswipebottom", event)

	# swipeupend: -> @_dispatchEvent("swipeupend", event)


	# swipedown: (event) ->
	# 	@_dispatchEvent("swipedown", event)
	# 	if 0 < event.start.y - Screen.canvasFrame.y < 30
	# 		event = @_createEvent("edgeswipetop", event)
	# 		Screen.emit("edgeswipe", event)
	# 		Screen.emit("edgeswipetop", event)
	
	# swipeleft: (event) ->
	# 	@_dispatchEvent("swipeleft", event)
	# 	maxX = Utils.frameGetMaxX(Screen.canvasFrame)
	# 	if maxX - 30 < event.start.x < maxX
	# 		event = @_createEvent("edgeswiperight", event)
	# 		Screen.emit("edgeswipe", event)
	# 		Screen.emit("edgeswiperight", event)
	
	# swiperight: (event) ->
	# 	@_dispatchEvent("swiperight", event)
	# 	if 0 < event.start.x - Screen.canvasFrame.x < 30
	# 		event = @_createEvent("edgeswipeleft", event)
	# 		Screen.emit("edgeswipe", event)
	# 		Screen.emit("edgeswipeleft", event)

	_process: (event) =>
		
		return unless @session 

		# Detect pan events
		if event.fingers == 1
			if not @session.started.pan and (Math.abs(event.offset.x) > 0 or Math.abs(event.offset.y) > 0)
				@panstart(event)
			else if @session.started.pan
				@pan(event)

		
		# Detect pinch, rotate and scale events
		if @session.started.pinch and event.fingers == 1
			@pinchend(event)
		else if not @session.started.pinch and event.fingers == 2 
			@pinchstart(event)	
		else if @session.started.pinch
			@pinch(event)
			
		# Detect swipe events
		if not @session.started.swipe and  event.fingers == 1
			if Math.abs(event.offset.x) > 30 or Math.abs(event.offset.y) > 30
				@swipestart(event)
		else if @session.started.swipe
			@swipe(event)
		
		@session.lastEvent = event

	_getGestureEvent: (event) ->
		
		_.extend event,
			time: Date.now() # Current time
			
			point: {x:event.pageX, y:event.pageY} # Current point
			start: {x:event.pageX, y:event.pageY} # Start point
			previous: {x:event.pageX, y:event.pageY} # Previous point
			
			offset: {x:0, y:0} # Offset since start
			offsetTime: 0 # Time since start
			offsetAngle: 0 # Angle from start
			offsetDirection: null # Direction from start (up, down, left, right)

			delta: {x:0, y:0} # Offset since last event
			deltaTime: 0 # Time since last event
			deltaAngle: 0 # Angle from last event
			deltaDirection: null # Direction from last event

			velocity: {x:0, y:0} # Velocity average over the last few events
			
			fingers: event.touches.length # Number of fingers used
			touchCenter: {x:event.pageX, y:event.pageY} # Center between two fingers
			touchDistance: 0 # Distance between two fingers
			touchOffset: {x:0, y:0} # Offset between two fingers
			scale: 1 # Scale value from two fingers
			rotation: 0 # Rotation value from two fingers

		if @session?.startEvent
			event.start = @session.startEvent.point
			event.offsetTime = event.time - @session.startEvent.time
			event.offset = Utils.pointSubtract(event.point, event.start)

		if @session?.lastEvent
			event.deltaTime = event.time - @session.lastEvent.time
			event.previous = @session.lastEvent.point
			event.delta = Utils.pointSubtract(event.point, event.previous)

		if event.touches.length > 0
			
			event.angle = 0
			
			if @session?.startEvent
				pointA = @_getTouchPoint(@session.startEvent, 0)
				pointB = @_getTouchPoint(event, 0)
				event.angle = Utils.pointAngle(pointA, pointB)
			
			event.direction = @_getDirection(event.offset)
		
		if event.touches.length > 1
			pointA = @_getTouchPoint(event, 0)
			pointB = @_getTouchPoint(event, 1)
			event.center = Utils.pointCenter(pointB, pointA)
			event.rotation = Utils.pointAngle(pointA, pointB)
			event.distance = Utils.pointDistance(pointA, pointB)
			event.scale = 1
		
		if @session?.pinchStartEvent
			event.scale = event.distance / @session.started.pinch.distance

		# Convert point style event properties to dom style:
		# event.delta -> event.deltaX, event.deltaY
		for pointKey in ["point", "start", "previous", "offset", "delta", "velocity", "touchCenter", "touchOffset"]
			event["#{pointKey}X"] = event[pointKey].x
			event["#{pointKey}Y"] = event[pointKey].y
			
		return event
	
	_getTouchPoint: (event, index) ->
		return point =
			x: event.touches[index].pageX
			y: event.touches[index].pageY
			
	_getDirection: (offset) ->
		if Math.abs(offset.x) > Math.abs(offset.y)
			return "right" if offset.x > 0
			return "left"  if offset.x < 0
		if Math.abs(offset.x) < Math.abs(offset.y)
			return "up"    if offset.y < 0
			return "down"  if offset.y > 0
		return null
	
	_createEvent: (type, event) ->

		touchEvent = document.createEvent("MouseEvent")
		touchEvent.initMouseEvent(type, true, true, window, 
			event.detail, event.screenX, event.screenY, 
			event.clientX, event.clientY, 
			event.ctrlKey, event.shiftKey, event.altKey, event.metaKey, 
			event.button, event.relatedTarget)
			
		touchEvent.touches = event.touches
		touchEvent.changedTouches = event.touches
		touchEvent.targetTouches = event.touches
		
		for k, v of event
			touchEvent[k] = v

		return touchEvent

	_dispatchEvent: (type, event, target) ->
		touchEvent = @_createEvent(type, event)
		target ?= event.target
		target.dispatchEvent(touchEvent)