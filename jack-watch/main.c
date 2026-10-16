#define _DEFAULT_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <jack/jack.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

#define POLL_SECONDS 5

// Silence threshold after which the amp and cooling fan are turned off
#define SILENCE_US (5ULL * 60 * 1000000ULL) /* 5 minutes */
// #define SILENCE_US (10ULL * 1000000ULL) /* 10 seconds for testing */

#define JACK_CLIENT_NAME "amp_power_controller_watch"

static jack_port_t *input;
static atomic_uint_fast64_t last_audio_us = ATOMIC_VAR_INIT(0);
static volatile sig_atomic_t running = 1;

static void stop_running(int sig) {
  (void)sig;
  running = 0;
}

/* JACK's real-time thread: never wait, lock, log, or touch serial I/O. */
static int process_audio(jack_nframes_t nframes, void *arg) {
  (void)arg;
  if (nframes == 0) return 0;

  const jack_default_audio_sample_t *samples =
    jack_port_get_buffer(input, nframes);

  /* Intentionally sample only the first frame in each JACK buffer. */
  if (samples[0] != 0.0f)
    // Lock-free on x86-64 Linux (no guarantee for other architectures)
    atomic_store_explicit(
      &last_audio_us,
      jack_get_time(),
      memory_order_relaxed
    );

  return 0;
}

static int open_serial(const char *path) {
  int fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC);
  if (fd < 0) {
    perror(path);
    return -1;
  }

  struct termios tty;
  if (tcgetattr(fd, &tty) != 0) {
    perror("tcgetattr");
    close(fd);
    return -1;
  }
  cfmakeraw(&tty);
  tty.c_cflag |= CLOCAL | CREAD;
  if (tcsetattr(fd, TCSANOW, &tty) != 0) {
    perror("tcsetattr");
    close(fd);
    return -1;
  }
  return fd;
}

static int send_command(int fd, const char *command) {
  const char *p = command;
  size_t remaining = strlen(command);

  while (remaining > 0) {
    ssize_t written = write(fd, p, remaining);
    if (written < 0 && errno == EINTR) continue;
    if (written <= 0) {
      if (written == 0) errno = EIO;
      perror("write to Pico");
      return -1;
    }
    p += written;
    remaining -= (size_t)written;
  }
  fprintf(stderr, "Pico ← %s", command);
  return 0;
}

static void set_power(const char *device, int *fd, bool want_on) {
  if (*fd < 0) {
    *fd = open_serial(device);
    if (*fd < 0) return;
    usleep(100000); /* Allow USB CDC/DTR to settle. */
  }

  const char *first  = want_on ? "FAN_ON\n" : "AMP_OFF\n";
  const char *second = want_on ? "AMP_ON\n" : "FAN_OFF\n";

  if (send_command(*fd, first) != 0 || send_command(*fd, second) != 0) {
    close(*fd);
    *fd = -1;
  }
}

int main(int argc, char **argv) {
  const char *serial_device = argc > 1 ? argv[1] : "/dev/ttyACM0";
  signal(SIGINT, stop_running);
  signal(SIGTERM, stop_running);

  if (!atomic_is_lock_free(&last_audio_us)) {
    fprintf(stderr, "A 64-bit atomic is not lock-free on this CPU.\n");
    return 1;
  }

  jack_client_t *client = jack_client_open(
    JACK_CLIENT_NAME,
    JackNoStartServer,
    NULL
  );
  if (!client) {
    fprintf(stderr, "Cannot connect to the JACK server.\n");
    return 1;
  }

  input = jack_port_register(
    client,
    "in",
    JACK_DEFAULT_AUDIO_TYPE,
    JackPortIsInput,
    0
  );
  if (
    !input ||
    jack_set_process_callback(client, process_audio, NULL) != 0 ||
    jack_activate(client) != 0
  ) {
    fprintf(stderr, "Cannot initialize JACK client.\n");
    jack_client_close(client);
    return 1;
  }

  int serial_fd = -1;
  uint64_t start_us = jack_get_time();

  fprintf(
    stderr,
    "Monitor sources: connect JACK outputs to %s\n",
    jack_port_name(input)
  );

  set_power(serial_device, &serial_fd, false);
  bool is_amp_on = false;

  while (running) {
    sleep(POLL_SECONDS);
    if (!running) break;

    bool no_audio_yet =
      atomic_load_explicit(&last_audio_us, memory_order_relaxed) == 0;
    uint64_t elapsed_us = jack_get_time() - (
      no_audio_yet ? start_us :
      atomic_load_explicit(&last_audio_us, memory_order_relaxed)
    );
    uint64_t secs = elapsed_us / 1000000ULL;
    fprintf(
      stderr,
      "No audio for %" PRIu64 " min %" PRIu64 " sec\n",
      secs / 60,
      secs % 60
    );

    if (!jack_port_connected(input))
      fprintf(stderr, "WARNING: no JACK audio sources connected.\n");

    bool want_on = !no_audio_yet && elapsed_us < SILENCE_US;
    if (is_amp_on != want_on) {
      set_power(serial_device, &serial_fd, want_on);
      is_amp_on = want_on;
    }
  }

  /* Clean shutdown: issue OFF commands even if both were already off. */
  if (serial_fd < 0) serial_fd = open_serial(serial_device);
  if (serial_fd >= 0) {
    send_command(serial_fd, "AMP_OFF\n");
    send_command(serial_fd, "FAN_OFF\n");
    close(serial_fd);
  }
  jack_deactivate(client);
  jack_client_close(client);
  return 0;
}
