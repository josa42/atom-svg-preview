'use babel'

import path from 'path'
import { Emitter, Disposable, CompositeDisposable, File } from 'atom'
import { $, $$$, View } from 'atom-space-pen-views'
import debounce from 'debounce'
import getSVGSize from './get-svg-size'

let fs = null // Defer until used
let svgToRaster = null // Defer until used

class SvgPreviewView extends View {

  static deserialize(state) {
    return new SvgPreviewView(state)
  }

  static content() {
    this.div({ outlet: 'container', class: 'svg-preview native-key-bindings', tabindex: -1, background: 'white' }, () => {
      this.div({ outlet: 'controls', class: 'image-controls' }, () => {
        this.div({ class: 'image-controls-group' }, () => {
          this.a({ outlet: 'whiteButton', class: 'image-controls-color-white', value: 'white' }, () => {
            this.text('white')
          })
          this.a({ outlet: 'blackButton', class: 'image-controls-color-black', value: 'black' }, () => {
            this.text('black')
          })
          this.a({ outlet: 'transparentButton', class: 'image-controls-color-transparent', value: 'transparent' }, () => {
            this.text('transparent')
          })
        })
        this.div({ class: 'image-controls-group btn-group' }, () => {
          this.button({ class: 'btn', outlet: 'zoomOutButton' }, () => {
            this.text('-')
          })
          this.button({ class: 'btn reset-zoom-button', outlet: 'resetZoomButton' }, () => {
            this.text('100%')
          })
          this.button({ class: 'btn', outlet: 'zoomInButton' }, () => {
            this.text('+')
          })
        })
      })
      this.div({ outlet: 'canvas', class: 'image-canvas' })
    })
  }

  constructor({ editorId, filePath, zoomValue }) {
    super()

    this.editorId = editorId
    this.filePath = filePath

    this.emitter = new Emitter
    this.disposables = new CompositeDisposable

    this.zoomValue = zoomValue || 1
  }

  attached() {
    if (this.isAttached) { return }

    this.isAttached = true

    if (this.editorId) {
      this.resolveEditor(this.editorId)
    } else if (this.filePath) {
      if (atom.workspace) {
        this.subscribeToFilePath(this.filePath)
      } else {
        this.disposables.add(atom.packages.onDidActivateInitialPackages(() =>
          this.subscribeToFilePath(this.filePath)
        ))
      }
    }

    this.disposables.add(atom.tooltips.add(this.whiteButton[0], { title: "Use white transparent background" }))
    this.disposables.add(atom.tooltips.add(this.blackButton[0], { title: "Use black transparent background" }))
    this.disposables.add(atom.tooltips.add(this.transparentButton[0], { title: "Use transparent background" }))

    this.controls.find('a').on('click', (e) => {
      this.changeBackground($(e.target).attr('value'))
    })
    this.zoomOutButton.on('click', (e) => this.zoom(-0.1))
    this.resetZoomButton.on('click', (e) => this.zoomReset())
    this.zoomInButton.on('click', (e) => this.zoom(0.1))
  }

  serialize() {
    return {
      deserializer: 'SvgPreviewView',
      filePath: this.getPath(),
      editorId: this.editorId,
      zoomValue: this.zoomValue
    }
  }

  destroy() {
    this.disposables.dispose()
  }

  onDidChangeTitle(callback) {
    return this.emitter.on('did-change-title', callback)
  }

  onDidChangeModified(callback) {
    // No op to suppress deprecation warning
    return new Disposable
  }

  onDidChangeSvg(callback) {
    return this.emitter.on('did-change-svg', callback)
  }

  subscribeToFilePath(filePath) {
    this.file = new File(filePath)
    this.emitter.emit('did-change-title')
    this.handleEvents()
    this.renderSvg()
  }

  resolveEditor(editorId) {
    resolve = () => {
      this.editor = this.editorForId(editorId)

      if (this.editor) {
        this.emitter.emit('did-change-title')
        this.handleEvents()
        this.renderSvg()
      } else {
        // The editor this preview was created for has been closed so close
        // this preview since a preview cannot be rendered without an editor
        const paneView = this.parents('.pane').view()
        if (paneView) {
          paneView.destroyItem(this)
        }
      }
    }

    if (atom.workspace) {
      resolve()
    } else {
      this.disposables.add(atom.packages.onDidActivateInitialPackages(resolve))
    }
  }

  editorForId(editorId) {
    for (let editor of atom.workspace.getTextEditors()) {
      if (editor.id && editor.id.toString() === editorId.toString()) {
        return editor
      }
    }

    return null
  }

  zoom(offset) {
    this.zoomTo(this.zoomValue + this.zoomValue * offset)
  }

  zoomReset() {
    this.zoomTo(1)
  }

  zoomTo(zoomValue) {
    if (zoomValue <= Number.EPSILON) {
      return
    }

    const svg = this.canvas.find('svg')
    if (svg[0]) {

      let width = svg.width() * zoomValue
      let height = svg.height() * zoomValue

      const factor = svg.data('factor')
      if (factor) {
        width /= factor
        height /= factor
      }

      svg
        .width(width)
        .height(height)
        .data('factor', zoomValue)

      this.zoomValue = zoomValue
      this.resetZoomButton.text(`${Math.round(zoomValue * 100)}%`)
    }
  }

