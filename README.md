# Audio Amplifier Raspberry Pico Power Controller

It’s a very simple build to control the power supplied for my audio power
amplifier and a cooling fan for it from the computer.

It consists of 2 parts:

- [Pico firmware](pico-firmware)
  (power switching using TinyUSB serial TTY interface)

- [JACK watcher program](jack-watch)
  (to automatically detect presence of audio received by the JACK audio port
  and power everything off after N minutes of inactivity; and power everything
  back on when audio starts playing again)

## Pico Firmware

Pico firmware just turns on and off GPIO pins following the commands it
receives.

I use Noctua NF-A20 5V USB-powered silent cooling fan. I connect VBUS of Pico
(forwarded 5VDC USB power) to fan’s positive. There there is BS170 MOSFET. Fan’s
negative goes to the drain of BS170, the MOSFET source is connected to ground.
There is also 100kΩ biasing resistor connected between MOSFET gate and ground.
GPIO pin 3 goes to MOSFET gate through 100Ω gate-stopper resistor.

The amp power is controlled via hot-lead mains voltage breaker relay module.
Connected to NO (normally-open, no power goes to the amplifier until the relay
is engaged). _**WARNING!** In this case there is potentially lethal AC voltages
present, I strongly recommend avoid building it unless you know what you’re
doing and following all safety precautions!_ Between 2 IEC connectors GROUND
lead is always connected, COLD is always connected. Hot is in series with the
high-voltage relay (rated 230V/10A). In my case it’s 3V relay. Pico 3V3 (not
3V3_EN) pin goes to the relay VCC input. Pico GPIO Pin 1 goes to relay module
IN, and any GND Pico pin goes to relay module GND.

So fan is switched via BS170 MOSFET (if you use a different fan or different
MOSFET check current capabilities of your MOSFET). And the amp power is switched
using a 3V-controlled high-voltage relay that breaks the HOT lead.

If your amplifier of choice supports something like 12V trigger it will be a
much safer build to just connect 12V positive through the relay. Or just use
similar BS170 MOSFET network (currents of those triggers are typically very
small, <10mA, so BS170 would handle it very easy). But you might want to switch
positive, not ground, so source-follower MOSFET configuration (connect 12V
straight to drain, and connect source to the amplifier V+ for the 12V trigger),
but it depends on how your amplifiers implements the trigger network. Breaking
ground instead of V+ (as showed for the fan powering) is less prone to voltage
drop.

## JACK Watch Program

JACK watch program creates a JACK client with a single audio input port and
“listens” to the port signal. It only checks for the first sample in a buffer
(there is no need in practice to check the entire buffer). If it is equal to 0
it is considered as silence. The main thread checks every N seconds for how long
the silence is present if M minutes silence threshold is reached the main thread
sends commands (to `/dev/ttyACM0` by default) to switch both fan and amp off.
If sounds starts playing again in maximum N seconds interval during the next
check the audio will be detected by the main thread and both fan and amp will be
commanded to switch back on. Thus your amp power is controlled automatically
based on audio presence received by the program’s JACK port.

This program doesn’t know anything about how and what you are going connect it
to. So connecting your audio sources as power triggers is up to you. This
program only creates a port. You can connect your forwarded PulseAudio for
example (both stereo channels summed to the trigger port):

```sh
jack_connect 'PulseAudio JACK Sink:front-left' 'amp_power_controller_watch:in'
jack_connect 'PulseAudio JACK Sink:front-right' 'amp_power_controller_watch:in'
```

There is a possibility for the audio to be considered as silence when left and
right channels are perfectly anti-phase relative to each other. But that would
be a really wrong audio source. So I’m not even taking this into account.

You can use something like
[jack_autoconnect](https://github.com/kripton/jack_autoconnect) for example to
keep the audio sources automatically connected to the trigger input.

You can always manually control the power when you need to instead of using this
program.

The program powering everything off when starting (and powering everything on
when audio is detected). And also powering everything off when exiting.

## Build and run

I recommend to use Nix package manager for managing dependencies and building
everything.

Clone this repo and enter the cloned directory first, then:

```sh
nix-build -A amp-power-controller-pico-firmware -o result-pico-firmware
nix-build -A amp-power-switch -o result-amp-power-switch
nix-build -A amp-power-controller-jack-watch -o result-jack-watch
```

### Install Pico firmware

First make sure you wired correctly the GPIO pins for switching:

```c
#define AMP_PIN 1
#define FAN_PIN 3
```

Unplug USB cable from Pico, hold BOOTSEL button and plug the USB cable back in,
then release the BOOTSEL button. Mount the Pico disk (I assume the mounted path
is `/run/media/USER/RPI-RP2/`).

```sh
cp result-pico-firmware/firmware/amp-power-controller.uf2 /run/media/USER/RPI-RP2/
```

After `cp` is done Pico will automatically apply the firmware and reboot.
You should see the LED on the Pico board lit up. It means it listens for the
commands.

### Manually test power controlling

On NixOS make sure your user is in `dialout` group so that you can access
`/dev/ttyACM0` without root-level access.

```sh
result-amp-power-switch/bin/amp-power-switch on
result-amp-power-switch/bin/amp-power-switch off
```

It switches both amp and fan on and off.

### Use JACK silence detector program

Say your audio source is PulseAudio forwarded to JACK, then:

```sh
result-jack-watch/bin/amp-power-controller-jack-watch
```

It works as a daemon, in a separate terminal:

```sh
jack_connect 'PulseAudio JACK Sink:front-left' 'amp_power_controller_watch:in'
jack_connect 'PulseAudio JACK Sink:front-right' 'amp_power_controller_watch:in'
```

Then it will automatically detect sound presence and power the amplifier on,
and power it off when there is no audio for specified amount of minutes. The
main thread will check every N seconds for the audio presence. So amplifier
turning on can be lagged by maximum that amount of seconds (I’m not accounting
for minor instructions execution and relay delays, amplifier capacitors charging
and other factors like these).

```c
#define POLL_SECONDS 5
#define SILENCE_US (5ULL * 60 * 1000000ULL) /* 5 minutes */
```

## License

SPDX: MIT

All files in this repository (apart from third-party dependencies) are
licensed under [MIT](LICENSE).
