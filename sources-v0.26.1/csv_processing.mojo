"""
Author: Ahmet Aksoy
Date: 2026-03-07
Revision Date: 2026-03-07
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Reading and processing CSV files in Mojo using PythonObject (Style B).

    Two approaches are demonstrated:
      1. Standard library  — Python's built-in csv module, no dependencies
      2. Pandas            — for more complex data operations

    In both cases, PythonObject is used explicitly in function signatures,
    making it clear which variables hold Python values vs Mojo values.

    The example uses a small sales dataset that is generated at runtime,
    so no external CSV file is needed.

    Operations covered:
      - Reading a CSV file row by row
      - Filtering rows by a condition
      - Computing column statistics (min, max, average)
      - Writing a filtered result to a new CSV file
      - Reading the same data with Pandas and computing group statistics

Requirements:
    pip install pandas
"""

from python import Python, PythonObject
from collections import Dict


# ------------------------------------------------------------
# Helper: create a sample CSV file for testing
# ------------------------------------------------------------

fn create_sample_csv(path: String) raises -> None:
    """
    Writes a small sales dataset to a CSV file.
    Columns: product, category, quantity, unit_price, total.
    """
    builtins: PythonObject = Python.import_module("builtins")
    var f: PythonObject = builtins.open(path, "w")
    f.write("product,category,quantity,unit_price,total\n")
    f.write("Keyboard,Electronics,10,450.00,4500.00\n")
    f.write("Mouse,Electronics,25,150.00,3750.00\n")
    f.write("Desk,Furniture,5,1200.00,6000.00\n")
    f.write("Chair,Furniture,8,950.00,7600.00\n")
    f.write("Monitor,Electronics,12,3200.00,38400.00\n")
    f.write("Notebook,Stationery,100,15.00,1500.00\n")
    f.write("Pen,Stationery,500,3.50,1750.00\n")
    f.write("Headphones,Electronics,7,800.00,5600.00\n")
    f.write("Lamp,Furniture,15,320.00,4800.00\n")
    f.write("USB Hub,Electronics,20,250.00,5000.00\n")
    f.close()
    print("Sample CSV created:", path)


# ------------------------------------------------------------
# Pattern 1: Reading CSV with Python's csv module
# ------------------------------------------------------------

fn read_csv_rows(path: String) raises -> PythonObject:
    """
    Reads a CSV file using the csv.DictReader.
    Returns a Python list of dicts, one dict per row.
    Each dict key is the column name, value is the cell string.

    DictReader is preferred over reader() because it gives
    named access to columns instead of positional index.
    """
    csv: PythonObject      = Python.import_module("csv")
    builtins: PythonObject = Python.import_module("builtins")

    var f: PythonObject    = builtins.open(path, "r", newline="")
    reader: PythonObject   = csv.DictReader(f)

    # Collect all rows into a Python list
    rows: PythonObject     = Python.evaluate("list")(reader)
    f.close()

    print("Read", len(rows), "rows from", path)
    return rows


fn print_rows(rows: PythonObject) raises -> None:
    """Print all rows in a simple tabular format."""
    var count: Int = Int(String(len(rows)))
    print()
    print("  Product          Category       Qty   Unit Price      Total")
    print("  " + "-" * 64)
    for i in range(count):
        var row: PythonObject = rows[i]
        print(" ",
            String(row["product"]) + "            ",
            String(row["category"]) + "        ",
            String(row["quantity"]),
            String(row["unit_price"]),
            String(row["total"])
        )


fn filter_by_category(rows: PythonObject, category: String) raises -> PythonObject:
    """
    Filter rows where the 'category' column matches the given value.
    Returns a new Python list with matching rows only.
    Demonstrates passing PythonObject between fn functions.
    """
    var result: PythonObject = Python.evaluate("list")()
    var count: Int = Int(String(len(rows)))

    for i in range(count):
        var row: PythonObject = rows[i]
        if String(row["category"]) == category:
            result.append(row)

    return result


