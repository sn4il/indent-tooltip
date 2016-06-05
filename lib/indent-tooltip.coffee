{CompositeDisposable} = require 'atom'

module.exports = IndentTooltip =
  tooltipFontFamily: null
  tooltipFontSize: null

  subscriptions: null
  tooltipSubscription: null

  isActive: false

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace',
      'indent-tooltip:toggle': => @toggle()

    atom.workspace.observeTextEditors (editor) =>
      editor.onDidChangeCursorPosition @debounce @updateTooltip, 50

    # Keeps the font family "up to date".
    atom.config.observe 'editor.fontFamily', (fontFamily) =>
      @tooltipFontFamily = fontFamily

    # Keep the font size "up to date".
    atom.config.observe 'editor.fontSize', (fontSize) =>
      @tooltipFontSize = fontSize

      unless fontSize < 10
        if fontSize < 15
          @tooltipFontSize -= 1
        else
          @tooltipFontSize -= 2

    # Updates the tooltip when font family or font size is changed.
    atom.config.observe 'editor.fontSize', @debounce @updateTooltip, 50
    atom.config.observe 'editor.fontFamily', @debounce @updateTooltip, 50

  # Toggles the state of the plugin.
  toggle: ->
    @isActive = not @isActive

    unless @isActive
      @disposeTooltip()

    @updateTooltip()

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

  # Disposes the tooltip subscription.
  disposeTooltip: ->
    if @tooltipSubscription?
      @tooltipSubscription.dispose()
      @tooltipSubscription = null

  # Updates the tooltip.
  updateTooltip: ->
    return unless @isActive

    @disposeTooltip()

    editor = atom.workspace.getActiveTextEditor()
    view = atom.views.getView editor
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

        @tooltipSubscription = atom.tooltips.add node, tooltipOptions
