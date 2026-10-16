// A simple audio amplifier power controller firmware for Raspberry Pico chip.
//
// - AMP_ON turns on amplifier mains power
// - AMP_OFF turns off amplifier mains power
// - FAN_ON turns on amplifier cooling fan
// - FAN_OFF turns off amplifier cooling fan

#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"

#define AMP_PIN 1
#define FAN_PIN 3

static void process_command(const char *cmd)
{
  if (strcmp(cmd, "AMP_ON") == 0) {
    gpio_put(AMP_PIN, 1);
    puts("OK AMP_ON");
  } else if (strcmp(cmd, "AMP_OFF") == 0) {
    gpio_put(AMP_PIN, 0);
    puts("OK AMP_OFF");
  } else if (strcmp(cmd, "FAN_ON") == 0) {
    gpio_put(FAN_PIN, 1);
    puts("OK FAN_ON");
  } else if (strcmp(cmd, "FAN_OFF") == 0) {
    gpio_put(FAN_PIN, 0);
    puts("OK FAN_OFF");
  } else {
    puts("ERR Unknown command");
  }
}

int main(void)
{
  // Initialize both controlling pin outputs as OFF.

  gpio_init(AMP_PIN);
  gpio_put(AMP_PIN, 0);
  gpio_set_dir(AMP_PIN, GPIO_OUT);

  gpio_init(FAN_PIN);
  gpio_put(FAN_PIN, 0);
  gpio_set_dir(FAN_PIN, GPIO_OUT);

  // Initialize USB serial.
  stdio_init_all();

  char buffer[32];
  unsigned pos = 0;

  // Turn on the onboard LED (GPIO25).
  gpio_init(PICO_DEFAULT_LED_PIN);
  gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
  gpio_put(PICO_DEFAULT_LED_PIN, 1);

  puts("READY LISTENING");

  while (true) {
    int c = getchar_timeout_us(1000);
    if (c == PICO_ERROR_TIMEOUT) continue;

    if (c == '\n') {
      if (pos > 0) {
        buffer[pos] = '\0';
        process_command(buffer);
        pos = 0;
      }
    } else if (pos < sizeof(buffer) - 1) {
      buffer[pos++] = (char)c;
    } else {
      // Discard buffer overflow.
      pos = 0;
    }
  }
}
