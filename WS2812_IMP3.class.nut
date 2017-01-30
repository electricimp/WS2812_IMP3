class WS2812_IMP3 {

    static VERSION = [1,0,0];

    // This class uses SPI to emulate the WS2812s' one-wire protocol.
    // The ideal speed for neopixels is 6.4 MHz via SPI.
    // The closest Imp003 supported SPI datarate is 9 MHz.
    // These consts define the "waveform" to represent a zero-zero, zero-one, one-zero, one-one.
    static ZERO_ZERO = "\xE0\x0E\x00";
    static ZERO_ONE = "\xE0\x0F\xC0";
    static ONE_ZERO = "\xFC\x0E\x00";
    static ONE_ONE = "\xFC\x0F\xC0";

    static BYTES_PER_PIXEL = 36;

    // When instantiated, the WS2812 class will fill this array with blobs to
    // represent the waveforms to send the numbers 0 to 255. This allows the
    // blobs to be copied in directly, instead of being built for each pixel.
    static _bits     = array(256, null);


    // Private variables passed into the constructor
    _spi             = null;  // imp SPI interface (pre-configured)
    _frameSize       = null;  // number of pixels per frame
    _frame           = null;  // a blob to hold the current frame


    // Parameters:
    //    spi          A pre-configured SPI bus (MSB_FIRST, 9000)
    //    frameSize    Number of Pixels per frame
    //    _draw        Whether or not to initially draw a blank frame
    constructor(spiBus, frameSize, _draw = true) {
        // spiBus must be configured
        _spi = spiBus;

        _frameSize = frameSize;
        _frame = blob(_frameSize * BYTES_PER_PIXEL + 1);
        _frame[_frameSize * BYTES_PER_PIXEL] = 0;

        // Used in constructing the _bits array
        local bytesPerColor = BYTES_PER_PIXEL / 3;

        // Fill the _bits array if required
        // (Multiple instance of WS2812 will only initialize it once)
        if (_bits[0] == null) {
            for (local i = 0; i < 256; i++) {
                local valblob = blob(bytesPerColor);
                valblob.writestring(_getNumber((i /64) % 4));
                valblob.writestring(_getNumber((i /16) % 4));
                valblob.writestring(_getNumber((i /4) % 4));
                valblob.writestring(_getNumber(i % 4));
                _bits[i] = valblob;
            }
        }

        // Clear the pixel buffer
        fill([0,0,0]);

        // Output the pixels if required
        if (_draw) {
            this.draw();
        }
    }

    // Configures the SPI Bus
    //
    // NOTE: If using the configure method, you *must* pass `false` to the
    // _draw parameter in the constructor (or else an error will be thrown)
    function configure() {
        _spi.configure(MSB_FIRST, 9000);
        return this;
    }

    // Sets a pixel in the buffer
    //   index - the index of the pixel (0 <= index < _frameSize)
    //   color - [r,g,b] (0 <= r,g,b <= 255)
    //
    // NOTE: set(index, color) replaces v1.x.x's writePixel(p, color) method
    function set(index, color) {
        index = _checkRange(index);
        color = _checkColorRange(color);

        _frame.seek(index * BYTES_PER_PIXEL);

        // Create a blob for the color
        // Red and green are swapped for some reason, so swizzle them back
        _frame.writeblob(_bits[color[1]]);
        _frame.writeblob(_bits[color[0]]);
        _frame.writeblob(_bits[color[2]]);

        return this;
    }

    // Sets the frame buffer (or a portion of the frame buffer)
    // to the specified color, but does not write it to the pixel strip
    //
    // NOTE: fill([0,0,0]) replaces v1.x.x's clear() method
    function fill(color, start=0, end=null) {
        // we can't default to _frameSize -1, so we
        // default to null and set to _frameSize - 1
        if (end == null) { end = _frameSize - 1; }

        // Make sure we're not out of bounds
        start = _checkRange(start);
        end = _checkRange(end);
        color = _checkColorRange(color);

        // Flip start & end if required
        if (start > end) {
            local temp = start;
            start = end;
            end = temp;
        }

        // Create a blob for the color
        // Red and green are swapped for some reason, so swizzle them back
        local colorBlob = blob(BYTES_PER_PIXEL);
        colorBlob.writeblob(_bits[color[1]]);
        colorBlob.writeblob(_bits[color[0]]);
        colorBlob.writeblob(_bits[color[2]]);

        // Write the color blob to each pixel in the fill
        _frame.seek(start*BYTES_PER_PIXEL);
        for (local index = start; index <= end; index++) {
            _frame.writeblob(colorBlob);
        }

        return this;
    }

    // Writes the frame to the pixel strip
    //
    // NOTE: draw() replaces v1.x.x's writeFrame() method
    function draw() {
        _spi.write(_frame);
        return this;
    }

    function _checkRange(index) {
        if (index < 0) index = 0;
        if (index >= _frameSize) index = _frameSize - 1;
        return index;
    }

    function _checkColorRange(colors) {
        foreach(idx, color in colors) {
            if (color < 0) colors[idx] = 0;
            if (color > 255) colors[idx] = 255;
        }
        return colors
    }

    function _getNumber(num) {
        if(num == 0) return ZERO_ZERO;
        if(num == 1) return ZERO_ONE;
        if(num == 2) return ONE_ZERO;
        if(num == 3) return ONE_ONE;
    }
}
