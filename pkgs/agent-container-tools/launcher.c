#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PYTHON "@python@"
#define GUARD "@guard@"

extern char **environ;

static int has_name(const char *entry, const char *name) {
  size_t length = strlen(name);

  return strncmp(entry, name, length) == 0 && entry[length] == '=';
}

static int is_allowed_environment(const char *entry) {
  return has_name(entry, "COLORTERM") || has_name(entry, "LANG") ||
         has_name(entry, "LANGUAGE") || has_name(entry, "NO_COLOR") ||
         has_name(entry, "TERM") || has_name(entry, "TZ") ||
         strncmp(entry, "LC_", 3) == 0;
}

int main(int argc, char **argv) {
  const char *separator = strrchr(argv[0], '/');
  const char *tool = separator == NULL ? argv[0] : separator + 1;
  char **arguments;
  char **environment;
  char **entry;
  size_t environment_count = 0;
  size_t environment_index = 0;
  int index;

  if (strcmp(tool, "podman") != 0 && strcmp(tool, "buildah") != 0) {
    fprintf(stderr, "agent-container-launcher: unsupported tool name: %s\n", tool);
    return 127;
  }

  arguments = calloc((size_t)argc + 3, sizeof(*arguments));
  if (arguments == NULL) {
    perror("agent-container-launcher: calloc");
    return 127;
  }

  for (entry = environ; *entry != NULL; entry++) {
    if (is_allowed_environment(*entry)) {
      environment_count++;
    }
  }
  environment = calloc(environment_count + 2, sizeof(*environment));
  if (environment == NULL) {
    perror("agent-container-launcher: calloc");
    return 127;
  }
  for (entry = environ; *entry != NULL; entry++) {
    if (is_allowed_environment(*entry)) {
      environment[environment_index++] = *entry;
    }
  }
  environment[environment_index] = (char *)"PYTHONNOUSERSITE=1";

  arguments[0] = (char *)PYTHON;
  arguments[1] = (char *)GUARD;
  arguments[2] = (char *)tool;
  for (index = 1; index < argc; index++) {
    arguments[index + 2] = argv[index];
  }

  execve(PYTHON, arguments, environment);
  fprintf(stderr, "agent-container-launcher: execve: %s\n", strerror(errno));
  return 127;
}