  config(key) {
    return atom.config.get(`svg-preview.${key}`)
  }

  handleEvents() {
    this.disposables.add(
      atom.grammars.onDidAddGrammar(debounce(() => this.renderSvg(), 250)),
      atom.grammars.onDidUpdateGrammar(debounce(() => this.renderSvg(), 250))
    )

    atom.commands.add(this.element, {
      'core:move-up': () => this.scrollUp(),
      'core:move-down': () => this.scrollDown(),
      'svg-preview:zoom-in': () => this.zoom(0.1),
      'svg-preview:zoom-out': () => this.zoom(-0.1),
      'svg-preview:reset-zoom': () => this.zoomReset(),
      'svg-preview:export-to-png': (event) => {
        event.stopPropagation()
        this.exportTo('png')
      },
      'svg-preview:export-to-jpeg': (event) => {
        event.stopPropagation()
        this.exportTo('jpeg')
      },
    })

    if (this.file) {
      this.disposables.add(
        this.file.onDidChange(() => this.changeHandler())
      )

    } else if (this.editor) {
      const buffer = this.editor.getBuffer()

      this.disposables.add(
        buffer.onDidSave(() => this.changeHandler(false)),
        buffer.onDidReload(() => this.changeHandler(false)),
        buffer.onDidStopChanging(() => this.changeHandler(true)),
        this.editor.onDidChangePath(() => this.emitter.emit('did-change-title'))
      )
    }
  }

  changeHandler(ifLiveUpdate = null) {

    if (ifLiveUpdate === !this.config('liveUpdate')) {
      return
    }

    this.renderSvg()

    const pane = atom.workspace.paneForItem(this)
    if (pane && pane !== atom.workspace.getActivePane()) {
      pane.activateItem(this)
    }
  }

  renderSvg() {
    return this.getSvgSource()
      .then((source) => this.renderSvgText(source))
  }

  getSvgSource() {
    if (this.file) {
      return this.file.read()
    } else if (this.editor) {
      return Promise.resolve(this.editor.getText())
    } else {
      return Promise.resolve(null)
    }
  }

  renderSvgText(text) {
    if (!text) { return }

    const scrollTop = this.canvas.scrollTop()
    const scrollLeft = this.canvas.scrollLeft()

    this.canvas.html(text)

    const svg = this.canvas.find('svg')
    if(svg.get(0)) {
      const { width, height } = getSVGSize(svg.get(0))
      svg.width(width)
      svg.height(height)

      this.zoomTo(this.zoomValue)

      this.canvas.scrollTop(scrollTop)
      this.canvas.scrollLeft(scrollLeft)
    }

    this.emitter.emit('did-change-svg')
    this.originalTrigger('svg-preview:svg-changed')
  }

  getTitle() {
    let title = 'SVG'
    if (this.file) {
      title = path.basename(this.getPath())
    } else if (this.editor) {
      title = this.editor.getTitle()
    }

    return `${title} Preview`
  }

  getIconName() {
    return 'svg'
  }

  getURI() {
    if (this.file) {
      return `svg-preview://${this.getPath()}`
    }
    return `svg-preview://editor/${this.editorId}`
  }

  getPath() {
    if (this.file) {
      return this.file.getPath()
    } else if (this.editor) {
      return this.editor.getPath()
    }
  }

  getGrammar() {
    if (this.editor) {
      return this.editor.getGrammar()
    }
  }

  showError(result) {
    const { message } = result || {}

    this.canvas.html($$$(function() {
      this.h2('Previewing SVG Failed')
      if (message) {
        this.h3(message)
      }
    }))
  }

  showLoading() {
    this.canvas.html($$$(function() {
      this.div({ class: 'svg-spinner'}, 'Loading SVG\u2026')
    }))
  }

  isEqual(other) {
    return other && this[0] === other[0] // Compare DOM elements
  }

  changeBackground(color) {
    this.attr('background', color)
  }

  exportTo(outputType) {
    let filePath, outputFilePath, projectPath
    if (this.loading) {
      return
    }

    filePath = this.getPath()

    if (filePath) {
      filePath = path.join(
        path.dirname(filePath),
        path.basename(
          filePath,
          path.extname(filePath)
        )
      ).concat(`.${outputType}`)
    } else {
      filePath = `untitled.${outputType}`
      if (projectPath = atom.project.getPaths()[0]) {
        filePath = path.join(projectPath, filePath)
      }
    }

    if (outputFilePath = atom.showSaveDialogSync(filePath)) {
      if (svgToRaster == null) {
        svgToRaster = require('./svg-to-raster')
      }
      if (fs == null) {
        fs = require('fs-plus')
      }
      this.getSvgSource().then((source) => {
        svgToRaster.transform(source, outputType, (result) => {
          fs.writeFileSync(outputFilePath, result)
          atom.workspace.open(outputFilePath)
        })
      })
    }
  }
}

atom.deserializers.add(SvgPreviewView)

module.exports = SvgPreviewView
