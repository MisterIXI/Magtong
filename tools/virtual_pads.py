#!/usr/bin/env python3
"""Virtual Xbox 360 gamepads for testing Magtong without real controllers (Linux, uinput).

Godot sees each pad as a real "Xbox 360 Controller" with the standard mapping, including plugging and
unplugging. Needs write access to /dev/uinput and python-evdev.

Usage:
    python3 tools/virtual_pads.py SCRIPT_FILE      # or '-' to read the steps from stdin

Live session (pads stay connected, steps are sent one at a time while you look at the game):
    mkfifo /tmp/pads; sleep infinity > /tmp/pads &     # keeps the pipe open between steps
    python3 -u tools/virtual_pads.py - < /tmp/pads &
    echo "pads 2" > /tmp/pads; echo "tap 0 a" > /tmp/pads
    kill %1                                            # closing the pipe ends the session, pads unplug

The script has one step per line, '#' starts a comment:
    pads N                  create N pads (pad 0..N-1), waits until the OS has them
    wait SECONDS            pause
    tap PAD BUTTON [SECS]   press and release a button (default hold 0.1 s)
    hold PAD BUTTON         press a button and keep it down
    release PAD BUTTON      let go of a held button
    stick PAD X Y           left stick, -1..1 each (Y: -1 = up), stays until changed
    rstick PAD X Y          right stick
    trigger PAD l|r VALUE   trigger 0..1
    unplug PAD              disconnect the pad (like pulling the cable)
    plug PAD                connect it again
    print TEXT              print a marker (to line up with screenshots/logs)

Buttons: a b x y lb rb back start guide ls rs up down left right (up/down/left/right = D-pad)

Example:
    pads 2
    tap 0 a          # pad 0 joins the lobby
    tap 1 a          # pad 1 joins
    stick 0 1 0      # pad 0 walks right
    wait 1
    stick 0 0 0
    unplug 1
"""
import sys
import time

from evdev import AbsInfo, UInput, ecodes as e

BUTTONS = {
    "a": e.BTN_SOUTH, "b": e.BTN_EAST, "x": e.BTN_WEST, "y": e.BTN_NORTH,
    "lb": e.BTN_TL, "rb": e.BTN_TR, "back": e.BTN_SELECT, "start": e.BTN_START,
    "guide": e.BTN_MODE, "ls": e.BTN_THUMBL, "rs": e.BTN_THUMBR,
}
DPAD = {"up": (e.ABS_HAT0Y, -1), "down": (e.ABS_HAT0Y, 1), "left": (e.ABS_HAT0X, -1), "right": (e.ABS_HAT0X, 1)}
STICK_MAX = 32767
TRIGGER_MAX = 255
# time the OS, SDL and Godot need to notice a new device
PLUG_DELAY = 1.5

CAPABILITIES = {
    e.EV_KEY: list(BUTTONS.values()),
    e.EV_ABS: [(axis, AbsInfo(0, -32768, STICK_MAX, 16, 128, 0)) for axis in (e.ABS_X, e.ABS_Y, e.ABS_RX, e.ABS_RY)]
    + [(axis, AbsInfo(0, 0, TRIGGER_MAX, 0, 0, 0)) for axis in (e.ABS_Z, e.ABS_RZ)]
    + [(axis, AbsInfo(0, -1, 1, 0, 0, 0)) for axis in (e.ABS_HAT0X, e.ABS_HAT0Y)],
}


class Pad:
    def __init__(self) -> None:
        self.device = None
        self.plug()

    def plug(self) -> None:
        if self.device is None:
            # the Xbox 360 vendor/product ids make SDL use the standard mapping
            self.device = UInput(CAPABILITIES, name="Microsoft X-Box 360 pad", vendor=0x045E, product=0x028E,
                                 version=0x110, bustype=e.BUS_USB)

    def unplug(self) -> None:
        if self.device is not None:
            self.device.close()
            self.device = None

    def _write(self, ev_type: int, code: int, value: int) -> None:
        if self.device is None:
            raise RuntimeError("pad is unplugged")
        self.device.write(ev_type, code, value)
        self.device.syn()

    def button(self, name: str, pressed: bool) -> None:
        if name in DPAD:
            axis, direction = DPAD[name]
            self._write(e.EV_ABS, axis, direction if pressed else 0)
        else:
            self._write(e.EV_KEY, BUTTONS[name], 1 if pressed else 0)

    def stick(self, x: float, y: float, right: bool = False) -> None:
        ax, ay = (e.ABS_RX, e.ABS_RY) if right else (e.ABS_X, e.ABS_Y)
        self._write(e.EV_ABS, ax, round(max(-1.0, min(1.0, x)) * STICK_MAX))
        self._write(e.EV_ABS, ay, round(max(-1.0, min(1.0, y)) * STICK_MAX))

    def trigger(self, side: str, value: float) -> None:
        self._write(e.EV_ABS, e.ABS_Z if side == "l" else e.ABS_RZ, round(max(0.0, min(1.0, value)) * TRIGGER_MAX))


def run(lines) -> None:
    pads: list[Pad] = []
    try:
        for number, raw in enumerate(lines, 1):
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            cmd, *args = line.split()
            try:
                if cmd == "pads":
                    pads.extend(Pad() for _ in range(int(args[0])))
                    time.sleep(PLUG_DELAY)
                elif cmd == "wait":
                    time.sleep(float(args[0]))
                elif cmd == "tap":
                    pad = pads[int(args[0])]
                    pad.button(args[1], True)
                    time.sleep(float(args[2]) if len(args) > 2 else 0.1)
                    pad.button(args[1], False)
                    time.sleep(0.05)
                elif cmd == "hold":
                    pads[int(args[0])].button(args[1], True)
                elif cmd == "release":
                    pads[int(args[0])].button(args[1], False)
                elif cmd in ("stick", "rstick"):
                    pads[int(args[0])].stick(float(args[1]), float(args[2]), right=cmd == "rstick")
                elif cmd == "trigger":
                    pads[int(args[0])].trigger(args[1], float(args[2]))
                elif cmd == "unplug":
                    pads[int(args[0])].unplug()
                elif cmd == "plug":
                    pads[int(args[0])].plug()
                    time.sleep(PLUG_DELAY)
                elif cmd == "print":
                    print(" ".join(args), flush=True)
                else:
                    raise ValueError(f"unknown step '{cmd}'")
            except (IndexError, KeyError, ValueError) as err:
                sys.exit(f"line {number}: {raw.strip()!r}: {err!r}")
    finally:
        for pad in pads:
            pad.unplug()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    if sys.argv[1] == "-":
        run(sys.stdin)
    else:
        with open(sys.argv[1]) as f:
            run(f)
