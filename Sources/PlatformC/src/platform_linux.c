#ifdef __linux__

#include "platform.h"
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// ---- GLFW Key Code Constants ----

#define AGILIS_KEY_SPACE        32
#define AGILIS_KEY_0            48
#define AGILIS_KEY_9            57
#define AGILIS_KEY_A            65
#define AGILIS_KEY_Z            90
#define AGILIS_KEY_ESCAPE       256
#define AGILIS_KEY_ENTER        257
#define AGILIS_KEY_TAB          258
#define AGILIS_KEY_BACKSPACE    259
#define AGILIS_KEY_INSERT       260
#define AGILIS_KEY_DELETE       261
#define AGILIS_KEY_RIGHT        262
#define AGILIS_KEY_LEFT         263
#define AGILIS_KEY_DOWN         264
#define AGILIS_KEY_UP           265
#define AGILIS_KEY_F1           290
#define AGILIS_KEY_F12          301
#define AGILIS_KEY_LEFT_SHIFT   340
#define AGILIS_KEY_LEFT_CONTROL 341
#define AGILIS_KEY_LEFT_ALT     342
#define AGILIS_KEY_RIGHT_SHIFT  344
#define AGILIS_KEY_RIGHT_CONTROL 345
#define AGILIS_KEY_RIGHT_ALT    346

#define MAX_KEYS 512
#define MAX_MOUSE_BUTTONS 3
#define MAX_GAMEPADS 4

// ---- X11 KeySym -> GLFW Key Mapping ----

static int xkeysym_to_agilis(KeySym ks) {
    // Letters
    if (ks >= XK_a && ks <= XK_z) return AGILIS_KEY_A + (int)(ks - XK_a);
    if (ks >= XK_A && ks <= XK_Z) return AGILIS_KEY_A + (int)(ks - XK_A);
    // Digits
    if (ks >= XK_0 && ks <= XK_9) return AGILIS_KEY_0 + (int)(ks - XK_0);
    // Function keys
    if (ks >= XK_F1 && ks <= XK_F12) return AGILIS_KEY_F1 + (int)(ks - XK_F1);

    switch (ks) {
        case XK_space:       return AGILIS_KEY_SPACE;
        case XK_Return:      return AGILIS_KEY_ENTER;
        case XK_Escape:      return AGILIS_KEY_ESCAPE;
        case XK_BackSpace:   return AGILIS_KEY_BACKSPACE;
        case XK_Tab:         return AGILIS_KEY_TAB;
        case XK_Delete:      return AGILIS_KEY_DELETE;
        case XK_Insert:      return AGILIS_KEY_INSERT;
        case XK_Right:       return AGILIS_KEY_RIGHT;
        case XK_Left:        return AGILIS_KEY_LEFT;
        case XK_Down:        return AGILIS_KEY_DOWN;
        case XK_Up:          return AGILIS_KEY_UP;
        case XK_Shift_L:     return AGILIS_KEY_LEFT_SHIFT;
        case XK_Shift_R:     return AGILIS_KEY_RIGHT_SHIFT;
        case XK_Control_L:   return AGILIS_KEY_LEFT_CONTROL;
        case XK_Control_R:   return AGILIS_KEY_RIGHT_CONTROL;
        case XK_Alt_L:       return AGILIS_KEY_LEFT_ALT;
        case XK_Alt_R:       return AGILIS_KEY_RIGHT_ALT;
        default:             return -1;
    }
}

// ---- Platform Window ----

struct PlatformWindow {
    Display* display;
    Window x_window;
    Atom wm_delete;
    bool should_close;
    bool resized;
    int width;
    int height;

    bool keys[MAX_KEYS];
    uint32_t char_pressed;

    bool mouse_buttons[MAX_MOUSE_BUTTONS];
    float mouse_x, mouse_y;
    float mouse_dx, mouse_dy;
    float mouse_scroll;
    float prev_mouse_x, prev_mouse_y;
    bool mouse_initialized;

    int target_fps;
    bool vsync;
};

// ---- Window Lifecycle ----

