'use babel'

import { $ } from 'atom-space-pen-views'

const { SVG_LENGTHTYPE_PERCENTAGE } = SVGLength

export default function getSVGSize(svg) {

  let style = getComputedStyle(svg)

  let width = parseFloat(style.width)
  let height = parseFloat(style.height)

  if (svg.style.width && svg.style.height) {
    width = parseFloat(svg.style.width)
    height = parseFloat(svg.style.height)

  } else if (svg.width.baseVal.unitType !== SVG_LENGTHTYPE_PERCENTAGE || svg.height.baseVal.unitType !== SVG_LENGTHTYPE_PERCENTAGE) {
    width = svg.width.baseVal.value
    height = svg.height.baseVal.value

  } else if (svg.viewBox.baseVal.width && svg.viewBox.baseVal.height) {
    width = svg.viewBox.baseVal.width
    height = svg.viewBox.baseVal.height
  }

  return { width, height }
}
