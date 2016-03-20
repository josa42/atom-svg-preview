'use babel'

const url = require('url')

let SvgPreviewView = null

function createSvgPreviewView(state) {
  if (SvgPreviewView == null) {
    SvgPreviewView = require('./svg-preview-view')
  }
  return new SvgPreviewView(state)
}

function isSvgPreviewView(object) {
  if (SvgPreviewView == null) {
    SvgPreviewView = require('./svg-preview-view')
  }
  return object instanceof SvgPreviewView
}

function configGet(key) {
  return atom.config.get(`svg-preview.${key}`)
}

atom.deserializers.add({
  name: 'SvgPreviewView',
  deserialize(state) {
    if (state.constructor === Object) {
      return createSvgPreviewView(state)
    }
  }
})

module.exports = {

  config: require('./config'),

  activate: function() {
    atom.commands.add('atom-workspace', {
      'svg-preview:toggle': () => this.toggle()
    })

    atom.workspace.addOpener((uriToOpen) => this.onOpenUri(uriToOpen))

    atom.workspace.onDidChangeActivePaneItem((item) => {
      this.onDidChangeActivePaneItem(item)
    })

    atom.workspace.onWillDestroyPaneItem((event) => {
      this.onWillDestroyPaneItem(event.item)
    })
  },

  onWillDestroyPaneItem(item) {
    if (!(
      configGet('closePreviewAutomatically') &&
      configGet('openPreviewInSplitPane')
    )) {
      return
    }
    return this.removePreviewForEditor(item)
  },

  onDidChangeActivePaneItem(item) {
    if (!(
      configGet('openPreviewAutomatically') &&
      configGet('openPreviewInSplitPane') &&
      this.isSvgEditor(item)
    )) {
      return
    }
    return this.addPreviewForEditor(item)
  },

  onOpenUri(uriToOpen) {
    let protocol, host, filePath

    try {
      const urlObjs = url.parse(uriToOpen)

      protocol = urlObjs.protocol
      host = urlObjs.host
      filePath = urlObjs.pathname

      if (protocol !== 'svg-preview:') { return }
      if (filePath) { filePath = decodeURI(filePath) }

    } catch (error) {
      return
    }

    if (host === 'editor') {
      return createSvgPreviewView({ editorId: filePath.substring(1) })
    }

    return createSvgPreviewView({ filePath })
  },

  isSvgEditor: function(item) {
    try {
      const grammars = ['text.xml.svg'].concat(configGet('grammars') || [])
      const grammar = item.getGrammar().scopeName

      return (
        ( item.getBuffer && item.getText ) &&
        ( grammars.indexOf(grammar) >= 0 && item.getText().match(/<svg/) )
      )
    } catch(error) {
      return false
    }
  },

  toggle() {
    if (isSvgPreviewView(atom.workspace.getActivePaneItem())) {
      atom.workspace.destroyActivePaneItem()
      return
    }

    const editor = atom.workspace.getActiveTextEditor()
    if (editor == null) { return }

    const grammars = configGet('grammars') || []

    if (
      grammars.indexOf(editor.getGrammar().scopeName) >= 0 &&
      !this.removePreviewForEditor(editor)
    ) {
      return this.addPreviewForEditor(editor)
    }
  },

  uriForEditor(editor) {
    return `svg-preview://editor/${editor.id}`
  },

  removePreviewForEditor(editor) {
    const uri = this.uriForEditor(editor)
    const previewPane = atom.workspace.paneForURI(uri)

    if (previewPane) {
      previewPane.destroyItem(previewPane.itemForURI(uri))
      return true
    }

    return false
  },

  addPreviewForEditor: function(editor) {
    const uri = this.uriForEditor(editor)
    const previousActivePane = atom.workspace.getActivePane()
    const options = {
      searchAllPanes: true,
      activatePane: false,
      split: configGet('openPreviewInSplitPane') ? 'right': undefined
    }

    atom.workspace.open(uri, options).then(function(svgPreviewView) {
      if (isSvgPreviewView(svgPreviewView)) {
        previousActivePane.activate()
      }
    })
  },

  previewFile: function({ target }) {
    const filePath = target.dataset.path
    if (!filePath) { return }

    const [ editor ] = atom.workspace.getTextEditors()
    if (editor && editor.getPath() === filePath) {
      this.addPreviewForEditor(editor)

    } else {
      atom.workspace.open(`svg-preview://${encodeURI(filePath)}`, {
        searchAllPanes: true
      })
    }
  }
}
