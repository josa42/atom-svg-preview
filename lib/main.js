'use babel'

import { CompositeDisposable } from 'atom'
import url from 'url'

let SvgPreviewView = null

function importSvgPreviewView() {
  if (SvgPreviewView == null) {
    SvgPreviewView = require('./svg-preview-view')
  }
}

function createSvgPreviewView(state) {
  importSvgPreviewView()
  return new SvgPreviewView(state)
}

function isSvgPreviewView(object) {
  importSvgPreviewView()
  return object instanceof SvgPreviewView
}

function configGet(key) {
  return atom.config.get(`svg-preview.${key}`)
}

module.exports = {

  config: require('./config'),

  deserializeSvgPreviewView(state) {
    if (state.constructor === Object) {
      return createSvgPreviewView(state)
    }
  },

  activate() {
    this.disposables = new CompositeDisposable

    this.disposables.add(atom.commands.add('atom-workspace', {
      'svg-preview:toggle': () => this.toggle()
    }))

    this.disposables.add(
      atom.workspace.addOpener((uriToOpen) => this.onOpenUri(uriToOpen))
    )

    this.disposables.add(
      atom.workspace.onDidChangeActivePaneItem((item) => {
        this.onDidChangeActivePaneItem(item)
      })
    )

    this.disposables.add(
      atom.workspace.onWillDestroyPaneItem((event) => {
        this.onWillDestroyPaneItem(event.item)
      })
    )
  },

  deactivate() {
    atom.workspace.getPaneItems()
      .filter((item) => isSvgPreviewView(item))
      .forEach((item) => this.removePreview(item))

    this.disposables.dispose()
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

  isSvgEditor(item) {
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

  removePreview(previewView) {
    const uri = `svg-preview://editor/${previewView.editorId}`
    const previewPane = atom.workspace.paneForURI(uri)

    if (previewPane) {
      previewPane.destroyItem(previewPane.itemForURI(uri))
      return true
    }

    return false
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

  addPreviewForEditor(editor) {
    const uri = this.uriForEditor(editor)
    const previousActivePane = atom.workspace.getActivePane()
    const options = {
      searchAllPanes: true,
      activatePane: false,
      split: configGet('openPreviewInSplitPane') ? 'right': undefined
    }

    atom.workspace.open(uri, options).then((svgPreviewView) => {
      if (isSvgPreviewView(svgPreviewView)) {
        previousActivePane.activate()
      }
    })
  },

  previewFile({ target }) {
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
