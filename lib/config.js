module.exports = {
  liveUpdate: {
    type: 'boolean',
    'default': true
  },
  openPreviewInPane: {
    type: 'string',
    default: 'right',
    enum: [
      { value: '', description: 'Current Pane' },
      { value: 'right', description: 'Right Pane' },
      { value: 'down', description: 'Bottom Pane' }
    ]
  },
  openPreviewAutomatically: {
    type: 'boolean',
    'default': false
  },
  closePreviewAutomatically: {
    type: 'boolean',
    'default': true
  },
  grammars: {
    type: 'array',
    'default': ['text.plain.null-grammar', 'text.xml', 'text.xml.svg']
  }
}
