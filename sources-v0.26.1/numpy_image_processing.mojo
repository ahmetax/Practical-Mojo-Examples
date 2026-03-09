"""
Author: Ahmet Aksoy
Date: 2026-03-08
Revision Date: 2026-03-08
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Image processing in Mojo using NumPy and Pillow via PythonObject.

    A test image is generated at runtime — no external file needed.
    The generated image contains geometric shapes with varying colors
    so that the effects of each transformation are clearly visible.

    Four transformations are demonstrated:
      1. Grayscale conversion  — weighted average of RGB channels
      2. Brightness adjustment — multiply all pixel values by a factor
      3. Contrast adjustment   — stretch pixel value range
      4. Negative              — invert all pixel values (255 - value)

    All pixel operations are performed with NumPy on the Python side.
    Mojo handles the orchestration: calling functions, passing parameters,
    reading shape/dtype metadata, and reporting results.

    NumPy's multi-dimensional slice syntax (arr[:, :, 0]) cannot be used
    directly in Mojo. Helper functions that require such syntax are placed
    in img_helpers.py and imported as a Python module.

    Output files are saved to /tmp/ so you can open them and visually
    verify each transformation.

    Both files must be in the same directory:
      numpy_image_processing.mojo
      img_helpers.py

Requirements:
    pip install numpy pillow
"""

from python import Python, PythonObject
import sys


fn create_test_image(helpers: PythonObject, path: String) raises -> None:
    """
    Generate a synthetic RGB test image using NumPy.
    The image contains colored rectangles on a gradient background.
    Size: 256 x 256 pixels, RGB.
    """
    np: PythonObject  = Python.import_module("numpy")
    PIL: PythonObject = Python.import_module("PIL.Image")

    # Create a blank 256x256 RGB array
    img_array: PythonObject = np.zeros(
        Python.evaluate("(256, 256, 3)"), dtype=np.uint8
    )

    # Apply horizontal blue gradient via helper
    # (multi-dimensional slice arr[:, :, 2] not supported in Mojo directly)
    helpers.apply_gradient(img_array)

    # Draw colored rectangles via helper
    helpers.set_rect(img_array, 20, 120, 20,  120, 220, 50,  50)   # Red
    helpers.set_rect(img_array, 20, 120, 136, 236, 50,  200, 50)   # Green
    helpers.set_rect(img_array, 136, 236, 20, 120, 220, 200, 50)   # Yellow
    helpers.set_rect(img_array, 136, 236, 136, 236, 240, 240, 240) # White

    img: PythonObject = PIL.fromarray(img_array)
    img.save(path)
    print("Test image created:", path)
    print("  Shape:", String(img_array.shape))
    print("  dtype:", String(img_array.dtype))


fn load_image_as_array(path: String) raises -> PythonObject:
    """
    Load a PNG file and return it as a NumPy uint8 array.
    Shape is (height, width, 3) for RGB images.
    """
    np: PythonObject  = Python.import_module("numpy")
    PIL: PythonObject = Python.import_module("PIL.Image")

    img: PythonObject   = PIL.open(path).convert("RGB")
    array: PythonObject = np.array(img, dtype=np.uint8)

    var height: Int = Int(Float64(String(array.shape[0])))
    var width: Int  = Int(Float64(String(array.shape[1])))
    print("Loaded:", path, "->", width, "x", height, "px")
    return array


fn save_array_as_image(array: PythonObject, path: String) raises -> None:
    """Save a NumPy array as a PNG file using Pillow."""
    PIL: PythonObject = Python.import_module("PIL.Image")
    img: PythonObject = PIL.fromarray(array)
    img.save(path)
    print("Saved :", path)


fn to_grayscale(helpers: PythonObject, array: PythonObject) raises -> PythonObject:
    """
    Convert an RGB image to grayscale using the luminosity formula:
      Y = 0.299 * R + 0.587 * G + 0.114 * B.

    These weights reflect human eye sensitivity — green contributes
    most to perceived brightness, blue the least.

    The result is stacked into (H, W, 3) so Pillow can save it as PNG.
    """
    np: PythonObject = Python.import_module("numpy")

    # Channel extraction via helper (arr[:, :, ch] not supported in Mojo)
    R: PythonObject = helpers.get_channel(array, 0)
    G: PythonObject = helpers.get_channel(array, 1)
    B: PythonObject = helpers.get_channel(array, 2)

    gray: PythonObject   = (R * 0.299 + G * 0.587 + B * 0.114).astype(np.uint8)
    result: PythonObject = helpers.stack_gray(gray)

    print("Grayscale conversion applied")
    return result