PlatformWindow* platform_create_window(const PlatformWindowConfig* config) {
    PlatformWindow* w = (PlatformWindow*)calloc(1, sizeof(PlatformWindow));
    if (!w) return NULL;

    w->display = XOpenDisplay(NULL);
    if (!w->display) {
        free(w);
        return NULL;
    }

    int screen = DefaultScreen(w->display);
    Window root = RootWindow(w->display, screen);

    w->x_window = XCreateSimpleWindow(
        w->display, root,
        0, 0, config->width, config->height, 0,
        BlackPixel(w->display, screen),
        BlackPixel(w->display, screen)
    );

    // Set window title
    XStoreName(w->display, w->x_window, config->title);

    // Request close events
    w->wm_delete = XInternAtom(w->display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(w->display, w->x_window, &w->wm_delete, 1);

    // Select input events
    XSelectInput(w->display, w->x_window,
        KeyPressMask | KeyReleaseMask |
        ButtonPressMask | ButtonReleaseMask |
        PointerMotionMask | StructureNotifyMask);

    // Set size hints if not resizable
    if (!config->resizable) {
        XSizeHints hints;
        hints.flags = PMinSize | PMaxSize;
        hints.min_width = config->width;
        hints.min_height = config->height;
        hints.max_width = config->width;
        hints.max_height = config->height;
        XSetWMNormalHints(w->display, w->x_window, &hints);
    }

    w->width = config->width;
    w->height = config->height;
    w->target_fps = config->target_fps;
    w->vsync = config->vsync;

    XMapWindow(w->display, w->x_window);
    XFlush(w->display);

    return w;
}

void platform_destroy_window(PlatformWindow* w) {
    if (!w) return;
    if (w->x_window) XDestroyWindow(w->display, w->x_window);
    if (w->display) XCloseDisplay(w->display);
    free(w);
}

bool platform_should_close(PlatformWindow* w) {
    return w ? w->should_close : true;
}

void platform_poll_events(PlatformWindow* w) {
    if (!w) return;

    // Compute mouse delta
    if (w->mouse_initialized) {
        w->mouse_dx = w->mouse_x - w->prev_mouse_x;
        w->mouse_dy = w->mouse_y - w->prev_mouse_y;
    } else {
        w->mouse_dx = 0;
        w->mouse_dy = 0;
        w->mouse_initialized = true;
    }
    w->prev_mouse_x = w->mouse_x;
    w->prev_mouse_y = w->mouse_y;

    w->mouse_scroll = 0;
    w->char_pressed = 0;
    w->resized = false;

    while (XPending(w->display)) {
        XEvent event;
        XNextEvent(w->display, &event);

        switch (event.type) {
            case KeyPress: {
                KeySym ks = XLookupKeysym(&event.xkey, 0);
                int key = xkeysym_to_agilis(ks);
                if (key >= 0 && key < MAX_KEYS)
                    w->keys[key] = true;

                // Text input
                char buf[8];
                int len = XLookupString(&event.xkey, buf, sizeof(buf), NULL, NULL);
                if (len > 0 && (unsigned char)buf[0] >= 32)
                    w->char_pressed = (uint32_t)(unsigned char)buf[0];
                break;
            }
            case KeyRelease: {
                // Check for auto-repeat (next event is KeyPress with same time)
                if (XEventsQueued(w->display, QueuedAfterReading)) {
                    XEvent next;
                    XPeekEvent(w->display, &next);
                    if (next.type == KeyPress &&
                        next.xkey.time == event.xkey.time &&
                        next.xkey.keycode == event.xkey.keycode) {
                        // Auto-repeat, skip both
                        XNextEvent(w->display, &next);
                        break;
                    }
                }
                KeySym ks = XLookupKeysym(&event.xkey, 0);
                int key = xkeysym_to_agilis(ks);
                if (key >= 0 && key < MAX_KEYS)
                    w->keys[key] = false;
                break;
            }
            case ButtonPress:
                if (event.xbutton.button == Button1) w->mouse_buttons[0] = true;
                else if (event.xbutton.button == Button3) w->mouse_buttons[1] = true;
                else if (event.xbutton.button == Button2) w->mouse_buttons[2] = true;
                else if (event.xbutton.button == Button4) w->mouse_scroll += 1.0f;
                else if (event.xbutton.button == Button5) w->mouse_scroll -= 1.0f;
                break;
            case ButtonRelease:
                if (event.xbutton.button == Button1) w->mouse_buttons[0] = false;
                else if (event.xbutton.button == Button3) w->mouse_buttons[1] = false;
                else if (event.xbutton.button == Button2) w->mouse_buttons[2] = false;
                break;
            case MotionNotify:
                w->mouse_x = (float)event.xmotion.x;
                w->mouse_y = (float)event.xmotion.y;
                break;
            case ConfigureNotify:
                if (event.xconfigure.width != w->width ||
                    event.xconfigure.height != w->height) {
                    w->width = event.xconfigure.width;
                    w->height = event.xconfigure.height;
                    w->resized = true;
                }
                break;
            case ClientMessage:
                if ((Atom)event.xclient.data.l[0] == w->wm_delete)
                    w->should_close = true;
                break;
        }
    }
}

int platform_window_width(PlatformWindow* w) { return w ? w->width : 0; }
int platform_window_height(PlatformWindow* w) { return w ? w->height : 0; }
bool platform_window_resized(PlatformWindow* w) { return w ? w->resized : false; }

// ---- EGL Surface Hooks ----

void* platform_native_display(PlatformWindow* w) {
    return w ? (void*)w->display : NULL;
}

void* platform_native_window(PlatformWindow* w) {
    return w ? (void*)(uintptr_t)w->x_window : NULL;
}

// ---- Keyboard ----

bool platform_is_key_down(PlatformWindow* w, int key) {
    if (!w || key < 0 || key >= MAX_KEYS) return false;
    return w->keys[key];
}

uint32_t platform_char_pressed(PlatformWindow* w) {
    return w ? w->char_pressed : 0;
}

// ---- Mouse ----

bool platform_is_mouse_button_down(PlatformWindow* w, int button) {
    if (!w || button < 0 || button >= MAX_MOUSE_BUTTONS) return false;
    return w->mouse_buttons[button];
}

float platform_mouse_x(PlatformWindow* w) { return w ? w->mouse_x : 0; }
float platform_mouse_y(PlatformWindow* w) { return w ? w->mouse_y : 0; }
float platform_mouse_dx(PlatformWindow* w) { return w ? w->mouse_dx : 0; }
float platform_mouse_dy(PlatformWindow* w) { return w ? w->mouse_dy : 0; }
float platform_mouse_scroll(PlatformWindow* w) { return w ? w->mouse_scroll : 0; }

// ---- Gamepad (stub — TODO: evdev/udev joystick) ----

bool platform_is_gamepad_available(int index) { return false; }
bool platform_is_gamepad_button_down(int index, int button) { return false; }
float platform_gamepad_axis(int index, int axis) { return 0; }
const char* platform_gamepad_name(int index) { return NULL; }

// ---- Frame Timing ----

void platform_set_target_fps(PlatformWindow* w, int fps) {
    if (w) w->target_fps = fps;
}

void platform_set_vsync(PlatformWindow* w, bool enabled) {
    if (w) w->vsync = enabled;
}

#endif // __linux__
