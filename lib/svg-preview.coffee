url = require 'url'
fs = require 'fs-plus'

SvgPreviewView = require './svg-preview-view'

module.exports =
  configDefaults:
    grammars: [ 'text.plain.null-grammar', 'text.xml' ]

  activate: ->
    atom.workspaceView.command 'svg-preview:toggle', =>
      @toggle()

    atom.workspace.registerOpener (uriToOpen) ->
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
        new SvgPreviewView(editorId: pathname.substring(1))
      else
        new SvgPreviewView(filePath: pathname)

  toggle: ->
    editor = atom.workspace.getActiveEditor()
    return unless editor?

    grammars = atom.config.get('svg-preview.grammars') ? []
    return unless editor.getGrammar().scopeName in grammars

    uri = "svg-preview://editor/#{editor.id}"

    previewPane = atom.workspace.paneForUri(uri)
    if previewPane
      previewPane.destroyItem(previewPane.itemForUri(uri))
      return

    previousActivePane = atom.workspace.getActivePane()
    atom.workspace.open(uri, split: 'right', searchAllPanes: true).done (svgPreviewView) ->
      if svgPreviewView instanceof SvgPreviewView
        svgPreviewView.renderSvg()
        previousActivePane.activate()
