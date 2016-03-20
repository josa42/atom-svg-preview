'use babel'

const path = require('path')
const SvgPreviewView = require('../lib/svg-preview-view')

describe('SvgPreviewView', () => {

  beforeEach(() => {

    const [ dir ] = atom.project.getDirectories()
    const filePath = dir != null ? dir.resolve('subdir/file.svg') : undefined

    preview = new SvgPreviewView({ filePath })

    jasmine.attachToDOM(preview.element)
    atom.deserializers.add(SvgPreviewView)
  })

  afterEach(() => preview.destroy())

  describe('::constructor', () => {
    it('shows a loading spinner and renders the svg', () => {
      preview.showLoading()
      expect(preview.find('.svg-spinner')).toExist()

      waitsForPromise(() => preview.renderSvg())
      runs(() => expect(preview.find(".svg-spinner")).not.toExist())
    })

    it('shows an error message when there is an error', () => {
      preview.showError("Not a real file")
      expect(preview.text()).toContain("Failed")
    })
  })

  describe('serialization', () => {
    let newPreview = null

    afterEach(() => newPreview.destroy())

    it('recreates the file when serialized/deserialized', () => {
      newPreview = atom.deserializers.deserialize(preview.serialize())
      jasmine.attachToDOM(newPreview.element)
      expect(newPreview.getPath()).toBe(preview.getPath())
    })

    it('serializes the editor id when opened for an editor', () => {
      preview.destroy()

      waitsForPromise(() => atom.workspace.open('new.svg'))
      runs(() => {
        preview = new SvgPreviewView({
          editorId: atom.workspace.getActiveTextEditor().id
        })
        jasmine.attachToDOM(preview.element)
        expect(preview.getPath()).toBe(atom.workspace.getActiveTextEditor().getPath())
        newPreview = atom.deserializers.deserialize(preview.serialize())
        jasmine.attachToDOM(newPreview.element)
        expect(newPreview.getPath()).toBe(preview.getPath())
      })
    })
  })
})
