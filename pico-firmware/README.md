# Raspberry Pico firmware for the amp power controlling

I recommend to use Nix for providing dependencies, enter `nix-shell` first.
Unplug USB cable from Pico, hold BOOTSEL button and plug the USB cable back in,
then release the BOOTSEL button. Mount the Pico disk (I assume the mounted path
is `/run/media/USER/RPI-RP2/`).

```sh
./build.sh
cp build/amp-power-controller.uf2 /run/media/USER/RPI-RP2/
```

After `cp` is done Pico will automatically apply the firmware and reboot.
You should see the LED on the Pico board lit up. It means it listens for the
commands. See the GPIO pins it turns on and off:

```c
#define AMP_PIN 1
#define FAN_PIN 3
```

On NixOS make sure your user is in `dialout` group so that you can access
`/dev/ttyACM0` without root-level access.

Then you can send commands terminated by `\n` (use raw TTY mode):

- `AMP_ON`/`AMP_OFF`
- `FAN_ON`/`FAN_OFF`

Use `./power.sh on` and `./power.sh off` to switch both amp and fan on and off.

You can also use `./test.sh` for testing.

## Vim ALE configuration for code checking

Run `./build.sh` at least once first to make it work.

```vim
let b:ale_linters = {'c': ['cc']}
let b:ale_c_cc_executable = 'arm-none-eabi-gcc'
let b:ale_c_parse_compile_commands = 1
let b:ale_c_build_dir = expand('%:p:h') . '/build'
```

This configuration makes GCC to find the Pico SDK sources correctly.
