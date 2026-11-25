"""PROTOTYPE: cuts the suppressed-shot candidates for the sound booth
(.scratch/weapon-attachments/issues/10-suppressed-shot-sounds.md).

    python3 assets/audio/audition/cut.py <dir of downloaded sources> assets/audio/audition

Each candidate is the first event of its source, mono 44.1 kHz, 1.2 s with a
fade. Every gun's set is levelled against that gun's own unsuppressed shot:
the reference peaks at -1.5 dB and the candidates 8 dB under it, so a
suppressed shot sounds quieter than the gun bare, as it will in the game.
"""
import array, os, subprocess, sys, wave
src, out = sys.argv[1], sys.argv[2]
L = src + "/lib/Prepared SFX Library/"
A = "assets/audio/"
OWN = {"p": A + "kurt_22_magnum/shot_1.ogg", "a": A + "kurt_gunshots/shot_1.ogg", "m": A + "firearm_library_marksman/shot.ogg"}
THUMP = "lowpass=f=900,lowpass=f=900,afade=t=out:st=0.25:d=0.35"
SOFT = "highpass=f=180,lowpass=f=2600,acompressor=threshold=0.1:ratio=6:attack=1:release=60,afade=t=out:st=0.35:d=0.45"
# name, source, ffmpeg filter (or None), is the reference
JOBS = [
    ("p0_REFERENCE_pistol_unsuppressed", OWN["p"], None, True),
    ("p1_own_shot_muffled_thump", OWN["p"], THUMP, False),
    ("p2_own_shot_softened", OWN["p"], SOFT, False),
    ("p3_real_22_pistol_ruger_mk3", L + "Ruger Mark III/R_35P.wav", None, False),
    ("p4_hollywood_silencer", src + "/silencer.wav", None, False),
    ("p5_emopreben_silencer_2", src + "/emo/Silencers - 2.wav", None, False),
    ("a0_REFERENCE_assault_rifle_unsuppressed", OWN["a"], None, True),
    ("a1_own_shot_muffled_thump", OWN["a"], THUMP, False),
    ("a2_own_shot_softened", OWN["a"], SOFT, False),
    ("a3_real_22_revolver_single_six", L + "Ruger Single Six/S_14P.wav", None, False),
    ("a4_hollywood_silencer_deeper", src + "/silencer.wav", "asetrate=44100*0.8,aresample=44100", False),
    ("a5_emopreben_silencer_6", src + "/emo/Silencers - 6.wav", None, False),
    ("m0_REFERENCE_marksman_unsuppressed", OWN["m"], None, True),
    ("m1_own_shot_muffled_thump", OWN["m"], THUMP, False),
    ("m2_own_shot_softened", OWN["m"], SOFT, False),
    ("m3_real_300_blackout_savage", L + "Savage 10 .300 Blackout/T_17P.wav", "lowpass=f=5000", False),
    ("m4_hollywood_silencer_deepest", src + "/silencer.wav", "asetrate=44100*0.65,aresample=44100", False),
    ("m5_emopreben_silencer_9", src + "/emo/Silencers - 9.wav", None, False),
]
# Round 2, Pistol only: the user picked a3 for the Assault Rifle and m3 for
# the Marksman Rifle, both real small or subsonic rounds, and rejected every
# Pistol candidate. So: more real recordings, mostly from further off.
UP = "asetrate=44100*%s,aresample=44100"
ROUND_2 = [
    ("p0_REFERENCE_pistol_unsuppressed", OWN["p"], None, True),
    ("p1_22_pistol_ruger_mk3_mid", L + "Ruger Mark III/R_30P.wav", None, False),
    ("p2_22_revolver_single_six_mid", L + "Ruger Single Six/S_11P.wav", None, False),
    ("p3_22_revolver_single_six_near_AS_ASSAULT_RIFLE", L + "Ruger Single Six/S_14P.wav", None, False),
    ("p4_22_revolver_single_six_near_higher", L + "Ruger Single Six/S_14P.wav", UP % "1.2", False),
    ("p5_380_bersa_mid", L + "Bersa/F_41P.wav", None, False),
    ("p6_380_bersa_mid_muffled", L + "Bersa/F_41P.wav", "lowpass=f=3000", False),
    ("p7_38_snubnose_642_mid", L + "Smith & Wesson 642/V_22P.wav", None, False),
    ("p8_9mm_walther_ppq_mid", L + "Walther PPQ/X_31P.wav", None, False),
    ("p9_9mm_walther_ppq_mid_muffled", L + "Walther PPQ/X_31P.wav", "lowpass=f=2500", False),
    ("pa_45_1911_mid", L + "1911/A_34P.wav", None, False),
    ("pb_45_1911_mid_muffled", L + "1911/A_34P.wav", "lowpass=f=2500", False),
    ("pc_300_blackout_AS_MARKSMAN_higher", L + "Savage 10 .300 Blackout/T_17P.wav", "lowpass=f=5000," + UP % "1.25", False),
]
if len(sys.argv) > 3 and sys.argv[3] == "2":
    JOBS = ROUND_2
R = 44100
for name, source, chain, reference in JOBS:
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", source, "-ac", "1", "-ar", str(R), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    a = array.array("h"); a.frombytes(raw[:len(raw) // 2 * 2])
    peak = max(abs(x) for x in a)
    start = max(next(i for i, x in enumerate(a) if abs(x) > peak * 0.15) - int(0.012 * R), 0)
    cut = a[start:start + int(1.2 * R)]
    tmp = out + "/_tmp.wav"
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R); w.writeframes(cut.tobytes())
    if chain:
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-af", chain, out + "/_tmp2.wav"], check=True)
        os.replace(out + "/_tmp2.wav", tmp)
    with wave.open(tmp) as w:
        b = array.array("h"); b.frombytes(w.readframes(w.getnframes()))
    p = max(abs(x) for x in b) or 1
    gain = 32767 * 10 ** ((-1.5 if reference else -9.5) / 20) / p
    n, fade = len(b), int(0.12 * R)
    done = array.array("h", (int(max(-32767, min(32767, x * gain * min(1.0, (n - i) / fade)))) for i, x in enumerate(b)))
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(R); w.writeframes(done.tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", out + "/" + name + ".ogg"], check=True)
    os.remove(tmp)
    print("%-42s %.2f s" % (name, n / R))
