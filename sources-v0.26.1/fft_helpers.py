"""
Helper module for numpy_fft.mojo.
Contains NumPy indexing and slicing operations
that cannot be expressed directly in Mojo.
"""
import numpy as np

def get_column(arr, col):
    """Return a single column from a 2D array."""
    return arr[:, col]

def get_row(arr, row):
    """Return a single row from a 2D array."""
    return arr[row, :]

def get_value(arr, index):
    """Return a single element from a 1D array."""
    return arr[index]

def apply_mask(arr, mask):
    """Apply a boolean mask to a 1D array."""
    return arr[mask]

def index_array(arr, indices):
    """Index a 1D array with an array of indices."""
    return arr[indices]
