"""Original v0.28 synthesized spell charges; no recordings or third-party audio.
Run from project root with Python 3. Standard library only, deterministic PCM WAV.
Each spell charges immediately, swells before the 660 ms impact, then rings out.
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/sfx'
SR = 22050
DURATION = .94
# Different register, harmonic structure, and rhythm for each spell family.
SPELLS = {
    'cast_orb': (330, (1, 1.5, 2), 5),
    'cast_lightning': (440, (1, 2.03, 3.1), 23),
    'cast_runes': (262, (1, 1.25, 1.5, 2), 7),
    'cast_stars': (659, (1, 1.5, 2.5), 11),
    'cast_blade': (220, (1, 2, 3), 13),
    'cast_ice': (784, (1, 1.414, 2), 17),
    'cast_heal': (523, (1, 1.25, 1.5), 3),
    'cast_burst': (196, (1, 1.5, 2, 4), 19),
    'monster_spell': (147, (1, 1.189, 1.5), 9),
    'boss_spell': (82.4, (1, 1.059, 1.5, 2, 3), 6),
}

def synth(name, base, harmonics, pulse):
    rng = random.Random(name)
    result = []
    for i in range(round(SR * DURATION)):
        t = i / SR
        # Quick audible onset; crescendo reaches its peak before contact.
        attack = min(1, t / .016)
        charge = .56 + .44 * min(1, t / .6)
        tail = 1 if t < .60 else max(0, (DURATION - t) / (DURATION - .60)) ** 1.4
        shimmer = .82 + .18 * math.sin(2 * math.pi * pulse * t)
        phase = base * t + 90 * t * t
        signal = sum(math.sin(2 * math.pi * h * phase) / (j + 1)
                     for j, h in enumerate(harmonics))
        if name in ('cast_lightning', 'cast_ice', 'cast_burst', 'monster_spell'):
            signal += rng.uniform(-1, 1) * .10
        result.append(signal * attack * charge * tail * shimmer)
    scale = .86 / max(abs(x) for x in result)
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(b''.join(struct.pack('<h', round(x * scale * 32767)) for x in result))

if __name__ == '__main__':
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, spec in SPELLS.items():
        synth(name, *spec)
    print(f'Generated {len(SPELLS)} original 940 ms cast sounds; contact at 660 ms.')
