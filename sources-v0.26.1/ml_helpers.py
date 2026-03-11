"""
Helper module for numpy_ml_preprocessing.mojo.
Contains NumPy indexing, slicing and encoding operations
that cannot be expressed directly in Mojo.
"""
import numpy as np

def get_column(arr, col):
    """Return a single column from a 2D array."""
    return arr[:, col]

def get_columns(arr, start, end):
    """Return a range of columns from a 2D array."""
    return arr[:, start:end]

def set_column(arr, col, values):
    """Set a column of a 2D array to given values."""
    arr[:, col] = values

def get_element(arr, row, col):
    """Return a single element from a 2D array."""
    return arr[row, col]

def set_nan(arr, row, col):
    """Set a single element to NaN."""
    arr[row, col] = np.nan

def fill_nan(arr, col, value):
    """Fill NaN values in a column with a given value."""
    mask = np.isnan(arr[:, col])
    arr[mask, col] = value

def one_hot(column, n_categories):
    """
    One-hot encode a 1D array of integer category indices.
    Returns a 2D array of shape (n_samples, n_categories).
    """
    n = len(column)
    result = np.zeros((n, n_categories), dtype=np.float64)
    for i in range(n):
        result[i, int(column[i])] = 1.0
    return result
