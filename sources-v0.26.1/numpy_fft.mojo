"""
Author: Ahmet Aksoy
Date: 2026-03-08
Revision Date: 2026-03-08
Mojo version no: 0.26.1
AI: Claude Sonnet 4.6

Description:
    Frequency analysis of vibration sensor data using NumPy FFT in Mojo.

    Simulates a rotating machine's vibration signal sampled at 1000 Hz.
    The signal contains three frequency components:
      - 50 Hz  : normal operating frequency (shaft rotation)
      - 120 Hz : bearing defect frequency (injected fault)
      - 300 Hz : gear mesh frequency (injected fault)

    Fast Fourier Transform (FFT) decomposes the time-domain signal into
    its frequency components, revealing which frequencies carry the most
    energy. This is the basis of predictive maintenance systems that
    detect mechanical faults before they cause failures.

    Three steps are demonstrated:
      1. Signal generation  — combine sine waves + noise to simulate sensor
      2. FFT computation    — transform to frequency domain
      3. Peak detection     — identify dominant frequencies automatically

    Results are saved to /tmp/fft_analysis.csv for further inspection.

    NumPy slice and index operations are delegated to fft_helpers.py.

    Both files must be in the same directory:
      numpy_fft.mojo
      fft_helpers.py

Requirements:
    pip install numpy
"""

from python import Python, PythonObject


fn generate_vibration_signal(helpers: PythonObject) raises -> PythonObject:
    """
    Generate a synthetic vibration signal by combining sine waves.

    Sampling rate: 1000 Hz (1000 samples per second).
    Duration     : 1 second (1000 samples total).

    Three sine wave components:
      - 50 Hz  at amplitude 1.0  — normal shaft rotation
      - 120 Hz at amplitude 0.5  — bearing defect (fault frequency)
      - 300 Hz at amplitude 0.3  — gear mesh frequency (fault frequency)

    Gaussian noise is added to simulate real sensor conditions.
    """
    np: PythonObject = Python.import_module("numpy")

    var sample_rate: Int = 1000
    var duration: Int    = 1

    # Time axis: 1000 evenly spaced points from 0 to 1 second
    t: PythonObject = np.linspace(0, duration, sample_rate * duration)

    # Component sine waves
    signal_50hz:  PythonObject = 1.0 * np.sin(2.0 * 3.14159265 * 50  * t)
    signal_120hz: PythonObject = 0.5 * np.sin(2.0 * 3.14159265 * 120 * t)
    signal_300hz: PythonObject = 0.3 * np.sin(2.0 * 3.14159265 * 300 * t)

    # Combine components and add noise
    np.random.seed(0)
    noise: PythonObject  = np.random.normal(0, 0.05, sample_rate * duration)
    signal: PythonObject = signal_50hz + signal_120hz + signal_300hz + noise

    print("Signal generated.")
    print("  Sample rate:", sample_rate, "Hz")
    print("  Duration   :", duration, "second")
    print("  Components : 50 Hz (amp=1.0), 120 Hz (amp=0.5), 300 Hz (amp=0.3)")
    print("  Noise      : Gaussian, std=0.05")
    return signal


