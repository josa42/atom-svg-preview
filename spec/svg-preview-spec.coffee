path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
wrench = require 'wrench'
SvgPreviewView = require '../lib/svg-preview-view'
{$} = require 'atom-space-pen-views'

describe "SVG preview package", ->
  [workspaceElement, preview] = []

  beforeEach ->
    fixturesPath = path.join(__dirname, 'fixtures')
    tempPath = temp.mkdirSync('atom')
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPaths([tempPath])

    jasmine.useRealClock()

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    atom.deserializers.add(SvgPreviewView)

    waitsForPromise ->
      atom.packages.activatePackage("svg-preview")

  expectPreviewInSplitPane = ->
    runs ->
      expect(atom.workspace.getPanes()).toHaveLength 2

    waitsFor "svg preview to be created", ->
      preview = atom.workspace.getPanes()[1].getActiveItem()

    runs ->
      expect(preview).toBeInstanceOf(SvgPreviewView)
      expect(preview.getPath())
        .toBe atom.workspace.getActivePaneItem().getPath()

  describe "when a preview has not been created for the file", ->
    it "displays a svg preview in a split pane", ->
      waitsForPromise -> atom.workspace.open("subdir/file.svg")
      runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
      expectPreviewInSplitPane()

      runs ->
        [editorPane] = atom.workspace.getPanes()
        expect(editorPane.getItems()).toHaveLength 1
        expect(editorPane.isActive()).toBe true

    describe "when the editor's path does not exist", ->
      it "splits the current pane to the right with a svg preview for the file", ->
        waitsForPromise -> atom.workspace.open("new.svg")
        runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
        expectPreviewInSplitPane()

    describe "when the editor does not have a path", ->
      it "splits the current pane to the right with a svg preview for the file", ->
        waitsForPromise -> atom.workspace.open("")
        runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
        expectPreviewInSplitPane()

    describe "when the path contains a space", ->
      it "renders the preview", ->
        waitsForPromise -> atom.workspace.open("subdir/file with space.svg")
        runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
        expectPreviewInSplitPane()

    describe "when the path contains accented characters", ->
      it "renders the preview", ->
        waitsForPromise -> atom.workspace.open("subdir/áccéntéd.svg")
        runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
        expectPreviewInSplitPane()

  describe "when a preview has been created for the file", ->
    beforeEach ->
      waitsForPromise -> atom.workspace.open("subdir/file.svg")
      runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
      expectPreviewInSplitPane()

    it "closes the existing preview when toggle is triggered a second time on the editor", ->
      atom.commands.dispatch workspaceElement, 'svg-preview:toggle'

      [editorPane, previewPane] = atom.workspace.getPanes()
      expect(editorPane.isActive()).toBe true
      expect(previewPane.getActiveItem()).toBeUndefined()

    it "closes the existing preview when toggle is triggered on it and it has focus", ->
      [editorPane, previewPane] = atom.workspace.getPanes()
      previewPane.activate()

      atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
      expect(previewPane.getActiveItem()).toBeUndefined()

    describe "when the editor is modified", ->
      it "invokes ::onDidChangeSvg listeners", ->
        svgEditor = atom.workspace.getActiveTextEditor()
        preview.onDidChangeSvg(listener = jasmine.createSpy('didChangeSvgListener'))

        runs ->
          svgEditor.setText("<svg></svg>")

        waitsFor "::onDidChangeSvg handler to be called", ->
          listener.callCount > 0

      describe "when the preview is in the active pane but is not the active item", ->
        it "re-renders the preview but does not make it active", ->
          svgEditor = atom.workspace.getActiveTextEditor()
          previewPane = atom.workspace.getPanes()[1]
          previewPane.activate()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            svgEditor.setText("<svg></svg>")

          waitsFor ->
            preview.html().indexOf("<svg></svg>") >= 0

          runs ->
            expect(previewPane.isActive()).toBe true
            expect(previewPane.getActiveItem()).not.toBe preview

      describe "when the preview is not the active item and not in the active pane", ->
        it "re-renders the preview and makes it active", ->
          svgEditor = atom.workspace.getActiveTextEditor()
          [editorPane, previewPane] = atom.workspace.getPanes()
          previewPane.splitRight(copyActiveItem: true)
          previewPane.activate()

          waitsForPromise ->
            atom.workspace.open()

          runs ->
            editorPane.activate()
            svgEditor.setText("<svg></svg>")

          waitsFor ->
            preview.html().indexOf("<svg></svg>") >= 0

          runs ->
            expect(editorPane.isActive()).toBe true
            expect(previewPane.getActiveItem()).toBe preview

      describe "when the liveUpdate config is set to false", ->
        it "only re-renders the svg when the editor is saved, not when the contents are modified", ->
          atom.config.set 'svg-preview.liveUpdate', false

          didStopChangingHandler = jasmine.createSpy('didStopChangingHandler')
          atom.workspace.getActiveTextEditor().getBuffer().onDidStopChanging didStopChangingHandler
          atom.workspace.getActiveTextEditor().setText('<svg foo="bar"></svg>')

          waitsFor ->
            didStopChangingHandler.callCount > 0

          runs ->
            expect(preview.html()).not.toContain('<svg foo="bar"></svg>')
            atom.workspace.getActiveTextEditor().save()

          waitsFor ->
            preview.html().indexOf('<svg foo="bar"></svg>') >= 0

  describe "when the svg preview view is requested by file URI", ->
    it "opens a preview editor and watches the file for changes", ->
      waitsForPromise "atom.workspace.open promise to be resolved", ->
        filePath = atom.project.getDirectories()[0].resolve('subdir/file.svg')
        atom.workspace.open("svg-preview://#{filePath}")

      runs ->
        preview = atom.workspace.getActivePaneItem()
        expect(preview).toBeInstanceOf(SvgPreviewView)

        spyOn(preview, 'renderSvgText')
        preview.file.emitter.emit('did-change')

      waitsFor "svg to be re-rendered after file changed", ->
        preview.renderSvgText.callCount > 0

  describe "when the editor's grammar it not enabled for preview", ->
    it "does not open the svg preview", ->
      atom.config.set('svg-preview.grammars', [])

      waitsForPromise ->
        atom.workspace.open("subdir/file.svg")

      runs ->
        spyOn(atom.workspace, 'open').andCallThrough()
        atom.commands.dispatch workspaceElement, 'svg-preview:toggle'
        expect(atom.workspace.open).not.toHaveBeenCalled()

  describe "when the editor's path changes on #win32 and #darwin", ->
    it "updates the preview's title", ->
      titleChangedCallback = jasmine.createSpy('titleChangedCallback')

      waitsForPromise -> atom.workspace.open("subdir/file.svg")
      runs -> atom.commands.dispatch workspaceElement, 'svg-preview:toggle'

      expectPreviewInSplitPane()

      runs ->
        expect(preview.getTitle()).toBe 'file.svg Preview'
        preview.onDidChangeTitle(titleChangedCallback)
        fs.renameSync(atom.workspace.getActiveTextEditor().getPath(),
                      path.join(path.dirname(atom.workspace.getActiveTextEditor().getPath()), 'file2.svg'))

      waitsFor ->
        preview.getTitle() is "file2.svg Preview"

      runs ->
        expect(titleChangedCallback).toHaveBeenCalled()

  describe "when the URI opened does not have a svg-preview protocol", ->
    it "does not throw an error trying to decode the URI (regression)", ->
      waitsForPromise ->
        atom.workspace.open('%')

      runs ->
        expect(atom.workspace.getActiveTextEditor()).toBeTruthy()
