'use babel'

import fs from 'fs'
import path from 'path'

const { $ } = require('atom-space-pen-views')
const getSVGSize = require('../lib/get-svg-size')

function getSVGElement(name) {

  const s = fs.readFileSync(path.join(__dirname, 'fixtures', 'subdir', `${name}.svg`), 'utf-8')
  const div = document.createElement('div')

  div.innerHTML = s

  return div.childNodes[0]
}

describe('getSVGSize()', () => {

  it('gets size of svg with width/height attributes', () => {
    const svg = getSVGElement('file-size-attr')
    expect(getSVGSize(svg)).toEqual({ width: 400, height: 400 })
  })

  it('gets size of svg with width/height style attributes', () => {
    const svg = getSVGElement('file-size-style')
    expect(getSVGSize(svg)).toEqual({ width: 400, height: 400 })
  })

  it('gets size of svg with only viewBox attribute', () => {
    const svg = getSVGElement('file-size-none')
    expect(getSVGSize(svg)).toEqual({ width: 100, height: 100 })
  })
})