fn compute_fft(signal: PythonObject, sample_rate: Int) raises -> PythonObject:
    """
    Compute the FFT of the signal and return frequency/amplitude pairs.

    np.fft.fft()      — computes the discrete Fourier transform.
    np.fft.fftfreq()  — computes the corresponding frequency axis in Hz.

    FFT output is complex — we take np.abs() to get amplitude.
    We only keep the positive half (up to Nyquist frequency = sample_rate/2)
    because the negative half is a mirror image for real-valued signals.

    Returns a 2D array where column 0 = frequency (Hz), column 1 = amplitude.
    """
    np: PythonObject = Python.import_module("numpy")

    var n: Int = Int(Float64(String(len(signal))))

    # Compute FFT and frequency axis
    fft_vals: PythonObject  = np.fft.fft(signal)
    freqs: PythonObject     = np.fft.fftfreq(n, d=1.0 / sample_rate)

    # Amplitude spectrum: abs of complex FFT output, normalized by n
    amplitude: PythonObject = np.abs(fft_vals) / n

    # Keep only positive frequencies (first half)
    half: Int = n // 2
    pos_freqs: PythonObject = np.abs(freqs[:half])
    pos_amp: PythonObject   = amplitude[:half] * 2  # multiply by 2 for single-sided

    # Stack into (n/2, 2) array: [[freq, amp], ...]
    result: PythonObject = np.column_stack(
        Python.evaluate("lambda f, a: (f, a)")(pos_freqs, pos_amp)
    )

    print("FFT computed.")
    print("  Total samples    :", n)
    print("  Frequency bins   :", half)
    print("  Frequency range  : 0 -", sample_rate // 2, "Hz")
    print("  Frequency resolution:", Float64(sample_rate) / Float64(n), "Hz/bin")
    return result


fn detect_peaks(helpers: PythonObject, fft_result: PythonObject,
                min_amplitude: Float64, n_peaks: Int) raises -> None:
    """
    Find the N strongest frequency components in the FFT result.

    Filters out components below min_amplitude to ignore noise floor.
    Sorts remaining peaks by amplitude (descending) and prints the top N.

    This is the core of frequency-domain fault detection:
    known fault frequencies (bearing, gear mesh, imbalance) appear as
    distinct peaks in the spectrum above the noise floor.
    """
    np: PythonObject = Python.import_module("numpy")

    freqs: PythonObject = helpers.get_column(fft_result, 0)
    amps: PythonObject  = helpers.get_column(fft_result, 1)

    # Boolean mask: only keep bins above threshold
    mask: PythonObject     = amps > min_amplitude
    peak_freqs: PythonObject = helpers.apply_mask(freqs, mask)
    peak_amps: PythonObject  = helpers.apply_mask(amps, mask)

    # Sort by amplitude descending
    sort_idx: PythonObject   = np.argsort(peak_amps)[::-1]
    sorted_freqs: PythonObject = helpers.index_array(peak_freqs, sort_idx)
    sorted_amps: PythonObject  = helpers.index_array(peak_amps, sort_idx)

    var total: Int = Int(Float64(String(len(sorted_freqs))))
    var show: Int  = total if total < n_peaks else n_peaks

    print("Top", show, "frequency peaks (amplitude >", min_amplitude, "):")
    print("  Rank  Frequency (Hz)  Amplitude")
    print("  " + "-" * 36)

    for i in range(show):
        var freq: Float64 = Float64(String(helpers.get_value(sorted_freqs, i)))
        var amp: Float64  = Float64(String(helpers.get_value(sorted_amps, i)))
        var freq_int: Int = Int(freq)

        # Flag known fault frequencies
        var flag: String = ""
        if freq_int == 50:
            flag = "  <- normal operating frequency"
        elif freq_int == 120:
            flag = "  <- BEARING DEFECT frequency"
        elif freq_int == 300:
            flag = "  <- GEAR MESH frequency"

        print("  ", i + 1, "    ", freq_int, "Hz          ", amp, flag)


fn save_fft_csv(helpers: PythonObject, fft_result: PythonObject, path: String) raises -> None:
    """
    Save the full FFT spectrum to a CSV file.
    Columns: frequency_hz, amplitude.
    """
    builtins: PythonObject = Python.import_module("builtins")

    var n: Int = Int(Float64(String(len(fft_result))))
    var f: PythonObject = builtins.open(path, "w")
    f.write("frequency_hz,amplitude\n")

    for i in range(n):
        var row: PythonObject = helpers.get_row(fft_result, i)
        var freq: Float64     = Float64(String(helpers.get_value(row, 0)))
        var amp: Float64      = Float64(String(helpers.get_value(row, 1)))
        f.write(String(Int(freq)) + "," + String(amp) + "\n")

    f.close()
    print("FFT spectrum saved to:", path)


fn main() raises:
    var sys: PythonObject = Python.import_module("sys")
    sys.path.insert(0, ".")
    var helpers: PythonObject = Python.import_module("fft_helpers")

    var sample_rate: Int = 1000

    print("=== Generating Vibration Signal ===")
    print()
    var signal: PythonObject = generate_vibration_signal(helpers)

    print()
    print("=== Computing FFT ===")
    print()
    var fft_result: PythonObject = compute_fft(signal, sample_rate)

    print()
    print("=== Detecting Frequency Peaks ===")
    print()
    detect_peaks(helpers, fft_result, min_amplitude=0.05, n_peaks=10)

    print()
    print("=== Saving FFT Spectrum ===")
    print()
    save_fft_csv(helpers, fft_result, "/tmp/fft_analysis.csv")