fn adjust_brightness(array: PythonObject, factor: Float64) raises -> PythonObject:
    """
    Multiply all pixel values by `factor`.
      factor > 1.0  ->  brighter
      factor < 1.0  ->  darker
      factor = 1.0  ->  no change.

    np.clip() ensures values stay within [0, 255] after multiplication.
    Without clipping, overflow would wrap bright areas to dark values.
    """
    np: PythonObject = Python.import_module("numpy")

    brightened: PythonObject = (array.astype(np.float32) * factor)
    result: PythonObject     = np.clip(brightened, 0, 255).astype(np.uint8)

    print("Brightness adjusted: factor =", factor)
    return result


fn adjust_contrast(array: PythonObject, factor: Float64) raises -> PythonObject:
    """
    Adjust contrast by stretching pixel values around the midpoint (128).
      factor > 1.0  ->  higher contrast
      factor < 1.0  ->  lower contrast (washed out).

    Formula: output = clip((pixel - 128) * factor + 128, 0, 255)
    """
    np: PythonObject = Python.import_module("numpy")

    f: PythonObject          = array.astype(np.float32)
    contrasted: PythonObject = (f - 128.0) * factor + 128.0
    result: PythonObject     = np.clip(contrasted, 0, 255).astype(np.uint8)

    print("Contrast adjusted: factor =", factor)
    return result


fn to_negative(array: PythonObject) raises -> PythonObject:
    """
    Invert all pixel values: output = 255 - input.
    Dark areas become bright, colors become their complements.
    """
    np: PythonObject     = Python.import_module("numpy")
    result: PythonObject = (255 - array.astype(np.int16)).astype(np.uint8)

    print("Negative applied")
    return result


fn print_channel_stats(helpers: PythonObject, array: PythonObject, label: String) raises -> None:
    """
    Print min, max, and mean for each RGB channel.
    Verifies that each transformation produced the expected value range.
    """
    np: PythonObject = Python.import_module("numpy")

    print("  Stats for:", label)
    var channels = List[String]()
    channels.append("R")
    channels.append("G")
    channels.append("B")

    for i in range(3):
        var ch: String        = channels[i]
        channel: PythonObject = helpers.get_channel(array, i)
        var mn:  Float64      = Float64(String(np.min(channel)))
        var mx:  Float64      = Float64(String(np.max(channel)))
        var avg: Float64      = Float64(String(np.mean(channel)))
        print("   ", ch, "-> min:", mn, " max:", mx, " mean:", avg)


fn main() raises:
    sys = Python.import_module("sys")
    # Add current directory to Python path so img_helpers.py can be found
    sys.path.insert(0, ".")

    # Import the helper module — contains NumPy slice operations
    # that cannot be expressed directly in Mojo
    var helpers: PythonObject = Python.import_module("img_helpers")

    var src_path      = "/tmp/test_image.png"
    var gray_path     = "/tmp/test_gray.png"
    var bright_path   = "/tmp/test_bright.png"
    var dark_path     = "/tmp/test_dark.png"
    var contrast_path = "/tmp/test_contrast.png"
    var negative_path = "/tmp/test_negative.png"

    print("=== Creating Test Image ===")
    print()
    create_test_image(helpers, src_path)

    print()
    print("=== Loading Image ===")
    print()
    var original: PythonObject = load_image_as_array(src_path)
    print_channel_stats(helpers, original, "original")

    print()
    print("=== Grayscale Conversion ===")
    print()
    var gray: PythonObject = to_grayscale(helpers, original)
    save_array_as_image(gray, gray_path)
    print_channel_stats(helpers, gray, "grayscale")

    print()
    print("=== Brightness: +50% ===")
    print()
    var bright: PythonObject = adjust_brightness(original, 1.5)
    save_array_as_image(bright, bright_path)
    print_channel_stats(helpers, bright, "brightness x1.5")

    print()
    print("=== Brightness: -40% ===")
    print()
    var dark: PythonObject = adjust_brightness(original, 0.6)
    save_array_as_image(dark, dark_path)
    print_channel_stats(helpers, dark, "brightness x0.6")

    print()
    print("=== Contrast: +80% ===")
    print()
    var contrast: PythonObject = adjust_contrast(original, 1.8)
    save_array_as_image(contrast, contrast_path)
    print_channel_stats(helpers, contrast, "contrast x1.8")

    print()
    print("=== Negative ===")
    print()
    var negative: PythonObject = to_negative(original)
    save_array_as_image(negative, negative_path)
    print_channel_stats(helpers, negative, "negative")

    print()
    print("=== All done! Output files in /tmp/ ===")
    print("  test_image.png    — original")
    print("  test_gray.png     — grayscale")
    print("  test_bright.png   — brightness x1.5")
    print("  test_dark.png     — brightness x0.6")
    print("  test_contrast.png — contrast x1.8")
    print("  test_negative.png — negative")
