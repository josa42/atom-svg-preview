path = require 'path'
{WorkspaceView} = require 'atom'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
SvgPreviewView = require '../lib/svg-preview-view'

describe "SVG preview package", ->
  beforeEach ->
    fixturesPath = path.join(__dirname, 'fixtures')
    tempPath = temp.mkdirSync('atom')
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPath(tempPath)
    jasmine.unspy(window, 'setTimeout')

    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model
    spyOn(SvgPreviewView.prototype, 'renderSvg')

    waitsForPromise ->
      atom.packages.activatePackage("svg-preview")

  describe "when a preview has not been created for the file", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "splits the current pane to the right with a SVG preview for the file", ->
      waitsForPromise ->
        atom.workspace.open("subdir/file.svg")

      runs ->
        atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

      waitsFor ->
        SvgPreviewView::renderSvg.callCount > 0

      runs ->
        expect(atom.workspaceView.getPanes()).toHaveLength 2
        [editorPane, previewPane] = atom.workspaceView.getPanes()

        expect(editorPane.items).toHaveLength 1
        preview = previewPane.getActiveItem()
        expect(preview).toBeInstanceOf(SvgPreviewView)
        expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
        expect(editorPane).toHaveFocus()

    describe "when the editor's path does not exist", ->
      it "splits the current pane to the right with a SVG preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("new.svg")

        runs ->
          atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

        waitsFor ->
          SvgPreviewView::renderSvg.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(SvgPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the editor does not have a path", ->
      it "splits the current pane to the right with a SVG preview for the file", ->
        waitsForPromise ->
          atom.workspace.open("")

        runs ->
          atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

        waitsFor ->
          SvgPreviewView::renderSvg.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(SvgPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the path contains a space", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/file with space.svg")

        runs ->
          atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

        waitsFor ->
          SvgPreviewView::renderSvg.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(SvgPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

    describe "when the path contains accented characters", ->
      it "renders the preview", ->
        waitsForPromise ->
          atom.workspace.open("subdir/áccéntéd.svg")

        runs ->
          atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

        waitsFor ->
          SvgPreviewView::renderSvg.callCount > 0

        runs ->
          expect(atom.workspaceView.getPanes()).toHaveLength 2
          [editorPane, previewPane] = atom.workspaceView.getPanes()

          expect(editorPane.items).toHaveLength 1
          preview = previewPane.getActiveItem()
          expect(preview).toBeInstanceOf(SvgPreviewView)
          expect(preview.getPath()).toBe atom.workspaceView.getActivePaneItem().getPath()
          expect(editorPane).toHaveFocus()

  describe "when a preview has been created for the file", ->
    [editorPane, previewPane, preview] = []

    beforeEach ->
      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspace.open("subdir/file.svg")

      runs ->
        atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

      waitsFor ->
        SvgPreviewView::renderSvg.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPanes()
        preview = previewPane.getActiveItem()
        SvgPreviewView::renderSvg.reset()

    it "closes the existing preview when toggle is triggered a second time", ->
      atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

      [editorPane, previewPane] = atom.workspaceView.getPanes()
      expect(editorPane).toHaveFocus()
      expect(previewPane?.activeItem).toBeUndefined()

    describe "when the editor is modified", ->
      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          previewPane.focus()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            atom.workspace.getActiveEditor().setText("Hey!")

          waitsFor ->
            SvgPreviewView::renderSvg.callCount > 0

          runs ->
            expect(previewPane).toHaveFocus()
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          previewPane.focus()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            editorPane.focus()
            atom.workspace.getActiveEditor().setText("Hey!")

          waitsFor ->
            SvgPreviewView::renderSvg.callCount > 0

          runs ->
            expect(editorPane).toHaveFocus()
            expect(previewPane.getActiveItem()).toBe preview

    describe "when a new grammar is loaded", ->
      it "re-renders the preview", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-javascript')

        waitsFor ->
          SvgPreviewView::renderSvg.callCount > 0

  describe "when the SVG preview view is requested by file URI", ->
    it "opens a preview editor and watches the file for changes", ->
      waitsForPromise ->
        atom.workspace.open("svg-preview://#{atom.project.resolve('subdir/file.svg')}")

      runs ->
        expect(SvgPreviewView::renderSvg.callCount).toBeGreaterThan 0
        preview = atom.workspaceView.getActivePaneItem()
        expect(preview).toBeInstanceOf(SvgPreviewView)

        SvgPreviewView::renderSvg.reset()

        fs.writeFileSync(atom.project.resolve('subdir/file.svg'), 'changed')

      waitsFor ->
        SvgPreviewView::renderSvg.callCount > 0

  describe "when the editor's grammar it not enabled for preview", ->
    it "does not open the SVG preview", ->
      atom.config.set('svg-preview.grammars', [])

      atom.workspaceView.attachToDom()

      waitsForPromise ->
        atom.workspace.open("subdir/file.svg")

      runs ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'
        expect(atom.workspace.open).not.toHaveBeenCalled()

  describe "when the editor's path changes", ->
    it "updates the preview's title", ->
      titleChangedCallback = jasmine.createSpy('titleChangedCallback')

      waitsForPromise ->
        atom.workspace.open("subdir/file.svg")

      runs ->
        atom.workspaceView.getActiveView().trigger 'svg-preview:toggle'

      waitsFor ->
        SvgPreviewView::renderSvg.callCount > 0

      runs ->
        [editorPane, previewPane] = atom.workspaceView.getPanes()
        preview = previewPane.getActiveItem()
        expect(preview.getTitle()).toBe 'file.svg Preview'

        titleChangedCallback.reset()
        preview.one('title-changed', titleChangedCallback)
        fs.renameSync(atom.workspace.getActiveEditor().getPath(), path.join(path.dirname(atom.workspace.getActiveEditor().getPath()), 'file2.md'))

      waitsFor ->
        titleChangedCallback.callCount is 1


  describe "when the URI opened does not have a svg-preview protocol", ->
    it "does not throw an error trying to decode the URI (regression)", ->
      waitsForPromise ->
        atom.workspace.open('%')

      runs ->
        expect(atom.workspace.getActiveEditor()).toBeTruthy()
