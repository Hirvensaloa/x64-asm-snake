; file for testing Xlib api

global main

; Xlib functions
extern XOpenDisplay
extern XDefaultScreen
extern XBlackPixel
extern XWhitePixel
extern XDefaultRootWindow
extern XCreateSimpleWindow
extern XCreateGC
extern XSelectInput
extern XMapWindow
extern XDrawRectangle
extern XFillRectangle
extern XFlush
extern XCloseDisplay
extern XCheckWindowEvent
extern XkbKeycodeToKeysym

; libc functions
extern clock
; libc helpers, TODO: replace these in production code
extern printf
extern exit

section .data

; Logs
dev_log: 
    .expose db "Exposure", 10, 0
    .keypress db "Keypress", 10, 0
    .event_not_recognized db "Event not recognized", 10, 0
    .key_press_not_recognized db "Key press not recognized", 10, 0
    .left db "Left", 10, 0
    .right db "Right", 10, 0
    .up db "Up", 10, 0
    .down db "Down", 10, 0
    .number_str db "Number: %d", 10, 0
    .x_str db "X: %d", 10, 0
    .y_str db "Y: %d", 10, 0
    .number db " %d", 0
    .result db "Result: %d", 10, 0
    .correct_overflow db "Correct overflow %c", 10, 0
game_log:
    .start db "Game started", 10, 0
    .end db "Game ended", 10, 0
error: db "Error", 0

; Game values   
tick_interval: dq 250 * 1000 ; milliseconds * CLOCKS_PER_MS

start_x db 1
start_y db 1

; Indicates which way the snake is moving
going_up db 0
going_down db 1
going_left db 2
going_right db 3

; Gamemap values
tile_size db 10
map_width dd 64 
map_height dd 64

; Xlib values
exposureMask dq 32768
keyPressMask dq 1
gc_foreground dq 4
exposeEvent dd 12
keyPressEvent dd 2

XK_Esc dd 65307
XK_Left dd 65361
XK_Right dd 65363
XK_Up dd 65362
XK_Down dd 65364

section .bss 

; Game variables
last_tick_count resq 1

; Game state variables
snake_head_x resb 1
snake_head_y resb 1
snake_tail_x resb 1
snake_tail_y resb 1
snake_dir resb 1

; Pixel values
pixels:
    .black resd 1
    .white resd 1

; Xlib variables
display resq 1
screen resd 1
root_window resq 1
window resq 1
gc_black resq 1
gc_white resq 1
colormap resq 1
keysym resd 1

; Xlib structures
xgvals_white resb 128
xgvals_black resb 128
xevent resb 192

section .text

advance_game:
    ; Print x and y
    mov rdi, dev_log.x_str
    movzx rsi, byte [snake_head_x]
    sub rsp, 8
    call printf
    add rsp, 8
    mov rdi, dev_log.y_str
    movzx rsi, byte [snake_head_y]
    sub rsp, 8
    call printf
    add rsp, 8

    ; Move snake to the next position

    mov al, [snake_dir]

check_up:
    cmp al, [going_up]
    jne check_right

    mov rdi, dev_log.up
    sub rsp, 8
    call printf
    add rsp, 8

    dec byte [snake_head_y]
    jmp correct_underflow_x

check_right: 
    cmp al, [going_right]
    jne check_down

    mov rdi, dev_log.right
    sub rsp, 8
    call printf
    add rsp, 8

    inc byte [snake_head_x]
    jmp correct_underflow_x

check_down:
    cmp al, [going_down]
    jne go_left

    mov rdi, dev_log.down
    sub rsp, 8
    call printf
    add rsp, 8

    inc byte [snake_head_y]
    jmp correct_underflow_x

    ; Left is the only option left so no checks needed
go_left:
    dec byte [snake_head_x]

    mov rdi, dev_log.left
    sub rsp, 8
    call printf
    add rsp, 8

correct_underflow_x:
    ; Check if snake is out of bounds
    xor al, al
    cmp byte [snake_head_x], al
    jns correct_underflow_y

    mov al, byte [map_width]
    mov [snake_head_x], al
    jmp game_state_updated

