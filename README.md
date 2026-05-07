Converts a 32-bit input from an array of switches to a decimal value and displays it on a 10 digit array of seven segment displays.

## How To Build
Make a build folder, change the current directory to it, and run cmake. Make sure PICO_SDK_PATH is set correctly before running the following sequence of command lines.

```bash
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Debug -DPICO_BOARD=pico ../src
make -j4
```

