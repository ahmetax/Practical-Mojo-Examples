"""
Helper module for numpy_timeseries.mojo.
Contains functions that use NumPy indexing and boolean operations
that cannot be expressed directly in Mojo.
"""
import numpy as np

def set_values(arr, index, value):
    """Set a single element of a 1D array by index."""
    arr[index] = value

def get_value(arr, index):
    """Get a single element of a 1D array by index."""
    return arr[index]

def get_slice(arr, start, end):
    """Return a slice of a 1D array."""
    return arr[start:end]