correct_underflow_y:
    ; Check if snake is out of bounds
    xor al, al
    cmp byte [snake_head_y], al
    jns correct_overflow_x

    mov al, byte [map_height]
    mov [snake_head_y], al
    jmp game_state_updated

correct_overflow_x:
    ; Check if snake is out of bounds
    movzx eax, byte [snake_head_x]
    cmp eax, [map_width]
    js correct_overflow_y

    mov rdi, dev_log.correct_overflow
    mov rsi, 'x'
    sub rsp, 8
    call printf
    add rsp, 8

    mov byte [snake_head_x], 0
    jmp game_state_updated

correct_overflow_y:
    ; Check if snake is out of bounds
    movzx eax, byte [snake_head_y]
    cmp eax, [map_height]
    js game_state_updated

    mov rdi, dev_log.correct_overflow
    mov rsi, 'y'
    sub rsp, 8
    call printf
    add rsp, 8

    mov byte [snake_head_y], 0
    
    ; Game state updated, return
game_state_updated:
    ret 

main: 
    mov rdi, game_log.start
    sub rsp, 8
    call printf
    add rsp, 8

    ; Open display
    mov rdi, 0
    sub rsp, 8
    call XOpenDisplay
    add rsp, 8
    mov [display], rax

    ; Get screen
    mov rdi, [display]
    sub rsp, 8
    call XDefaultScreen
    add rsp, 8

    ; Get black pixel value
    mov rdi, [display]
    mov rsi, [screen]
    sub rsp, 8
    call XBlackPixel
    mov [pixels.black], eax
    add rsp, 8

    ; Get white pixel value
    mov rdi, [display]
    mov rsi, [screen]
    sub rsp, 8
    call XWhitePixel
    mov [pixels.white], eax
    add rsp, 8

    ; Get root window
    mov rdi, [display]
    sub rsp, 8
    call XDefaultRootWindow
    mov [root_window], rax
    add rsp, 8

    ; Create window
    mov rdi, [display]
    mov rsi, [root_window]
    mov rdx, 0
    mov rcx, 0

    mov eax, [map_width]
    mul byte [tile_size]
    mov r8d, eax
    mov eax, [map_height]
    mul byte [tile_size]
    mov r9d, eax

    mov rax, 0
    push rax
    mov eax, [pixels.black]
    push rax
    push rax

    call XCreateSimpleWindow
    mov [window], rax
    add rsp, 24

    ; Create graphics context for black
    mov rdi, [display]
    mov rsi, [window]
    mov ecx, [pixels.black]
    mov [xgvals_black + 16], ecx
    mov rdx, [gc_foreground]
    mov rcx, xgvals_black
    sub rsp, 8
    call XCreateGC
    mov [gc_black], rax
    add rsp, 8

    ; Create graphics context for white
    mov rdi, [display]
    mov rsi, [window]
    mov ecx, [pixels.white]
    mov [xgvals_white + 16], ecx
    mov rdx, [gc_foreground]
    mov rcx, xgvals_white
    sub rsp, 8
    call XCreateGC
    mov [gc_white], rax
    add rsp, 8

    ; Select input
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [exposureMask]
    or rdx, [keyPressMask]
    sub rsp, 8
    call XSelectInput
    add rsp, 8

    ; Map window
    mov rdi, [display]
    mov rsi, [window]
    sub rsp, 8
    call XMapWindow
    add rsp, 8

    sub rsp, 8
    call XFlush
    add rsp, 8

    ; Initialize clock
    sub rsp, 8
    call clock
    mov [last_tick_count], rax
    add rsp, 8

    ; Initialize snake
    mov al, [start_x]
    mov bl, [start_y]
    mov cl, [going_right]
    mov [snake_head_x], al
    mov [snake_head_y], bl
    mov [snake_dir], cl

    ; Main loop, listens for events
