"""
Helper module for numpy_image_processing.mojo
Contains functions that use NumPy multi-dimensional slicing,
which cannot be expressed directly in Mojo.
"""
import numpy as np

def apply_gradient(arr):
    """Apply a horizontal blue gradient to the background."""
    gradient = np.tile(np.arange(256), (256, 1))
    arr[:, :, 2] = gradient

def set_rect(arr, r0, r1, c0, c1, rv, gv, bv):
    """Fill a rectangular region with the given RGB values."""
    arr[r0:r1, c0:c1, 0] = rv
    arr[r0:r1, c0:c1, 1] = gv
    arr[r0:r1, c0:c1, 2] = bv

def get_channel(arr, ch):
    """Return a single color channel as float32 array."""
    return arr[:, :, ch].astype(np.float32)

def stack_gray(g):
    """Stack a 2D grayscale array into (H, W, 3) RGB format."""
    return np.stack((g, g, g), axis=2)
