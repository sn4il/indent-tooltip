{CompositeDisposable} = require 'atom'

module.exports = IndentTooltip =
  subscriptions: null
  activeStateSubscriptions: null
  tooltipSubscriptions: null

  tooltipFontFamily: null
  tooltipFontSize: null

  isActive: false

  activate: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'indent-tooltip:toggle': => @toggle()

  # Toggles the state of the plugin.
  toggle: ->
    if @isActive = not @isActive
      @enable()
    else
      @disable()

  # Enables tooltip.
  enable: ->
    @activeStateSubscriptions = new CompositeDisposable

    # Displays tooltip immediately after enabling
    @updateTooltip()

    @activeStateSubscriptions.add atom.workspace.observeTextEditors (editor) =>
      @activeStateSubscriptions.add editor.onDidChangeCursorPosition @debounce @updateTooltip, 50

      # Hides tooltip on scroll.
      view = atom.views.getView editor
      @activeStateSubscriptions.add [
        view.onDidChangeScrollTop @debounce @updateTooltip, 500
        view.onDidChangeScrollTop () => @tooltipSubscriptions.dispose()
      ]...

    @activeStateSubscriptions.add [

      # Handles font family change.
      atom.config.observe 'editor.fontFamily', @debounce @updateTooltip, 50
      atom.config.observe 'editor.fontFamily', (fontFamily) =>
        @tooltipFontFamily = fontFamily

      # Handles font size change.
      atom.config.observe 'editor.fontSize', @debounce @updateTooltip, 50
      atom.config.observe 'editor.fontSize', (fontSize) =>
        @tooltipFontSize = fontSize - 1
    ]...

    # Updates tooltip on tab/pane change.
    @activeStateSubscriptions.add atom.workspace.onDidChangeActivePaneItem () => @updateTooltip()

  # Disables tooltip.
  disable: ->
    @activeStateSubscriptions.dispose()

  # Executes the callback with delay.
  debounce: (callback, delay) ->
    context = @
    timeout = null

    (args...) ->
      timeoutCallback = () ->
        callback.apply context, args

      clearTimeout timeout
      timeout = setTimeout timeoutCallback, delay

  # Returns the parent row for the passed startRow.
  getParentRow: (startRow) ->
    editor = atom.workspace.getActiveTextEditor()
    buffer = editor.getBuffer()

    prevRow = startRow
    until prevRow is 0
      prevRow = buffer.previousNonBlankRow prevRow

      prevRowIndent = editor.indentationForBufferRow prevRow
      startRowIndent = editor.indentationForBufferRow startRow

      if prevRowIndent < startRowIndent
        return prevRow

  # Updates the tooltip.
  updateTooltip: ->
    @tooltipSubscriptions.dispose() if @tooltipSubscriptions?
    @tooltipSubscriptions = new CompositeDisposable

    editor = atom.workspace.getActiveTextEditor()
    view = atom.views.getView editor
    return unless view?
    node = view.shadowRoot.querySelector '.cursor-line .source'

    if node?
      parentRow = @getParentRow editor.getCursorBufferPosition().row

      if parentRow?
        [scope] = editor.scopeDescriptorForBufferPosition([parentRow, 0]).scopes
        return unless /jade|stylus|coffee/i.test scope

        parentRowLine = editor.lineTextForBufferRow parentRow

        tooltipOptions =
          title: '<b>inside</b> ' + parentRowLine
          trigger: 'manual'
          placement: 'auto right'
          template: '<div class="tooltip indent-tooltip__tooltip indent-tooltip__tooltip--compact" role="tooltip" style="font-family: \'' + @tooltipFontFamily + '\'; font-size: ' + @tooltipFontSize + 'px;"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'

        tooltipDisposable = atom.tooltips.add node, tooltipOptions
        @tooltipSubscriptions.add tooltipDisposable
        @activeStateSubscriptions.add tooltipDisposable
