#include <cstdio>
#include <unistd.h>

int main(int argc, char** argv) {
  printf("Howdy partner!\n");

  while (true) {
    printf("y\n");
    sleep(2);
  }

  return 0;
}