main_loop:
    ; Check for events
    sub rsp, 8
    call check_events
    add rsp, 8

    ; Check to see if it's time to update the game state
    sub rsp, 8
    call clock
    add rsp, 8
    mov rbx, rax ; temporarily save latest clock value
    sub rbx, [tick_interval] 
    sub rbx, [last_tick_count] ; If clock ticks now - tick interval < last tick count, update game state

    ; If its not time to tick, go back to start of loop
    js main_loop

    ; Update last tick count
    mov [last_tick_count], rax

    ; Update game state
    sub rsp, 8
    call advance_game
    add rsp, 8

    ; draw new state
    sub rsp, 8
    call draw
    add rsp, 8

    jmp main_loop

check_events:
    ; Get event
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [exposureMask]
    or rdx, [keyPressMask]
    mov rcx, xevent
    sub rsp, 8
    call XCheckWindowEvent
    add rsp, 8

    ; Jump to event if there is one
    cmp rax, 1
    je event

    ; No event
    ret

    ; Handle window event
event: 
    ; Check if event is key press
    mov ecx, [xevent + 0]
    cmp ecx, [keyPressEvent]
    je key_press

    ; Check if event is exposure
    mov ecx, [xevent + 0]
    cmp ecx, [exposeEvent]
    je expose

    ; Unhandled event
    mov rdi, dev_log.event_not_recognized
    sub rsp, 8
    call printf
    add rsp, 8

    ret

    ; Key press
key_press:
    ; Logs TODO: remove in production code
    mov rdi, dev_log.keypress
    sub rsp, 8
    call printf
    add rsp, 8

    ; Get keysym
    mov rdi, [display]
    mov esi, [xevent + 84]
    mov rdx, 0
    mov rcx, 0
    sub rsp, 8
    call XkbKeycodeToKeysym
    add rsp, 8

    ; Latest key is now stored in rax
    ; Check if key is left
    cmp eax, [XK_Left]
    je left

    ; Check if key is right
    cmp eax, [XK_Right]
    je right

    ; Check if key is up
    cmp eax, [XK_Up]
    je up

    ; Check if key is down
    cmp eax, [XK_Down]
    je down

    ; Check if key is escape, exit program immediately if it is
    cmp eax, [XK_Esc]
    je exit_program

    ; Unhandled key
    mov rdi, dev_log.key_press_not_recognized
    sub rsp, 8
    call printf
    add rsp, 8

    ret

    ; Left
left:
    mov rdi, dev_log.left
    sub rsp, 8
    call printf
    add rsp, 8

    ; Set snake direction to left
    mov al, [going_left]
    mov [snake_dir], al

    ret

    ; Right
right:
    mov rdi, dev_log.right
    sub rsp, 8
    call printf
    add rsp, 8

    ; Set snake direction to right
    mov al, [going_right]
    mov [snake_dir], al

    ret

    ; Up
up:
    mov rdi, dev_log.up
    sub rsp, 8
    call printf
    add rsp, 8

    ; Set snake direction to up
    mov al, [going_up]
    mov [snake_dir], al

    ret

    ; Down
down:
    mov rdi, dev_log.down
    sub rsp, 8
    call printf
    add rsp, 8

    ; Set snake direction to down
    mov al, [going_down]
    mov [snake_dir], al

    ret

expose: 
    ; Logs TODO: remove in production code
    mov rdi, dev_log.expose
    sub rsp, 8
    call printf
    add rsp, 8

    ; Redraw window
    sub rsp, 8
    call draw
    add rsp, 8

    ; Go back to main loop
    ret

draw: 
    ; Calculate rectangle coordinates
    movzx rax, byte [tile_size]
    mul byte [snake_head_x]
    mov rcx, rax
    movzx rax, byte [tile_size]
    mul byte [snake_head_y]
    mov r8, rax

    ; Fill rectangle
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc_white]
    movzx r9, byte [tile_size]
    push r9
    call XFillRectangle
    pop r9

    ret

exit_program:
    mov rdi, game_log.end
    sub rsp, 8
    call printf
    add rsp, 8

    ; close display
    mov rdi, [display]
    sub rsp, 8
    call XCloseDisplay
    add rsp, 8

    ; exit
    mov rdi, 0
    sub rsp, 8
    call exit
    add rsp, 8








