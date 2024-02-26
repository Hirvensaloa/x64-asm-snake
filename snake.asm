; Snake game in x64 assembly. Works on 64-bit Linux. 

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
extern getrandom
extern malloc
extern realloc
extern free
extern printf
extern exit

section .data

; ----------- Configs -----------

; Snake starting coordinates
start_x db 1
start_y db 1

; Gamemap values
tile_size db 10
map_width dd 64
map_height dd 64

; ------------ ----------- ------------

; Logs
game_log:
    .start db "Game started", 10, 0
    .end db "Game ended! Total score: %d", 10, 0

; Game values   
tick_interval: dq 100 * 1000 ; milliseconds * CLOCKS_PER_MS

; Indicates which way the snake is moving
going_up db 0
going_down db 1
going_left db 2
going_right db 3

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
snake_head_old_x resb 1
snake_head_old_y resb 1
snake_end_x resb 1
snake_end_y resb 1
snake_tail_x resq 1
snake_tail_y resq 1
snake_dir resb 1
snake_length resw 1
food_x resb 1
food_y resb 1
advance_game_flag resb 1


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
    ; Set the old head to the tail. r8b & r9b stores the old tail index 0. 
    mov r14, [snake_tail_x]
    mov r15, [snake_tail_y]
    mov r8b, [r14]
    mov r9b, [r15]
    mov [snake_head_old_x], r8b
    mov [snake_head_old_y], r9b
    mov al, [snake_head_x]
    mov bl, [snake_head_y]
    mov [r14], al
    mov [r15], bl

    ; Move snake to the next position

    mov al, [snake_dir]

check_up:
    cmp al, [going_up]
    jne check_right

    dec byte [snake_head_y]
    jmp correct_underflow_x

check_right: 
    cmp al, [going_right]
    jne check_down

    inc byte [snake_head_x]
    jmp correct_underflow_x

check_down:
    cmp al, [going_down]
    jne go_left

    inc byte [snake_head_y]
    jmp correct_underflow_x

    ; Left is the only option left so no checks needed
go_left:
    dec byte [snake_head_x]

correct_underflow_x:
    ; Check if snake is out of bounds
    xor al, al
    cmp byte [snake_head_x], al
    jns correct_underflow_y

    mov al, byte [map_width]
    mov [snake_head_x], al
    jmp snake_coords_updated

correct_underflow_y:
    ; Check if snake is out of bounds
    xor al, al
    cmp byte [snake_head_y], al
    jns correct_overflow_x

    mov al, byte [map_height]
    mov [snake_head_y], al
    jmp snake_coords_updated

correct_overflow_x:
    ; Check if snake is out of bounds
    movzx eax, byte [snake_head_x]
    cmp eax, [map_width]
    js correct_overflow_y

    mov byte [snake_head_x], 0
    jmp snake_coords_updated

correct_overflow_y:
    ; Check if snake is out of bounds
    movzx eax, byte [snake_head_y]
    cmp eax, [map_height]
    js snake_coords_updated

    mov byte [snake_head_y], 0
    
    ; Game state updated, return
snake_coords_updated:

    ; Check if snake has eaten food
    mov al, [snake_head_x]
    cmp al, [food_x]
    jne move_tail
    mov bl, [snake_head_y]
    cmp bl, [food_y]
    jne move_tail

    inc word [snake_length]

    ; Snake ate food, get new food position
    sub rsp, 8
    call randomize_food_xy
    add rsp, 8

    ; Allocate memory for the new snake tail (length has increased by one). 
    mov rdi, [snake_tail_x]
    movzx rsi, word [snake_length]
    sub rsp, 8
    call realloc
    add rsp, 8
    mov [snake_tail_x], rax

    mov rdi, [snake_tail_y]
    movzx rsi, word [snake_length]
    sub rsp, 8
    call realloc
    add rsp, 8
    mov [snake_tail_y], rax

move_tail:
    ; loop through the snake tail. Move [i] -> [i + 1], [i + 1] -> [i + 2], etc.
    mov r14, [snake_tail_x]
    mov r15, [snake_tail_y]
    mov r8b, [snake_head_old_x]
    mov r9b, [snake_head_old_y]

    xor ch, ch ; index
tail_loop:
    inc ch
    cmp ch, [snake_length]
    jge update_end

    inc r14
    inc r15
    mov al, [r14]
    mov bl, [r15]
    mov [r14], r8b
    mov [r15], r9b
    mov r8b, al
    mov r9b, bl
    jmp tail_loop

update_end:
    ; Update the new snake end
    mov r8b, byte [r14]
    mov r9b, byte [r15]
    mov [snake_end_x], r8b
    mov [snake_end_y], r9b

