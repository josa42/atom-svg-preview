path = require 'path'
{WorkspaceView} = require 'atom'
SvgPreviewView = require '../lib/svg-preview-view'

describe "SvgPreviewView", ->
  [file, preview] = []

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model

    filePath = atom.project.resolve('subdir/file.svg')
    preview = new SvgPreviewView({filePath})

  afterEach ->
    preview.destroy()

  describe "::constructor", ->
    it "shows a loading spinner and renders the svg", ->
      preview.showLoading()
      expect(preview.find('.svg-spinner')).toExist()

      waitsForPromise ->
        preview.renderSvg()

      runs ->
        expect(preview.find("#circle")).toExist()

    it "shows an error message when there is an error", ->
      preview.showError("Not a real file")
      expect(preview.text()).toContain "Failed"

  describe "serialization", ->
    newPreview = null

    afterEach ->
      newPreview.destroy()

    it "recreates the file when serialized/deserialized", ->
      newPreview = atom.deserializers.deserialize(preview.serialize())
      expect(newPreview.getPath()).toBe preview.getPath()

    it "serializes the editor id when opened for an editor", ->
      preview.destroy()

      waitsForPromise ->
        atom.workspace.open('new.svg')

      runs ->
        preview = new SvgPreviewView({editorId: atom.workspace.getActiveEditor().id})
        expect(preview.getPath()).toBe atom.workspace.getActiveEditor().getPath()

        newPreview = atom.deserializers.deserialize(preview.serialize())
        expect(newPreview.getPath()).toBe preview.getPath()
