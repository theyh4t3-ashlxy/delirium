#!/usr/bin/env python3
"""Lightweight PipeWire sink monitor 24-band FFT visualizer (pure stdlib, auto-zeros on silence)."""

from __future__ import annotations

import array
import cmath
import math
import signal
import subprocess
import sys

RATE = 16000
N = 256
HOP_BYTES = N * 2  # 256 x int16 = 512 bytes (~32ms @ 16kHz)
NUM_BANDS = 24
SILENCE_RMS = 0.0014

# Precompute Hann window & radix-2 twiddle factors once at import
HANN = [0.5 * (1.0 - math.cos(2.0 * math.pi * i / (N - 1))) for i in range(N)]

# Bit-reversal permutation table for N=256
BITREV = [0] * N
_bits = int(math.log2(N))
for _i in range(N):
    _r = 0
    _v = _i
    for _ in range(_bits):
        _r = (_r << 1) | (_v & 1)
        _v >>= 1
    BITREV[_i] = _r

TWIDDLES: list[list[complex]] = []
_size = 2
while _size <= N:
    _half = _size // 2
    _step = -2.0 * math.pi / _size
    TWIDDLES.append([cmath.exp(1j * _step * k) for k in range(_half)])
    _size *= 2

# Logarithmic bin ranges across bins 1..(N//2 - 1) (~62 Hz .. 7900 Hz)
BAND_RANGES: list[tuple[int, int]] = []
_f_min = 60.0
_f_max = 7600.0
for b in range(NUM_BANDS):
    lo_f = _f_min * ((_f_max / _f_min) ** (b / NUM_BANDS))
    hi_f = _f_min * ((_f_max / _f_min) ** ((b + 1) / NUM_BANDS))
    b0 = max(1, min(N // 2 - 1, int(lo_f * N / RATE)))
    b1 = max(b0 + 1, min(N // 2, int(math.ceil(hi_f * N / RATE))))
    BAND_RANGES.append((b0, b1))


def fft256(samples: list[float]) -> list[float]:
    buf = [complex(samples[BITREV[i]], 0.0) for i in range(N)]
    stage = 0
    size = 2
    while size <= N:
        half = size // 2
        tw = TWIDDLES[stage]
        for start in range(0, N, size):
            for k in range(half):
                u = buf[start + k]
                t = tw[k] * buf[start + k + half]
                buf[start + k] = u + t
                buf[start + k + half] = u - t
        size *= 2
        stage += 1
    scale = 2.0 / N
    return [abs(buf[i]) * scale for i in range(N // 2)]


def main() -> None:
    pw = subprocess.Popen(
        [
            "pw-record",
            "--format=s16",
            f"--rate={RATE}",
            "--channels=1",
            "--raw",
            "-P",
            "stream.capture.sink=true",
            "-",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    def cleanup(*_args: object) -> None:
        if pw.poll() is None:
            pw.terminate()
            try:
                pw.wait(timeout=0.3)
            except subprocess.TimeoutExpired:
                pw.kill()
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    smoothed = [0.0] * NUM_BANDS
    prev_zeros = False
    norm_factor = 1.0 / 32768.0

    try:
        assert pw.stdout is not None
        while True:
            raw = pw.stdout.read(HOP_BYTES)
            if not raw or len(raw) < HOP_BYTES:
                break

            pcm = array.array("h")
            pcm.frombytes(raw)
            if sys.byteorder != "little":
                pcm.byteswap()

            # Compute RMS + apply Hann window cleanly
            sq_sum = 0.0
            win_samples = [0.0] * N
            for i in range(N):
                v = pcm[i] * norm_factor
                sq_sum += v * v
                win_samples[i] = v * HANN[i]

            rms = math.sqrt(sq_sum / N)
            if rms < SILENCE_RMS:
                any_nz = False
                for i in range(NUM_BANDS):
                    smoothed[i] *= 0.45
                    if smoothed[i] < 0.012:
                        smoothed[i] = 0.0
                    else:
                        any_nz = True
                if not any_nz:
                    if not prev_zeros:
                        sys.stdout.write("0," * (NUM_BANDS - 1) + "0\n")
                        sys.stdout.flush()
                        prev_zeros = True
                    continue
            else:
                prev_zeros = False
                mags = fft256(win_samples)
                for b in range(NUM_BANDS):
                    b0, b1 = BAND_RANGES[b]
                    peak = 0.0
                    for k in range(b0, b1):
                        if mags[k] > peak:
                            peak = mags[k]
                    # Tilt slightly toward higher bands so treble doesn't disappear next to sub-bass
                    boost = 1.0 + (b / NUM_BANDS) * 1.4
                    val = min(1.0, math.log1p(peak * 18.0 * boost) / math.log1p(5.5))
                    if val > smoothed[b]:
                        smoothed[b] = smoothed[b] * 0.25 + val * 0.75
                    else:
                        smoothed[b] = smoothed[b] * 0.60 + val * 0.40

            out = ",".join(str(max(0, min(99, int(round(x * 99))))) for x in smoothed)
            sys.stdout.write(out + "\n")
            sys.stdout.flush()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        cleanup()


if __name__ == "__main__":
    main()