game_state_updated:

    ; Check if snake has hit itself
    mov bl, [snake_head_x]
    mov cl, [snake_head_y]
    sub rsp, 8
    call collides_with_snake_tail
    add rsp, 8
    test al, al
    jnz exit_program

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
    mov bl, [start_x]
    mov cl, [start_y]
    mov dl, [going_right]
    mov [snake_head_x], bl
    mov [snake_head_y], cl
    mov [snake_end_x], bl
    mov [snake_end_y], cl
    mov [snake_dir], dl
    mov word [snake_length], 1
    ; Allocate memory for snake tail
    movzx rdi, word [snake_length]
    sub rsp, 8
    call malloc
    add rsp, 8
    mov r14, rax
    sub rsp, 8
    call malloc
    add rsp, 8
    mov r15, rax
    ; Initialize snake tail
    mov [r14], bl
    mov [r15], cl
    mov [snake_tail_x], r14
    mov [snake_tail_y], r15

    ; Initialize food position
    call randomize_food_xy

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

    cmp byte [advance_game_flag], 0
    jne draw_new

    ; Update game state
    sub rsp, 8
    call advance_game
    add rsp, 8

draw_new:
    mov byte [advance_game_flag], 0

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

    ret

    ; Key press
key_press:
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

    ; Unhandled key press

    ret

left:
    ; Set snake direction to left
    mov al, [going_left]
    mov [snake_dir], al

    ret

right:
    ; Set snake direction to right
    mov al, [going_right]
    mov [snake_dir], al

    ret

up:
    ; Set snake direction to up
    mov al, [going_up]
    mov [snake_dir], al

    ret

down:
    ; Set snake direction to down
    mov al, [going_down]
    mov [snake_dir], al

    ret

expose: 
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

    ; Calculate food coordinates
    movzx rax, byte [tile_size]
    mul byte [food_x]
    mov rcx, rax
    movzx rax, byte [tile_size]
    mul byte [food_y]
    mov r8, rax

    ; Fill rectangle
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc_white]
    movzx r9, byte [tile_size]
    push r9
    call XFillRectangle
    pop r9

    ; Calculate end coordinates to be erased
    movzx rax, byte [tile_size]
    mul byte [snake_end_x]
    mov rcx, rax
    movzx rax, byte [tile_size]
    mul byte [snake_end_y]
    mov r8, rax

    ; Fill rectangle
    mov rdi, [display]
    mov rsi, [window]
    mov rdx, [gc_black]
    movzx r9, byte [tile_size]
    push r9
    call XFillRectangle
    pop r9

    ret

exit_program:
    mov rdi, game_log.end
    movzx rsi, word [snake_length]
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


; ----------- Utility functions -----------

; Randomizes food position, returns void
randomize_food_xy:
	mov	rdi, food_x
	mov rsi, 1
	xor	rdx, rdx
    sub rsp, 8
	call getrandom
	add rsp, 8

    ; Zero two most significant bits
    shl byte [food_x], 2
    shr byte [food_x], 2

	mov	rdi, food_y
	mov rsi, 1
	xor	rdx, rdx
    sub rsp, 8
	call getrandom
	add rsp, 8

    ; Zero two most significant bits
    shl byte [food_y], 2
    shr byte [food_y], 2

    ; If food is on the snake head, randomize again
    mov bl, [food_x]
    mov cl, [food_y]
    sub rsp, 8
    call collides_with_snake_head
    add rsp, 8
    test al, al
    jnz randomize_food_xy

    ; If food is on the snake end, randomize again
    sub rsp, 8
    call collides_with_snake_tail
    add rsp, 8
    test al, al
    jnz randomize_food_xy

    ret

; Check if coordinates in bl (x) and cl (y) are in snake head, return al = 1 if they are, 0 otherwise
collides_with_snake_head:
    cmp bl, [snake_head_x]
    jne doesnt_collide
    cmp cl, [snake_head_y]
    jne doesnt_collide

; Check if coordinates in bl (x) and cl (y) are in snake tail, return al = 1 if they are, 0 otherwise
collides_with_snake_tail:
    xor dl, dl
    mov r14, [snake_tail_x]
    mov r15, [snake_tail_y]

    dec r14
    dec r15
    dec dl
check_tail: 
    inc r14
    inc r15
    inc dl
    cmp dl, [snake_length]
    jge doesnt_collide

    cmp bl, [r14]
    jne check_tail
    cmp cl, [r15]
    jne check_tail

collides: 
    mov al, 1
    ret

doesnt_collide: 
    mov al, 0
    ret





