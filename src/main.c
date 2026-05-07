#include <stdio.h>
#include "pico/stdlib.h"

uint32_t picoword();

int main(void) {
  while (true) {
    picoword();
  }
}