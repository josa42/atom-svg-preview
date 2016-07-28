'use babel'

exports.transform = (svg, outputType, callback) => {
    let img = document.createElement('img')
    img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`

    img.addEventListener('load', (event) => {
        // create an (undisplayed) canvas
        let canvas = document.createElement('canvas')
        let img = event.target

        // resize the canvas to the size of the image
        canvas.width = img.width
        canvas.height = img.height

        // ... and draw the image on there
        canvas.getContext('2d').drawImage(img, 0, 0)

        // smurf the data url of the canvas
        dataURL = canvas.toDataURL(`image/${outputType}`, 0.8)

        // extract the base64 encoded image, decode and return it
        return callback(new Buffer(dataURL.replace(`data:image/${outputType};base64,`, ''), 'base64'))
    })
}
