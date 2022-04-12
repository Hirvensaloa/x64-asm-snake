# Snake

## About

Learning x64 assembly on Linux by building a classic snake game. Uses [Xlib](https://x.org/releases/current/doc/libX11/libX11/libX11.html#Introduction_to_Xlib) to handle drawing and event listening on a window.

## Get started

Run `make` to build the executable. To start the game run `.snake`. NOTE: Works only on 64-bit Linux.

### Commands

Snake can be moved with arrow keys.

### Rules

The goal is to try feed the snake by eating food that appears on the map. By consuming one piece of food, the snake grows by one and a point is earned. Snake can go through the walls (afterwards appears on the other side). Game is lost if snake collides with itself.