fn compute_stats(rows: PythonObject, column: String) raises -> None:
    """
    Compute min, max, and average for a numeric column.
    Values are read as PythonObject strings, converted to Mojo Float64
    for arithmetic, then printed.
    """
    var count: Int = Int(String(len(rows)))
    if count == 0:
        print("No rows to compute stats.")
        return

    var total: Float64 = 0.0
    var min_val: Float64 = Float64(String(rows[0][column]))
    var max_val: Float64 = min_val

    for i in range(count):
        var row: PythonObject = rows[i]
        var val: Float64 = Float64(String(row[column]))
        total += val
        if val < min_val:
            min_val = val
        if val > max_val:
            max_val = val

    var avg: Float64 = total / count
    print("  Column   :", column)
    print("  Count    :", count)
    print("  Min      :", min_val)
    print("  Max      :", max_val)
    print("  Average  :", avg)
    print("  Total    :", total)


fn write_filtered_csv(rows: PythonObject, path: String) raises -> None:
    """
    Write a filtered set of rows to a new CSV file.
    Uses Python's csv.DictWriter to preserve column headers.
    """
    csv: PythonObject      = Python.import_module("csv")
    builtins: PythonObject = Python.import_module("builtins")

    if Int(String(len(rows))) == 0:
        print("No rows to write.")
        return

    # Get column names from the first row's keys
    var fieldnames: PythonObject = Python.evaluate("list")(rows[0].keys())

    var f: PythonObject      = builtins.open(path, "w", newline="")
    writer: PythonObject     = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
    f.close()

    print("Wrote", len(rows), "rows to", path)


# ------------------------------------------------------------
# Pattern 2: Reading and grouping with Pandas
# ------------------------------------------------------------

fn pandas_group_stats(path: String) raises -> None:
    """
    Read the CSV with Pandas and compute total sales per category.
    Demonstrates using PythonObject to work with a DataFrame.

    Pandas is more concise for aggregation tasks compared to
    manual iteration with the csv module.
    """
    pd: PythonObject = Python.import_module("pandas")

    # Read CSV into a DataFrame — all columns auto-detected
    df: PythonObject = pd.read_csv(path)

    print("DataFrame shape: rows =", String(df.shape[0]),
          ", cols =", String(df.shape[1]))
    print()

    # Group by category, sum the numeric columns
    grouped: PythonObject = df.groupby("category")["total"].agg(
        Python.evaluate("['sum', 'mean', 'count']")
    )

    print("Sales summary by category:")
    print("  " + "-" * 44)

    # Iterate over grouped result rows
    categories: PythonObject = grouped.index.tolist()
    var n: Int = Int(String(len(categories)))

    for i in range(n):
        var cat: String    = String(categories[i])
        var row: PythonObject = grouped.loc[categories[i]]
        var total: Float64 = Float64(String(row["sum"]))
        var mean: Float64  = Float64(String(row["mean"]))
        var cnt: Int       = Int(Float64(String(row["count"])))
        print("  Category :", cat)
        print("    Count  :", cnt)
        print("    Total  :", total)
        print("    Average:", mean)
        print()


fn main() raises:
    var csv_path      = "/tmp/sales.csv"
    var filtered_path = "/tmp/sales_electronics.csv"

    # --- Setup ---
    print("=== Creating sample CSV ===")
    print()
    create_sample_csv(csv_path)

    # --- Pattern 1: csv module ---
    print()
    print("=== Reading CSV with csv module ===")
    var rows: PythonObject = read_csv_rows(csv_path)
    print_rows(rows)

    print()
    print("=== Filtering: Electronics only ===")
    var electronics: PythonObject = filter_by_category(rows, "Electronics")
    print_rows(electronics)

    print()
    print("=== Stats for 'total' column (Electronics) ===")
    compute_stats(electronics, "total")

    print()
    print("=== Writing filtered CSV ===")
    write_filtered_csv(electronics, filtered_path)

    # --- Pattern 2: Pandas ---
    print()
    print("=== Group statistics with Pandas ===")
    print()
    pandas_group_stats(csv_path)
