path = require 'path'
{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
debounce = require 'debounce'

module.exports =
class SvgPreviewView extends ScrollView
  atom.deserializers.add(this)

  @deserialize: (state) ->
    new SvgPreviewView(state)

  @content: ->
    @div class: 'svg-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, @filePath}) ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  attached: ->
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else if @filePath
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  serialize: ->
    deserializer: 'SvgPreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @disposables.dispose()

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    # No op to suppress deprecation warning
    new Disposable

  onDidChangeSvg: (callback) ->
    @emitter.on 'did-change-svg', callback

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath)
    @emitter.emit 'did-change-title'
    @handleEvents()
    @renderSvg()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderSvg()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @disposables.add atom.grammars.onDidAddGrammar =>
      debounce((=> @renderSvg()), 250)
    @disposables.add atom.grammars.onDidUpdateGrammar =>
      debounce((=> @renderSvg()), 250)

    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()
      'svg-preview:zoom-in': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel + .1)
      'svg-preview:zoom-out': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel - .1)
      'svg-preview:reset-zoom': =>
        @css('zoom', 1)

    changeHandler = =>
      @renderSvg()

      # TODO: Remove paneForURI call when ::paneForItem is released
      pane = atom.workspace.paneForItem?(this) ?
             atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      @disposables.add @editor.getBuffer().onDidStopChanging ->
        changeHandler() if atom.config.get 'svg-preview.liveUpdate'
      @disposables.add @editor.getBuffer().onDidSave ->
        changeHandler() unless atom.config.get 'svg-preview.liveUpdate'
      @disposables.add @editor.getBuffer().onDidReload ->
        changeHandler() unless atom.config.get 'svg-preview.liveUpdate'
      @disposables.add @editor.onDidChangePath =>
        @emitter.emit 'did-change-title'

  renderSvg: ->
    @showLoading()
    @getSvgSource().then (source) => @renderSvgText(source) if source?

  getSvgSource: ->
    if @file?
      return @file.read()
    else if @editor?
      return Promise.resolve(@editor.getText())
    else
      return Promise.resolve(null)

  renderSvgText: (text) ->
    #@loading = false
    #@empty()
    #@append(text)
    @html(text)
    @emitter.emit 'did-change-svg'
    @originalTrigger('svg-preview:svg-changed')

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "SVG Preview"

  getIconName: ->
    "svg"

  getURI: ->
    if @file?
      "svg-preview://#{@getPath()}"
    else
      "svg-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getGrammar()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing SVG Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @html $$$ ->
      @div class: 'svg-spinner', 'Loading SVG\u2026'

  isEqual: (other) ->
    @[0] is other?[0] # Compare DOM elements
