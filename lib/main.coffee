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
    grammars:
      type: 'array'
      default: [
        'text.plain.null-grammar'
        'text.xml'
        'text.xml.svg'
      ]

  activate: ->
    atom.commands.add 'atom-workspace',
      'svg-preview:toggle': =>
        @toggle()

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
    if atom.config.get('svg-preview.openPreviewInSplitPane')
      options.split = 'right'
    atom.workspace.open(uri, options).done (svgPreviewView) ->
      if isSvgPreviewView(svgPreviewView)
        previousActivePane.activate()

  previewFile: ({target}) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "svg-preview://#{encodeURI(filePath)}", searchAllPanes: true
