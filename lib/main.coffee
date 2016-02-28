url = require 'url'

SvgPreviewView = null # Defer until used

createSvgPreviewView = (state) ->
  SvgPreviewView ?= require './svg-preview-view'
  new SvgPreviewView(state)

isSvgPreviewView = (object) ->
  SvgPreviewView ?= require './svg-preview-view'
  object instanceof SvgPreviewView

atom.deserializers.add
  name: 'SvgPreviewView'
  deserialize: (state) ->
    createSvgPreviewView(state) if state.constructor is Object

module.exports =
  config:
    liveUpdate:
      type: 'boolean'
      default: true
    openPreviewInSplitPane:
      type: 'boolean'
      default: true
    openPreviewAutomatically:
      type: 'boolean'
      default: false
    closePreviewAutomatically:
      type: 'boolean'
      default: true
    grammars:
      type: 'array'
      default: [
        'text.plain.null-grammar'
        'text.xml'
        'text.xml.svg'
      ]

  activate: ->
    atom.commands.add 'atom-workspace',
      'svg-preview:toggle': => @toggle()

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'svg-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createSvgPreviewView(editorId: pathname.substring(1))
      else
        createSvgPreviewView(filePath: pathname)

    atom.workspace.onDidChangeActivePaneItem (item) =>
      @onDidChangeActivePaneItem(item)

    atom.workspace.onWillDestroyPaneItem (event) =>
      @onWillDestroyPaneItem(event.item)

  onWillDestroyPaneItem: (item) ->
    return unless (
      atom.config.get('svg-preview.closePreviewAutomatically') and
      atom.config.get('svg-preview.openPreviewInSplitPane')
    )
    @removePreviewForEditor(item)

  onDidChangeActivePaneItem: (item) ->
    return unless (
      atom.config.get('svg-preview.openPreviewAutomatically') and
      atom.config.get('svg-preview.openPreviewInSplitPane') and
      @isSvgEditor item
    )
    @addPreviewForEditor item

  isSvgEditor: (item) ->
    grammars = ['text.xml.svg'].concat(atom.config.get('svg-preview.grammars') ? [])
    grammar = item?.getGrammar?()?.scopeName

    return (
      ( item?.getBuffer? and item?.getText? ) and
      ( grammar in grammars and item.getText().match(/<svg/) )
    )

  toggle: ->
    if isSvgPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('svg-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "svg-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
      activatePane: false

    if atom.config.get('svg-preview.openPreviewInSplitPane')
      options.split = 'right'

    console.log 'uri', uri

    atom.workspace.open(uri, options).then (svgPreviewView) ->
      if isSvgPreviewView(svgPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "svg-preview://#{encodeURI(filePath)}", searchAllPanes: true
